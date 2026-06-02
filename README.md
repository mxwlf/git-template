# git-template

My baseline git template. It ships a shared git configuration and a set of
[pre-commit](https://pre-commit.com) hooks so every repo started from this
template gets consistent commit hygiene and commit-message formatting out of
the box.

## Requirements

- [`pre-commit`](https://pre-commit.com) installed and on your `PATH`:
  ```sh
  pipx install pre-commit   # or: brew install pre-commit
  ```
- A Python **>= 3.10** interpreter available on your system (required by the
  [commitizen](https://commitizen-tools.github.io/commitizen/) hook).

## Setup

From the repository root:

```sh
make setup
```

This runs:

```sh
git config --local include.path ../.gitconfig
```

which makes the repo's local config include the committed [`.gitconfig`](.gitconfig).
That config sets `core.hooksPath = .githooks/`, activating the committed hook
scripts. Because the hooks live in `.githooks/` and are wired up through
`include.path`, **`pre-commit install` is not required**.

Run `make help` (or just `make`) to list the available targets.

## What gets configured

| File | Purpose |
| --- | --- |
| [`.gitconfig`](.gitconfig) | Sets `core.hooksPath = .githooks/` so the committed hooks are used. |
| [`.githooks/pre-commit`](.githooks/pre-commit) | Runs the `pre-commit`-stage hooks (formatting, secret detection, etc.). |
| [`.githooks/commit-msg`](.githooks/commit-msg) | Runs commitizen to enforce [Conventional Commits](https://www.conventionalcommits.org/) message format. |
| [`.pre-commit-config.yaml`](.pre-commit-config.yaml) | Declares the hook repos and versions. |

### Hooks included

- **pre-commit-hooks**: trailing whitespace, end-of-file fixer, YAML checks,
  illegal Windows names, merge-conflict markers, private-key detection,
  byte-order-marker fix, mixed line endings.
- **gitleaks**: scans for hardcoded secrets.
- **commitizen** (`commit-msg` stage): validates commit messages follow the
  Conventional Commits format, e.g.:
  ```
  feat: add user login
  fix(api): handle null response
  chore: bump dependencies
  ```
- **sync-pre-commit-deps**: keeps hook dependency versions in sync.

## Make targets

| Target | Description |
| --- | --- |
| `make help` | Show available targets (default when running `make`). |
| `make setup` | Configure the repo to use the shared git config and pre-commit hooks. |
| `make check-pre-commit` | Verify the `pre-commit` tool is installed. |

## Troubleshooting

- **`` `pre-commit` not found ``** — install the tool (see [Requirements](#requirements)).
- **commitizen fails to build / `requires a different Python`** — ensure a
  Python >= 3.10 interpreter is installed. The commitizen hook pins
  `language_version: python3.10` in [`.pre-commit-config.yaml`](.pre-commit-config.yaml);
  adjust it if your environment provides a different 3.10+ interpreter name.
- **Hook is ignored / not running** — confirm `make setup` has been run
  (`git config --get include.path` should print `../.gitconfig`) and that the
  hook scripts in `.githooks/` are executable.
