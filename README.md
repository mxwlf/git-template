# git-template

My baseline git template. It ships a shared git configuration and a set of
[pre-commit](https://pre-commit.com) hooks so every repo started from this
template gets consistent commit hygiene and commit-message formatting out of
the box.

All tooling lives in a **repo-local virtualenv** (`.venv/`) created by
`make setup`. Nothing is installed globally, and no specific global Python
version is required.

## Requirements

- **GNU make**, **git**, and a POSIX shell (on Windows: Git Bash or WSL).
- **Any Python interpreter `>= 3.10`** reachable as `python3`. It is used *only*
  to create `.venv/`, so whatever you already have works — system, Homebrew,
  pyenv, uv, asdf. If your default `python3` is older, point make at another
  interpreter instead of changing your system default:

  ```sh
  make setup PYTHON=python3.12          # or an absolute path
  ```

  Check what make will use with `make check-python`.

That is the whole list — `pre-commit` itself is **not** a prerequisite.
`make setup` installs the pinned version from
[`requirements-dev.txt`](requirements-dev.txt) into `.venv/`.

> **Why a venv instead of a required global Python version?** Some hooks
> (commitizen, sync-pre-commit-deps) are `language: python` and need
> Python `>= 3.10`. Their upstream manifests declare `language_version: python3`,
> which pre-commit resolves to *the interpreter running pre-commit itself* — not
> to whatever `python3` is on your `PATH`. So a `pre-commit` installed under an
> old interpreter (e.g. macOS's bundled Python 3.9) builds those hook
> environments with 3.9 and fails with `requires a different Python`.
>
> Rather than papering over that with per-hook `language_version` pins — which
> forced every contributor to install one exact Python version globally — the
> template runs pre-commit from `.venv/`, built from any Python `>= 3.10`. The
> hooks inherit that interpreter, so
> [`.pre-commit-config.yaml`](.pre-commit-config.yaml) needs no interpreter pins
> at all and your machine's Python setup is left alone.

## Setup

From the repository root:

```sh
make setup
```

This does three things:

1. Creates `.venv/` and installs the pinned tooling
   ([`requirements-dev.txt`](requirements-dev.txt)) into it.
2. Runs `git config --local include.path ../.gitconfig`, which makes the repo's
   local config include the committed [`.gitconfig`](.gitconfig). That config
   sets `core.hooksPath = .githooks/`, activating the committed hook scripts.
   Because the hooks live in `.githooks/` and are wired up through
   `include.path`, **`pre-commit install` is not required**.
3. Runs `pre-commit install-hooks` to pre-build the hook environments, so your
   first commit isn't slowed down by it.

You never need to *activate* `.venv`: the hook scripts in `.githooks/` and every
make target invoke `.venv/bin/pre-commit` by absolute path.

Run `make help` (or just `make`) to list the available targets.

## What gets configured

| File | Purpose |
| --- | --- |
| [`.gitconfig`](.gitconfig) | Sets `core.hooksPath = .githooks/` so the committed hooks are used. |
| [`.githooks/pre-commit`](.githooks/pre-commit) | Runs the `pre-commit`-stage hooks (formatting, secret detection, etc.) via `.venv`. |
| [`.githooks/commit-msg`](.githooks/commit-msg) | Runs commitizen via `.venv` to enforce [Conventional Commits](https://www.conventionalcommits.org/) message format. |
| [`.pre-commit-config.yaml`](.pre-commit-config.yaml) | Declares the hook repos and pinned versions (`rev`). |
| [`requirements-dev.txt`](requirements-dev.txt) | The pinned tooling installed into `.venv/` — just `pre-commit`. |
| `.venv/` | The repo-local virtualenv. Created by `make setup`, git-ignored, disposable (`make clean`). |

Each hook's own dependencies are installed by pre-commit into its own cached
environments (`~/.cache/pre-commit`, or `~/Library/Caches/pre-commit` on macOS),
not into `.venv/`.

### Hooks included

- **pre-commit-hooks**: trailing whitespace, end-of-file fixer, YAML checks,
  large-file guard (blocks files over 500 kB by default), case-conflict
  detection (catches filename collisions on case-insensitive filesystems like
  macOS/Windows), illegal Windows names, merge-conflict markers, private-key
  detection, byte-order-marker fix, and mixed line endings.
- **gitleaks**: scans for hardcoded secrets.
- **commitizen** (`commit-msg` stage): validates commit messages follow the
  Conventional Commits format, e.g.:
  ```
  feat: add user login
  fix(api): handle null response
  chore: bump dependencies
  ```
- **sync-pre-commit-deps**: keeps hook dependency versions in sync.

## CI/CD integration

This template is designed so that wiring it into **any** CI/CD platform is
simple and deterministic. It follows the industry-standard *thin wrapper*
pattern (see [Martin Fowler on Continuous
Integration](https://martinfowler.com/articles/continuousIntegration.html#AutomateTheBuild)):
all the actual check logic lives **in the repository** behind a single command,
and each CI platform's config does nothing more than check out the code,
provide a Python interpreter, and run that one command.

```
make ci                       ← single source of truth (runs locally too)
  └── .venv/ (built from requirements-dev.txt)
        └── pre-commit run --all-files
              └── hooks in .pre-commit-config.yaml

.github/workflows/ci.yml      ← thin stub: checkout → python → `make ci`
azure-pipelines.yml           ← thin stub: checkout → python → `make ci`
```

The same `make ci` a developer runs on their laptop is exactly what runs on
GitHub Actions and Azure DevOps — including building the venv, so the CI stubs
install nothing themselves. To change *what* CI does, edit the
[`Makefile`](Makefile) and [`.pre-commit-config.yaml`](.pre-commit-config.yaml)
— **not** the platform YAML.

| File | Purpose |
| --- | --- |
| [`Makefile`](Makefile) (`make ci`) | The portable entrypoint. All check logic lives here. Extend it with your project's build/test commands. |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | Thin GitHub Actions stub that runs `make ci`. |
| [`azure-pipelines.yml`](azure-pipelines.yml) | Thin Azure DevOps stub that runs `make ci`. |

### Extending `make ci` for your project

Add your build/test steps to the `ci` target in the [`Makefile`](Makefile). For
example, for a .NET project:

```make
ci: lint test ## Run the full CI check suite

test: ## Run the test suite
	dotnet test
```

Because the logic is in the Makefile, those steps run identically locally and
on every CI platform — no YAML changes required.

#### The `sbom` convention

An SBOM is the clearest example of a check whose *contract* is portable while its
*implementation* cannot be. This template therefore defines the contract and
deliberately ships no generator:

| Portable — keep this shape in every project | Project-specific |
| --- | --- |
| A `sbom` target, in the `ci` chain, after whatever builds | The generator and its toolchain |
| Output under the same gitignored artifacts directory the other reports use | The dependency-manifest path it reads |
| Published by the CI stubs alongside the test and coverage reports | The SBOM's subject name and version |

Nothing portable can generate the document itself, because an SBOM's substance is
the *resolved* dependency graph, and that graph only exists inside an ecosystem's
resolver — NuGet's `project.assets.json`, a `package-lock.json`, a populated
virtualenv. A repo-level tool either shells out to those resolvers anyway or
parses manifests and guesses, and guessing gets transitive and
conditionally-referenced packages wrong. Standardising a generator here would also
mean forcing its toolchain onto every project made from this template, which is
exactly what the [Requirements](#requirements) list above exists to avoid.

This repository has no `sbom` target of its own on purpose: it ships no artifact.
Its only dependencies are `pre-commit` and the rev-pinned hook repos — a developer
toolchain nobody deploys — so an SBOM of it would inventory something that is
never shipped.

[`dotnet-template`](https://github.com/mxwlf/dotnet-template) implements this
contract for .NET, with Microsoft's `sbom-tool` producing SPDX 2.2 from
`project.assets.json`, if you want a worked example.

Two decisions worth making deliberately when you do implement it:

- **Generate from the build output, not the source tree.** An SBOM should describe
  what you ship, which means it comes after the build, the way a coverage report
  comes after the tests.
- **A per-pull-request SBOM and a release SBOM are different artifacts.** The
  first is a drift detector — it catches a dependency added without its lockfile
  updated. The authoritative one describes a released artifact and should be
  attached to the release and attested (for example with `actions/attest-sbom`).
  Putting `sbom` in `ci` gets you the first; the second belongs to a release
  workflow.

### What you still configure per platform (and why)

The thin-wrapper pattern minimizes platform-specific config but cannot
eliminate it. Each platform requires its own small YAML stub, and a few
concerns are inherently platform-specific and **cannot** be pushed into a
portable script:

- **The stub file itself** — GitHub needs `.github/workflows/*.yml`; Azure
  DevOps needs `azure-pipelines.yml`. The template ships both, pre-wired to
  `make ci`.
- **Triggers** (which branches/events run CI) — expressed differently on each
  platform. Both stubs ship pre-configured to run CI on:
  - **pushes** to `main`, and
  - **pull requests** targeting `main`, from any source branch.

  Feature branches are intentionally absent from the push trigger: a branch that
  has an open pull request would otherwise build the same commits twice for no
  extra signal.

  The pull-request trigger must cover every branch you gate with a required
  status check (see [Branch protection](#branch-protection-github-rulesets)).
  A required check that never runs is never reported, and the pull request
  waits on it forever.

  Adjust the `on`/`trigger`/`pr` sections in
  [`.github/workflows/ci.yml`](.github/workflows/ci.yml) and
  [`azure-pipelines.yml`](azure-pipelines.yml) to change this.
- **Secrets, service connections, OIDC, and permissions** — managed in each
  platform's settings/YAML, never in the repo.
- **Runner/agent image** and **which Python interpreter is on the agent** (the
  base for `.venv`).

Everything else — the actual checks — is shared via `make ci`.

### Determinism

- `pre-commit` is pinned in [`requirements-dev.txt`](requirements-dev.txt) and
  installed into an isolated `.venv/`, so CI and laptops run the same version
  regardless of what is installed globally.
- Hook versions are pinned via `rev` in
  [`.pre-commit-config.yaml`](.pre-commit-config.yaml).
- Both CI stubs pin the interpreter used to build `.venv` (currently 3.14) for
  reproducible runs. Any `>= 3.10` works; the pin is not a hook requirement.
- Both stubs pin the runner/agent image (currently `ubuntu-24.04`) instead of
  using `ubuntu-latest`. That label is remapped to a new Ubuntu release
  periodically, which would move the build environment on the platform's
  schedule rather than yours.
- Both stubs cache pre-commit hook environments keyed on the config file, so
  unchanged hooks are not rebuilt.

Bump these versions deliberately when you want to upgrade.

## Branch protection (GitHub rulesets)

CI that merely *reports* a failure does not keep a broken commit off `main`.
A commit cannot be rejected because CI failed — CI only starts once the commit
exists. What actually protects a branch is a rule that refuses the merge until
a check has already passed, which lives on the GitHub side, not in a git hook.

This template keeps those rules **in the repo**, as
[`.github/rulesets/*.json`](.github/rulesets), and rebuilds them with the
GitHub CLI:

```sh
make rulesets-apply     # create/update the rulesets on GitHub
make rulesets-diff      # fail if GitHub no longer matches the repo
make rulesets-export    # overwrite the JSON from GitHub (after a UI edit)
```

Rulesets are reconciled **by name**, not by id: GitHub assigns ids per
repository, so a committed id would be meaningless in a repo created from this
template. `apply` looks up each file's `name`, updates the ruleset if it exists
and creates it if it does not — so it is idempotent, and works on a fresh repo.

`make rulesets-apply` requires the GitHub CLI (`gh`), authenticated with admin
rights on the repo. Unlike everything else here, `gh` is **not** installed by
`make setup`, and these targets are deliberately **not** part of `make ci` — see
[`.github/rulesets/README.md`](.github/rulesets/README.md) for why, and for what
the shipped rulesets enforce.

### The workflow these rules require

The workflow is **trunk-based**. `main` is the only long-lived branch: there is
no `develop` to stage through, and no release branches. Everything else is a
short-lived branch that exists just long enough to carry one pull request, and
is deleted after it merges.

With `main-protection` active, `main` cannot be written to directly. Every
change reaches it the same way:

1. **Branch off `main`.** Name it however you like — the rules place no
   constraint on source branches, and a feature branch needs no protection of
   its own, since it cannot reach `main` except through the gate below. Keep it
   short-lived; the point of trunk-based work is that branches merge in days,
   not weeks. Commits are checked locally by the hooks from `make setup`.
2. **Open a pull request into `main`.** A direct `git push origin main` is
   rejected by the ruleset, as is a force-push and a branch deletion.
3. **Let `ci` finish and pass.** It is a required check, so the merge button
   stays disabled until it reports success. The branch must also be up to date
   with `main` first (`strict_required_status_checks_policy`), so if `main`
   moved, update the branch and let `ci` run again.
4. **Merge with a merge commit, then delete the branch.** `main` accepts *only*
   merge commits — squash and rebase are not offered. That choice is about
   authorship: a merge commit leaves your commits untouched, so each keeps the
   signature you made, and GitHub signs the merge commit itself to satisfy
   `required_signatures`. The trade is that `main` is not linear.

   **Rebase merges are not allowed, and cannot be.** A rebase merge rewrites
   each commit into a new object, which discards the author's signature, and
   GitHub has no key with which to re-sign on the author's behalf. Enabling
   `rebase` alongside `required_signatures` produces a merge button that always
   fails with *"Base branch requires signed commits. Rebase merges cannot be
   automatically signed by GitHub."* A squash merge does work, but it collapses
   the branch into one new GitHub-signed commit, so your own signatures do not
   survive onto `main`.

What this buys you, and what it does not: the rules keep a red build from
reaching `main` by accident. They are not a hard stop, because the shipped
`main-protection` lets a repository admin bypass them *inside a pull request*
(`bypass_mode: "pull_request"`) — which is also what makes the required approval
satisfiable on a one-maintainer repo, since you cannot approve your own pull
request. Drop the `bypass_actors` entry to make the check absolute, and drop
`required_approving_review_count` to 0 at the same time or nothing will ever
merge.

> **Keep the check name and the trigger in sync.** The required check is the
> `ci` **job id** in [`.github/workflows/ci.yml`](.github/workflows/ci.yml), and
> that workflow's `pull_request` trigger must list every branch the rulesets
> protect. Rename the job, or protect a new branch without extending the
> trigger, and the required check is simply never reported — the pull request
> then waits on it indefinitely rather than failing. Both files have to change
> together.

## Make targets

| Target | Description |
| --- | --- |
| `make help` | Show available targets (default when running `make`). |
| `make setup` | Create `.venv`, then configure the repo to use the shared git config and pre-commit hooks. |
| `make venv` | Create/update `.venv` from `requirements-dev.txt` (no-op when up to date). |
| `make ci` | Run the full CI check suite — the single command CI/CD pipelines invoke. Runs identically locally. |
| `make lint` | Run all pre-commit hooks against all files. |
| `make clean` | Remove `.venv` (rebuild with `make setup`). |
| `make check-python` | Verify the interpreter used to build `.venv` is `>= 3.10`. |
| `make rulesets-apply` | Create/update this repo's GitHub rulesets from `.github/rulesets/`. Needs `gh`. |
| `make rulesets-diff` | Report drift between `.github/rulesets/` and the live rulesets. Needs `gh`. |
| `make rulesets-export` | Overwrite `.github/rulesets/` with the live rulesets. Needs `gh`. |

Override the interpreter for any of these with `PYTHON=...`, e.g.
`make setup PYTHON=python3.12`.

## Troubleshooting

- **`` `pre-commit` was not found in this repository's .venv/ ``** — the venv is
  missing (fresh clone, new worktree, or `make clean`). Run `make setup` from
  the repository root.
- **`Error: python3 ... but >= 3.10 is required`** — the interpreter make would
  use to build `.venv` is too old. Install any newer Python and either put it on
  your `PATH` as `python3` or pass it explicitly: `make setup PYTHON=python3.12`.
  You do **not** need to change your system default.
- **commitizen / sync-pre-commit-deps fails to build / `requires a different Python`** —
  the hooks are being run by a pre-commit *outside* `.venv/` (a global install
  under an old interpreter). Confirm `make setup` has been run and that
  `git config --get core.hooksPath` prints `.githooks/`; if a stray
  `pre-commit install` overwrote `.git/hooks/`, delete those generated files so
  `core.hooksPath` takes effect again. See
  [Requirements](#requirements) for why the interpreter is chosen this way.
- **`.venv` broke after a Python upgrade** (e.g. Homebrew replaced the
  interpreter it was built from) — recreate it: `make clean && make setup`.
- **Hook is ignored / not running** — confirm `make setup` has been run
  (`git config --get include.path` should print `../.gitconfig`) and that the
  hook scripts in `.githooks/` are executable.
