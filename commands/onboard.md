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
   SHA="$(sha256sum docs/context/PROJECT_CONTEXT.md | awk '{print $1}')"   # or: shasum -a 256 ...
   .harness/harness query sql "INSERT INTO project_context(kind,path,sha256,summary) VALUES('pack','docs/context/PROJECT_CONTEXT.md','$SHA','<one-line summary>')"
   .harness/harness query sql "SELECT id,kind,path,sha256,summary,captured_at FROM project_context ORDER BY id DESC LIMIT 1"
   ```
   Keep the summary on one line; escape any `'` as `''`.
5. Report what was captured. Onboarding records NO intake — the first code edit still requires `/claude-harness:intake`.
