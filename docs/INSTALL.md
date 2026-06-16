# Installing claude-harness

## Requirements

- **Claude Code v2.1+** (hooks: `permissionDecision`, Stop `decision`, `${CLAUDE_PLUGIN_DATA}`).
- **curl** (to fetch the CLI binary) and a SHA-256 tool (`sha256sum`/`shasum`/`certutil`).
- **Windows:** **Git for Windows** — hooks run through a polyglot `run-hook.cmd` that locates `bash.exe`. Without bash, the plugin still loads but gates are inert (it exits 0 silently).

## Install (Claude Code)

```
/plugin marketplace add <owner>/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

Or, for local development, point the marketplace at a checkout:

```
/plugin marketplace add /path/to/claude-harness
/plugin install claude-harness@claude-harness-marketplace
```

Restart the session (or run `/clear`) so the `SessionStart` hook fires.

## What happens on first session

The `SessionStart` hook runs `scripts/bootstrap-binary`, which:

1. Detects the platform and downloads the matching `harness-cli` asset from the pinned GitHub release (`scripts/harness-cli-release-tag`), verifies its `.sha256`, and caches it at
   `${CLAUDE_PLUGIN_DATA}/claude-harness/bin/<tag>/harness-cli[.exe]`.
2. Materializes `<project>/.harness/` with the schema and a launcher (`.harness/harness`) wired to that binary, and appends `.harness/` to the project `.gitignore`.
3. Injects the `using-claude-harness` skill into the session.

If any step fails (offline, unsupported platform, read-only project), the session still starts and the gates **degrade to advisory** — nothing is blocked.

## Opting a project in

A project is governed only once it has `.harness/harness.db`. Create it by running:

```
/claude-harness:intake "<what you want to do>"
```

(or `.harness/harness init`). Until then, the gates allow everything.

## Environment overrides

| Variable | Effect |
|---|---|
| `HARNESS_CLI_RELEASE_TAG` | Use a different release tag (or `latest`). |
| `HARNESS_CLI_BASE_URL` | Download from a mirror / offline location. |
| `HARNESS_CLI_BIN` | Use a specific binary (skips download). |
| `CLAUDE_CODE_STOP_HOOK_BLOCK_CAP` | Max consecutive Stop blocks before Claude Code overrides (default 8). |

## Uninstall

```
/plugin uninstall claude-harness@claude-harness-marketplace
```

Per-project state lives in `.harness/` (gitignored); delete it to fully reset a project. The cached binary lives under the plugin data dir.

## Composing with superpowers (recommended)

Install [superpowers](https://github.com/obra/superpowers) alongside. claude-harness defers engineering execution (brainstorming, plans, subagent-driven development, TDD, debugging, code review) to it; claude-harness itself owns durable state, risk lanes, and the hard gates. Neither requires the other to function.
