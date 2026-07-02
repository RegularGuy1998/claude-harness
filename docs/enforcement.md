# Enforcement: how the hard gates work

**English** · [Tiếng Việt](vi/enforcement.md) · [简体中文](zh/enforcement.md)

The point of claude-harness over a Codex-style `AGENTS.md` install is that its
rules are **enforced by hooks**, not merely written down. Three hooks are
registered in `hooks/hooks.json`; all run through the polyglot
`hooks/run-hook.cmd` wrapper.

Every gate is **fail-open**: no database (project not opted in), no binary, or a
query error always results in *allow*. A harness must never brick a repo.

## 1. SessionStart — `hooks/session-start`

- Matcher: `startup|resume|clear|compact`.
- Bootstraps the binary + `.harness/`, then injects the `using-claude-harness`
  skill via `hookSpecificOutput.additionalContext` so the workflow is live for
  the whole session.
- Degrade: on bootstrap failure it still injects the skill plus an "ADVISORY
  mode" note. Always exits 0.

## 2. PreToolUse — `hooks/pretool-intake-gate`

Turns *"classify before you edit"* into a block.

- Matcher: `Edit|Write|MultiEdit`.
- Logic: if the project is initialized (`.harness/harness.db` exists) **and**
  `SELECT COUNT(*) FROM intake` is 0 → **deny**:

  ```json
  { "hookSpecificOutput": {
      "hookEventName": "PreToolUse",
      "permissionDecision": "deny",
      "permissionDecisionReason": "...run /claude-harness:intake before editing code..." } }
  ```

- Exemptions (always allow): paths under `.harness/`, `docs/stories/`, or
  `docs/superpowers/` — so recording intake and writing story/spec docs is never
  self-blocked.
- It is a **first-edit gate**: one recorded intake opens editing for the
  session. It is not per-file.

## 3. Stop — `hooks/stop-verify-gate`

Turns *"verify before done"* into a block.

- Logic: if any story is `in_progress` with a `verify_command` whose
  `last_verified_result` is not `pass` → **block** ending the turn:

  ```json
  { "decision": "block", "reason": "...run /claude-harness:verify (exit 0) and /claude-harness:trace..." }
  ```

- **Loop-safe:** when the hook has already blocked, Claude Code sets
  `stop_hook_active: true` on the next Stop; the hook then allows, so the human
  is never trapped. (Claude Code also caps consecutive blocks at 8 by default,
  override via `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`.)
- The only way past is to make `story verify` actually pass — recorded through
  the CLI, not talked around.

## Worktrees and sessions

- **Linked git worktrees share the main repository's `.harness/`.** The hooks
  resolve a linked worktree to the main root (`git rev-parse
  --git-common-dir`), session-start writes only a thin `.harness/harness`
  launcher inside the worktree (hidden via the worktree's private exclude),
  and every gate and CLI call reads and writes the ONE root `harness.db`.
- **Stop gate scopes per session.** When a session is started with
  `HARNESS_SESSION_ID=<id>` and its stories are recorded with `story add
  --session` (or the env var), the Stop gate blocks only on that session's
  unmet stories. Without the env var the gate keeps its original repo-wide
  behavior. Orchestrators (e.g. claude-team-harness) set the variable per
  spawned worktree session. Only `story add` falls back to the env var;
  `story update` changes assignment solely via an explicit `--session`, so
  updating another session's story never steals it.

## Parsing note

Only `tool check` and `query tools` emit JSON; the gates therefore rely on exit
codes and `query sql`. `query sql` always prints a header line and a dashed
separator before any data rows, so the gates skip the first two lines
(`tail -n +3`) when counting rows. See `hooks/lib/harness-env`
(`he_sql_rows` / `he_sql_count`).

## Tests

`tests/run-tests.sh` exercises all of the above against the real `harness-cli`
binary (allow → deny → allow for intake; allow → block → loop-guard → allow for
verify; degrade with a missing binary). Run: `bash tests/run-tests.sh`.

## What is NOT enforced (by design)

Agent honesty inside a turn (e.g. setting a proof axis it shouldn't) is shaped
by the skills' binding language, not a hook — there is no reliable mechanical
signal for it. The gates enforce the two checkpoints that *do* have a signal:
an intake row before edits, and a passing verification before stop.
