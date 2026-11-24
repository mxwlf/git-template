# Makefile for git-template
#
# Provides one-command setup for this repository's shared git configuration
# and pre-commit hooks.
#
# Usage:
#   make            # same as `make help`
#   make help       # list available targets
#   make init       # reconcile branches, then run local setup
#   make setup      # install tooling and configure local Git hooks
#   make reconcile-branches  # reconcile main and develop on origin
#   make ci         # run the pull-request checks
#   make acceptance # run post-integration acceptance checks
#   make lint       # run read-only repository hooks
#   make clean      # remove the local virtualenv
#
#   make rulesets-apply    # rebuild this repo's GitHub branch protection
#   make rulesets-diff     # check live branch protection against the repo
#   make rulesets-export   # save live branch protection into the repo
#
# Requirements:
#   - GNU make, git, and a POSIX shell (on Windows: Git Bash or WSL).
#   - A Python interpreter >= $(MIN_PYTHON) reachable as `python3`. It runs
#     branch reconciliation and creates the virtualenv. Use any installation
#     (system, Homebrew, pyenv, ...). Point make at a specific one with:
#         make setup PYTHON=/path/to/python3.12
#
#   Nothing is installed globally and no exact global Python version is
#   required: `make setup` creates a repo-local virtualenv in .venv/ and
#   installs the pinned `pre-commit` from requirements-dev.txt into it.
#
# How it works:
#   `make init` runs these steps:
#     1. Reconciles origin/main and origin/develop in fresh template clones.
#     2. Builds .venv/ and installs the pinned tooling into it.
#     3. Runs `git config --local include.path ../.gitconfig`, which makes this
#        repo's local config include the committed `.gitconfig`. That in turn
#        sets `core.hooksPath = .githooks/`, activating the committed hook
#        scripts (pre-commit and commit-msg) without needing `pre-commit
#        install`. Those scripts run .venv's `pre-commit`, never PATH's.

.DEFAULT_GOAL := help

# ---------------------------------------------------------------------------
# REPO-LOCAL VIRTUALENV
# ---------------------------------------------------------------------------
# The interpreter for the setup script and .venv. Override on the command line
# (e.g. `make setup PYTHON=python3.12`) to use a specific one.
PYTHON ?= python3

# Minimum version for the interpreter above: some hooks (commitizen,
# sync-pre-commit-deps) are `language: python` and require >= 3.10. Because
# their manifests say `language_version: python3`, pre-commit builds them with
# whichever interpreter is running pre-commit itself — i.e. .venv's.
MIN_PYTHON := 3.10

VENV := .venv
ifeq ($(OS),Windows_NT)
VENV_BIN := $(VENV)/Scripts
else
VENV_BIN := $(VENV)/bin
endif
PRE_COMMIT := $(VENV_BIN)/pre-commit
# Marker file recording that requirements-dev.txt has been installed into
# .venv; makes `venv` a no-op until the requirements change.
VENV_STAMP := $(VENV)/.requirements-installed

RULESETS := ./scripts/github-rulesets.sh

.PHONY: init setup check clean-venv reconcile-branches branch-reconciliation-test \
        venv ci pre-commit test acceptance candidate candidate-acceptance release publish record-release lint clean check-python help \
        rulesets-apply rulesets-diff rulesets-export

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

init: reconcile-branches ## Initialize template branches, then configure local development tools
	@$(MAKE) --no-print-directory setup

setup: venv ## Install development tooling and configure local Git hooks
	git config --local include.path ../.gitconfig
	$(PRE_COMMIT) install-hooks

reconcile-branches: check-python ## Reconcile main and develop on origin in a fresh template clone
	@$(PYTHON) scripts/reconcile_branches.py

branch-reconciliation-test: check-python ## Test branch reconciliation with local Git repositories
	@$(PYTHON) -m unittest discover -s tests -p test_reconcile_branches.py

venv: $(VENV_STAMP) ## Create/update the repo-local virtualenv (.venv) with the pinned tooling

$(VENV_STAMP): requirements-dev.txt
	@$(MAKE) --no-print-directory check-python
	$(PYTHON) -m venv $(VENV)
	$(VENV_BIN)/python -m pip install --disable-pip-version-check --upgrade pip
	$(VENV_BIN)/python -m pip install --disable-pip-version-check --require-virtualenv -r requirements-dev.txt
	@touch $@

