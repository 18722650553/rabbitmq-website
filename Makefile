SHELL := bash# we want bash behaviour in all shell invocations

RED := $(shell tput setaf 1)
GREEN := $(shell tput setaf 2)
YELLOW := $(shell tput setaf 3)
BOLD := $(shell tput bold)
NORMAL := $(shell tput sgr0)

ifneq (4,$(firstword $(sort $(MAKE_VERSION) 4)))
  $(error $(BOLD)$(RED)GNU Make v4 or above is required$(NORMAL). On macOS please install with $(BOLD)brew install make$(NORMAL) and use $(BOLD)gmake$(NORMAL) instead of make)
endif

PLATFORM := $(shell uname)

ifeq ($(PLATFORM),Darwin)
OPEN := open

LIBXSLT := /usr/local/opt/libxslt
export PATH := $(LIBXSLT)/bin:$(PATH)
export LDFLAGS := "-L$(LIBXSLT)/lib"
export CPPFLAGS := "-I$(LIBXSLT)/include"

PYTHON := /usr/local/bin/python3
PIPENV := /usr/local/bin/pipenv
endif

ifeq ($(PLATFORM),Linux)
OPEN ?= xdg-open

LIBXSLT ?= /usr/include/libxslt

PYTHON ?= /usr/bin/python3
PIPENV ?= /usr/bin/pipenv
endif

export LC_ALL := en_US.UTF-8
export LANG := en_US.UTF-8

TCP_PORT := 8191

### TARGETS ###
#
.DEFAULT_GOAL = help

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-16s\033[0m %s\n", $$1, $$2}'

$(LIBXSLT):
ifeq ($(PLATFORM),Darwin)
	@brew install libxslt
endif

$(PYTHON):
ifeq ($(PLATFORM),Darwin)
	@brew install python
endif

$(PIPENV): $(PYTHON)
ifeq ($(PLATFORM),Darwin)
  ifeq ($(wildcard $(PIPENV_BIN)),)
	@brew install pipenv
  endif
endif

deps: $(LIBXSLT) $(PIPENV)
	@$(PIPENV) --python $(PYTHON) --venv || $(PIPENV) --python $(PYTHON) install

preview: deps ## Preview docs
	@$(PIPENV) run ./driver.py

browse: ## Open docs in browser
	@$(OPEN) http://localhost:$(TCP_PORT)

# noop, required by rabbitmq-public-umbrella clean-subrepos make target
clean:
	@

live:
	@browser-sync start --proxy http://localhost:$(TCP_PORT) --files site --no-notify --no-open || \
	  (echo "See $(BOLD)https://www.browsersync.io/$(NORMAL) for more info" && exit 1)

ifeq ($(PLATFORM),Darwin)
NPM ?= /usr/local/bin/npm
$(NPM):
	brew install node
else
NPM ?= /usr/bin/npm
$(NPM):
	$(error Please install NPM/node.js for your OS: https://nodejs.org/en/download/)
endif
WRANGLER ?= /usr/local/bin/wrangler
$(WRANGLER): | $(NPM)
	$(NPM) install -g @cloudflare/wrangler
WRANGLER_CONFIG = $(HOME)/.wrangler/config/default.toml
$(WRANGLER_CONFIG): | $(WRANGLER)
	$(WRANGLER) config
LIVE_SERVER ?= /usr/local/bin/live-server
$(LIVE_SERVER): | $(NPM)
	$(NPM) install -g live-server

site-preview: | $(LIVE_SERVER)
	$(LIVE_SERVER) site

site-stage: | $(WRANGLER)
	$(WRANGLER) publish

site-live: | $(WRANGLER)
	$(WRANGLER) publish --env production
