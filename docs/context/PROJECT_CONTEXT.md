# Project context

> Captured by claude-harness onboarding. Refresh with `/claude-harness:onboard`
> when the stack, key paths, or commands change.

## What this is
**claude-harness** is a Claude Code *plugin* that turns any repository into an
agent-governed workspace with hard gates (intake → story → verify → trace). It
wraps a durable Rust CLI (`harness-cli`) and adds `SessionStart` / `PreToolUse` /
`Stop` hooks that block instead of merely advising. Audience: agents (and the
developers who install the plugin) working in governed repos.

## Stack & runtime
- Languages: Rust (the `harness-cli` binary); Bash polyglot wrappers (hooks/launcher); Markdown (skills/commands/docs).
- Frameworks / runtime: clap 4 (CLI), rusqlite 0.39 (bundled SQLite — no system lib), sha2, thiserror.
- Package manager: Cargo (workspace). Lockfile: `Cargo.lock`.
- Notable versions / constraints: Rust edition 2021, workspace resolver 3. `harness-cli` version `0.1.14` pinned in lockstep with `scripts/harness-cli-release-tag` (`harness-cli-v0.1.14`). Plugin is at v0.1.0.

## Entry points & key paths
- Entry point(s): `crates/harness-cli/src/main.rs` (binary). Plugin entry: `.claude-plugin/` hooks + `commands/*.md` slash commands.
- Important directories:
  - `crates/harness-cli/src/` — the Rust CLI, organized DDD-style: `domain.rs`, `application.rs`, `infrastructure.rs`, `interface.rs`, `main.rs`.
  - `skills/` — agent skills (`harness-onboard-context`, `harness-intake`, `harness-story`, `harness-verification-before-completion`, `harness-trace-and-friction`, `harness-audit-and-propose`, `using-claude-harness`).
  - `commands/` — slash commands (`onboard`, `intake`, `story`, `verify`, `trace`, `audit`, `harness-status`).
  - `hooks/` — `SessionStart` / `PreToolUse` / `Stop` gate scripts + `run-hook.cmd` polyglot dispatcher.
  - `scripts/` — `bootstrap-binary`, `build-harness-cli-release.sh`, `harness-cli-release-tag`, `schema/` (SQL migrations).
  - `tests/` — integration tests (`run-tests.sh`, `fixtures/`, `hooks/`).
  - `docs/` — `INSTALL.md`, `USAGE.md`, `enforcement.md`, `vi/` (Vietnamese translations).
- Generated / vendored (do not edit): `target/` (Rust build), `tests/fixtures/bin/` (downloaded test binary), `.harness/` (materialized per-project workspace, git-ignored).

## Build / Test / Run
| Action | Command |
|---|---|
| Install | `cargo build` (deps fetched automatically) |
| Build | `cargo build -p harness-cli` (release: `cargo build --release -p harness-cli`) |
| Run / dev | `cargo run -p harness-cli -- <args>` ; in a project: `.harness/harness <command>` |
| Test (all) | `cargo test` (unit) ; `bash tests/run-tests.sh` (hook/gate integration) |
| Test (single) | `cargo test <name>` ; `cargo test -p harness-cli <name>` |
| Lint / format | `cargo fmt` ; `cargo clippy` |
| Type-check | `cargo check` |

> Hook/gate integration tests need the test binary at `tests/fixtures/bin/harness-cli[.exe]` first (fetched, not committed).

## Conventions
- Code style / formatter: rustfmt (`cargo fmt`); clippy for lints.
- Commit / branch conventions: feature branches off `main`; PRs target `main`. (Code & commit messages in English; chat replies in Vietnamese per user global config.)
- Testing conventions: Rust unit tests inline/with crate; integration tests in `tests/run-tests.sh` (bash) exercise real hooks against the real binary via fixtures.
- Other house rules: DDD layering inside `harness-cli` (domain → application → infrastructure → interface). The CLI owns all durable state — never hand-edit `.harness/harness.db` or mark proof manually; use `harness story update` / `story verify`.

## External dependencies & services
- Datastores / queues / APIs: per-project SQLite DB at `.harness/harness.db` (bundled rusqlite, no external server). GitHub Releases hosts the `harness-cli` binary downloaded on first session.
- Required env vars / secrets: none for normal use. Runtime overrides: `HARNESS_CLI_BIN`, `HARNESS_CLI_RELEASE_TAG`, `HARNESS_CLI_BASE_URL`, `HARNESS_CLI_RELEASE_REPO`, `CLAUDE_PLUGIN_ROOT`, `CLAUDE_PROJECT_DIR`, `CLAUDE_PLUGIN_DATA`.
- Local services to run: none.

## Domain glossary
- **Intake** — a recorded classification (input type + risk lane) required before any code edit; enforced by a `PreToolUse` hook.
- **Risk lane** — tiny / normal / high-risk; determines whether a story is required.
- **Story** — a tracked unit of normal/high-risk work with a verification command + proof matrix.
- **Trace / friction** — a durable execution record at task end, capturing where the harness itself got in the way; feeds `audit`.
- **Context-pack** — this file (`docs/context/PROJECT_CONTEXT.md`); committed, hashed into the DB so the harness can detect a missing/stale pack.
- **Gate / hook** — `SessionStart` (auto-loads workflow, fetches binary), `PreToolUse` (blocks edits without intake), `Stop` (blocks "done" without passing verification).

## Where docs & decisions live
- Docs: `docs/USAGE.md` (full guide), `docs/INSTALL.md` (Windows/Git Bash setup), `docs/enforcement.md` (how gates work & degrade), `docs/vi/` (Vietnamese), `README.md`.
- Architecture decisions: `docs/enforcement.md` for the gating/degradation model.
- Other references: `.github/workflows/harness-cli-release.yml` (build/publish CLI), `scripts/harness-cli-release-tag` (pinned release).

## Gotchas / non-obvious constraints
- **Windows-first dev environment** — hooks run through a polyglot bash wrapper; requires Git for Windows. Run `.harness/harness` via Git Bash on Windows.
- **Binary on demand** — the CLI is downloaded + SHA-256-verified on first session; if the download fails the gates degrade to advisory rather than bricking the session.
- **`.harness/` is git-ignored** — the context-pack must live under `docs/`, never `.harness/`, so it is committed and shared.
- **Method global, state per-project** — the plugin installs once; each repo carries only its own `.harness/harness.db` + schema. No mass file-copy into repos.
- Keep `crates/harness-cli/Cargo.toml` version and `scripts/harness-cli-release-tag` bumped in lockstep.
