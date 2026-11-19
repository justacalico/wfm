CREATE TABLE auto_shares (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL,
    invitee_id TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'edit',
    created_at BIGINT NOT NULL,
    UNIQUE(owner_id, invitee_id)
);
