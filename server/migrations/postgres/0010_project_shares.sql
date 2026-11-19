CREATE TABLE project_shares (
    id TEXT PRIMARY KEY,
    project_id TEXT NOT NULL,
    inviter_id TEXT NOT NULL,
    invitee_id TEXT NOT NULL,
    level TEXT NOT NULL DEFAULT 'view',
    status TEXT NOT NULL DEFAULT 'pending',
    created_at BIGINT NOT NULL,
    responded_at BIGINT NOT NULL DEFAULT 0,
    UNIQUE(project_id, invitee_id)
);
CREATE INDEX idx_shares_invitee ON project_shares(invitee_id);
