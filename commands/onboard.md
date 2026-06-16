---
description: Scan a project and capture a durable context-pack (stack, key paths, build/test commands, conventions) the harness reuses every session.
argument-hint: "[focus or notes — optional]"
---

Invoke the `claude-harness:harness-onboard-context` skill to onboard this project's context.

$ARGUMENTS

Steps:
1. If `docs/context/PROJECT_CONTEXT.md` already exists, READ it first — refresh rather than overwrite blindly.
2. DETECT: read manifests/lockfiles, README/CLAUDE.md/AGENTS.md, top-level layout, and test/CI config — do not guess.
3. WRITE `docs/context/PROJECT_CONTEXT.md` from `references/context-pack-template.md` (committed; lives under `docs/`, not `.harness/`).
4. RECORD the pointer in the harness:
   ```bash
   .harness/harness init
   .harness/harness migrate
   .harness/harness context capture --path docs/context/PROJECT_CONTEXT.md --summary "<one-line summary>"
   .harness/harness context show
   ```
   `context capture` hashes the file automatically (override with `--sha256`); no manual SQL or quoting.
5. Report what was captured. Onboarding records NO intake — the first code edit still requires `/claude-harness:intake`.
