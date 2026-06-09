#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

removed=0

for skill_dir in "$REPO_DIR/skills"/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    target="$SKILLS_DIR/$skill_name"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_dir" ]; then
        rm "$target"
        echo "removed: $skill_name"
        ((removed++)) || true
    fi
done

echo ""
echo "$removed skill(s) removed."
