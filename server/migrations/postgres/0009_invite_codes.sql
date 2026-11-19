CREATE TABLE invite_codes(
  id TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL UNIQUE,
  created_by TEXT NOT NULL,
  role TEXT NOT NULL,
  preset_username TEXT NOT NULL DEFAULT '',
  preset_name TEXT NOT NULL DEFAULT '',
  used_by TEXT NOT NULL DEFAULT '',
  used_at BIGINT NOT NULL DEFAULT 0,
  expires_at BIGINT NOT NULL,
  revoked INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL
);
