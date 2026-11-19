pub mod sqlite;
#[cfg(feature = "postgres")]
pub mod postgres;

use std::fmt;
use std::sync::Arc;

use async_trait::async_trait;
use rust_embed::RustEmbed;

use crate::model::*;

#[derive(Debug)]
pub enum DbError {
    NotFound,
    Conflict,
    Other(String),
}

impl fmt::Display for DbError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DbError::NotFound => write!(f, "not found"),
            DbError::Conflict => write!(f, "conflict"),
            DbError::Other(m) => write!(f, "{m}"),
        }
    }
}

impl std::error::Error for DbError {}

impl From<tokio_rusqlite::Error> for DbError {
    fn from(e: tokio_rusqlite::Error) -> Self {
        DbError::Other(e.to_string())
    }
}

pub type DbResult<T> = Result<T, DbError>;

pub enum LockOutcome {
    Acquired(LockInfo),
    Held(LockInfo),
}

/// Storage backend contract. SQLite is bundled and default; Postgres is
/// available with `--features postgres`. Adding another engine means
/// implementing this trait and registering it in `connect`.
#[async_trait]
pub trait Db: Send + Sync {
    // users
    async fn user_by_id(&self, id: &str) -> DbResult<User>;
    async fn user_by_name(&self, name: &str) -> DbResult<(User, String)>;
    async fn create_user(&self, u: &User, pass_hash: &str) -> DbResult<()>;
    async fn create_owner(&self, u: &User, pass_hash: &str) -> DbResult<bool>;
    async fn set_password(&self, id: &str, pass_hash: &str) -> DbResult<()>;
    async fn update_user(&self, u: &User) -> DbResult<()>;
    async fn set_user_disabled(&self, id: &str, disabled: bool) -> DbResult<()>;
    async fn delete_user(&self, id: &str) -> DbResult<()>;
    async fn touch_login(&self, id: &str, ts: i64) -> DbResult<()>;
    async fn owner_count(&self) -> DbResult<i64>;
    async fn managed_users(&self, actor: &User) -> DbResult<Vec<User>>;

    // sessions
    async fn create_session(
        &self,
        token_hash: &str,
        user_id: &str,
        csrf: &str,
        expires: i64,
        ip: &str,
        ua: &str,
    ) -> DbResult<()>;
    async fn session_user(&self, token_hash: &str, now: i64) -> DbResult<(String, String)>;
    async fn delete_session(&self, token_hash: &str) -> DbResult<()>;
    async fn delete_user_sessions(&self, user_id: &str) -> DbResult<()>;
    async fn list_sessions(&self, user_id: &str) -> DbResult<Vec<SessionInfo>>;
    async fn delete_user_session(&self, user_id: &str, token_hash: &str) -> DbResult<()>;
    async fn delete_user_sessions_except(
        &self,
        user_id: &str,
        token_hash: &str,
    ) -> DbResult<()>;
    async fn clean_sessions(&self, now: i64) -> DbResult<()>;

    // projects
    async fn create_project(&self, p: &Project) -> DbResult<()>;
    async fn project_by_id(&self, id: &str) -> DbResult<Project>;
    async fn projects_by_owner(&self, owner_id: &str) -> DbResult<Vec<Project>>;
    async fn update_project(
        &self,
        id: &str,
        display_name: &str,
        group_id: &str,
        tags: &str,
    ) -> DbResult<()>;
    async fn delete_project(&self, id: &str) -> DbResult<()>;
    async fn touch_project(&self, id: &str, ts: i64) -> DbResult<()>;
    async fn set_project_pinned(&self, id: &str, pinned: bool) -> DbResult<()>;

    // project groups
    async fn create_group(&self, g: &ProjectGroup) -> DbResult<()>;
    async fn group_by_id(&self, id: &str) -> DbResult<ProjectGroup>;
    async fn groups_by_owner(&self, owner_id: &str) -> DbResult<Vec<ProjectGroup>>;
    async fn rename_group(&self, id: &str, name: &str) -> DbResult<()>;
    async fn delete_group(&self, id: &str) -> DbResult<()>;

