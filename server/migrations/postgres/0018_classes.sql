CREATE TABLE classes(
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL,
  name TEXT NOT NULL,
  unmanaged INTEGER NOT NULL DEFAULT 0,
  created_at BIGINT NOT NULL
);
CREATE UNIQUE INDEX classes_owner_name ON classes(owner_id, name);
CREATE UNIQUE INDEX classes_unmanaged_owner ON classes(owner_id) WHERE unmanaged<>0;
ALTER TABLE users ADD COLUMN class_id TEXT NOT NULL DEFAULT '';
CREATE INDEX users_class ON users(class_id);

INSERT INTO classes(id, owner_id, name, unmanaged, created_at)
  SELECT md5(random()::text || clock_timestamp()::text), created_by, 'unmanaged', 1, EXTRACT(EPOCH FROM now())::BIGINT
  FROM users WHERE role=1 AND created_by<>'' GROUP BY created_by;
UPDATE users SET class_id=(SELECT c.id FROM classes c WHERE c.owner_id=users.created_by AND c.unmanaged=1)
  WHERE role=1 AND created_by<>'';
