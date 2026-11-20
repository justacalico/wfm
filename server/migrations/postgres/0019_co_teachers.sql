CREATE TABLE class_teachers(
  class_id TEXT NOT NULL,
  teacher_id TEXT NOT NULL,
  created_at BIGINT NOT NULL,
  PRIMARY KEY(class_id, teacher_id)
);
CREATE INDEX class_teachers_teacher ON class_teachers(teacher_id);
