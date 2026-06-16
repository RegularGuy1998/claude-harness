---
name: using-claude-harness
description: Use when starting any conversation in a repository that has a .harness/ workspace or the claude-harness plugin is active — establishes the intake → work → verify → trace loop and how to drive the durable harness-cli.
---

# Using claude-harness

This repository is governed by **claude-harness**: a durable operating harness backed by `harness-cli` (a local SQLite database under `.harness/`). The app is what users touch; the harness is what you touch.

## Running the harness CLI

Always invoke through the project launcher (env is pre-wired):

```bash
.harness/harness <command>     # e.g. .harness/harness query matrix
```

If `.harness/harness` does not exist, the project has not opted in yet — running `/claude-harness:intake` (or `.harness/harness init`) creates it. On Windows, run via Git Bash.

## The Loop (every task)

1. **Classify before editing.** Before changing ANY code, record an intake → invoke `claude-harness:harness-intake`. This assigns a **risk lane** (tiny / normal / high-risk). A `PreToolUse` hook hard-blocks edits in an initialized project that has no intake.
2. **One active feature.** Normal/high-risk work becomes a story → `claude-harness:harness-story`. Do not start a second feature before the current one passes.
3. **Verify before claiming done.** Before saying "done/fixed/passing", invoke `claude-harness:harness-verification-before-completion`. A `Stop` hook hard-blocks ending the turn while an in-progress story's verification has not passed.
4. **Trace at the end.** Before your final response, record a trace with friction → `claude-harness:harness-trace-and-friction`.
5. **Harness health.** When friction repeats, invoke `claude-harness:harness-audit-and-propose`.

## Skill priority

Process skills first (intake, verification), then implementation. "Let's build/fix X" → `harness-intake` BEFORE any code.

## Composes with superpowers

claude-harness owns durable state, risk governance, and enforcement. For the engineering work itself, defer to **superpowers** when installed: `brainstorming`/`writing-plans` for high-risk design, `subagent-driven-development` for execution, `test-driven-development`, `systematic-debugging`, code-review. The harness records *what happened and whether it is proven*; superpowers governs *how the code gets written*.

## Red flags (STOP)

- About to edit code without a recorded intake → run `/claude-harness:intake` first.
- About to say "done" without running the verify command in this turn → run the verification skill.
- Marking proof/state by hand → the CLI owns state; use `.harness/harness story update` / `story verify`.
