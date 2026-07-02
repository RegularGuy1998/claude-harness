-- Harness schema - migration 007
-- Session binding: a story may be assigned to one agent session
-- (HARNESS_SESSION_ID). The stop-verify-gate scopes its blocking query to the
-- current session so parallel worktree agents do not block each other.
-- NULL = unassigned (solo behavior, exactly as before this migration).

ALTER TABLE story ADD COLUMN assigned_session TEXT;

INSERT INTO schema_version (version) VALUES (7);
