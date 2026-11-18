CREATE UNIQUE INDEX IF NOT EXISTS users_one_owner ON users(role) WHERE role=5;
