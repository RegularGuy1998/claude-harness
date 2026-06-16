---
name: harness-verification-before-completion
description: Use when about to claim work is complete, fixed, or passing in a harness project, before committing or ending the turn — requires running the story's verification command this turn and confirming exit 0 before any success claim.
---

# Harness Verification Before Completion

## Overview

Claiming work is complete without fresh evidence is dishonesty, not efficiency. This skill is the harness-backed extension of `superpowers:verification-before-completion`: same discipline, plus a durable, gate-enforced proof.

**Core principle:** Evidence before claims, always. **Violating the letter of this rule is violating the spirit of it.**

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you have not run the verification command **in this message**, you cannot claim it passes. For a tracked story, "the verification command" is the story's `verify_command`, run through the CLI so the result is recorded.

## The Gate Function

```
BEFORE claiming any status or expressing satisfaction:
1. IDENTIFY  the command that proves the claim (the story's verify command).
2. RUN it fresh this turn, recorded in the harness:
       .harness/harness story verify US-001      # runs verify_command; exit 0 = pass, 1 = fail
3. READ the output and exit code; count failures.
4. RECORD proof axes that now genuinely pass:
       .harness/harness story update --id US-001 --status implemented --unit 1 --integration 1 ...
5. SCORE the run / prepare the trace:
       .harness/harness score-trace
6. ONLY THEN make the claim — WITH the evidence.
Skip any step = lying, not verifying.
```

A `Stop` hook hard-blocks ending the turn while an `in_progress` story has a `verify_command` whose `last_verified_result` is not `pass`. The way past the gate is to make verification actually pass — not to talk around it.

## Common Failures

| Claim | Requires | Not sufficient |
|---|---|---|
| Tests pass | `story verify` exit 0 this turn | "should pass", a previous run |
| Bug fixed | Verify reproduces-then-passes | code changed, assumed fixed |
| Story done | `last_verified_result = pass` + proof axes set | status flipped by hand |
| Build succeeds | build command exit 0 | linter passing, logs "look good" |
| Subagent completed | git diff shows the changes | the subagent reported "success" |

## Red Flags — STOP

- "should / probably / seems to", or "Great!/Perfect!/Done!" before running verify.
- Flipping a story to `implemented` without `story verify` passing this turn.
- Setting a proof axis to `1` for a test class that does not exist.
- Trusting a subagent's success report without checking the diff.

## Rationalization Prevention

| Excuse | Reality |
|---|---|
| "I ran it earlier" | Fresh run this turn or it doesn't count. |
| "The Stop hook is annoying" | It encodes the rule. Make verify pass. |
| "Different words, so the rule doesn't apply" | Spirit over letter. Any success implication counts. |

## Terminal state

After proof is recorded → `claude-harness:harness-trace-and-friction` before the final response.
