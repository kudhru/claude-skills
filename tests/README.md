# Tests

## Structural tests (no Claude required)

```bash
bash tests/test_install.sh       # install/uninstall symlink correctness
bash tests/test_skill_syntax.sh  # SKILL.md frontmatter validation
```

## Smoke dataset

`fixtures/smoke_dataset.jsonl` — 3 trivial samples for manual end-to-end testing:

```bash
# In a Claude Code session:
/eval-llm tests/fixtures/smoke_dataset.jsonl --model claude-haiku-4-5-20251001 --scorer exact
```

Expected: workflow script is written, 3 agents spawn, exact-match accuracy reported.
