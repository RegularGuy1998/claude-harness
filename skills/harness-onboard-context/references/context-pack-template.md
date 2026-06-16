# Context-pack template

Render this into `docs/context/PROJECT_CONTEXT.md`. Fill every section from what
you actually read in the repo; use `TBD` for anything you could not confirm. Keep
it scannable — this file is loaded at the start of future sessions, so favor the
few facts that change how work is done over exhaustive detail.

---

```markdown
# Project context

> Captured by claude-harness onboarding. Refresh with `/claude-harness:onboard`
> when the stack, key paths, or commands change.

## What this is
<one or two lines: what the project does and who uses it>

## Stack & runtime
- Languages: <e.g. TypeScript, Rust>
- Frameworks / runtime: <e.g. Electron + React 18, Node 20>
- Package manager: <npm | pnpm | yarn | cargo | uv | …> (lockfile: <path>)
- Notable versions / constraints: <e.g. ESM only, min Node 20>

## Entry points & key paths
- Entry point(s): <e.g. src/main/index.ts, src/cli.rs>
- Important directories:
  - `<path>` — <what lives here>
  - `<path>` — <what lives here>
- Generated / vendored (do not edit): <e.g. dist/, node_modules/, target/>

## Build / Test / Run
| Action | Command |
|---|---|
| Install | `<cmd>` |
| Build | `<cmd>` |
| Run / dev | `<cmd>` |
| Test (all) | `<cmd>` |
| Test (single) | `<cmd or pattern>` |
| Lint / format | `<cmd>` |
| Type-check | `<cmd>` |

## Conventions
- Code style / formatter: <e.g. Prettier, rustfmt, ruff>
- Commit / branch conventions: <e.g. Conventional Commits; feature branches>
- Testing conventions: <where tests live, naming, framework>
- Other house rules: <from CLAUDE.md / AGENTS.md / CONTRIBUTING>

## External dependencies & services
- Datastores / queues / APIs: <e.g. SQLite file, Postgres, Stripe>
- Required env vars / secrets: <names only, not values>
- Local services to run: <e.g. docker-compose up db>

## Domain glossary
- **<term>** — <meaning specific to this project>

## Where docs & decisions live
- Docs: <e.g. docs/, README sections>
- Architecture decisions: <e.g. docs/decisions/>
- Other references: <links / paths>

## Gotchas / non-obvious constraints
- <anything that bit you or that a newcomer would get wrong>
```
