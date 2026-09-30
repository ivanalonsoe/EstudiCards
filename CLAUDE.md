# CLAUDE.md

The project instructions are in `AGENTS.md`, shared with other coding agents. Claude Code loads them through this import:

@AGENTS.md

## Notes specific to Claude Code

- Talk to the owner in Spanish; write code, tests, commits and documentation in English (see `AGENTS.md`).
- Before starting a task, read it in `docs/TASKS.md`, together with the user stories and rules from `docs/SPEC.md` it references. If it involves UI, look at the screenshots in `docs/design/` and the brief.
- Apply TDD: first show the tests failing, then green (see `AGENTS.md`).
- For multi-part tasks, create a task list and tick items off as you go.
- If a decision is not in the spec and changes the behaviour the user sees, ask before implementing it.
