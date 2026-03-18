#!/usr/bin/env bash
# ==============================================================================
# setup.sh — Install git-template hooks and configuration
#
# Usage:
#   ./setup.sh [TARGET_REPO_DIR]
#
#   TARGET_REPO_DIR defaults to the current directory (.).
#
# What this script does:
#   1. Copies / symlinks the hooks from this template into TARGET_REPO_DIR/.git/hooks/
#   2. Optionally includes the bundled git-config into the repo's local git config
#   3. Optionally copies .gitattributes and .gitignore into TARGET_REPO_DIR
#       (only when those files do not already exist)
#
# Options (environment variables):
#   SYMLINK=1        — symlink hooks instead of copying (default: copy)
#   INCLUDE_CONFIG=1 — include git-config in the repo's local config (default: 1)
#   COPY_ATTRS=1     — copy .gitattributes if missing (default: 1)
#   COPY_IGNORE=1    — copy .gitignore if missing (default: 1)
# ==============================================================================

set -euo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[setup]${NC} $*"; }
pass()    { echo -e "${GREEN}[setup]${NC} $*"; }
warn()    { echo -e "${YELLOW}[setup]${NC} $*"; }
fail()    { echo -e "${RED}[setup] ERROR${NC} $*"; exit 1; }
section() { echo -e "\n${BOLD}$*${NC}"; }

# ── Resolve paths ─────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"

# ── Validate target is a git repository ──────────────────────────────────────
if [[ ! -d "$TARGET_DIR/.git" ]]; then
    fail "'$TARGET_DIR' is not a git repository. Run 'git init' first."
fi

GIT_HOOKS_DIR="$TARGET_DIR/.git/hooks"
TEMPLATE_HOOKS_DIR="$SCRIPT_DIR/hooks"

SYMLINK="${SYMLINK:-0}"
INCLUDE_CONFIG="${INCLUDE_CONFIG:-1}"
COPY_ATTRS="${COPY_ATTRS:-1}"
COPY_IGNORE="${COPY_IGNORE:-1}"

# ── 1. Install hooks ──────────────────────────────────────────────────────────
section "Installing git hooks into $GIT_HOOKS_DIR …"

hooks=("pre-commit" "commit-msg" "pre-push" "prepare-commit-msg")

for hook in "${hooks[@]}"; do
    src="$TEMPLATE_HOOKS_DIR/$hook"
    dst="$GIT_HOOKS_DIR/$hook"

    if [[ ! -f "$src" ]]; then
        warn "Hook source not found, skipping: $src"
        continue
    fi

    if [[ -f "$dst" && ! -L "$dst" ]]; then
        backup="${dst}.bak.$(date +%Y%m%d_%H%M%S)"
        warn "Hook '$hook' already exists at $dst — backing up as $(basename "$backup")"
        mv "$dst" "$backup"
    elif [[ -L "$dst" ]]; then
        rm "$dst"
    fi

    if [[ "$SYMLINK" == "1" ]]; then
        ln -s "$src" "$dst"
        info "Symlinked $hook → $src"
    else
        cp "$src" "$dst"
        info "Copied   $hook → $dst"
    fi

    chmod +x "$dst"
done

# ── 2. Include git-config ─────────────────────────────────────────────────────
if [[ "$INCLUDE_CONFIG" == "1" ]]; then
    section "Configuring git (include.path) …"

    config_src="$SCRIPT_DIR/git-config"
    if [[ ! -f "$config_src" ]]; then
        warn "git-config file not found at $config_src — skipping."
    else
        # Use absolute path so git can always find the file
        git -C "$TARGET_DIR" config --local include.path "$config_src"
        pass "Added: include.path = $config_src"
        info "To remove:  git config --local --unset include.path"
    fi
fi

# ── 3. Copy .gitattributes ────────────────────────────────────────────────────
if [[ "$COPY_ATTRS" == "1" ]]; then
    section "Checking .gitattributes …"
    attrs_src="$SCRIPT_DIR/.gitattributes"
    attrs_dst="$TARGET_DIR/.gitattributes"

    if [[ -f "$attrs_dst" ]]; then
        warn ".gitattributes already exists at $attrs_dst — skipping."
        warn "  Manually merge from: $attrs_src"
    elif [[ -f "$attrs_src" ]]; then
        cp "$attrs_src" "$attrs_dst"
        pass "Copied .gitattributes → $attrs_dst"
    else
        warn ".gitattributes source not found at $attrs_src — skipping."
    fi
fi

# ── 4. Copy .gitignore ────────────────────────────────────────────────────────
if [[ "$COPY_IGNORE" == "1" ]]; then
    section "Checking .gitignore …"
    ignore_src="$SCRIPT_DIR/.gitignore"
    ignore_dst="$TARGET_DIR/.gitignore"

    if [[ -f "$ignore_dst" ]]; then
        warn ".gitignore already exists at $ignore_dst — skipping."
        warn "  Manually merge from: $ignore_src"
    elif [[ -f "$ignore_src" ]]; then
        cp "$ignore_src" "$ignore_dst"
        pass "Copied .gitignore → $ignore_dst"
    else
        warn ".gitignore source not found at $ignore_src — skipping."
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────
section "Setup complete!"
echo ""
echo "  Hooks installed:  ${hooks[*]}"
echo "  Target repo:      $TARGET_DIR"
echo ""
echo "Tips:"
echo "  • To use symlinks (auto-update when template changes):"
echo "      SYMLINK=1 $0 $TARGET_DIR"
echo "  • To skip including git-config in the local config:"
echo "      INCLUDE_CONFIG=0 $0 $TARGET_DIR"
echo "  • To skip all checks for a single commit/push:"
echo "      git commit --no-verify"
echo "      git push --no-verify"
echo ""
