ALTER TABLE project_comments ADD COLUMN parent_id TEXT NOT NULL DEFAULT '';
CREATE INDEX project_comments_parent ON project_comments(parent_id);
