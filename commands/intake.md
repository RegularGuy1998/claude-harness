---
description: Classify and record a feature intake (input type + risk lane) before any code edit.
argument-hint: "<what you want to do>"
---

Invoke the `claude-harness:harness-intake` skill and classify this request:

$ARGUMENTS

Steps:
1. Determine the input type and run the risk-flag checklist to pick a lane (`tiny|normal|high-risk`), honoring hard-gate overrides.
2. Ensure the project is initialized and record the intake:
   ```bash
   .harness/harness init
   .harness/harness intake --type <type> --summary "<one line>" --lane <lane> [--flags '[...]'] [--docs '[...]']
   ```
3. Report the chosen lane + flags + affected docs, then proceed per the lane's terminal state (tiny → work; normal/high-risk → `claude-harness:harness-story`).
