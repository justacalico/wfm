#[cfg(feature = "postgres")]
pub mod postgres;
pub mod sqlite;

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

/// Filters for audit_list: empty action/actor and zero from/to mean unfiltered.
#[derive(Default)]
pub struct AuditFilter {
    pub action: String,
    pub actor: String,
    pub from: i64,
    pub to: i64,
    pub limit: i64,
    pub offset: i64,
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
    async fn set_user_avatar(&self, id: &str, key: &str) -> DbResult<()>;
    async fn set_user_disabled(&self, id: &str, disabled: bool) -> DbResult<()>;
    async fn delete_user(&self, id: &str) -> DbResult<()>;
    async fn touch_login(&self, id: &str, ts: i64) -> DbResult<()>;
    async fn owner_count(&self) -> DbResult<i64>;
    /// Accounts the actor may administrate: their lower-rank subtree plus, for
    /// staff, members of classes they own or co-teach.
    async fn managed_users(&self, actor: &User) -> DbResult<Vec<User>>;
    /// The users `actor` may see for sharing: their subtree, their ancestry,
    /// classmates in the same class (students only), and staff linked by a
    /// co-taught class. `model::can_see` in SQL form.
    async fn visible_users(&self, actor: &User) -> DbResult<Vec<User>>;

    // classes
    /// Classes the actor may use: their own, classes they co-teach, classes
    /// owned by users in their subtree, and the class they themselves sit in.
    async fn classes_for(&self, actor: &User) -> DbResult<Vec<Class>>;
    async fn class_by_id(&self, id: &str) -> DbResult<Class>;
    async fn create_class(&self, c: &Class) -> DbResult<()>;
    async fn rename_class(&self, id: &str, name: &str) -> DbResult<bool>;
    /// Deletes a non-unmanaged class and moves its members to `fallback`.
    async fn delete_class(&self, id: &str, fallback: &str) -> DbResult<()>;
    /// The owner's unmanaged class, created on first use.
    async fn unmanaged_class(&self, owner: &User) -> DbResult<Class>;

    // co-teachers: staff attached to a class by its owner for co-teaching
    /// Co-teacher accounts attached to the class.
    async fn class_teachers(&self, class_id: &str) -> DbResult<Vec<User>>;
    async fn class_teacher_add(&self, class_id: &str, teacher_id: &str, ts: i64) -> DbResult<()>;
    async fn class_teacher_remove(&self, class_id: &str, teacher_id: &str) -> DbResult<bool>;
    /// Drop every co-teacher link for the account (demotion or deletion).
    async fn class_teacher_purge(&self, teacher_id: &str) -> DbResult<()>;
    /// Whether the actor co-teaches the class; ownership alone does not count.
    async fn co_teaches(&self, class_id: &str, teacher_id: &str) -> DbResult<bool>;
    /// Whether the actor teaches (owns or co-teaches) a class `target` sits in.
    async fn teaches_member(&self, actor: &User, target: &User) -> DbResult<bool>;
    /// Whether the two users share a class at least one of them teaches:
    /// co-teachers see their class's members and each other.
    async fn shares_taught_class(&self, a: &User, b: &User) -> DbResult<bool>;

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
    async fn delete_user_sessions_except(&self, user_id: &str, token_hash: &str) -> DbResult<()>;
    async fn clean_sessions(&self, now: i64) -> DbResult<()>;

    // projects
    async fn create_project(&self, p: &Project) -> DbResult<()>;
    async fn project_by_id(&self, id: &str) -> DbResult<Project>;
    async fn projects_by_owner(&self, owner_id: &str) -> DbResult<Vec<Project>>;
    async fn user_in_subtree(&self, actor: &User, user_id: &str) -> DbResult<bool>;
    async fn set_project_owner(&self, id: &str, owner_id: &str) -> DbResult<()>;
    async fn update_project(
        &self,
        id: &str,
        display_name: &str,
        folder_id: &str,
    ) -> DbResult<()>;
    async fn delete_project(&self, id: &str) -> DbResult<()>;
    async fn touch_project(&self, id: &str, ts: i64) -> DbResult<()>;
    async fn set_project_pinned(&self, id: &str, pinned: bool) -> DbResult<()>;
    async fn set_project_template(&self, id: &str, template: bool) -> DbResult<()>;
    async fn set_project_status(
        &self,
        id: &str,
        status: &str,
        submitted_at: i64,
        reviewed_by: &str,
    ) -> DbResult<()>;
    async fn set_project_submit_allowed(&self, id: &str, allowed: bool) -> DbResult<()>;

    // comments
    async fn comment_add(
        &self,
        id: &str,
        project: &str,
        user: &str,
        body: &str,
        parent: &str,
        ts: i64,
    ) -> DbResult<()>;
    async fn comments_for(&self, project: &str) -> DbResult<Vec<CommentView>>;
    async fn comment_by_id(&self, id: &str) -> DbResult<CommentView>;
    async fn comment_edit(&self, id: &str, body: &str, ts: i64) -> DbResult<bool>;
    async fn comment_delete(&self, id: &str) -> DbResult<bool>;
    async fn comments_delete_project(&self, project: &str) -> DbResult<()>;

