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

**Node is not a prerequisite either**, even though the cspell hook runs on it.
pre-commit builds that runtime itself (through `nodeenv`) inside the hook's own
cached environment, so the spell checker runs on the version pinned in
[`.pre-commit-config.yaml`](.pre-commit-config.yaml) whether or not you have
Node installed, and regardless of which version you have.

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

> **In a project that has its own linters, add `.venv/` to their ignore lists.**
> It is git-ignored, but that does not stop a linter from walking it, and some
> packages installed under it vendor JavaScript — enough to fail an ESLint run
> that was clean the day before. This template has no such linters, so it ships
> no ignore entries for them; a project adopting it should expect to add
> `.venv/` to `.eslintignore`/`eslint.config.js`, `.prettierignore`, and
> anything else that globs the whole tree.

Run `make help` (or just `make`) to list the available targets.

## What gets configured

| File | Purpose |
| --- | --- |
| [`.gitconfig`](.gitconfig) | Sets `core.hooksPath = .githooks/` so the committed hooks are used. |
| [`.githooks/pre-commit`](.githooks/pre-commit) | Runs the `pre-commit`-stage hooks (formatting, secret detection, etc.) via `.venv`. |
| [`.githooks/commit-msg`](.githooks/commit-msg) | Runs commitizen via `.venv` to enforce [Conventional Commits](https://www.conventionalcommits.org/) message format. |
| [`.pre-commit-config.yaml`](.pre-commit-config.yaml) | Declares the hook repos and pinned versions (`rev`). |
| [`cspell.json`](cspell.json) | Spell-check dialect, the regions excluded from dictionary checking, and the project word list. |
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
- **codespell** and **cspell** (markdown only): spell-check documentation. See
  [Spell checking](#spell-checking) for how the two split the work.
- **gitleaks**: scans for hardcoded secrets.
- **commitizen** (`commit-msg` stage): validates commit messages follow the
  Conventional Commits format, e.g.:
  ```
  feat: add user login
  fix(api): handle null response
  chore: bump dependencies
  ```
- **sync-pre-commit-deps**: keeps hook dependency versions in sync.

### Spell checking

Documentation is the part of a repository nobody compiles, so a typo in it
survives every other check. Two spell checkers run on markdown, and they are
complementary rather than redundant:

| | What it knows | Where it looks |
| --- | --- | --- |
| **codespell** | A curated list of ~40k known typos (`teh`, `definately`). It cannot invent a correction, so it effectively never fires falsely — but it only catches typos someone has already catalogued. | The **whole file**, fenced code blocks included. <!-- codespell:ignore teh,definately --> |
| **cspell** | A real dictionary, so it also catches one-off misspellings nobody has catalogued. That power is also its cost: aimed at code it flags identifiers, CLI flags and file paths. | **Prose only.** [`cspell.json`](cspell.json) excludes fenced blocks, inline code spans, link *targets* and HTML comments; link *text* stays checked, since the reader sees it. |

So prose gets full dictionary coverage, code blocks still get the
high-confidence typo sweep, and neither hook can block a pull request over an
identifier. The practical consequence for writing: **anything that is not
English belongs in backticks** — which is what you wanted for rendering
anyway.

Three knobs, in the order you are likely to reach for them:

- **A correct word is flagged** → add it to `words` in
  [`cspell.json`](cspell.json), or put it in backticks if it is really an
  identifier.

  If *codespell* is the one complaining, prefer a line-scoped exemption —
  `codespell:ignore word1,word2` anywhere on the line, which in markdown goes
  in an HTML comment. The table above needs one, because naming an example
  typo is indistinguishable from making it; view this file's source to see it.
  A repo-wide `.codespellrc` with `ignore-words-list = ...` is the fallback,
  and a worse one: it stops that typo being caught *everywhere*, which for a
  real typo is the opposite of what you want.
- **Check more than markdown** → drop the `types: [markdown]` override on both
  hooks. Markdown is the conservative default for a template, being the one
  file type every repo created from this one is certain to have; a real project
  will want its source, YAML comments and scripts swept too.
- **British spelling** → `"language"` in [`cspell.json`](cspell.json) is `en`
  (en-US), so `behaviour` and `standardise` are flagged — that is how the one
  stray `Standardising` in this README was caught when the hooks were added.
  Set it to `en-GB` to switch, or `"en,en-GB"` to accept both. Switching is
  partial by nature: `en-GB` rejects `behavior`, but still accepts
  `standardized`, because `-ize` is valid British spelling and `-ise` is a
  style preference no dictionary can adjudicate.

## CI/CD integration

Pull requests into `develop` run `make ci`. Every push to `develop`, including
an integration merge, runs `make acceptance` against that commit. Acceptance
initially runs the same checks and is a separate extension point for a broader
suite as a project grows. PRs into `main` also run `ci` because the shipped
ruleset requires it.

The portable checks live in the Makefile; the GitHub Actions and Azure DevOps
configurations provide the environment and select the entry point. See the
[integration and release baseline](docs/integration-release.md) for the complete
intended lifecycle and what this foundation does and does not implement.

| File | Purpose |
| --- | --- |
| [`Makefile`](Makefile) | Defines `make ci` and `make acceptance`. |
| [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | Runs PR validation. |
| [`.github/workflows/acceptance.yml`](.github/workflows/acceptance.yml) | Runs acceptance on each `develop` push. |
| [`azure-pipelines.yml`](azure-pipelines.yml) | Selects the equivalent entry point on Azure DevOps. |

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

Extend `acceptance` with additional post-integration checks; its default
dependency on `ci` keeps the PR checks in the broader suite.

#### The `sbom` convention

An SBOM is the clearest example of a check whose *contract* is portable while its
*implementation* cannot be. This template therefore defines the contract and
deliberately ships no generator:

| Portable — keep this shape in every project | Project-specific |
| --- | --- |
| An `sbom` target after the relevant build, when a project ships an artifact | The generator and its toolchain |
| Output under the same gitignored artifacts directory the other reports use | The dependency-manifest path it reads |
| Keep the release SBOM with its artifact and evidence | The SBOM's subject name and version |

Nothing portable can generate the document itself, because an SBOM's substance is
the *resolved* dependency graph, and that graph only exists inside an ecosystem's
resolver — NuGet's `project.assets.json`, a `package-lock.json`, a populated
virtualenv. A repo-level tool either shells out to those resolvers anyway or
parses manifests and guesses, and guessing gets transitive and
conditionally-referenced packages wrong. Standardizing a generator here would also
mean forcing its toolchain onto every project made from this template, which is
exactly what the [Requirements](#requirements) list above exists to avoid.

This repository has no `sbom` target of its own on purpose: it ships no artifact.
Its only dependencies are `pre-commit` and the rev-pinned hook repos — a developer
toolchain nobody deploys — so an SBOM of it would inventory something that is
never shipped.

[`dotnet-template`](https://github.com/mxwlf/dotnet-template) implements this
contract for an example .NET package, with Microsoft's `sbom-tool` producing
SPDX 2.2 from `project.assets.json`. A specialized project chooses its own
SBOM scope and whether to generate one in each CI run or at release time.

Two decisions worth making deliberately when you do implement it:

- **Generate from the build output, not the source tree.** An SBOM should describe
  what you ship, which means it comes after the build, the way a coverage report
  comes after the tests.
- **A per-pull-request SBOM and a release SBOM are different artifacts.** The
  first is a drift detector — it catches a dependency added without its lockfile
  updated. The authoritative one describes a released artifact and should be
  attached to the release and attested (for example with `actions/attest-sbom`).
  A project may generate the first in `ci`; the second belongs to a release
  workflow.

#### Release foundations

The general Git template ships no product and does not publish a release. A
project that does ship should build and validate its release candidate, keep its
artifact and evidence together, and promote the same verified artifact to its
destination. The artifact format, SBOM, signing, publishing credentials, and
deployment are specific to the project. A checksum detects changes relative to
its manifest; it does not authenticate the manifest. Protect or attest the
release artifact before relying on it for promotion.

### What you still configure per platform

The GitHub and Azure wrappers install prerequisites and select the entry point;
projects must add their own toolchains, artifact storage, security settings,
and release or deployment integrations. GitHub runs `ci` for PRs targeting
`develop` or `main`, and acceptance on pushes to `develop`. Azure Repos needs a
branch-policy build validation for pull requests; YAML `pr` triggers are
provider-dependent.

The job name `ci` is required by the shipped rulesets. If you change the name
or the protected branches, update the triggers and rulesets together. The
acceptance run is a post-merge result, not a PR-required check and not yet a
release gate. A release implementation must explicitly require the result for
the exact candidate commit.

### Determinism

- `pre-commit` is pinned in [`requirements-dev.txt`](requirements-dev.txt) and
  installed into an isolated `.venv/`, so CI and laptops run the same version
  regardless of what is installed globally.
- Hook versions are pinned via `rev` in
  [`.pre-commit-config.yaml`](.pre-commit-config.yaml).
- The cspell hook additionally pins its `language_version` (the Node runtime
  pre-commit builds for it). Without that pin pre-commit uses whatever `node`
  is on `PATH`, so the spell checker would run on a different runtime per
  machine — the same failure the `.venv` indirection avoids for Python.
- Both CI stubs pin the interpreter used to build `.venv` (currently 3.14) for
  reproducible runs. Any `>= 3.10` works; the pin is not a hook requirement.
- Both stubs pin the runner/agent image (currently `ubuntu-24.04`) instead of
  using `ubuntu-latest`. That label is remapped to a new Ubuntu release
  periodically, which would move the build environment on the platform's
  schedule rather than yours.
- Both stubs cache pre-commit hook environments keyed on the config file, so
  unchanged hooks are not rebuilt.

Bump these versions deliberately when you want to upgrade.

## Security and dependency alignment

The [security baseline](docs/security-baseline.md) compares the shared hooks
with the homepage's additional checks and records proposed policies. It
identifies which capabilities are implemented and which still need alignment.

## Branch protection (GitHub rulesets)

CI that merely *reports* a failure does not keep a broken commit off `develop`.
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

Create `develop`, branch from it, and propose changes through a PR back to
`develop`. Its ruleset requires `ci`, an up-to-date branch and one review;
repository admins can bypass those requirements within a PR. When a PR merges,
the resulting push starts acceptance. The default acceptance suite runs the
same checks as the PR suite, and projects can extend it.

`main` is intended to record the successfully promoted source commit. This
foundation has no release or promotion automation. Its `main` ruleset blocks
direct updates, including from automation without an explicit bypass; do not
assume it is ready to record a deployment. The [integration and release
baseline](docs/integration-release.md) covers the planned gates, account-specific
authority, and rollback limitation.

A required check must run for every PR to a protected branch. Both shipped
rulesets require the `ci` job from [`.github/workflows/ci.yml`](.github/workflows/ci.yml),
which includes `develop` and `main` in its trigger. Create `develop` and confirm
the checks report before applying the rulesets.

## Make targets

| Target | Description |
| --- | --- |
| `make help` | Show available targets (default when running `make`). |
| `make setup` | Create `.venv`, then configure the repo to use the shared git config and pre-commit hooks. |
| `make venv` | Create/update `.venv` from `requirements-dev.txt` (no-op when up to date). |
| `make ci` | Run the pull-request checks locally or in CI. |
| `make acceptance` | Run post-integration acceptance; extends `ci` by default. |
| `make candidate`, `make candidate-acceptance`, `make release`, `make publish`, `make record-release` | Reserved release phases; fail until implemented for a project. |
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

## License

[MIT](LICENSE).

That covers this template's own files — the `Makefile`, the git and pre-commit
configuration, the CI stubs, the rulesets and this documentation. A repository
created from the template inherits those files under the same terms, and MIT lets
you relicense your own work on top of them however you like. Replace the copyright
holder in `LICENSE` with your own when you do.
