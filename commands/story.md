---
description: Create or update a story (with verify command + proof matrix) for normal/high-risk work.
argument-hint: "<US-id> [title]"
---

Invoke the `claude-harness:harness-story` skill for: $ARGUMENTS

- If the story does not exist, create it with a mechanical verify command:
  ```bash
  .harness/harness story add --id <US-id> --title "<title>" --lane <lane> --verify "<command>"
  .harness/harness story update --id <US-id> --status in_progress
  ```
- Keep exactly one story `in_progress`.
- For high-risk work, design with `superpowers:brainstorming` → `superpowers:writing-plans` first (if installed), then execute via `superpowers:subagent-driven-development`.
- Record proof axes only once each test class genuinely passes (done by the verification skill, not here).
