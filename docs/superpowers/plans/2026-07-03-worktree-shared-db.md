# Worktree-Aware Shared Root DB (Plan 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make claude-harness multi-worktree capable: every linked git worktree of a repo resolves to the **main repository root's** `.harness/harness.db`, stories can be bound to an agent session via `HARNESS_SESSION_ID`, the stop gate scopes to the current session, `query matrix` gains output filters, and the "one active feature" policy becomes per-session.

**Architecture:** Four independent changes: (1) a schema migration + CLI plumbing for `story.assigned_session`; (2) `query matrix` filters; (3) worktree-aware path resolution in `hooks/lib/harness-env` plus a thin per-worktree launcher; (4) a session-scoped `stop-verify-gate` query. All hook changes preserve the fail-open invariant: any resolution or query failure results in *allow*, never a block.

**Tech Stack:** Rust (rusqlite, clap, thiserror) for `crates/harness-cli`; POSIX bash for hooks; bash integration tests in `tests/run-tests.sh`; SQL migrations in `scripts/schema/`.

**Spec:** `d:\Source\claude-team-harness\docs\superpowers\specs\2026-07-02-claude-team-harness-design.md`, section 7 (items 1–4) and section 11 open item on gate fallback semantics.

## Global Constraints

- All code, comments, and commit messages in English.
- Hooks stay fail-open: no DB / no binary / query error / unsupported git ⇒ allow (never brick a repo).
- Backward compatible: without `HARNESS_SESSION_ID` and outside worktrees, behavior is byte-identical to today.
- Schema migrations are append-only files `scripts/schema/NNN-*.sql` ending with `INSERT INTO schema_version (version) VALUES (N);` — current version is 6 (`006-context.sql`); this plan adds 7.
- CLI version and release tag bump in lockstep: `crates/harness-cli/Cargo.toml` and `scripts/harness-cli-release-tag`.
- Rust tests: `cargo test --workspace`. Hook tests: `bash tests/run-tests.sh` (needs the fixture binary at `tests/fixtures/bin/harness-cli.exe`; rebuild it from source in Task 5).
- Work on a feature branch: `git checkout -b feature/worktree-shared-db` before Task 1.

---

### Task 1: Migration 007 + `story.assigned_session` through the CLI

**Files:**
- Create: `scripts/schema/007-session-binding.sql`
- Modify: `crates/harness-cli/src/application.rs:30-49` (`StoryAddInput`, `StoryUpdateInput`)
- Modify: `crates/harness-cli/src/interface.rs:162-196` (`StoryAddArgs`, `StoryUpdateArgs`), `interface.rs:504-531` (handlers)
- Modify: `crates/harness-cli/src/infrastructure.rs:504-560` (`add_story`, `update_story` SQL)
- Test: inline `#[cfg(test)]` tests in `crates/harness-cli/src/infrastructure.rs` and `interface.rs`

**Interfaces:**
- Consumes: existing migration runner (`apply_pending_migrations` discovers `scripts/schema/NNN-*.sql` above the current `schema_version`; the existing test `init_creates_database_and_schema` asserts the version — bump its expectation 6 → 7).
- Produces: `story.assigned_session TEXT NULL` column; `StoryAddInput.assigned_session: Option<String>`; `StoryUpdateInput.assigned_session: Option<String>`; CLI flags `story add --session <id>` / `story update --session <id>`; resolution helper `fn session_from_env(explicit: Option<String>) -> Option<String>` in `interface.rs` (explicit flag wins, else non-empty env `HARNESS_SESSION_ID`, else `None`). Tasks 3–4 rely on the column name `assigned_session` exactly.

- [ ] **Step 1: Write the migration**

`scripts/schema/007-session-binding.sql`:
```sql
-- Harness schema - migration 007
-- Session binding: a story may be assigned to one agent session
-- (HARNESS_SESSION_ID). The stop-verify-gate scopes its blocking query to the
-- current session so parallel worktree agents do not block each other.
-- NULL = unassigned (solo behavior, exactly as before this migration).

ALTER TABLE story ADD COLUMN assigned_session TEXT;

INSERT INTO schema_version (version) VALUES (7);
```

