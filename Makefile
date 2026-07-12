SHELL := /bin/bash

.PHONY: deploy-check deploy resume up down pull status logs verify backup restore test

deploy-check:
	sudo DEPLOY_CONFIG="$${DEPLOY_CONFIG:-/root/server.env}" ./scripts/deploy.sh --check

deploy:
	sudo DEPLOY_CONFIG="$${DEPLOY_CONFIG:-/root/server.env}" ./scripts/deploy.sh

resume:
	sudo DEPLOY_CONFIG="$${DEPLOY_CONFIG:-/root/server.env}" ./scripts/deploy.sh --resume

up:
	./scripts/stack.sh up

down:
	./scripts/stack.sh down

pull:
	./scripts/stack.sh pull

status:
	./scripts/stack.sh status

logs:
	@test -n "$(stack)" || { echo "Usage: make logs stack=<name>"; exit 1; }
	./scripts/stack.sh logs "$(stack)"

verify:
	./scripts/stack.sh verify

backup:
	./scripts/stack.sh backup

restore:
	@test -n "$(backup)" || { echo "Usage: make restore backup=/srv/backups/server-infra-TIMESTAMP"; exit 1; }
	./scripts/stack.sh restore "$(backup)" --confirm

test:
	./scripts/test-infra.sh
