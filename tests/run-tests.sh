#!/usr/bin/env bash
# Integration tests for claude-harness hooks/gates against the REAL harness-cli
# binary (tests/fixtures/bin/harness-cli[.exe]). Run from anywhere:
#   bash tests/run-tests.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"

FIX_BIN="$ROOT/tests/fixtures/bin/harness-cli.exe"
[ -f "$FIX_BIN" ] || FIX_BIN="$ROOT/tests/fixtures/bin/harness-cli"
if [ ! -f "$FIX_BIN" ]; then
  echo "FATAL: test binary not found at tests/fixtures/bin/ — fetch it first." >&2
  exit 1
fi

pass=0; fail=0
ok() { echo "  PASS: $1"; pass=$((pass+1)); }
no() { echo "  FAIL: $1 ${2:+>> $2}"; fail=$((fail+1)); }
have_python() { command -v python >/dev/null 2>&1; }

# Fresh project with .harness/ materialized (NOT initialized — no harness.db yet).
new_project() {
  local p; p="$(mktemp -d)"
  CLAUDE_PROJECT_DIR="$p" CLAUDE_PLUGIN_DATA="$(mktemp -d)" HARNESS_CLI_BIN="$FIX_BIN" \
    bash "$ROOT/scripts/bootstrap-binary" >/dev/null 2>&1 || true
  printf '%s' "$p"
}
# Run a gate script. Args: <script> <project> <stdin-json>; sets OUT/RC.
run_gate() {
  OUT="$(CLAUDE_PROJECT_DIR="$2" HARNESS_CLI_BIN="$FIX_BIN" bash "$ROOT/hooks/$1" <<<"$3" 2>/dev/null)"; RC=$?
}
cli() { local p="$1"; shift; "$p/.harness/harness" "$@"; }

echo "== T1: bootstrap + session-start =="
P="$(new_project)"
[ -x "$P/.harness/harness" ] && ok "launcher created" || no "launcher missing"
[ -f "$P/.harness/scripts/schema/001-init.sql" ] && ok "schema staged" || no "schema not staged"
SS="$(CLAUDE_PROJECT_DIR="$P" CLAUDE_PLUGIN_DATA="$(mktemp -d)" HARNESS_CLI_BIN="$FIX_BIN" bash "$ROOT/hooks/run-hook.cmd" session-start 2>/dev/null)"
if have_python; then
  echo "$SS" | python -c 'import sys,json; d=json.load(sys.stdin); assert d["hookSpecificOutput"]["hookEventName"]=="SessionStart"' 2>/dev/null \
    && ok "run-hook.cmd -> session-start emits valid SessionStart JSON" || no "session-start JSON invalid" "$SS"
else
  case "$SS" in *'"hookEventName": "SessionStart"'*) ok "session-start JSON (structural)";; *) no "session-start JSON";; esac
fi

echo "== T2: PreToolUse intake gate =="
P="$(new_project)"
EDIT='{"tool_name":"Edit","tool_input":{"file_path":"src/app.ts"}}'
run_gate pretool-intake-gate "$P" "$EDIT"
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "no DB -> allow" || no "no DB should allow" "$OUT"

cli "$P" init >/dev/null 2>&1
run_gate pretool-intake-gate "$P" "$EDIT"
case "$OUT" in *'"permissionDecision": "deny"'*) ok "initialized + 0 intakes -> DENY";; *) no "should deny edit with no intake" "$OUT";; esac

run_gate pretool-intake-gate "$P" '{"tool_name":"Write","tool_input":{"file_path":"'"$P"'/.harness/notes.md"}}'
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "bookkeeping (.harness) path -> allow" || no "bookkeeping path should allow" "$OUT"

cli "$P" intake --type change_request --summary "do a thing" --lane tiny >/dev/null 2>&1
run_gate pretool-intake-gate "$P" "$EDIT"
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "intake recorded -> allow edit" || no "should allow after intake" "$OUT"

echo "== T3: Stop verify gate =="
P="$(new_project)"; cli "$P" init >/dev/null 2>&1
run_gate stop-verify-gate "$P" '{}'
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "no in-progress story -> allow stop" || no "should allow stop" "$OUT"

cli "$P" story add --id US-001 --title "demo" --lane normal --verify "exit 0" >/dev/null 2>&1
cli "$P" story update --id US-001 --status in_progress >/dev/null 2>&1
run_gate stop-verify-gate "$P" '{}'
case "$OUT" in *'"decision": "block"'*) ok "unmet verify -> BLOCK stop";; *) no "should block stop on unmet verify" "$OUT";; esac

run_gate stop-verify-gate "$P" '{"stop_hook_active":true}'
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "loop guard (stop_hook_active) -> allow" || no "loop guard should allow" "$OUT"

cli "$P" story verify US-001 >/dev/null 2>&1
run_gate stop-verify-gate "$P" '{}'
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "verified story -> allow stop" || no "should allow after verify pass" "$OUT"