    // project folders
    async fn create_folder(&self, f: &Folder) -> DbResult<()>;
    async fn folder_by_id(&self, id: &str) -> DbResult<Folder>;
    async fn folders_by_owner(&self, owner_id: &str) -> DbResult<Vec<Folder>>;
    async fn rename_folder(&self, id: &str, name: &str) -> DbResult<()>;
    async fn delete_folder(&self, id: &str) -> DbResult<()>;

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
    async fn jobs_by_project(
        &self,
        project_id: &str,
        offset: i64,
        limit: i64,
    ) -> DbResult<Vec<RenderJob>>;
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
        f: &AuditFilter,
    ) -> DbResult<Vec<AuditEntry>>;
    async fn audit_purge(&self, before: i64) -> DbResult<()>;
    async fn audit_wipe(&self, scope: &str) -> DbResult<()>;
    async fn db_size(&self) -> DbResult<Option<u64>>;

    // invite codes
    async fn invite_create(&self, i: &InviteCode) -> DbResult<()>;
    async fn invite_by_hash(&self, hash: &str) -> DbResult<InviteCode>;
    async fn invites_by_creator(&self, uid: &str) -> DbResult<Vec<InviteCode>>;
    /// Atomically claim a code that is unused, unrevoked and unexpired.
    async fn invite_use(&self, hash: &str, uid: &str, ts: i64) -> DbResult<bool>;
    async fn invite_unuse(&self, hash: &str) -> DbResult<()>;
    async fn invite_revoke(&self, id: &str, creator: &str) -> DbResult<bool>;
    async fn share_by(&self, project: &str, invitee: &str) -> DbResult<ProjectShare>;
    async fn share_upsert(&self, s: &ProjectShare) -> DbResult<()>;
    async fn shares_by_project(&self, project: &str) -> DbResult<Vec<ShareView>>;
    async fn shares_for_user(&self, invitee: &str) -> DbResult<Vec<ShareView>>;
    async fn share_respond(&self, id: &str, invitee: &str, status: &str, ts: i64)
        -> DbResult<bool>;
    async fn share_set_level(&self, id: &str, project: &str, level: &str) -> DbResult<bool>;
    async fn share_delete(&self, id: &str, project: &str) -> DbResult<bool>;
    async fn shares_delete_project(&self, project: &str) -> DbResult<()>;
    async fn auto_shares_list(&self, owner: &str) -> DbResult<Vec<AutoShareView>>;
    async fn auto_share_upsert(&self, owner: &str, invitee: &str, level: &str) -> DbResult<()>;
    async fn auto_share_delete(&self, owner: &str, id: &str) -> DbResult<bool>;
    async fn auto_shares_all(&self) -> DbResult<Vec<AutoShare>>;
    async fn share_by_id(&self, id: &str) -> DbResult<ProjectShare>;

    // assignments
    async fn create_assignment(&self, a: &Assignment, copies: &[AssignmentCopy]) -> DbResult<()>;
    async fn assignment(&self, id: &str) -> DbResult<Assignment>;
    async fn assignment_for_source(&self, project: &str) -> DbResult<Assignment>;
    /// The assignment + copy row a student project belongs to, if any.
    async fn assignment_for_project(
        &self,
        project: &str,
    ) -> DbResult<Option<(Assignment, AssignmentCopy)>>;
    async fn submissions(&self, assignment: &str) -> DbResult<Vec<SubmissionView>>;
    /// A student's revealed copies joined with their assignments and projects.
    async fn assignments_for_student(&self, student: &str) -> DbResult<Vec<MyAssignment>>;
    /// Copy project ids the student must not see (hidden assignments).
    async fn hidden_assignment_projects(&self, student: &str) -> DbResult<Vec<String>>;
    async fn update_assignment(&self, a: &Assignment) -> DbResult<()>;
    async fn delete_assignment(&self, id: &str) -> DbResult<()>;
    async fn bump_submissions(&self, project: &str) -> DbResult<()>;

    // notifications
    async fn notify(&self, user: &str, kind: &str, payload: &str, ts: i64) -> DbResult<()>;
    async fn notifications_for(
        &self,
        user: &str,
        before: i64,
        limit: i64,
    ) -> DbResult<Vec<Notification>>;
    async fn notifications_unread(&self, user: &str) -> DbResult<i64>;
    async fn notification_read(&self, user: &str, id: &str, ts: i64) -> DbResult<bool>;
    async fn notifications_read_all(&self, user: &str, ts: i64) -> DbResult<()>;
    /// Teacher-and-above, non-disabled users.
    async fn staff_ids(&self) -> DbResult<Vec<String>>;
    /// Nodes past `stale_before` that have not been reported offline yet;
    /// marks them so the report fires once.
    async fn nodes_newly_offline(&self, stale_before: i64) -> DbResult<Vec<RenderNode>>;

    // public view-only share links
    async fn link_create(&self, l: &ProjectLink) -> DbResult<()>;
    async fn link_by_hash(&self, hash: &str) -> DbResult<ProjectLink>;
    async fn links_by_project(&self, project: &str) -> DbResult<Vec<ProjectLink>>;
    async fn link_revoke(&self, id: &str, project: &str) -> DbResult<bool>;
    async fn links_delete_project(&self, project: &str) -> DbResult<()>;

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
