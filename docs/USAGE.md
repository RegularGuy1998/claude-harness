# Using claude-harness

A practical, end-to-end guide to driving the harness day to day. For installation
see [INSTALL.md](INSTALL.md); for exactly how the gates block see [enforcement.md](enforcement.md).

---

## 1. Mental model

claude-harness makes a repository **govern the agent** instead of trusting it. It
enforces one workflow loop and **hard-blocks** at two checkpoints:

- **Before editing code** — the work must be *classified* (an intake recorded).
- **Before claiming "done"** — the story's *verification must actually pass*.

Two design rules shape everything:

- **Method is global, state is per-project.** The plugin (skills + hooks + a binary
  launcher) is installed once for your user. Each project keeps only its own state in
  `.harness/harness.db` (SQLite) — which is git-ignored automatically.
- **Opt-in per project.** A project is governed only after it has `.harness/harness.db`.
  Until you create it (via `/claude-harness:intake` or `.harness/harness init`), the
  gates allow everything. The harness never gets in the way of a repo that doesn't use it.

The durable record (intake, stories, test matrix, traces, decisions) lives in the DB and
is driven through `harness-cli` — invoked via the per-project launcher `.harness/harness`.

---

## 2. Install & activate

Installation is already done on this machine (user scope), alongside `superpowers`:

```
claude plugin list
# > claude-harness@claude-harness-marketplace   enabled
# > superpowers@claude-plugins-official          enabled
```

To install elsewhere, see [INSTALL.md](INSTALL.md). The short version:

```bash
claude plugin marketplace add RegularGuy1998/claude-harness   # or a local path
claude plugin install claude-harness@claude-harness-marketplace
```

### Activation is per session

Hooks load **when a session starts**. After installing (or after editing the plugin),
**open a new Claude Code session** (or `/clear`). On the first session in a project the
`SessionStart` hook will:

1. Download the matching `harness-cli` binary, verify its SHA-256, and cache it under the
   plugin data dir (once per machine/version).
2. Create `.harness/` in the current project: the `harness` launcher (env pre-wired) + the
   schema, and append `.harness/` to the project `.gitignore`.
3. Inject the `using-claude-harness` workflow into the session.

**Signal it worked:** a `.harness/` directory appears in your project. If it doesn't,
see Troubleshooting.

> The session-start step creates the launcher and schema but **not** the database. The DB
> is created the first time you record an intake — that is the opt-in moment.

---

## 3. The daily loop

You usually don't type commands — the skills auto-trigger from what you ask (e.g. asking
to add or fix something triggers `harness-intake` before any edit). The slash commands
below are the explicit equivalents if you want to drive it yourself.

| You want to… | Slash command | Gate involved |
|---|---|---|
| Start any change (add / fix / build / refactor) | `/claude-harness:intake "what you want"` | **PreToolUse** blocks the first edit if no intake exists |
| Turn normal/high-risk work into a tracked story | `/claude-harness:story US-001 "title"` | — |
| Prove it before saying "done" | `/claude-harness:verify US-001` | **Stop** blocks ending the turn until verify passes |
| Close out a task | `/claude-harness:trace` | — |
| Review harness health / recurring friction | `/claude-harness:audit` | — |
| Diagnose (binary, DB, schema, init state) | `/claude-harness:harness-status` | — |

Names are namespaced `/claude-harness:<name>`; the short form (`/intake`) also works when
there's no collision.

---

## 4. Worked example

In a **new session**, inside your project, you say:

> "Add rate limiting to login."

Step by step:

**1. Intake (auto).** The agent invokes `harness-intake`, runs the risk checklist, sees
*auth* — a hard gate — and assigns lane **high-risk**, recording it (this also creates the DB):

```bash
.harness/harness init
.harness/harness intake --type change_request --summary "Add rate limiting to login" \
  --lane high-risk --flags '["auth","existing_behavior"]'
```

> If the agent tries to `Edit`/`Write` *before* this, the **PreToolUse gate denies it** with
> "no feature intake recorded… run /claude-harness:intake before editing code."

**2. Story.** high-risk ⇒ `harness-story` creates a tracked story with a verification command:

```bash
.harness/harness story add --id US-001 --title "Login rate limiting" --lane high-risk \
  --verify "npm test -- rate-limit"
.harness/harness story update --id US-001 --status in_progress
```

**3. Design & build.** Engineering is delegated to **superpowers** (installed): design with
`brainstorming` → `writing-plans`, implement with `subagent-driven-development` + TDD.

**4. Verify (gated).** Before claiming done, `harness-verification-before-completion` runs:

```bash
.harness/harness story verify US-001     # runs the verify command; exit 0 = pass
```