echo "== T4: degrade (no binary) =="
P="$(new_project)"; cli "$P" init >/dev/null 2>&1
OUT="$(CLAUDE_PROJECT_DIR="$P" HARNESS_CLI_BIN="/nonexistent/harness-cli" bash "$ROOT/hooks/pretool-intake-gate" <<<'{"tool_input":{"file_path":"src/app.ts"}}' 2>/dev/null)"; RC=$?
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "missing binary -> PreToolUse allow (advisory)" || no "missing binary should allow" "$OUT"
OUT="$(CLAUDE_PROJECT_DIR="$P" HARNESS_CLI_BIN="/nonexistent/harness-cli" bash "$ROOT/hooks/stop-verify-gate" <<<'{}' 2>/dev/null)"; RC=$?
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "missing binary -> Stop allow (advisory)" || no "missing binary should allow stop" "$OUT"

echo "== T5: project_context (onboarding) =="
P="$(new_project)"; cli "$P" init >/dev/null 2>&1; cli "$P" migrate >/dev/null 2>&1
case "$(cli "$P" query sql "SELECT name FROM sqlite_master WHERE type='table' AND name='project_context'" 2>/dev/null)" in
  *project_context*) ok "init/migrate creates project_context table";; *) no "project_context table missing";;
esac
cli "$P" query sql "INSERT INTO project_context(kind,path,sha256,summary) VALUES('pack','docs/context/PROJECT_CONTEXT.md','deadbeef','t')" >/dev/null 2>&1
case "$(cli "$P" query sql "SELECT path FROM project_context ORDER BY id DESC LIMIT 1" 2>/dev/null)" in
  *docs/context/PROJECT_CONTEXT.md*) ok "query sql INSERT writes a context row";; *) no "context row not written";;
esac

echo "== T6: intake gate exempts docs/context/ =="
P="$(new_project)"; cli "$P" init >/dev/null 2>&1
run_gate pretool-intake-gate "$P" '{"tool_name":"Write","tool_input":{"file_path":"'"$P"'/docs/context/PROJECT_CONTEXT.md"}}'
{ [ "$RC" -eq 0 ] && [ -z "$OUT" ]; } && ok "docs/context path -> allow (no intake needed)" || no "docs/context should be exempt" "$OUT"

echo "== T7: he_context_status transitions =="
P="$(new_project)"
(
  export CLAUDE_PLUGIN_ROOT="$ROOT" CLAUDE_PROJECT_DIR="$P" HARNESS_CLI_BIN="$FIX_BIN"
  . "$ROOT/hooks/lib/harness-env"
  [ "$(he_context_status)" = "silent" ] || { echo "want silent, got $(he_context_status)"; exit 11; }
  cli "$P" init >/dev/null 2>&1; cli "$P" migrate >/dev/null 2>&1
  [ "$(he_context_status)" = "onboard" ] || { echo "want onboard, got $(he_context_status)"; exit 12; }
  mkdir -p "$P/docs/context"; printf 'hello world' > "$P/docs/context/PROJECT_CONTEXT.md"
  [ "$(he_context_status)" = "read-stale" ] || { echo "want read-stale, got $(he_context_status)"; exit 13; }
  SHA="$(he_sha256_file "$P/docs/context/PROJECT_CONTEXT.md")"
  cli "$P" query sql "INSERT INTO project_context(kind,path,sha256,summary) VALUES('pack','docs/context/PROJECT_CONTEXT.md','$SHA','t')" >/dev/null 2>&1
  [ "$(he_context_status)" = "read" ] || { echo "want read, got $(he_context_status)"; exit 14; }
) && ok "silent -> onboard -> read-stale -> read" || no "he_context_status transition wrong"

echo "== T8: context capture/show subcommand =="
P="$(new_project)"; cli "$P" init >/dev/null 2>&1; cli "$P" migrate >/dev/null 2>&1
mkdir -p "$P/docs/context"; printf 'pack body' > "$P/docs/context/PROJECT_CONTEXT.md"
( cd "$P" && "$P/.harness/harness" context capture --path docs/context/PROJECT_CONTEXT.md --summary "smoke pack" >/dev/null 2>&1 )
case "$(cli "$P" context show 2>/dev/null)" in
  *docs/context/PROJECT_CONTEXT.md*) ok "context capture + show records the pack";; *) no "context show missing row";;
esac
SHA_STORED="$(cli "$P" query sql "SELECT sha256 FROM project_context ORDER BY id DESC LIMIT 1" 2>/dev/null | tail -n +3 | head -n1 | tr -dc 'a-f0-9')"
if command -v sha256sum >/dev/null 2>&1; then SHA_FILE="$(sha256sum "$P/docs/context/PROJECT_CONTEXT.md" | awk '{print $1}')"
else SHA_FILE="$(shasum -a 256 "$P/docs/context/PROJECT_CONTEXT.md" | awk '{print $1}')"; fi
{ [ -n "$SHA_STORED" ] && [ "$SHA_STORED" = "$SHA_FILE" ]; } && ok "context capture auto-hashes the file" || no "auto-hash mismatch" "$SHA_STORED vs $SHA_FILE"

echo
echo "==== $pass passed, $fail failed ===="
[ "$fail" -eq 0 ]
