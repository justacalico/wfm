CREATE TABLE project_comments(
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  edited_at INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX project_comments_project ON project_comments(project_id);
ALTER TABLE projects ADD COLUMN status TEXT NOT NULL DEFAULT 'draft';
ALTER TABLE projects ADD COLUMN submitted_at INTEGER NOT NULL DEFAULT 0;
ALTER TABLE projects ADD COLUMN reviewed_by TEXT NOT NULL DEFAULT '';
