#!/usr/bin/env bash
# Tests that install.sh correctly creates symlinks in ~/.claude/skills/
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
PASS=0
FAIL=0

ok()   { echo "PASS: $*"; ((PASS++)) || true; }
fail() { echo "FAIL: $*"; ((FAIL++)) || true; }

echo "=== test_install.sh ==="

# Run install
bash "$REPO_DIR/install.sh" > /dev/null

for skill_dir in "$REPO_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"

    if [ -L "$target" ]; then
        ok "$skill_name: symlink exists"
    else
        fail "$skill_name: symlink missing at $target"
    fi

    if [ -f "$target/SKILL.md" ]; then
        ok "$skill_name: SKILL.md readable through symlink"
    else
        fail "$skill_name: SKILL.md not readable through symlink"
    fi
done

# Run uninstall and verify removal
bash "$REPO_DIR/uninstall.sh" > /dev/null

for skill_dir in "$REPO_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"

    if [ ! -e "$target" ]; then
        ok "$skill_name: symlink removed by uninstall"
    else
        fail "$skill_name: symlink still exists after uninstall"
    fi
done

# Reinstall so skills are active after tests
bash "$REPO_DIR/install.sh" > /dev/null

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