    // locks
    #[allow(dead_code)]
    async fn lock_get(&self, project_id: &str, kind: &str) -> DbResult<LockInfo>;
    async fn lock_acquire(
        &self,
        project_id: &str,
        kind: &str,
        holder: &str,
        label: &str,
        expires: i64,
        now: i64,
        force: bool,
    ) -> DbResult<LockOutcome>;
    async fn lock_heartbeat(
        &self,
        project_id: &str,
        kind: &str,
        holder: &str,
        expires: i64,
    ) -> DbResult<bool>;
    async fn lock_release(&self, project_id: &str, kind: &str, holder: &str) -> DbResult<()>;
    async fn clean_locks(&self, now: i64) -> DbResult<()>;

    // render jobs
    async fn job_create(&self, j: &RenderJob) -> DbResult<()>;
    async fn job_by_id(&self, id: &str) -> DbResult<RenderJob>;
    async fn jobs_by_project(&self, project_id: &str, offset: i64, limit: i64) -> DbResult<Vec<RenderJob>>;
    async fn job_delete(&self, id: &str) -> DbResult<()>;
    async fn job_next_queued(&self) -> DbResult<Option<RenderJob>>;
    async fn job_claim(&self, id: &str, worker: &str, lease_until: i64) -> DbResult<bool>;
    /// Returns false when the job is no longer `running` under `worker`, so a
    /// stale claimant can tell its lease was lost.
    async fn job_progress(
        &self,
        id: &str,
        worker: &str,
        progress: f64,
        lease_until: i64,
    ) -> DbResult<bool>;
    /// Only applies while the job is still `queued`/`running` and claimed by
    /// `worker`; a requeued or finished job ignores stale completions.
    async fn job_finish(
        &self,
        id: &str,
        worker: &str,
        status: &str,
        error: &str,
        finished_at: i64,
    ) -> DbResult<()>;
    async fn job_requeue_stale(&self, now: i64) -> DbResult<u64>;
    async fn job_fail_stale(&self, now: i64) -> DbResult<u64>;

    // render nodes
    async fn node_create(&self, n: &RenderNode, token_hash: &str) -> DbResult<()>;
    async fn node_by_token(&self, token_hash: &str) -> DbResult<RenderNode>;
    async fn node_list(&self) -> DbResult<Vec<RenderNode>>;
    async fn node_touch(&self, id: &str, ts: i64) -> DbResult<()>;
    async fn node_set_disabled(&self, id: &str, disabled: bool) -> DbResult<()>;
    async fn node_delete(&self, id: &str) -> DbResult<()>;

    // audit
    async fn audit(
        &self,
        scope: &str,
        actor_id: &str,
        actor_name: &str,
        action: &str,
        target: &str,
        detail: &str,
        lineage: &str,
        ts: i64,
    ) -> DbResult<()>;
    async fn audit_list(
        &self,
        scope: &str,
        subtree_user_id: Option<&str>,
        limit: i64,
    ) -> DbResult<Vec<AuditEntry>>;

    // key-value settings
    async fn setting_get(&self, k: &str) -> DbResult<Option<String>>;
    async fn setting_set(&self, k: &str, v: &str) -> DbResult<()>;
}

#[derive(RustEmbed)]
#[folder = "migrations/"]
struct Migrations;

/// Names of migration files for a dialect, sorted.
pub fn migration_files(dialect: &str) -> Vec<String> {
    let prefix = format!("{dialect}/");
    let mut v: Vec<String> = Migrations::iter()
        .map(|c| c.into_owned())
        .filter(|n| n.starts_with(&prefix) && n.ends_with(".sql"))
        .collect();
    v.sort();
    v
}

pub fn migration_sql(name: &str) -> Option<String> {
    Migrations::get(name).and_then(|f| String::from_utf8(f.data.into_owned()).ok())
}

/// Open a database from a URL:
///   sqlite (default): "wfm.db", "sqlite:wfm.db", "sqlite:///abs/path.db"
///   postgres:         "postgres://user:pass@host/db" (needs postgres feature)
pub async fn connect(url: &str) -> Result<Arc<dyn Db>, String> {
    if url.starts_with("postgres://") || url.starts_with("postgresql://") {
        #[cfg(feature = "postgres")]
        {
            return postgres::connect(url).await;
        }
        #[cfg(not(feature = "postgres"))]
        {
            return Err(
                "postgres url given but this binary was built without the 'postgres' feature"
                    .to_string(),
            );
        }
    }
    let path = url
        .strip_prefix("sqlite://")
        .or_else(|| url.strip_prefix("sqlite:"))
        .unwrap_or(url);
    sqlite::connect(path).await
}
