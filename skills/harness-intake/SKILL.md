---
name: harness-intake
description: Use when a user asks to add, change, fix, build, or refactor anything in a harness project, before editing any code — classifies the work's input type and risk lane and records it in the durable harness before implementation begins.
---

# Harness Intake

## Overview

Every piece of work enters the harness through intake: you classify it (input type + **risk lane**) and record it before touching code. This is what lets the harness schedule, gate, and trace the work.

**Violating the letter of this rule is violating the spirit of it.**

## The Iron Law

```
NO CODE EDIT WITHOUT A RECORDED INTAKE
```

In an initialized project a `PreToolUse` hook hard-blocks the first `Edit`/`Write`/`MultiEdit` until an intake row exists. Don't fight the gate — record the intake.

## The Gate Function

```
BEFORE editing any code:
1. CLASSIFY input type: new_spec | spec_slice | change_request | new_initiative | maintenance | harness_improvement
2. RUN the risk checklist → assign a lane (see references/risk-lanes.md)
3. RECORD it (this also creates the DB on first use):
     .harness/harness init
     .harness/harness intake --type <type> --summary "<one line>" --lane <tiny|normal|high-risk> [--flags '["auth","data_model"]'] [--docs '["docs/..."]']
4. ONLY THEN proceed per the lane's terminal state
```

Lane values on the CLI are `tiny`, `normal`, `high-risk` (hyphen). Input types use underscores.

## Risk lanes (summary — full checklist in references/risk-lanes.md)

- **tiny** (0–1 flags): trivial, reversible, no contract/architecture impact. Proceed directly; still verify + trace at the end.
- **normal** (2–3 flags): real feature/bugfix. → invoke `claude-harness:harness-story`.
- **high-risk** (4+ flags OR any hard gate): auth, authorization, data model / migration / deletion, audit/security, external provider, or weakening validation. → invoke `claude-harness:harness-story`, and defer design to `superpowers:brainstorming` then `superpowers:writing-plans` when available. **Stop conditions apply** — pause for the human on data loss, auth, or weakening validation.

**Hard-gate override:** any single hard-gate flag forces high-risk regardless of flag count. Never under-report flags to land an easier lane.

## Terminal state

- tiny → do the work, then `claude-harness:harness-verification-before-completion` → `claude-harness:harness-trace-and-friction`.
- normal / high-risk → `claude-harness:harness-story`.

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "This is a one-line fix, intake is overkill" | One-liners touch auth/migrations too. 10 seconds to classify. |
| "I'll record the intake after I edit" | The gate blocks the edit. Intake is the entry, not the exit. |
| "I'll just explore/read first" | Reading is fine; the intake comes before the first *edit*, not before reading. |
| "It's obviously tiny" | Run the checklist. "Obvious" is how hard-gate work gets mislabeled. |

## Red Flags — STOP

- About to call `Edit`/`Write` with no intake recorded this project.
- Picking a lane by gut without running the flag checklist.
- Downgrading a flag ("it's not *really* auth") to avoid high-risk.
