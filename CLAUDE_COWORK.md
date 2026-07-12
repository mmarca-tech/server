# Claude Cowork Operator Workflow

Claude Cowork is not installed on the VPS and has no privileged server token,
daemon, connector, or management endpoint. Use it from a supported Claude
surface to review this repository, prepare configuration changes, summarize
health reports, and maintain runbooks.

Server changes remain explicit:

1. Review or prepare the change locally.
2. Run `scripts/test-infra.sh`.
3. Commit and transfer the reviewed repository state.
4. Use SSH to run `deploy.sh`, `stack.sh`, or another documented command.
5. Review runtime verification and logs.

For direct terminal-based agent work, use a separately authorized development
tool from an administrator workstation. Do not expose Docker, SSH credentials,
or a generic command-execution API to Cowork.

