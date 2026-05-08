import multiprocessing
import traceback
import textwrap
import types
import json
import io
import os
import sys
import logging
from typing import cast

from src.errors import (
    TaskCancelledError,
    TaskKilledError,
    TaskResultMissingError,
    TaskResultReadError,
    TaskRuntimeError,
    TaskTimeoutError,
    TaskSubprocessFailedError,
    SecurityViolationError,
)
from src.import_validation import validate_module_import
from src.config.security_config import SecurityConfig

from src.message_types.broker import NodeMode, Items, Query
from src.message_types.pipe import (
    PipeResultMessage,
    PipeErrorMessage,
    TaskErrorInfo,
    PrintArgs,
)
from src.pipe_reader import PipeReader
from src.constants import (
    EXECUTOR_CIRCULAR_REFERENCE_KEY,
    EXECUTOR_USER_OUTPUT_KEY,
    EXECUTOR_ALL_ITEMS_FILENAME,
    EXECUTOR_PER_ITEM_FILENAME,
    SIGTERM_EXIT_CODE,
    SIGKILL_EXIT_CODE,
    PIPE_MSG_PREFIX_LENGTH,
)

from multiprocessing.context import ForkServerProcess
from multiprocessing.connection import Connection

logger = logging.getLogger(__name__)

MULTIPROCESSING_CONTEXT = multiprocessing.get_context("forkserver")
MAX_PRINT_ARGS_ALLOWED = 100

type PipeConnection = Connection