- [ ] **Step 2: Write the failing Rust tests**

In `crates/harness-cli/src/infrastructure.rs` tests module (next to the existing story tests around line 2227), add:

```rust
#[test]
fn story_add_and_update_persist_assigned_session() {
    let (repository, _dir) = repository_with_initialized_db();
    repository
        .add_story(StoryAddInput {
            id: "US-900".to_owned(),
            title: "session bound".to_owned(),
            risk_lane: RiskLane::Normal,
            contract_doc: None,
            verify_command: None,
            notes: None,
            assigned_session: Some("th-us-900-abcd1234".to_owned()),
        })
        .unwrap();
    let connection = repository.open_existing().unwrap();
    let session: Option<String> = connection
        .query_row(
            "SELECT assigned_session FROM story WHERE id='US-900';",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(session.as_deref(), Some("th-us-900-abcd1234"));

    repository
        .update_story(StoryUpdateInput {
            id: "US-900".to_owned(),
            status: None,
            evidence: None,
            unit: None,
            integration: None,
            e2e: None,
            platform: None,
            verify_command: None,
            assigned_session: Some("th-other-00000000".to_owned()),
        })
        .unwrap();
    let session: Option<String> = connection
        .query_row(
            "SELECT assigned_session FROM story WHERE id='US-900';",
            [],
            |row| row.get(0),
        )
        .unwrap();
    assert_eq!(session.as_deref(), Some("th-other-00000000"));
}
```

