---
description: Run the harness drift audit and turn recurring patterns into improvement proposals.
---

Invoke the `claude-harness:harness-audit-and-propose` skill.

```bash
.harness/harness audit
.harness/harness query friction
.harness/harness query interventions
.harness/harness propose
```

Summarize the entropy score + top drift categories + the most actionable proposals. Treat the lowest-scoring area as a *candidate* bottleneck — confirm against real outcomes. Use `propose --commit` only to create proposed backlog items; do not change policy or risk rules without human confirmation.
