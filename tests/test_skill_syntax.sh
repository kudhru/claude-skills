#!/usr/bin/env bash
# Tests that every SKILL.md has valid frontmatter and required fields.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

ok()   { echo "PASS: $*"; ((PASS++)) || true; }
fail() { echo "FAIL: $*"; ((FAIL++)) || true; }

echo "=== test_skill_syntax.sh ==="

for skill_md in "$REPO_DIR/skills"/*/SKILL.md; do
    [ -f "$skill_md" ] || continue
    skill_name="$(basename "$(dirname "$skill_md")")"

    # Opening --- on line 1
    if head -1 "$skill_md" | grep -q "^---$"; then
        ok "$skill_name: opens with frontmatter"
    else
        fail "$skill_name: missing opening --- on line 1"
    fi

    # Closing --- exists
    if awk 'NR>1 && /^---$/{found=1; exit} END{exit !found}' "$skill_md"; then
        ok "$skill_name: closes frontmatter"
    else
        fail "$skill_name: missing closing ---"
    fi

    # description field
    if grep -q "^description:" "$skill_md"; then
        ok "$skill_name: has description field"
    else
        fail "$skill_name: missing description field"
    fi

    # Non-empty body after frontmatter
    body_lines=$(awk '/^---$/{n++} n==2{found=1} found && NF>0{print}' "$skill_md" | wc -l)
    if [ "$body_lines" -gt 0 ]; then
        ok "$skill_name: has non-empty body"
    else
        fail "$skill_name: empty body after frontmatter"
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] || exit 1
