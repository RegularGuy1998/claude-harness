---
description: Record a durable execution trace (with required friction) at the end of a task.
argument-hint: "[summary]"
---

Invoke the `claude-harness:harness-trace-and-friction` skill. Record one trace scaled to the work's lane:

```bash
.harness/harness trace --summary "<what changed + observable result>" [--story <US-id>] \
  --outcome <completed|blocked|partial|failed> \
  --friction "<where the harness got in the way, or 'none' after checking>" \
  [--changed '[...]'] [--read '[...]'] [--actions N] [--duration MIN]
```

`--outcome` is one of completed|blocked|partial|failed (never "success"). Friction is required. If a process change is warranted, add a backlog item with a measurable `--predicted`. Then review the printed score.
