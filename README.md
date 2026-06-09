# claude-skills

Personal Claude Code skills — shareable, version-controlled, installable.

## Install

```bash
git clone https://github.com/kudhru/claude-skills ~/work/research/claude-skills
cd ~/work/research/claude-skills
bash install.sh
```

Each skill is symlinked into `~/.claude/skills/`. Claude Code's live change detection picks up edits immediately — no restart needed.

## Uninstall

```bash
bash uninstall.sh
```

## Skills

| Skill | Invoke | Description |
|-------|--------|-------------|
| `eval-llm` | `/eval-llm <dataset> [--model] [--output] [--scorer]` | Run LLM evaluation as a reusable dynamic workflow. One agent per sample. Supports Claude and OpenAI models. |

## Tests

```bash
bash tests/test_install.sh       # symlink correctness
bash tests/test_skill_syntax.sh  # SKILL.md frontmatter validation
```

See `tests/README.md` for smoke-test instructions.

## Adding a skill

```bash
mkdir -p skills/<skill-name>
# Write skills/<skill-name>/SKILL.md
bash install.sh   # symlink the new skill
```