# ---------------------------------------------------------------------------
# CI AND ACCEPTANCE ENTRYPOINTS
# ---------------------------------------------------------------------------
# PRs run `make ci`; each push to develop runs `make acceptance` for that
# commit. Acceptance starts with the same checks and is a separate extension
# point for slower integration tests. Successful acceptance alone does not
# publish a release or verify a release candidate.
test: branch-reconciliation-test security-exceptions-check ## Run the template test suite

check: test lint ## Run tests and read-only repository checks

ci: test pre-commit ## Run the pull-request check suite

# Validate exception metadata even when dependency review is unavailable.
.PHONY: security-exceptions-check
security-exceptions-check: check-python ## Reject invalid or expired dependency exceptions
	@$(PYTHON) scripts/security_exceptions.py > /dev/null
	@$(PYTHON) -m unittest discover -s tests -p test_security_exceptions.py

acceptance: ci ## Run post-integration acceptance checks (extends ci by default)

# Reserved release phases are deliberately not successful no-ops. A downstream
# project replaces each recipe and connects the gates for its own artifact.
# None depends on another by default: invoking one must not accidentally run
# a partial release or publish. See docs/integration-release.md.
candidate: ## Reserved: build a versioned immutable candidate
	@echo 'candidate: not implemented for this repository' >&2; exit 2

candidate-acceptance: ## Reserved: test and record the exact candidate
	@echo 'candidate-acceptance: not implemented for this repository' >&2; exit 2

release: ## Reserved: create a release from an accepted candidate
	@echo 'release: not implemented for this repository' >&2; exit 2

publish: ## Reserved: promote a verified release to its destination
	@echo 'publish: not implemented for this repository' >&2; exit 2

record-release: ## Reserved: record the successfully promoted source on main
	@echo 'record-release: not implemented for this repository' >&2; exit 2

lint: venv ## Run read-only repository hooks
	SKIP=sync-pre-commit-deps,trailing-whitespace,end-of-file-fixer,fix-byte-order-marker,mixed-line-ending $(PRE_COMMIT) run --all-files --show-diff-on-failure

pre-commit: venv ## Run all pre-commit hooks against all files (same hooks as the git hooks)
	$(PRE_COMMIT) run --all-files --show-diff-on-failure

clean: clean-venv ## Remove the local virtualenv (compatibility alias)

clean-venv: ## Remove the local virtualenv (rebuild it with `make setup`)
	rm -rf $(VENV)

# ---------------------------------------------------------------------------
# GITHUB RULESETS (branch protection as code)
# ---------------------------------------------------------------------------
# Branch protection lives in .github/rulesets/*.json and is reconciled by name,
# so `make rulesets-apply` rebuilds it in any repo created from this template.
# See scripts/github-rulesets.sh for the details.
#
# These targets are deliberately NOT dependencies of `ci`: rulesets are admin
# API surface, and a workflow's default GITHUB_TOKEN cannot read them. Making
# `ci` depend on them would fail for reasons unrelated to the code under test,
# and would break the rule that `make ci` runs identically on a laptop.
#
# Requires the GitHub CLI (`gh`), authenticated — unlike the targets above, this
# is not covered by `make setup`. Target another repo with REPO=owner/name.

rulesets-apply: ## Create/update this repo's GitHub rulesets from .github/rulesets/
	$(RULESETS) apply

rulesets-diff: ## Report drift between .github/rulesets/ and the live rulesets
	$(RULESETS) diff

rulesets-export: ## Overwrite .github/rulesets/ with the live rulesets
	$(RULESETS) export

check-python: ## Verify the setup interpreter is new enough
	@command -v $(PYTHON) > /dev/null 2>&1 || { \
		echo 'Error: `$(PYTHON)` was not found on your PATH.' 1>&2; \
		echo '       Install any Python >= $(MIN_PYTHON), or point make at one you have:' 1>&2; \
		echo '           make setup PYTHON=/path/to/python3' 1>&2; \
		exit 1; \
	}
	@$(PYTHON) -c 'import sys; req = tuple(int(p) for p in "$(MIN_PYTHON)".split(".")); raise SystemExit(sys.version_info[:len(req)] < req)' || { \
		echo "Error: $(PYTHON) is $$($(PYTHON) -V 2>&1 | cut -d" " -f2), but >= $(MIN_PYTHON) is required to build $(VENV)." 1>&2; \
		echo '       Any interpreter >= $(MIN_PYTHON) will do; it need not be your default python3:' 1>&2; \
		echo '           make setup PYTHON=python3.12' 1>&2; \
		exit 1; \
	}
