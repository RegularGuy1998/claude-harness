# claude-harness

A Claude Code **plugin** that turns any repository into an agent-governed workspace with **hard gates**.

It wraps the durable Rust `harness-cli` (feature intake, risk lanes, story packets + test matrix, decision records, execution traces, drift audit) and adds what a Codex-style `AGENTS.md` install cannot: a `SessionStart` hook that auto-loads the workflow, and `PreToolUse` / `Stop` hooks that **block** instead of merely advising.

The app is what users touch. The harness is what the agent touches.

## What it gives an agent

- **Intake before edits** — every change is classified (input type + risk lane) before any code is touched. A `PreToolUse` hook blocks the first edit in an initialized project that has no intake.
- **One active feature** — normal/high-risk work becomes a story with a test matrix.
- **Verification before "done"** — a `Stop` hook blocks ending the turn while an in-progress story's verification command has not passed.
- **Traces with friction** — every task records what happened and where the harness got in the way, feeding `audit` and `propose`.

## Design

- **Method is global, state is per-project.** The plugin (skills + hooks + binary launcher) installs once; each project carries only its own `.harness/harness.db` + schema. No 42-file copy into every repo.
- **Binary on demand.** On first session the `SessionStart` hook downloads the matching `harness-cli` from GitHub Releases, verifies its SHA-256, and caches it under the plugin data dir. Missing/failed download → gates degrade to advisory, never brick the session.
- **Composes with [superpowers](https://github.com/obra/superpowers).** claude-harness owns durable state, risk governance, and enforcement; superpowers owns engineering discipline (brainstorming, plans, subagent-driven development, TDD, debugging, code review). Install both for the full workflow; claude-harness still stands alone.

## Install (Claude Code)

```
/plugin marketplace add <owner>/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

Then open a project and run `/claude-harness:intake "<your request>"` to opt that project in.

**Windows:** requires Git for Windows (hooks run through a polyglot bash wrapper). See `docs/INSTALL.md`.

## Usage

Open a new session in a project. On a new repo (or a fresh clone), run
`/claude-harness:onboard` once to capture a durable context-pack, then drive the loop with
`/claude-harness:intake` → `:story` → `:verify` → `:trace`. The full guide (mental model, a
worked example, the gates, CLI cheat-sheet, and troubleshooting) is in
**[docs/USAGE.md](docs/USAGE.md)**.

## Skills

| Skill | When |
|---|---|
| `using-claude-harness` | Auto-loaded each session; the intake → work → verify → trace loop. |
| `harness-onboard-context` | New repo / fresh clone / stale pack: capture a durable project context-pack. |
| `harness-intake` | Before editing code: classify input + risk lane. |
| `harness-story` | Normal/high-risk work needing a story + test matrix. |
| `harness-verification-before-completion` | Before claiming done/fixed/passing. |
| `harness-trace-and-friction` | Finishing a task; record trace + friction. |
| `harness-audit-and-propose` | Reviewing harness health / recurring friction. |

## Slash commands

`/claude-harness:onboard`, `:intake`, `:story`, `:verify`, `:trace`, `:audit`, `:harness-status`.

## Status

v0.1.0. The durable CLI and its release binaries come from [hoangnb24/repository-harness](https://github.com/hoangnb24/repository-harness) (pinned in `scripts/harness-cli-release-tag`). See `docs/enforcement.md` for how the gates work and how they degrade.
