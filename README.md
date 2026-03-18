# git-template

A baseline git configuration template following best practices. Copy or symlink these files into any new (or existing) repository to get a consistent, well-configured git setup in seconds.

---

## What's included

| File / Directory | Purpose |
|---|---|
| `.gitattributes` | Line-ending normalization, binary file detection, diff drivers, linguist overrides |
| `.gitignore` | Common ignore patterns for OS, editors, languages, build tools, secrets |
| `git-config` | Recommended git settings (aliases, diff algorithm, rerere, signing hints, …) |
| `hooks/pre-commit` | Checks for conflict markers, trailing whitespace, large files, secret patterns; runs optional formatters/linters |
| `hooks/commit-msg` | Enforces the [Conventional Commits](https://www.conventionalcommits.org/) specification |
| `hooks/prepare-commit-msg` | Pre-fills the editor with a Conventional Commits template |
| `hooks/pre-push` | Blocks direct pushes to protected branches, runs tests, runs optional security audits |
| `setup.sh` | One-command installer that wires everything into a target repository |

---

## Quick start

```bash
# Clone this template somewhere convenient
git clone https://github.com/mxwlf/git-template ~/.git-template

# Run the installer against any repo
cd /path/to/your-repo
~/.git-template/setup.sh
```

The installer will:
1. Copy (or symlink) the hooks into `.git/hooks/` and mark them executable.
2. Add an `include.path` entry to the repo's local `.git/config` pointing at the bundled `git-config`.
3. Copy `.gitattributes` and `.gitignore` into the repo root if they don't already exist.

### Installer options

```bash
# Symlink hooks instead of copying (hooks auto-update when the template changes)
SYMLINK=1 ~/.git-template/setup.sh

# Skip including git-config in the local repo config
INCLUDE_CONFIG=0 ~/.git-template/setup.sh

# Install into a specific directory
~/.git-template/setup.sh /path/to/your-repo
```

---

## Using git-config globally

To apply the recommended settings to **all** your repositories, add an include to your global config:

```bash
git config --global include.path ~/.git-template/git-config
```

---

## Hooks reference

### `pre-commit`

Runs automatically before every commit. Fails the commit if:

- Merge conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) are present in staged files.
- Trailing whitespace is found in staged text files.
- A staged file exceeds `MAX_FILE_SIZE_KB` (default: 5 MB). Consider [Git LFS](https://git-lfs.com/) for large assets.
- A potential secret is detected (AWS keys, GitHub tokens, `password =`, `api_key =`, etc.).

Also **warns** (without blocking) when common debug statements (`console.log`, `debugger;`, `binding.pry`, …) are detected.

If the following tools are installed, they are run automatically on the relevant staged files:

| Tool | Files |
|---|---|
| `prettier` | JS, TS, CSS, SCSS, HTML, JSON, YAML, Markdown |
| `eslint` | JS, JSX, TS, TSX |
| `black` | Python |
| `ruff` | Python |
| `shellcheck` | Shell scripts (`.sh`, `.bash`) |
| `golangci-lint` | Go |

#### Controlling behaviour

```bash
# Disable debug-marker warnings
CHECK_DEBUG_MARKERS=0 git commit -m "…"

# Raise the large-file threshold to 20 MB
MAX_FILE_SIZE_KB=20480 git commit -m "…"

# Skip all hooks (not recommended)
git commit --no-verify
```

---

### `commit-msg`

Validates the commit message against the [Conventional Commits](https://www.conventionalcommits.org/) specification.

**Format:**

```
<type>[optional scope][optional !]: <description>

[optional body]

[optional footer(s)]
```

**Valid types:** `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`

**Examples:**

```
feat: add login endpoint
fix(auth): handle expired tokens
feat!: drop support for Node 12
chore(deps): bump lodash to 4.17.21
```

Additional rules:
- Subject line must be ≤ 72 characters.
- Subject line must not end with a period.
- Description must not be blank.

---

### `prepare-commit-msg`

Pre-fills the commit editor with a Conventional Commits template each time you open it. If the branch name starts with a recognised type prefix (e.g. `feat/my-feature`), the matching type is pre-populated automatically.

---

### `pre-push`

Runs automatically before every push. Fails the push if:

- You are pushing **directly** to a protected branch (`main`, `master`, `develop`). Open a pull request instead. Override the list with the `PROTECTED_BRANCHES` env var.
- There are uncommitted changes in the working tree.
- The project's test suite fails (auto-detected for npm, Make, pytest, Cargo, Go, Bundler).
- A security audit finds high-severity vulnerabilities (`npm audit`, `pip-audit`, `bundle-audit` — only if installed).

```bash
# Skip security audit for this push
RUN_AUDIT=0 git push

# Allow direct push to main (use with caution)
PROTECTED_BRANCHES="master develop" git push

# Skip all hooks (not recommended)
git push --no-verify
```

---

## Conventional Commits cheat-sheet

| Type | When to use |
|---|---|
| `feat` | A new feature visible to users |
| `fix` | A bug fix |
| `docs` | Documentation only |
| `style` | Whitespace, formatting — no logic change |
| `refactor` | Code restructure — no feature or bug change |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system, dependencies |
| `ci` | CI/CD configuration |
| `chore` | Maintenance, tooling, housekeeping |
| `revert` | Reverts a previous commit |

Append `!` after the type/scope to signal a **BREAKING CHANGE**: `feat!: …`

---

## Contributing

Issues and pull requests are welcome. When contributing, follow the Conventional Commits format — the `commit-msg` hook will enforce it for you once set up.
