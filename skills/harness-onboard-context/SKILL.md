---
name: harness-onboard-context
description: Use when starting work in a harness project that has no project context-pack yet — a brand-new repository, a fresh clone, or one whose pack is stale. Scans the repo to produce a durable, committed context-pack (stack, key paths, build/test commands, conventions) and records it in the harness, so every later session starts with project-specific context instead of rediscovering the repo.
---

# Harness Onboard Context

## Overview

A fresh project gives the agent the harness *method* but no knowledge of *this* repository. Onboarding fixes that once: scan the project, write a durable **context-pack** (`docs/context/PROJECT_CONTEXT.md`, committed), and record a pointer + content hash in the harness DB. Every later session reads the pack instead of re-deriving the stack, key paths, and commands.

Storage is **hybrid**: the rich content lives in the committed markdown file (human-readable, shared via git); the harness DB holds only a governance row (path + sha256 + when) so it can tell when the pack is **missing or stale**.

## The Iron Law

```
A PROJECT EARNS A CONTEXT-PACK BEFORE ITS FIRST FEATURE
```

This is discipline, not a hard block: the `SessionStart` hook **nudges** when a pack is missing or stale and points the agent to read an existing one — it never denies. Onboarding records *what the project is*; intake still gates *each change*.

## When to run

- A brand-new repo, or one the harness has never seen.
- A fresh clone (the committed pack may exist — read it; if absent, create it).
- The session-start nudge says the pack is missing or stale.
- Major structural change (new language/build system) makes the pack wrong.

## The Gate Function

```
WHEN onboarding project context:
1. DETECT  — read the manifests and structure; do NOT guess.
2. WRITE   — render docs/context/PROJECT_CONTEXT.md from the template.
3. RECORD  — init + migrate, hash the file, insert the pointer row.
4. CONFIRM — read the row back.
```

### 1. Detect (read, never assume)

Read what exists, in roughly this order, and stop when you have enough:

- **Manifests / lockfiles** → stack, package manager, scripts: `package.json`, `pnpm-workspace.yaml`, `Cargo.toml`, `pyproject.toml`/`requirements.txt`, `go.mod`, `pom.xml`/`build.gradle`, `*.csproj`, `Gemfile`, `composer.json`.
- **README / CONTRIBUTING / existing `CLAUDE.md`/`AGENTS.md`** → purpose, build/test/run commands, conventions.
- **Top-level layout** → entry points and the few directories that matter.
- **Test & CI config** → the real test command (`vitest`, `jest`, `pytest`, `cargo test`, `.github/workflows`).
- **Env / config samples** → external services (`.env.example`, `docker-compose.yml`).

### 2. Write the context-pack

Render `docs/context/PROJECT_CONTEXT.md` using `references/context-pack-template.md`. Keep it tight and **factual** — record only what you actually confirmed; mark unknowns as `TBD` rather than inventing. This file is **committed** (it lives under `docs/`, not `.harness/`).

### 3. Record in the harness

```bash
.harness/harness init        # create harness.db if absent (idempotent)
.harness/harness migrate     # apply pending migrations (brings older DBs to the project_context table)
.harness/harness context capture --path docs/context/PROJECT_CONTEXT.md --summary "<one-line summary>"
```

`context capture` hashes the file automatically (so the harness can later detect a stale pack);
pass `--sha256 <hash>` to override, or `--kind note` / `--notes "..."` as needed. No raw SQL, no
quote-escaping.

### 4. Confirm

```bash
.harness/harness context show
```

## Terminal state

Onboarding creates the DB but records **no intake** — so the next code edit still hits the intake gate, exactly as intended. After onboarding, return to the normal loop: `claude-harness:harness-intake` before the first edit.

## Red Flags — STOP

- Writing the pack from assumptions instead of reading manifests/README.
- Putting the pack under `.harness/` (git-ignored) — it must live at `docs/context/PROJECT_CONTEXT.md` so it is committed and shared.
- Writing the pack file but never running `context capture` — the harness then can't point sessions at it or detect staleness.
- Treating onboarding as the intake — it is not; classify the first change separately.
- Re-onboarding every session — do it once; refresh only when the pack is stale or the project structure changed.
