ALTER TABLE project_groups RENAME TO folders;
ALTER TABLE projects RENAME COLUMN group_id TO folder_id;
ALTER TABLE projects DROP COLUMN tags;
