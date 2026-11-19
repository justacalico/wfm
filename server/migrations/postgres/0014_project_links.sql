CREATE TABLE project_links (
    id TEXT PRIMARY KEY,
    token_hash TEXT NOT NULL UNIQUE,
    project_id TEXT NOT NULL,
    scope TEXT NOT NULL DEFAULT 'project',
    created_by TEXT NOT NULL,
    created_at BIGINT NOT NULL,
    expires_at BIGINT NOT NULL DEFAULT 0,
    revoked BIGINT NOT NULL DEFAULT 0
);
