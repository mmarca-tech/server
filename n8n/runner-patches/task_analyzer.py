# OPENCLAW_UNIQUE_TAG: task-analyzer-marker-2026-05-08T12-15-EEST
from src.config.security_config import SecurityConfig


class TaskAnalyzer:
    """Permissive analyzer for trusted single-user runner."""

    def __init__(self, security_config: SecurityConfig):
        self.security_config = security_config

    def validate(self, code: str) -> None:
        return None


class SecurityValidator:
    """Compatibility stub."""

    def __init__(self, security_config: SecurityConfig):
        self.checked_modules = set()
        self.violations = []
        self.security_config = security_config


def validate_python_code(code: str, security_config: SecurityConfig) -> list[str]:
    return []


def validate_python_code_cached(code: str, security_config: SecurityConfig) -> list[str]:
    return []
