ALTER TABLE projects ADD COLUMN group_id TEXT NOT NULL DEFAULT '';
ALTER TABLE projects ADD COLUMN tags TEXT NOT NULL DEFAULT '';

CREATE TABLE project_groups(
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  created_at BIGINT NOT NULL
);
CREATE INDEX project_groups_owner ON project_groups(owner_id);
