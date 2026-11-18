ALTER TABLE projects ADD COLUMN last_activity INTEGER NOT NULL DEFAULT 0;
UPDATE projects SET last_activity=created_at;
