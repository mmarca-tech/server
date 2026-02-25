SHELL := /bin/bash

.PHONY: bootstrap init pull up down logs openclaw-install openclaw-onboard security-check docker-install local-llm-install clawdbot-local clawdbot-openai master-setup ha-public-enable

bootstrap:
	./scripts/bootstrap-host.sh

init:
	./scripts/init-env.sh

pull:
	./scripts/pull-all.sh

up:
	./scripts/up-all.sh

down:
	./scripts/down-all.sh

logs:
	@if [ -z "$(stack)" ]; then \
		echo "Usage: make logs stack=<stack> [service=<service>]"; \
		exit 1; \
	fi
	./scripts/logs.sh "$(stack)" "$(service)"

openclaw-install:
	./scripts/install-openclaw-host.sh

openclaw-onboard:
	./scripts/openclaw-onboard.sh

security-check:
	./scripts/security-check.sh

docker-install:
	./scripts/install-docker-host.sh

local-llm-install:
	./scripts/install-local-llm.sh

clawdbot-local:
	./scripts/connect-clawdbot-local.sh

clawdbot-openai:
	./scripts/connect-clawdbot-openai.sh

master-setup:
	./scripts/master-setup.sh

ha-public-enable:
	./scripts/enable-ha-public.sh
