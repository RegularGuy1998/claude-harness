---
description: Diagnose the harness: binary version, DB path, schema version, and whether this project is initialized.
---

Report the harness status for this project. Do NOT initialize the database (that opts the project in — use `/claude-harness:intake` for that).

```bash
# Binary + launcher
test -x .harness/harness && .harness/harness --version || echo "launcher missing — session-start has not run, or .harness/ is not writable"

# Is this project opted in?
test -f .harness/harness.db && echo "initialized" || echo "NOT initialized (run /claude-harness:intake to opt in)"

# If initialized, show schema version + counts
.harness/harness query sql "SELECT MAX(version) AS schema_version FROM schema_version" 2>/dev/null
.harness/harness query stats 2>/dev/null

# Context-pack (onboarding) status
test -f docs/context/PROJECT_CONTEXT.md && echo "context-pack: present (docs/context/PROJECT_CONTEXT.md)" || echo "context-pack: none (run /claude-harness:onboard)"
.harness/harness query sql "SELECT path,sha256,captured_at FROM project_context ORDER BY id DESC LIMIT 1" 2>/dev/null
```

Flag any skew between the binary's expected schema and the applied schema version, and note if gates are in advisory mode (no binary / no DB). For the context-pack, note if the file exists but is unrecorded, or if its current sha256 differs from the recorded row (stale → suggest `/claude-harness:onboard`).
