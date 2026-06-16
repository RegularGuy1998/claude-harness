# Risk Lanes & Intake Classification

## Input types (`--type`)

| Type | Meaning |
|---|---|
| `new_spec` | A project specification that must become product docs + initial stories |
| `spec_slice` | A selected behavior from an existing spec |
| `change_request` | A bounded behavior change, bug fix, or refinement |
| `new_initiative` | A larger product area needing multiple stories |
| `maintenance` | Dependency, performance, security, or operational work |
| `harness_improvement` | A process / template / proof / instruction change to the harness itself |

## The risk-flag checklist

Count how many apply:

1. Touches **authentication**
2. Touches **authorization** / access control
3. Changes the **data model** / schema
4. Involves **data migration or deletion**
5. Touches **audit or security** surfaces
6. Integrates an **external system / provider**
7. Changes a **public contract / API shape**
8. **Cross-platform** behavior (shell, mobile, desktop, deploy)
9. Modifies **existing user-visible behavior**
10. Has **weak or missing proof** (hard to verify)

## Lane assignment

| Lane | Rule |
|---|---|
| `tiny` | 0–1 flags, fully reversible, no contract/architecture impact |
| `normal` | 2–3 flags |
| `high-risk` | 4+ flags, **OR** any hard gate below (count is irrelevant) |

## Hard gates → force `high-risk`

Any one of these forces high-risk regardless of flag count:

- Authentication
- Authorization
- Data loss / migration / deletion
- Audit / security
- External provider integration
- **Weakening or removing validation**

## Stop conditions (high-risk)

Pause and ask the human before proceeding when the work would:

- delete or migrate data,
- change an auth/authorization boundary,
- weaken existing validation, or
- change architecture direction.

Record the lane and flags in the intake:

```bash
.harness/harness intake --type change_request --summary "Add rate limiting to login" \
  --lane high-risk --flags '["auth","existing_behavior"]' --docs '["docs/ARCHITECTURE.md"]'
```
