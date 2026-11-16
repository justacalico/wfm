CREATE TABLE users(
  id TEXT PRIMARY KEY,
  username TEXT NOT NULL UNIQUE COLLATE NOCASE,
  display_name TEXT NOT NULL,
  pass_hash TEXT NOT NULL,
  role INTEGER NOT NULL,
  student_id TEXT NOT NULL DEFAULT '',
  note TEXT NOT NULL DEFAULT '',
  disabled INTEGER NOT NULL DEFAULT 0,
  created_by TEXT NOT NULL DEFAULT '',
  lineage TEXT NOT NULL DEFAULT '/',
  created_at INTEGER NOT NULL,
  last_login INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE sessions(
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  csrf TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  expires_at INTEGER NOT NULL,
  ip TEXT NOT NULL DEFAULT '',
  ua TEXT NOT NULL DEFAULT ''
);
CREATE INDEX sessions_user ON sessions(user_id);

CREATE TABLE projects(
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  dir TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX projects_owner ON projects(owner_id);

CREATE TABLE locks(
  project_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  holder TEXT NOT NULL,
  label TEXT NOT NULL DEFAULT '',
  expires_at INTEGER NOT NULL,
  PRIMARY KEY(project_id, kind)
);

CREATE TABLE render_jobs(
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  status TEXT NOT NULL,
  mode TEXT NOT NULL DEFAULT 'server',
  spec TEXT NOT NULL,
  output_name TEXT NOT NULL,
  progress REAL NOT NULL DEFAULT 0,
  error TEXT NOT NULL DEFAULT '',
  worker TEXT NOT NULL DEFAULT '',
  attempts INTEGER NOT NULL DEFAULT 0,
  lease_until INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  finished_at INTEGER NOT NULL DEFAULT 0
);
CREATE UNIQUE INDEX render_jobs_one_active
  ON render_jobs(project_id) WHERE status IN ('queued','running');

CREATE TABLE render_nodes(
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  token_hash TEXT NOT NULL,
  disabled INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  last_seen INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE audit(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ts INTEGER NOT NULL,
  scope TEXT NOT NULL,
  actor_id TEXT NOT NULL,
  actor_name TEXT NOT NULL,
  action TEXT NOT NULL,
  target TEXT NOT NULL DEFAULT '',
  detail TEXT NOT NULL DEFAULT '',
  lineage TEXT NOT NULL DEFAULT ''
);
CREATE INDEX audit_scope ON audit(scope);
