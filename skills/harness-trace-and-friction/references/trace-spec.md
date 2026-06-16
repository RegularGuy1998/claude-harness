# Trace Spec

A trace is the durable record of one task. The depth expected scales with the
work's risk lane. `score-trace` rewards completeness against the tier.

## Fields (`harness-cli trace`)

| Flag | Meaning |
|---|---|
| `--summary` (required) | One line: what changed and the observable result |
| `--story` | Linked story id (`US-NNN`) |
| `--intake` | Linked intake id |
| `--outcome` | `completed` \| `blocked` \| `partial` \| `failed` |
| `--friction` | Where the harness got in the way (required by discipline; `none` only after checking) |
| `--read` | JSON array of files read |
| `--changed` | JSON array of files changed |
| `--actions` | Count of tool actions |
| `--duration` | Minutes |
| `--tokens` | Token estimate |
| `--decisions` | Decisions made (link a decision record for behavior/architecture changes) |
| `--errors` | Errors hit and how resolved |
| `--notes` | Anything else |

## Tier by lane

| Lane | Required | Recommended |
|---|---|---|
| **tiny** | summary, outcome, friction | changed |
| **normal** | + story, changed, read | actions, duration |
| **high-risk** | + decisions, errors | actions, duration, tokens; a `decision add` record when a contract/architecture changed |

## Friction is the engine

`harness-cli query friction` surfaces recurring pain; `harness-cli propose`
turns repeated friction + interventions + audit drift into backlog proposals.
A trace with honest friction is what makes the harness improve. An empty
`--friction "none"` on every trace silently starves that loop.
