CREATE TABLE assignments(
  id TEXT PRIMARY KEY,
  project_id TEXT NOT NULL,
  teacher_id TEXT NOT NULL,
  allow_withdraw INTEGER NOT NULL DEFAULT 1,
  max_submissions INTEGER NOT NULL DEFAULT 0,
  due_at INTEGER NOT NULL DEFAULT 0,
  hidden INTEGER NOT NULL DEFAULT 0,
  locked INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX assignments_project ON assignments(project_id);
CREATE TABLE assignment_copies(
  project_id TEXT PRIMARY KEY,
  assignment_id TEXT NOT NULL,
  student_id TEXT NOT NULL,
  submissions INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX assignment_copies_assignment ON assignment_copies(assignment_id);
CREATE INDEX assignment_copies_student ON assignment_copies(student_id);
