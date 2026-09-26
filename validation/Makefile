# validation/Makefile — top-level entry for post-boot feature validation.
#
# Usage:
#   make list                          # show suites/groups
#   make setup                         # venv + paramiko
#   make validate HOST=192.168.1.50    # password prompted (or PASS=...)
#
# Optional variables: USER= PASS= KEY= PORT= GROUPS= ONLY= EXCLUDE= STRICT=1
# Credentials may also come from VALIDATION_HOST / VALIDATION_USER /
# VALIDATION_PASSWORD / VALIDATION_KEY environment variables.

SHELL := /bin/bash
PY ?= python3
VENV := .venv
VENV_PY := $(VENV)/bin/python
RUNNER := $(shell test -x $(VENV_PY) && echo $(VENV_PY) || echo $(PY)) -m acadia_validation

HOST ?= $(VALIDATION_HOST)
USER ?= $(VALIDATION_USER)
PASS ?= $(VALIDATION_PASSWORD)
KEY  ?= $(VALIDATION_KEY)
PORT ?= 22

ARGS := --host '$(HOST)' --port $(PORT)
ifneq ($(strip $(USER)),)
ARGS += --user '$(USER)'
endif
ifneq ($(strip $(PASS)),)
ARGS += --password '$(PASS)'
endif
ifneq ($(strip $(KEY)),)
ARGS += --key '$(KEY)'
endif
ifneq ($(strip $(MANIFEST)),)
ARGS += --manifest '$(MANIFEST)'
endif
ifneq ($(strip $(GROUPS)),)
ARGS += --groups '$(GROUPS)'
endif
ifneq ($(strip $(EXCLUDE)),)
ARGS += --exclude-groups '$(EXCLUDE)'
endif
ifneq ($(strip $(ONLY)),)
ARGS += --only '$(ONLY)'
endif
ifeq ($(strip $(STRICT)),1)
ARGS += --strict
endif

PYRUN := $(shell test -x $(VENV_PY) && echo $(VENV_PY) || echo $(PY))

.PHONY: help setup list validate smoke lint report report-diff clean manifest serial validate-all

manifest: ## Generate build manifest from newest deploy dir  (DEPLOY_DIR= optional)
	@bash tools/generate-manifest.sh $(if $(DEPLOY_DIR),'$(DEPLOY_DIR)',)

serial: ## Passive boot-chain check over UART  (PORT=/dev/ttyUSB0 BAUD=115200 TIMEOUT=120 [REBOOT_CMD=...])
	@if [ -z '$(PORT)' ]; then echo "usage: make serial PORT=/dev/ttyUSB0 [BAUD=115200] [TIMEOUT=120] [REBOOT_CMD='...']"; exit 2; fi
	@$(PYRUN) -m acadia_validation.serial_console --port '$(PORT)' --baud $(or $(BAUD),115200) --timeout $(or $(TIMEOUT),120) $(if $(REBOOT_CMD),--reboot-command '$(REBOOT_CMD)',)

validate-all: ## Fleet: validate every INVENTORY line (host user password [key])  (PARALLEL=2 MANIFEST= STRICT=1)
	@if [ -z '$(INVENTORY)' ]; then echo "usage: make validate-all INVENTORY=fleet.txt [PARALLEL=2] [GROUPS=] [ONLY=] [MANIFEST=]"; exit 2; fi
	@$(RUNNER) --inventory '$(INVENTORY)' \
		$(if $(PARALLEL),--parallel $(PARALLEL),) \
		$(if $(GROUPS),--groups '$(GROUPS)',) \
		$(if $(ONLY),--only '$(ONLY)',) \
		$(if $(MANIFEST),--manifest '$(MANIFEST)',) \
		$(if $(filter 1,$(STRICT)),--strict,)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS=":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

setup: ## Create venv and install paramiko
	$(PY) -m venv $(VENV)
	$(VENV_PY) -m pip install --quiet --upgrade pip
	$(VENV_PY) -m pip install --quiet -r requirements.txt
	@echo "setup: ok ($(VENV))"

list: ## List feature suites and groups (no target needed)
	$(RUNNER) --list

validate: ## Validate a booted target  (HOST= [USER= PASS= KEY= GROUPS= ONLY= EXCLUDE= STRICT=1])
	@if [ -z '$(HOST)' ]; then echo "usage: make validate HOST=<ip> [PASS=...]"; exit 2; fi
	@$(RUNNER) $(ARGS)

smoke: ## Fast core subset (boot, storage, packages, services, network)
	@if [ -z '$(HOST)' ]; then echo "usage: make smoke HOST=<ip> [PASS=...]"; exit 2; fi
	@$(RUNNER) $(ARGS) --groups core

lint: ## Byte-compile all suite code (syntax gate)
	@$(PY) -m compileall -q acadia_validation \
		&& echo "lint: ok" || exit 1

report: ## Print the most recent Markdown report
	@latest=$$(ls -t reports/*.md 2>/dev/null | head -1); \
	if [ -n "$$latest" ]; then cat "$$latest"; \
	else echo "no reports yet — run make validate HOST=..."; exit 1; fi

report-diff: ## Compare two reports; exit 1 on regressions  (A=old.json B=new.json)
	@if [ -z '$(A)' ] || [ -z '$(B)' ]; then echo "usage: make report-diff A=old.json B=new.json"; exit 2; fi
	@$(RUNNER) --diff '$(A)' '$(B)'

clean: ## Remove generated reports
	rm -rf reports
	@echo "clean: reports removed"