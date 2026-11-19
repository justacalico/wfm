CREATE TABLE notifications (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    kind TEXT NOT NULL,
    payload TEXT NOT NULL DEFAULT '{}',
    read_at BIGINT NOT NULL DEFAULT 0,
    created_at BIGINT NOT NULL
);
CREATE INDEX notifications_user ON notifications(user_id, created_at DESC);
ALTER TABLE render_nodes ADD COLUMN offline_notified BIGINT NOT NULL DEFAULT 0;