(Use the same test-fixture helper the surrounding tests use to build an initialized repository — the module already has one that inits a temp DB from `scripts/schema`; reuse it verbatim. If its name differs from `repository_with_initialized_db`, keep the file's existing helper name.)

In `crates/harness-cli/src/interface.rs` tests module, add:

```rust
#[test]
fn session_from_env_prefers_explicit_flag() {
    std::env::set_var("HARNESS_SESSION_ID", "from-env");
    assert_eq!(
        session_from_env(Some("explicit".to_owned())).as_deref(),
        Some("explicit")
    );
    assert_eq!(session_from_env(None).as_deref(), Some("from-env"));
    std::env::set_var("HARNESS_SESSION_ID", "");
    assert_eq!(session_from_env(None), None);
    std::env::remove_var("HARNESS_SESSION_ID");
    assert_eq!(session_from_env(None), None);
}
```

Also bump the existing schema-version assertion (infrastructure.rs test `init_creates_database_and_schema`, currently `assert_eq!(schema_version, 6);` near line 2005) to `7`.

- [ ] **Step 3: Run tests to verify they fail**

Run: `cargo test --workspace story_add_and_update_persist_assigned_session`
Expected: FAIL — `StoryAddInput` has no field `assigned_session` (compile error).

- [ ] **Step 4: Implement**

`application.rs` — add the field to both structs:
```rust
pub struct StoryAddInput {
    pub id: String,
    pub title: String,
    pub risk_lane: RiskLane,
    pub contract_doc: Option<String>,
    pub verify_command: Option<String>,
    pub notes: Option<String>,
    pub assigned_session: Option<String>,
}

pub struct StoryUpdateInput {
    pub id: String,
    pub status: Option<String>,
    pub evidence: Option<String>,
    pub unit: Option<BoolFlag>,
    pub integration: Option<BoolFlag>,
    pub e2e: Option<BoolFlag>,
    pub platform: Option<BoolFlag>,
    pub verify_command: Option<String>,
    pub assigned_session: Option<String>,
}
```

`interface.rs` — add the flag to both arg structs and the helper:
```rust
// in StoryAddArgs and StoryUpdateArgs, after the existing fields:
    /// Bind this story to an agent session (defaults to $HARNESS_SESSION_ID).
    #[arg(long)]
    session: Option<String>,
```
```rust
fn session_from_env(explicit: Option<String>) -> Option<String> {
    explicit.or_else(|| {
        std::env::var("HARNESS_SESSION_ID")
            .ok()
            .filter(|value| !value.is_empty())
    })
}
```
Wire it in the two handlers (interface.rs:506 and 517):
```rust
                    assigned_session: session_from_env(args.session),
```
(added as the last field of each input struct literal).

`infrastructure.rs` — extend the SQL:
```rust
    fn add_story(&self, input: StoryAddInput) -> Result<()> {
        let connection = self.open_existing()?;
        connection.execute(
            "INSERT INTO story (id, title, risk_lane, contract_doc, verify_command, notes, assigned_session)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7);",
            params![
                input.id,
                input.title,
                input.risk_lane.as_db_value(),
                input.contract_doc,
                input.verify_command,
                input.notes,
                input.assigned_session,
            ],
        )?;
        Ok(())
    }
```
In `update_story`, add `assigned_session=COALESCE(?8, assigned_session)` to the SET list, shift `WHERE id=` to `?9`, and append `input.assigned_session` before `input.id` in `params![]`. `update_story`'s empty-update guard also gains `&& input.assigned_session.is_none()`.

Fix all existing `StoryAddInput { ... }` / `StoryUpdateInput { ... }` literals in tests (infrastructure.rs lines ~2227–2698) by adding `assigned_session: None,`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cargo test --workspace`
Expected: PASS, including the bumped `schema_version == 7` assertion.

- [ ] **Step 6: Commit**

```bash
git add scripts/schema/007-session-binding.sql crates/harness-cli/src
git commit -m "feat(cli): bind stories to agent sessions via assigned_session and HARNESS_SESSION_ID"
```

---

### Task 2: `query matrix --open / --story / --limit`

**Files:**
- Modify: `crates/harness-cli/src/application.rs` (new `MatrixFilter` next to `InterventionFilter`; `query_matrix` service signature)
- Modify: `crates/harness-cli/src/interface.rs:398-403` (`MatrixQueryArgs`), `interface.rs:704` (handler), help-text test near `interface.rs:1480`
- Modify: `crates/harness-cli/src/infrastructure.rs:96` (trait), `infrastructure.rs:991-1012` (`query_matrix`)
- Test: inline tests in `infrastructure.rs`

**Interfaces:**
- Consumes: `StoryMatrixRecord` (domain.rs:566) — unchanged.
- Produces: `pub struct MatrixFilter { pub open: bool, pub story: Option<String>, pub limit: Option<u32> }` in `application.rs`; trait method becomes `fn query_matrix(&self, filter: &MatrixFilter) -> Result<Vec<StoryMatrixRecord>>`; CLI flags `--open` (only `planned`/`in_progress` stories), `--story <id>`, `--limit <N>`. `print_matrix` is unchanged.

- [ ] **Step 1: Write the failing tests**

In `infrastructure.rs` tests (reuse the initialized-repository helper; seed with `add_story` + `update_story` calls):

```rust
#[test]
fn query_matrix_filters_open_story_and_limit() {
    let (repository, _dir) = repository_with_initialized_db();
    for (id, status) in [("US-1", "in_progress"), ("US-2", "implemented"), ("US-3", "planned")] {
        repository
            .add_story(StoryAddInput {
                id: id.to_owned(),
                title: format!("story {id}"),
                risk_lane: RiskLane::Normal,
                contract_doc: None,
                verify_command: None,
                notes: None,
                assigned_session: None,
            })
            .unwrap();
        repository
            .update_story(StoryUpdateInput {
                id: id.to_owned(),
                status: Some(status.to_owned()),
                evidence: None,
                unit: None,
                integration: None,
                e2e: None,
                platform: None,
                verify_command: None,
                assigned_session: None,
            })
            .unwrap();
    }
    let all = repository.query_matrix(&MatrixFilter::default()).unwrap();
    assert_eq!(all.len(), 3);

    let open = repository
        .query_matrix(&MatrixFilter { open: true, ..MatrixFilter::default() })
        .unwrap();
    assert_eq!(
        open.iter().map(|r| r.id.as_str()).collect::<Vec<_>>(),
        vec!["US-1", "US-3"]
    );

    let one = repository
        .query_matrix(&MatrixFilter { story: Some("US-2".to_owned()), ..MatrixFilter::default() })
        .unwrap();
    assert_eq!(one.len(), 1);
    assert_eq!(one[0].id, "US-2");

    let limited = repository
        .query_matrix(&MatrixFilter { limit: Some(2), ..MatrixFilter::default() })
        .unwrap();
    assert_eq!(limited.len(), 2);
}
```

Extend the existing help test near `interface.rs:1480` so `matrix_help` also asserts `--open`, `--story`, and `--limit` appear.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cargo test --workspace query_matrix_filters`
Expected: FAIL — no `MatrixFilter` type (compile error).

- [ ] **Step 3: Implement**

`application.rs`:
```rust
#[derive(Debug, Default)]
pub struct MatrixFilter {
    pub open: bool,
    pub story: Option<String>,
    pub limit: Option<u32>,
}
```
and change the service method:
```rust
    pub fn query_matrix(&self, filter: &MatrixFilter) -> crate::infrastructure::Result<Vec<StoryMatrixRecord>> {
        self.repository.query_matrix(filter)
    }
```

`infrastructure.rs` — trait (line 96) becomes `fn query_matrix(&self, filter: &MatrixFilter) -> Result<Vec<StoryMatrixRecord>>;` and the implementation:
```rust
    fn query_matrix(&self, filter: &MatrixFilter) -> Result<Vec<StoryMatrixRecord>> {
        let connection = self.open_existing()?;
        let mut clauses: Vec<&str> = Vec::new();
        let mut params_vec: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
        if filter.open {
            clauses.push("status IN ('planned','in_progress')");
        }
        if let Some(story) = &filter.story {
            clauses.push("id = ?");
            params_vec.push(Box::new(story.clone()));
        }
        let where_clause = if clauses.is_empty() {
            String::new()
        } else {
            format!("WHERE {}", clauses.join(" AND "))
        };
        let limit_clause = match filter.limit {
            Some(limit) => format!("LIMIT {limit}"),
            None => String::new(),
        };
        let sql = format!(
            "SELECT id, title, status, unit_proof, integration_proof, e2e_proof, platform_proof, evidence
             FROM story {where_clause} ORDER BY id {limit_clause};"
        );
        let mut statement = connection.prepare(&sql)?;
        let rows = statement.query_map(
            rusqlite::params_from_iter(params_vec.iter().map(|p| p.as_ref())),
            |row| {
                Ok(StoryMatrixRecord {
                    id: row.get(0)?,
                    title: row.get(1)?,
                    status: row.get(2)?,
                    unit: row.get(3)?,
                    integration: row.get(4)?,
                    e2e: row.get(5)?,
                    platform: row.get(6)?,
                    evidence: row.get(7)?,
                })
            },
        )?;
        collect_rows(rows)
    }
```
(`ORDER BY id` must come before `LIMIT` — note the clause order in the `format!`.)

`interface.rs`:
```rust
#[derive(Args, Debug)]
struct MatrixQueryArgs {
    /// Render proof flags as CLI input values, 1 and 0, instead of yes and no.
    #[arg(long)]
    numeric: bool,
    /// Only stories with status planned or in_progress.
    #[arg(long)]
    open: bool,
    /// Only the story with this id.
    #[arg(long)]
    story: Option<String>,
    /// Print at most N rows.
    #[arg(long, value_name = "N")]
    limit: Option<u32>,
}
```
Handler (line 704):
```rust
            QueryView::Matrix(args) => print_matrix(
                &service.query_matrix(&MatrixFilter {
                    open: args.open,
                    story: args.story.clone(),
                    limit: args.limit,
                })?,
                args.numeric,
            ),
```
Add `MatrixFilter` to the `use crate::application::{...}` lists in `interface.rs` and `infrastructure.rs`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cargo test --workspace`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add crates/harness-cli/src
git commit -m "feat(cli): query matrix --open/--story/--limit output filters"
```

---

### Task 3: Worktree-aware resolution + per-worktree launcher (hooks)

**Files:**
- Modify: `hooks/lib/harness-env` (path resolution block, lines 31-37; add `he_materialize_worktree_launcher`)
- Modify: `hooks/session-start` (call the new function; opportunistic `he_cli migrate`)
- Test: `tests/run-tests.sh` (new section)

**Interfaces:**
- Consumes: nothing from Tasks 1–2 at runtime (works with any binary version — fail-open).
- Produces: after sourcing `harness-env`: `HE_SESSION_DIR` = the pre-promotion workspace (worktree itself), `HE_PROJECT_DIR` = the **main repository root** when the workspace is a linked worktree, unchanged otherwise. `he_materialize_worktree_launcher <bin>` — writes `$HE_SESSION_DIR/.harness/harness` pointing at the ROOT `.harness/` when `HE_SESSION_DIR != HE_PROJECT_DIR`, and registers `.harness/` in the worktree's private exclude. Task 4's gate inherits correct DB routing purely through this resolution.

- [ ] **Step 1: Write the failing bash tests**

Append to `tests/run-tests.sh` before the final summary block:

```bash
echo "== T-WT: linked worktree resolves to the main root =="
P="$(new_project)"
git -C "$P" init -b main >/dev/null 2>&1
git -C "$P" -c user.email=t@e -c user.name=t commit --allow-empty -m init >/dev/null 2>&1
git -C "$P" worktree add "$P/.worktrees/wt1" -b task/wt1 >/dev/null 2>&1
WT="$P/.worktrees/wt1"

# session-start inside the worktree must NOT create a fresh DB workspace there;
# it must write a thin launcher pointing at the root.
CLAUDE_PROJECT_DIR="$WT" CLAUDE_PLUGIN_DATA="$(mktemp -d)" HARNESS_CLI_BIN="$FIX_BIN" \
  bash "$ROOT/hooks/run-hook.cmd" session-start >/dev/null 2>&1
[ -x "$WT/.harness/harness" ] && ok "worktree launcher created" || no "worktree launcher missing"
[ ! -d "$WT/.harness/scripts" ] && ok "no schema staged in worktree" || no "worktree got its own schema copy"
grep -q "HARNESS_DB=\"$P/.harness/harness.db\"" "$WT/.harness/harness" \
  && ok "worktree launcher points at root DB" || no "launcher DB path wrong" "$(cat "$WT/.harness/harness")"

# CLI runs from the worktree must write into the ROOT database.
cli "$WT" init >/dev/null 2>&1
[ -f "$P/.harness/harness.db" ] && ok "init from worktree created ROOT db" || no "root db missing"
[ ! -f "$WT/.harness/harness.db" ] && ok "no db inside worktree" || no "worktree db should not exist"

# Gates run inside the worktree must see the root DB (deny: 0 intakes).
run_gate pretool-intake-gate "$WT" '{"tool_name":"Edit","tool_input":{"file_path":"src/x.ts"}}'
case "$OUT" in *'"permissionDecision": "deny"'*) ok "intake gate reads root db from worktree";; *) no "gate did not use root db" "$OUT";; esac

# git status in the worktree stays clean (launcher hidden by private exclude).
ST="$(git -C "$WT" status --porcelain)"
[ -z "$ST" ] && ok "worktree status clean" || no "worktree dirtied" "$ST"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run-tests.sh`
Expected: the new T-WT section FAILS (today session-start materializes a full `.harness/` with schema inside the worktree, and gates read a worktree-local DB).

- [ ] **Step 3: Implement `harness-env` resolution**

Replace the `HE_PROJECT_DIR` block (harness-env lines 31-37) with:

```bash
if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
  HE_PROJECT_DIR="$CLAUDE_PROJECT_DIR"
elif _he_top="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  HE_PROJECT_DIR="$_he_top"
else
  HE_PROJECT_DIR="$PWD"
fi

# The session's own workspace, before worktree promotion.
HE_SESSION_DIR="$HE_PROJECT_DIR"

# Linked worktree -> promote to the main repository root so every worktree
# shares ONE .harness/ and ONE harness.db. Fail-open: any git error (old git,
# not a repo, bare repo) leaves HE_PROJECT_DIR untouched.
_he_git_dir="$(git -C "$HE_PROJECT_DIR" rev-parse --path-format=absolute --git-dir 2>/dev/null || true)"
_he_common_dir="$(git -C "$HE_PROJECT_DIR" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -n "$_he_git_dir" ] && [ -n "$_he_common_dir" ] && [ "$_he_git_dir" != "$_he_common_dir" ]; then
  case "$_he_common_dir" in
    */.git)
      _he_main_root="$(dirname "$_he_common_dir")"
      [ -d "$_he_main_root" ] && HE_PROJECT_DIR="$_he_main_root"
      ;;
  esac
fi
```

Add the launcher function next to `he_materialize_project`:

```bash
# In a linked worktree, write a thin launcher so `.harness/harness <cmd>` keeps
# working verbatim inside the worktree while all state lives at the main root.
# No schema copy, no DB, no .gitignore edits (the tracked .gitignore belongs to
# the branch) — the launcher is hidden via the worktree's private exclude.
he_materialize_worktree_launcher() {
  local bin="$1"
  [ "$HE_SESSION_DIR" = "$HE_PROJECT_DIR" ] && return 0
  local hdir="$HE_SESSION_DIR/.harness"
  mkdir -p "$hdir" || return 1
  cat > "$hdir/harness" <<EOF
#!/usr/bin/env bash
# Auto-generated by claude-harness session-start (worktree launcher). Do not edit.
export HARNESS_CLI_BIN="$bin"
export HARNESS_REPO_ROOT="$HE_PROJECT_DIR/.harness"
export HARNESS_DB="$HE_PROJECT_DIR/.harness/harness.db"
exec "\$HARNESS_CLI_BIN" "\$@"
EOF
  chmod 755 "$hdir/harness" 2>/dev/null || true
  local exclude
  exclude="$(git -C "$HE_SESSION_DIR" rev-parse --git-path info/exclude 2>/dev/null)" || return 0
  case "$exclude" in
    /*|[A-Za-z]:*) : ;;
    *) exclude="$HE_SESSION_DIR/$exclude" ;;
  esac
  mkdir -p "$(dirname "$exclude")" 2>/dev/null || true
  grep -qxF '.harness/' "$exclude" 2>/dev/null || printf '.harness/\n' >> "$exclude"
}
```

- [ ] **Step 4: Wire session-start**

In `hooks/session-start`, replace the materialize line:

```bash
if bin="$(he_ensure_binary 2>/dev/null)"; then
  he_materialize_project "$bin" 2>/dev/null || advisory=" Could not write .harness/ in this project — harness gates run in ADVISORY mode."
  he_materialize_worktree_launcher "$bin" 2>/dev/null || true
  # Opportunistic schema upgrade: never blocks, never creates a DB.
  if he_have_db; then he_cli migrate >/dev/null 2>&1 || true; fi
else
  advisory=" harness-cli could not be fetched — harness gates run in ADVISORY mode (no hard blocking)."
fi
```

Note: `he_materialize_project` already targets the promoted `HE_PROJECT_DIR` (main root), so with the resolution change it becomes a root-only operation automatically; verify it is not called with the worktree path anywhere else. Because `he_cli`, `he_have_db`, `he_db_path`, and `he_harness_dir` all derive from `HE_PROJECT_DIR`, the gates and the context-status check inherit root routing with no further edits.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: all sections PASS including T-WT (5 new assertions) — and every pre-existing section still passes (regression check for non-worktree behavior).

- [ ] **Step 6: Commit**

```bash
git add hooks/lib/harness-env hooks/session-start tests/run-tests.sh
git commit -m "feat(hooks): resolve linked worktrees to the main root and write thin worktree launchers"
```

---

### Task 4: Session-scoped `stop-verify-gate`

**Files:**
- Modify: `hooks/stop-verify-gate` (query construction)
- Test: `tests/run-tests.sh` (new section)

**Interfaces:**
- Consumes: `story.assigned_session` (Task 1), worktree resolution (Task 3).
- Produces: gate behavior — with `HARNESS_SESSION_ID` set: block only on unmet in-progress stories whose `assigned_session` equals the current session id. Without it: today's repo-wide query, unchanged. Query failure (e.g. pre-007 DB without the column) ⇒ empty rows ⇒ allow (existing fail-open path).

- [ ] **Step 1: Write the failing bash tests**

Append to `tests/run-tests.sh`:

```bash
echo "== T-SESS: stop gate scopes to HARNESS_SESSION_ID =="
P="$(new_project)"
cli "$P" init >/dev/null 2>&1
cli "$P" intake --type change_request --summary "t" --lane normal >/dev/null 2>&1
cli "$P" story add --id US-A --title "a" --lane normal --verify "exit 1" --session sess-A >/dev/null 2>&1
cli "$P" story update --id US-A --status in_progress >/dev/null 2>&1
cli "$P" story add --id US-B --title "b" --lane normal --verify "exit 1" --session sess-B >/dev/null 2>&1
cli "$P" story update --id US-B --status in_progress >/dev/null 2>&1

# Session A is blocked by its own story only.
OUT="$(CLAUDE_PROJECT_DIR="$P" HARNESS_CLI_BIN="$FIX_BIN" HARNESS_SESSION_ID="sess-A" \
  bash "$ROOT/hooks/stop-verify-gate" <<<'{}' 2>/dev/null)"
case "$OUT" in
  *'"decision": "block"'*US-A*) ok "session A blocked on US-A";;
  *) no "session A should block on US-A" "$OUT";;
esac
case "$OUT" in *US-B*) no "session A must not see US-B" "$OUT";; *) ok "US-B not visible to session A";; esac

# A session with no assigned stories is free to stop.
OUT="$(CLAUDE_PROJECT_DIR="$P" HARNESS_CLI_BIN="$FIX_BIN" HARNESS_SESSION_ID="sess-C" \
  bash "$ROOT/hooks/stop-verify-gate" <<<'{}' 2>/dev/null)"; RC=$?
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "unrelated session allowed" || no "unrelated session should be allowed" "$OUT"

# Without the env var: repo-wide behavior (blocks, mentions both stories).
OUT="$(CLAUDE_PROJECT_DIR="$P" HARNESS_CLI_BIN="$FIX_BIN" \
  bash "$ROOT/hooks/stop-verify-gate" <<<'{}' 2>/dev/null)"
case "$OUT" in
  *'"decision": "block"'*US-A*US-B*) ok "no session id -> repo-wide block";;
  *) no "repo-wide block expected" "$OUT";;
esac
```

(These tests need the Task 1 binary in `tests/fixtures/bin/` — build it first: `cargo build --release && cp target/release/harness-cli.exe tests/fixtures/bin/harness-cli.exe`.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash tests/run-tests.sh`
Expected: T-SESS FAILS — "session A must not see US-B" (today's query is repo-wide).

- [ ] **Step 3: Implement**

In `hooks/stop-verify-gate`, replace the fixed query line

```bash
q="SELECT id FROM story WHERE status='in_progress' AND verify_command IS NOT NULL AND (last_verified_result IS NULL OR last_verified_result<>'pass')"
```

with:

```bash
q="SELECT id FROM story WHERE status='in_progress' AND verify_command IS NOT NULL AND (last_verified_result IS NULL OR last_verified_result<>'pass')"
if [ -n "${HARNESS_SESSION_ID:-}" ]; then
  # Scope to this session's stories. Single quotes doubled for SQL safety.
  _sid="$(printf '%s' "$HARNESS_SESSION_ID" | sed "s/'/''/g")"
  q="$q AND assigned_session='$_sid'"
fi
```

No other change: the existing parse (`he_cli query sql "$q"` + row extraction) and the existing fail-open behavior (query error ⇒ no rows ⇒ allow) already handle a pre-007 database, where the column reference makes the query fail.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bash tests/run-tests.sh`
Expected: all sections PASS, including T-SESS (4 new assertions) and every pre-existing stop-gate test (no-env behavior unchanged).

- [ ] **Step 5: Commit**

```bash
git add hooks/stop-verify-gate tests/run-tests.sh
git commit -m "feat(hooks): scope stop-verify-gate to HARNESS_SESSION_ID when present"
```

---

### Task 5: Policy text, docs, release bump

**Files:**
- Modify: `skills/using-claude-harness/SKILL.md:27`, `skills/harness-story/SKILL.md:23`, `README.md:14`
- Modify: `docs/enforcement.md` (+ mirrors `docs/vi/enforcement.md`, `docs/zh/enforcement.md`)
- Modify: `crates/harness-cli/Cargo.toml` (version), `scripts/harness-cli-release-tag`
- Test: full suite re-run

**Interfaces:**
- Consumes: everything above.
- Produces: released policy + docs; version `0.1.13` pinned so `he_binary_path` fetches the new binary (`bin/harness-cli-v0.1.13/`).

- [ ] **Step 1: Update the policy text**

`skills/using-claude-harness/SKILL.md` line 27 — replace:
```markdown
2. **One active feature per session.** Normal/high-risk work becomes a story → `claude-harness:harness-story`. Do not start a second feature in the same session before the current one passes. Parallel sessions (e.g. one per git worktree) each carry their own active feature, bound via `HARNESS_SESSION_ID`.
```

`skills/harness-story/SKILL.md` line 23 — replace `2. **One active feature only.**` with:
```markdown
2. **One active feature per session.** Mark it in progress when you start:
```

`README.md` line 14 — replace with:
```markdown
- **One active feature per session** — normal/high-risk work becomes a story with a test matrix; parallel worktree sessions each own theirs.
```

- [ ] **Step 2: Update enforcement docs**

In `docs/enforcement.md`, add after the Stop-gate section:

```markdown
## Worktrees and sessions

- **Linked git worktrees share the main repository's `.harness/`.** The hooks
  resolve a linked worktree to the main root (`git rev-parse
  --git-common-dir`), session-start writes only a thin `.harness/harness`
  launcher inside the worktree (hidden via the worktree's private exclude),
  and every gate and CLI call reads and writes the ONE root `harness.db`.
- **Stop gate scopes per session.** When a session is started with
  `HARNESS_SESSION_ID=<id>` and its stories are recorded with `story add
  --session` (or the env var), the Stop gate blocks only on that session's
  unmet stories. Without the env var the gate keeps its original repo-wide
  behavior. Orchestrators (e.g. claude-team-harness) set the variable per
  spawned worktree session.
```

Mirror the same section in `docs/vi/enforcement.md` (Vietnamese) and `docs/zh/enforcement.md` (Chinese) following each file's existing tone.

- [ ] **Step 3: Bump the release version**

- `crates/harness-cli/Cargo.toml`: `version = "0.1.12"` → `"0.1.13"` (keep in lockstep).
- `scripts/harness-cli-release-tag`: `harness-cli-v0.1.12` → `harness-cli-v0.1.13`.

- [ ] **Step 4: Rebuild fixture binary + full test run**

```bash
cargo build --release
cp target/release/harness-cli.exe tests/fixtures/bin/harness-cli.exe
cargo test --workspace
bash tests/run-tests.sh
```
Expected: everything PASS.

- [ ] **Step 5: Commit**

```bash
git add skills README.md docs crates/harness-cli/Cargo.toml scripts/harness-cli-release-tag
git commit -m "docs+release: one active feature per session; bump harness-cli to 0.1.13"
```

- [ ] **Step 6: Post-merge release note**

After the branch merges, the release workflow (`.github/workflows/harness-cli-release.yml`) must publish tag `harness-cli-v0.1.13` with the platform binaries + `.sha256` assets (same flow as previous releases) so `he_ensure_binary` can fetch it. Until the release exists, installed plugins keep using their cached 0.1.12 binary — the hooks stay fail-open, and the 007 migration simply hasn't happened yet (gates behave exactly as today).

---

## Self-review notes

- Spec section 7 coverage: item 1 (worktree resolution + thin launcher → Task 3), item 2 (session binding + scoped gate → Tasks 1, 4), item 3 (matrix filters → Task 2), item 4 (policy text → Task 5). Item 5 (convention skill) is optional and out of scope here.
- Open-item resolution (spec section 11): chosen semantics — with `HARNESS_SESSION_ID`, the gate sees ONLY stories assigned to that exact session (NULL-assigned stories do not block worktree sessions); without it, repo-wide as today. This is the spec's "leaning" made concrete.
- Fail-open verified at each change: git errors leave resolution untouched; pre-007 DBs make the scoped query error out into allow; missing binary paths unchanged.
- Type/name consistency: `assigned_session` (column, input fields, SQL), `session_from_env`, `MatrixFilter`, `he_materialize_worktree_launcher`, `HE_SESSION_DIR` used consistently across tasks.