class TaskExecutor:
    """Responsible for executing Python code tasks in isolated subprocesses."""

    @staticmethod
    def create_process(
        code: str,
        node_mode: NodeMode,
        items: Items,
        security_config: SecurityConfig,
        query: Query = None,
    ) -> tuple[ForkServerProcess, PipeConnection, PipeConnection]:
        fn = (
            TaskExecutor._all_items
            if node_mode == "all_items"
            else TaskExecutor._per_item
        )

        read_conn, write_conn = MULTIPROCESSING_CONTEXT.Pipe(duplex=False)

        process = MULTIPROCESSING_CONTEXT.Process(
            target=fn,
            args=(
                code,
                items,
                write_conn,
                security_config,
                query,
            ),
        )

        return process, read_conn, write_conn

    @staticmethod
    def execute_process(
        process: ForkServerProcess,
        read_conn: PipeConnection,
        write_conn: PipeConnection,
        task_timeout: int,
        continue_on_fail: bool,
    ) -> tuple[Items, PrintArgs, int]:
        print_args: PrintArgs = []

        pipe_reader = PipeReader(read_conn.fileno(), read_conn)
        pipe_reader.start()

        try:
            try:
                process.start()
            except Exception as e:
                raise TaskSubprocessFailedError(-1, e)
            finally:
                write_conn.close()

            process.join(timeout=task_timeout)

            if process.is_alive():
                TaskExecutor.stop_process(process)
                raise TaskTimeoutError(task_timeout)

            if process.exitcode == SIGTERM_EXIT_CODE:
                raise TaskCancelledError()

            if process.exitcode == SIGKILL_EXIT_CODE:
                raise TaskKilledError()

            if process.exitcode != 0:
                assert process.exitcode is not None
                raise TaskSubprocessFailedError(process.exitcode)

            pipe_reader.join(timeout=task_timeout)

            if pipe_reader.is_alive():
                try:
                    read_conn.close()
                except Exception:
                    pass
                raise TaskResultReadError(
                    TimeoutError(f"Pipe reader timed out after {task_timeout}s")
                )

            if pipe_reader.error:
                raise TaskResultReadError(pipe_reader.error)

            if pipe_reader.pipe_message is None:
                raise TaskResultMissingError()

            returned = pipe_reader.pipe_message

            if "error" in returned:
                error_msg = cast(PipeErrorMessage, returned)
                raise TaskRuntimeError(error_msg["error"])

            if "result" not in returned:
                raise TaskResultMissingError()

            result_msg = cast(PipeResultMessage, returned)
            result = result_msg["result"]
            print_args = result_msg.get("print_args", [])
            assert pipe_reader.message_size is not None
            result_size_bytes = pipe_reader.message_size

            return result, print_args, result_size_bytes

        except Exception as e:
            if continue_on_fail:
                return [{"json": {"error": str(e)}}], print_args, 0
            raise

    @staticmethod
    def stop_process(process: ForkServerProcess | None):
        if process is None or not process.is_alive():
            return

        try:
            process.terminate()
            process.join(timeout=1)

            if process.is_alive():
                process.kill()
                process.join()
        except (ProcessLookupError, ConnectionError, BrokenPipeError):
            pass

    @staticmethod
    def _all_items(
        raw_code: str,
        items: Items,
        write_conn,
        security_config: SecurityConfig,
        query: Query = None,
    ):
        if security_config.runner_env_deny:
            os.environ.clear()

        TaskExecutor._sanitize_sys_modules(security_config)

        print_args: PrintArgs = []
        sys.stderr = stderr_capture = io.StringIO()

        try:
            wrapped_code = TaskExecutor._wrap_code(raw_code)
            compiled_code = compile(wrapped_code, EXECUTOR_ALL_ITEMS_FILENAME, "exec")

            globals = {
                "_items": items,
                "_query": query,
                "print": TaskExecutor._create_custom_print(print_args),
            }

            exec(compiled_code, globals)

            result = cast(Items, globals[EXECUTOR_USER_OUTPUT_KEY])
            TaskExecutor._put_result(write_conn.fileno(), result, print_args)

        except BaseException as e:
            TaskExecutor._put_error(
                write_conn.fileno(), e, stderr_capture.getvalue(), print_args
            )

    @staticmethod
    def _per_item(
        raw_code: str,
        items: Items,
        write_conn,
        security_config: SecurityConfig,
        _query: Query = None,
    ):
        if security_config.runner_env_deny:
            os.environ.clear()

        TaskExecutor._sanitize_sys_modules(security_config)

        print_args: PrintArgs = []
        sys.stderr = stderr_capture = io.StringIO()

        try:
            wrapped_code = TaskExecutor._wrap_code(raw_code)
            compiled_code = compile(wrapped_code, EXECUTOR_PER_ITEM_FILENAME, "exec")

            custom_print = TaskExecutor._create_custom_print(print_args)

            result: Items = []
            for index, item in enumerate(items):
                globals = {
                    "_item": item,
                    "print": custom_print,
                }

                exec(compiled_code, globals)

                user_output = globals[EXECUTOR_USER_OUTPUT_KEY]
                if isinstance(user_output, list):
                    result.extend(user_output)
                else:
                    result.append(user_output)

            TaskExecutor._put_result(write_conn.fileno(), result, print_args)

        except BaseException as e:
            TaskExecutor._put_error(
                write_conn.fileno(), e, stderr_capture.getvalue(), print_args
            )

    @staticmethod
    def _wrap_code(code: str) -> str:
        indented = textwrap.indent(code, "    ")
        return f"def __n8n__runner__():\n{indented}\n\n{EXECUTOR_USER_OUTPUT_KEY} = __n8n__runner__()"

    @staticmethod
    def _put_result(write_fd: int, result: Items, print_args: PrintArgs):
        payload = {"result": result, "print_args": print_args}
        os.write(write_fd, TaskExecutor._serialize_result(payload))

    @staticmethod
    def _put_error(write_fd: int, error: BaseException, stderr: str, print_args: PrintArgs):
        error_info: TaskErrorInfo = {
            "name": error.__class__.__name__,
            "message": str(error),
            "stack": traceback.format_exc(),
            "stderr": stderr,
        }
        payload = {"error": error_info, "print_args": print_args}
        os.write(write_fd, TaskExecutor._serialize_result(payload))

    @staticmethod
    def _serialize_result(data) -> bytes:
        raw = json.dumps(data, default=TaskExecutor._json_default).encode("utf-8")
        return len(raw).to_bytes(PIPE_MSG_PREFIX_LENGTH, "big") + raw

    @staticmethod
    def _json_default(obj):
        if isinstance(obj, types.GeneratorType):
            return list(obj)
        raise TypeError(f"Object of type {obj.__class__.__name__} is not JSON serializable")

    @staticmethod
    def _create_custom_print(print_args: PrintArgs):
        def _print(*args, **kwargs):
            if len(args) > MAX_PRINT_ARGS_ALLOWED:
                raise SecurityViolationError(
                    f"print() supports at most {MAX_PRINT_ARGS_ALLOWED} args"
                )
            print_args.append([str(a) for a in args])
        return _print

    @staticmethod
    def _filter_builtins(security_config: SecurityConfig):
        return __builtins__

    @staticmethod
    def _sanitize_sys_modules(security_config: SecurityConfig):
        return None
