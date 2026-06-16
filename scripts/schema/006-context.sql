-- Harness v0 schema - migration 006
-- Project context pointer: a durable record of the committed "context-pack"
-- the agent reads each session (stack, key paths, build/test commands,
-- conventions) plus capture metadata so the harness can detect a missing or
-- stale pack. The rich content lives in the committed markdown file; this
-- table holds only the governance signal (where it is + the hash at capture).

CREATE TABLE project_context (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    captured_at TEXT    NOT NULL DEFAULT (datetime('now')),
    kind        TEXT    NOT NULL DEFAULT 'pack'
                        CHECK(kind IN ('pack','note')),
    path        TEXT,            -- repo-relative path to the context-pack file
    sha256      TEXT,            -- hash of the file content at capture time
    summary     TEXT,            -- one-line description of the captured context
    notes       TEXT
);

INSERT INTO schema_version (version) VALUES (6);
