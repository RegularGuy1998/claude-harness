# harness-cli reference (via `.harness/harness`)

The launcher pre-wires `HARNESS_CLI_BIN`, `HARNESS_REPO_ROOT`, and `HARNESS_DB`.
On Windows, invoke through Git Bash. Lanes on the CLI use the hyphenated form
`high-risk`; proof booleans are numeric (`1`/`0`), never `yes`/`no`.

## Lifecycle
```bash
.harness/harness init                 # create harness.db if absent (idempotent)
.harness/harness migrate              # apply pending schema migrations
.harness/harness query stats          # summary counts
```

## Intake
```bash
.harness/harness intake --type <new_spec|spec_slice|change_request|new_initiative|maintenance|harness_improvement> \
  --summary "<one line>" --lane <tiny|normal|high-risk> [--flags '["auth"]'] [--docs '["docs/.."]'] [--story US-001] [--notes "..."]
```

## Story + test matrix
```bash
.harness/harness story add --id US-001 --title "<t>" --lane <lane> [--verify "<cmd>"] [--contract <doc>]
.harness/harness story update --id US-001 [--status <planned|in_progress|implemented|changed|retired>] \
  [--unit 1] [--integration 1] [--e2e 0] [--platform 0] [--verify "<cmd>"] [--evidence "<text>"]
.harness/harness story verify US-001        # runs verify_command; exit 0 pass / 1 fail; records result
.harness/harness story verify-all           # run all; exit 1 if any fail
```

## Trace + friction
```bash
.harness/harness trace --summary "<t>" [--story US-001] [--outcome <completed|blocked|partial|failed>] \
  [--friction "<what was hard>"] [--read '[..]'] [--changed '[..]'] [--actions N] [--duration MIN] [--decisions "..."] [--errors "..."]
.harness/harness score-trace [--id <n>]      # completeness tier of a trace
.harness/harness score-context <trace-id>    # context-rule coverage (advisory)
```

## Decisions (high-risk behavior/architecture changes)
```bash
.harness/harness decision add --id 0001-<slug> --title "<t>" [--doc docs/decisions/<f>.md] [--status accepted] [--notes "..."]
```

## Backlog (harness improvement loop)
```bash
.harness/harness backlog add --title "<t>" [--pain "<>"] [--suggestion "<>"] [--risk <lane>] [--predicted "<measurable>"]
.harness/harness backlog close --id <n> --outcome "<measured result>"
```

## Audit / propose / query
```bash
.harness/harness audit                        # drift categories + entropy score
.harness/harness propose [--commit]           # proposals from friction/interventions/drift
.harness/harness query <matrix|backlog|decisions|intakes|traces|friction|tools|interventions|stats|sql>
.harness/harness query matrix [--numeric]     # proof matrix (numeric mirrors CLI input)
.harness/harness query sql "<SELECT ...>"      # arbitrary SQL (read carefully; output has header + separator)
```
