---
name: harness-trace-and-friction
description: Use when finishing a task in a harness project, before the final response — records a durable execution trace, including where the harness itself created friction, so quality and process can be measured and improved.
---

# Harness Trace & Friction

## Overview

Every task ends with a trace: a durable record of what happened, linked to its intake/story, plus the **friction** the harness created. Friction is how the harness improves itself — skipping it blinds `audit` and `propose`.

## Output shape (recipe)

Record one trace, scaled to the lane's tier (see references/trace-spec.md):

```bash
.harness/harness trace \
  --summary "Added login rate limiting; 429 after 5 attempts/min" \
  --story US-001 \
  --outcome completed \
  --changed '["src/auth/rateLimit.ts","src/auth/login.ts"]' \
  --read '["docs/ARCHITECTURE.md"]' \
  --friction "TEST_MATRIX had no rate-limit row; had to infer the proof shape" \
  [--actions N] [--duration MIN] [--decisions "..."] [--errors "..."]
```

**`--outcome` accepts only:** `completed | blocked | partial | failed`. (There is no `success`.)

**`--friction` is required by discipline.** If nothing was hard, state that explicitly (`--friction "none"`) — but first check: did you re-derive anything, lack a rule, infer a proof shape, or hit a confusing CLI/doc? That is friction; record it.

Then review the auto-printed score, or:

```bash
.harness/harness score-trace
```

## If friction warrants a process change

Record a backlog item with a falsifiable prediction:

```bash
.harness/harness backlog add --title "Add rate-limit row to TEST_MATRIX template" \
  --pain "No proof shape for rate limiting; inferred it" \
  --suggestion "Add a throttling row to the matrix template" \
  --risk tiny --predicted "Future throttling stories start with a proof row"
```

## Trace tiers (by lane)

| Lane | Minimum fields |
|---|---|
| tiny | summary, outcome, friction |
| normal | + story link, files changed, files read |
| high-risk | + decisions, errors, actions/duration; link a decision record when behavior/architecture changed |

## Red Flags

- Ending the turn with no trace recorded.
- `--friction "none"` without actually checking for re-derivation / missing rules.
- Using `--outcome success` (invalid) instead of `completed`.
- A high-risk trace with no decision link when a contract/architecture changed.
