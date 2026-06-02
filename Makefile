# Makefile for git-template
#
# Provides one-command setup for this repository's shared git configuration
# and pre-commit hooks.
#
# Usage:
#   make            # same as `make help`
#   make help       # list available targets
#   make setup      # configure the repo to use shared git config + hooks
#
# Requirements:
#   - The `pre-commit` tool must be installed and on your PATH.
#     Install with: `pipx install pre-commit` or `brew install pre-commit`
#   - A Python >= 3.10 interpreter must be available (required by commitizen).
#
# How it works:
#   `make setup` runs `git config --local include.path ../.gitconfig`, which
#   makes this repo's local config include the committed `.gitconfig`. That in
#   turn sets `core.hooksPath = .githooks/`, activating the committed hook
#   scripts (pre-commit and commit-msg) without needing `pre-commit install`.

.DEFAULT_GOAL := help

.PHONY: setup check-pre-commit help

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

setup: check-pre-commit ## Configure the repo to use the shared git config and pre-commit hooks
	git config --local include.path ../.gitconfig

check-pre-commit: ## Verify the pre-commit tool is installed
	@command -v pre-commit > /dev/null || { \
		echo 'Error: `pre-commit` not found. Install it with `pipx install pre-commit` or `brew install pre-commit`.' 1>&2; \
		exit 1; \
	}