> If the story is still `in_progress` and verification hasn't passed and you try to end the
> turn, the **Stop gate blocks** it: "story US-001 … unmet verification gate." It blocks once;
> on the next stop it lets you out (loop-safe) so you're never trapped.

On pass, proof + status are recorded:

```bash
.harness/harness story update --id US-001 --status implemented --unit 1 --integration 1 --e2e 1 --platform 0
```

**5. Trace.** `harness-trace-and-friction` records what happened + where the harness got in
the way (friction is required — it's what drives improvement):

```bash
.harness/harness trace --summary "Login throttles after 5 attempts/min (429)" --story US-001 \
  --outcome completed --changed '["src/auth/rateLimit.ts"]' \
  --friction "TEST_MATRIX had no throttling row; inferred the proof shape"
```

---

## 5. The two hard gates (what actually blocks)

Both gates are **fail-open**: no DB (project not opted in), no binary, a Git Bash absence,
or a query error all result in *allow*. The harness never bricks a repo. Full detail in
[enforcement.md](enforcement.md).

- **PreToolUse** (`Edit|Write|MultiEdit`): if the project is initialized and has **zero
  intakes**, the edit is denied. It's a *first-edit* gate — one recorded intake opens editing
  for the session. Paths under `.harness/`, `docs/stories/`, and `docs/superpowers/` are
  exempt so recording intake / writing story & spec docs is never self-blocked.
- **Stop**: if any story is `in_progress` with a `verify_command` whose last result isn't
  `pass`, ending the turn is blocked. Loop-safe via `stop_hook_active` (blocks once, then
  allows). The only real way past is to make `story verify` actually pass.

---

## 6. Composing with superpowers

| Layer | Owner |
|---|---|
| Durable state, risk lanes, intake, stories/test-matrix, traces, audit, the hard gates | **claude-harness** |
| Engineering discipline: brainstorming, plans, subagent-driven dev, TDD, debugging, code review | **superpowers** |

They chain automatically: `harness-intake` (high-risk) → `superpowers:brainstorming`/`writing-plans`;
`harness-story` → `superpowers:subagent-driven-development`; any "done" claim →
`harness-verification-before-completion`. claude-harness records *what happened and whether it's
proven*; superpowers governs *how the code gets written*. Neither requires the other to run.

---

## 7. CLI cheat-sheet

Always invoke through the launcher (env is pre-wired). On Windows, run via Git Bash. Lanes use
the hyphen form `high-risk`; proof booleans are numeric `1`/`0` (never `yes`/`no`); trace
`--outcome` is one of `completed|blocked|partial|failed`.

```bash
.harness/harness query matrix         # proof matrix across stories
.harness/harness query stats          # summary counts
.harness/harness query traces         # recent traces
.harness/harness query friction       # traces carrying friction
.harness/harness story verify-all     # run every story's verify command (before a merge)
.harness/harness audit                # drift categories + entropy score
.harness/harness propose              # improvement proposals from friction/interventions
```

Full command reference (every flag): see
[skills/using-claude-harness/references/cli-reference.md](../skills/using-claude-harness/references/cli-reference.md).

---

## 8. Troubleshooting / FAQ

**Nothing happens / no `.harness/` appears.**
You're still in the session that was open before install. Hooks load at session start — open a
new session (or `/clear`).

**Edits aren't being blocked.**
Either the project isn't opted in (no `.harness/harness.db` yet — run `/claude-harness:intake`),
or the harness is in **advisory mode** (binary or Git Bash unavailable). Run
`/claude-harness:harness-status` to see binary version, schema, and init state.

**Windows.** Hooks run through a polyglot wrapper that needs **Git for Windows** on PATH. Without
bash, the plugin still loads but the gates are inert (they exit 0 silently). If a Stop block ever
feels stuck, it self-releases after one block (`stop_hook_active`); Claude Code also caps
consecutive Stop blocks at 8 (`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`).

**I edited the plugin — how do I pick up changes?**
The local install points at the directory `<your-local-checkout>`, so file edits are reflected
in the next session. If you installed from GitHub instead:
```bash
claude plugin marketplace update claude-harness-marketplace
claude plugin update claude-harness@claude-harness-marketplace   # restart to apply
```

**Local dir vs GitHub source.** This machine's marketplace points at the local directory (great for
development). The GitHub repo (`RegularGuy1998/claude-harness`, private) is for installing on other
machines — those need `gh`/git auth with access to the repo. The binary itself is fetched from the
public `hoangnb24/repository-harness` releases, so no extra auth is needed for it.

**Reset a project.** Delete its `.harness/` directory (it's git-ignored). The binary cache lives under
the plugin data dir and is shared across projects.

**Turn the gates off temporarily.** Disable the plugin for a session: `claude plugin disable
claude-harness@claude-harness-marketplace` (re-enable with `enable`). Or simply don't opt a project in.
