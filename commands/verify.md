---
description: Run a story's verification command this turn and record the result before any "done" claim.
argument-hint: "[US-id]"
---

Invoke the `claude-harness:harness-verification-before-completion` skill for: $ARGUMENTS

```bash
.harness/harness story verify <US-id>     # or: .harness/harness story verify-all
```

- Read the output and exit code (0 = pass, 1 = fail). Do NOT claim success unless it passed THIS run.
- On pass, record proof axes that now genuinely pass and set status:
  ```bash
  .harness/harness story update --id <US-id> --status implemented --unit 1 --integration 1 --e2e 0 --platform 0
  ```
- Then proceed to `claude-harness:harness-trace-and-friction`.
