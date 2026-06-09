#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"

installed=0
skipped=0

for skill_dir in "$REPO_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"

    if [ -L "$target" ]; then
        ln -sf "$skill_dir" "$target"
        echo "updated:   $skill_name"
        ((installed++)) || true
    elif [ -e "$target" ]; then
        echo "skipped:   $skill_name  (exists at $target and is not a symlink — remove manually to reinstall)"
        ((skipped++)) || true
    else
        ln -s "$skill_dir" "$target"
        echo "installed: $skill_name"
        ((installed++)) || true
    fi
done

echo ""
echo "$installed skill(s) installed/updated, $skipped skipped."
echo "Skills dir: $SKILLS_DIR"
