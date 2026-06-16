---
name: harness-audit-and-propose
description: Use when reviewing harness health, when friction or interventions keep recurring, or before a milestone — runs the drift audit and turns observed patterns into concrete improvement proposals.
---

# Harness Audit & Propose

## Overview

The harness grows from friction. This skill reads the durable record and turns recurring pain into proposed changes. It is a judgment skill — adapt it to what the data shows.

## When to use

- Recurring friction across traces (`query friction` keeps showing the same theme).
- Repeated human/CI interventions on similar work.
- Before a milestone, merge train, or maturity claim.
- Periodic harness maintenance.

## Procedure

1. **Read the signals:**

   ```bash
   .harness/harness audit                 # drift categories + entropy score
   .harness/harness query friction        # traces carrying friction
   .harness/harness query interventions   # corrections/overrides/escalations
   .harness/harness query backlog --open  # already-proposed improvements
   .harness/harness query stats           # summary counts
   ```

2. **Generate proposals** deterministically from the patterns:

   ```bash
   .harness/harness propose               # print proposals (read-only)
   .harness/harness propose --commit      # create proposed backlog items (does NOT edit policy or approve)
   ```

3. **Interpret, don't obey.** The entropy score and proposals are signals, not verdicts. Treat the lowest-scoring area or loudest friction as a *candidate* bottleneck; confirm against real outcomes before claiming a change will help.

4. **Close the loop with evidence.** When a backlog improvement is implemented, close it with the measured result so prediction can be compared to outcome:

   ```bash
   .harness/harness backlog close --id <n> --outcome "<measured result or review evidence>"
   ```

## Boundaries (ask the human first)

These are not agent-autonomous — propose, then get human confirmation:

- changing risk-classification rules,
- removing or weakening validation requirements,
- changing the source-of-truth hierarchy,
- replacing the feature workflow,
- changing architecture direction.

## Note

`audit`/`propose` measure *structure and recorded patterns*, not ground-truth effectiveness. Pair them with real before/after task outcomes before concluding a change worked.
