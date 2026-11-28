use std::sync::Arc;

use async_trait::async_trait;
use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, Row};

use crate::model::*;
use crate::store::{
    migration_files, migration_sql, AuditFilter, Db, DbError, DbResult, LockOutcome,
};

pub struct PgDb {
    pool: PgPool,
}

pub async fn connect(url: &str) -> Result<Arc<dyn Db>, String> {
    let pool = PgPoolOptions::new()
        .max_connections(8)
        .connect(url)
        .await
        .map_err(|e| format!("connect postgres: {e}"))?;
    run_migrations(&pool).await?;
    Ok(Arc::new(PgDb { pool }))
}

async fn run_migrations(pool: &PgPool) -> Result<(), String> {
    sqlx::query(
        "CREATE TABLE IF NOT EXISTS wfm_migrations(name TEXT PRIMARY KEY, applied_at BIGINT NOT NULL)",
    )
    .execute(pool)
    .await
    .map_err(|e| e.to_string())?;

    for file in migration_files("postgres") {
        let sql = migration_sql(&file).ok_or_else(|| format!("migration {file} unreadable"))?;
        let applied: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM wfm_migrations WHERE name=$1")
            .bind(&file)
            .fetch_one(pool)
            .await
            .map_err(|e| e.to_string())?;
        if applied > 0 {
            continue;
        }
        sqlx::raw_sql(&sql)
            .execute(pool)
            .await
            .map_err(|e| format!("migration {file}: {e}"))?;
        sqlx::query(
            "INSERT INTO wfm_migrations(name, applied_at) VALUES($1, EXTRACT(EPOCH FROM now())::BIGINT)",
        )
        .bind(&file)
        .execute(pool)
        .await
        .map_err(|e| e.to_string())?;
        tracing::info!(%file, "applied postgres migration");
    }
    Ok(())
}

fn map_err(e: sqlx::Error) -> DbError {
    match e {
        sqlx::Error::RowNotFound => DbError::NotFound,
        sqlx::Error::Database(d) if d.is_unique_violation() => DbError::Conflict,
        other => DbError::Other(other.to_string()),
    }
}

fn row_user(r: sqlx::postgres::PgRow) -> User {
    let role: i32 = r.get("role");
    User {
        id: r.get("id"),
        username: r.get("username"),
        display_name: r.get("display_name"),
        role: Role::from_i64(role as i64),
        role_name: Role::from_i64(role as i64).as_str().to_string(),
        student_id: r.get("student_id"),
        note: r.get("note"),
        disabled: r.get::<i32, _>("disabled") != 0,
        avatar: r.get("avatar"),
        created_by: r.get("created_by"),
        lineage: r.get("lineage"),
        created_at: r.get("created_at"),
        last_login: r.get("last_login"),
        quota_bytes: r.get("quota_bytes"),
        class_id: r.get("class_id"),
    }
}

fn row_class(r: sqlx::postgres::PgRow) -> Class {
    Class {
        id: r.get("id"),
        owner_id: r.get("owner_id"),
        name: r.get("name"),
        unmanaged: r.get::<i32, _>("unmanaged") != 0,
        created_at: r.get("created_at"),
        members: r.get("members"),
        teachers: r.get("teachers"),
    }
}

const CLASS_SELECT: &str = "SELECT c.id,c.owner_id,c.name,c.unmanaged,c.created_at,(SELECT COUNT(*) FROM users u WHERE u.class_id=c.id) AS members,(SELECT COUNT(*) FROM class_teachers ct WHERE ct.class_id=c.id) AS teachers FROM classes c";

fn row_project(r: sqlx::postgres::PgRow) -> Project {
    Project {
        id: r.get("id"),
        owner_id: r.get("owner_id"),
        name: r.get("name"),
        display_name: r.get("display_name"),
        dir: r.get("dir"),
        folder_id: r.get("folder_id"),
        created_at: r.get("created_at"),
        last_activity: r.get("last_activity"),
        pinned: r.get::<i32, _>("pinned") != 0,
        template: r.get::<i32, _>("template") != 0,
        status: r.get("status"),
        submitted_at: r.get("submitted_at"),
        reviewed_by: r.get("reviewed_by"),
        submit_allowed: r.get::<i32, _>("submit_allowed") != 0,
    }
}

fn row_comment(r: sqlx::postgres::PgRow) -> CommentView {
    CommentView {
        id: r.get("id"),
        project_id: r.get("project_id"),
        user_id: r.get("user_id"),
        username: r.get("username"),
        display_name: r.get("display_name"),
        avatar: r.get("avatar"),
        body: r.get("body"),
        parent_id: r.get("parent_id"),
        created_at: r.get("created_at"),
        edited_at: r.get("edited_at"),
    }
}

fn row_folder(r: sqlx::postgres::PgRow) -> Folder {
    Folder {
        id: r.get("id"),
        owner_id: r.get("owner_id"),
        name: r.get("name"),
        created_at: r.get("created_at"),
    }
}

fn row_job(r: sqlx::postgres::PgRow) -> RenderJob {
    RenderJob {
        id: r.get("id"),
        project_id: r.get("project_id"),
        user_id: r.get("user_id"),
        status: r.get("status"),
        mode: r.get("mode"),
        spec: r.get("spec"),
        output_name: r.get("output_name"),
        progress: r.get("progress"),
        error: r.get("error"),
        worker: r.get("worker"),
        attempts: r.get::<i32, _>("attempts") as i64,
        created_at: r.get("created_at"),
        finished_at: r.get("finished_at"),
    }
}

fn row_node(r: sqlx::postgres::PgRow) -> RenderNode {
    RenderNode {
        id: r.get("id"),
        name: r.get("name"),
        disabled: r.get::<i32, _>("disabled") != 0,
        created_at: r.get("created_at"),
        last_seen: r.get("last_seen"),
    }
}

fn row_assignment(r: &sqlx::postgres::PgRow) -> Assignment {
    Assignment {
        id: r.get("id"),
        project_id: r.get("project_id"),
        teacher_id: r.get("teacher_id"),
        allow_withdraw: r.get::<i32, _>("allow_withdraw") != 0,
        max_submissions: r.get("max_submissions"),
        due_at: r.get("due_at"),
        hidden: r.get::<i32, _>("hidden") != 0,
        locked: r.get::<i32, _>("locked") != 0,
        created_at: r.get("created_at"),
    }
}

fn row_copy(r: &sqlx::postgres::PgRow) -> AssignmentCopy {
    AssignmentCopy {
        project_id: r.get("project_id"),
        assignment_id: r.get("assignment_id"),
        student_id: r.get("student_id"),
        submissions: r.get("submissions"),
    }
}

const ASSIGNMENT_COLS: &str =
    "id,project_id,teacher_id,allow_withdraw,max_submissions,due_at,hidden,locked,created_at";

fn row_link(r: sqlx::postgres::PgRow) -> ProjectLink {
    ProjectLink {
        id: r.get("id"),
        token_hash: r.get("token_hash"),
        project_id: r.get("project_id"),
        scope: r.get("scope"),
        created_by: r.get("created_by"),
        created_at: r.get("created_at"),
        expires_at: r.get("expires_at"),
        revoked: r.get::<i32, _>("revoked") != 0,
    }
}

fn row_notification(r: sqlx::postgres::PgRow) -> Notification {
    let payload: String = r.get("payload");
    Notification {
        id: r.get("id"),
        kind: r.get("kind"),
        payload: serde_json::from_str(&payload).unwrap_or(serde_json::Value::Null),
        read_at: r.get("read_at"),
        created_at: r.get("created_at"),
    }
}

fn row_invite(r: sqlx::postgres::PgRow) -> InviteCode {
    InviteCode {
        id: r.get("id"),
        code_hash: r.get("code_hash"),
        created_by: r.get("created_by"),
        role: r.get("role"),
        preset_username: r.get("preset_username"),
        preset_name: r.get("preset_name"),
        used_by: r.get("used_by"),
        used_at: r.get("used_at"),
        expires_at: r.get("expires_at"),
        revoked: r.get::<i32, _>("revoked") != 0,
        created_at: r.get("created_at"),
    }
}

fn row_share(r: sqlx::postgres::PgRow) -> ProjectShare {
    ProjectShare {
        id: r.get("id"),
        project_id: r.get("project_id"),
        inviter_id: r.get("inviter_id"),
        invitee_id: r.get("invitee_id"),
        level: r.get("level"),
        status: r.get("status"),
        created_at: r.get("created_at"),
        responded_at: r.get("responded_at"),
    }
}

fn row_share_view(r: sqlx::postgres::PgRow) -> ShareView {
    ShareView {
        id: r.get("id"),
        project_id: r.get("project_id"),
        inviter_id: r.get("inviter_id"),
        invitee_id: r.get("invitee_id"),
        level: r.get("level"),
        status: r.get("status"),
        created_at: r.get("created_at"),
        responded_at: r.get("responded_at"),
        project_name: r.get("project_name"),
        inviter_username: r.get("inviter_username"),
        invitee_username: r.get("invitee_username"),
        invitee_name: r.get("invitee_name"),
        template: r.get::<i32, _>("template") != 0,
    }
}

const SHARE_VIEW_SELECT: &str = "SELECT s.id,s.project_id,s.inviter_id,s.invitee_id,s.level,s.status,s.created_at,s.responded_at,p.name AS project_name,iv.username AS inviter_username,ie.username AS invitee_username,ie.display_name AS invitee_name,p.template AS template FROM project_shares s JOIN projects p ON p.id=s.project_id JOIN users iv ON iv.id=s.inviter_id JOIN users ie ON ie.id=s.invitee_id";
fn row_auto_share(r: sqlx::postgres::PgRow) -> AutoShare {
    AutoShare {
        id: r.get("id"),
        owner_id: r.get("owner_id"),
        invitee_id: r.get("invitee_id"),
        level: r.get("level"),
        status: r.get("status"),
        created_at: r.get("created_at"),
    }
}

fn row_auto_share_view(r: sqlx::postgres::PgRow) -> AutoShareView {
    AutoShareView {
        id: r.get("id"),
        invitee_id: r.get("invitee_id"),
        invitee_username: r.get("invitee_username"),
        invitee_name: r.get("invitee_name"),
        owner_username: r.get("owner_username"),
        owner_name: r.get("owner_name"),
        level: r.get("level"),
        status: r.get("status"),
        created_at: r.get("created_at"),
    }
}

fn row_audit(r: sqlx::postgres::PgRow) -> AuditEntry {
    AuditEntry {
        id: r.get("id"),
        ts: r.get("ts"),
        scope: r.get("scope"),
        actor_id: r.get("actor_id"),
        actor_name: r.get("actor_name"),
        action: r.get("action"),
        target: r.get("target"),
        detail: r.get("detail"),
    }
}

#[async_trait]
impl Db for PgDb {
    async fn user_by_id(&self, id: &str) -> DbResult<User> {
        sqlx::query("SELECT * FROM users WHERE id=$1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(|r| row_user(r))
            .map_err(map_err)
    }

    async fn user_by_name(&self, name: &str) -> DbResult<(User, String)> {
        sqlx::query("SELECT * FROM users WHERE lower(username)=lower($1)")
            .bind(name)
            .fetch_one(&self.pool)
            .await
            .map(|r| {
                let hash: String = r.get("pass_hash");
                (row_user(r), hash)
            })
            .map_err(map_err)
    }

    async fn create_user(&self, u: &User, pass_hash: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO users(id,username,display_name,pass_hash,role,student_id,note,disabled,avatar,created_by,lineage,created_at,last_login,quota_bytes,class_id)
             VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)",
        )
        .bind(&u.id)
        .bind(&u.username)
        .bind(&u.display_name)
        .bind(pass_hash)
        .bind(u.role as i32)
        .bind(&u.student_id)
        .bind(&u.note)
        .bind(u.disabled as i32)
        .bind(&u.avatar)
        .bind(&u.created_by)
        .bind(&u.lineage)
        .bind(u.created_at)
        .bind(u.last_login)
        .bind(u.quota_bytes)
        .bind(&u.class_id)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn create_owner(&self, u: &User, pass_hash: &str) -> DbResult<bool> {
        sqlx::query(
            "INSERT INTO users(id,username,display_name,pass_hash,role,student_id,note,disabled,avatar,created_by,lineage,created_at,last_login,quota_bytes,class_id)
             SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15
             WHERE NOT EXISTS(SELECT 1 FROM users WHERE role=$16)",
        )
        .bind(&u.id)
        .bind(&u.username)
        .bind(&u.display_name)
        .bind(pass_hash)
        .bind(u.role as i32)
        .bind(&u.student_id)
        .bind(&u.note)
        .bind(u.disabled as i32)
        .bind(&u.avatar)
        .bind(&u.created_by)
        .bind(&u.lineage)
        .bind(u.created_at)
        .bind(u.last_login)
        .bind(u.quota_bytes)
        .bind(&u.class_id)
        .bind(Role::Owner as i32)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn set_password(&self, id: &str, pass_hash: &str) -> DbResult<()> {
        sqlx::query("UPDATE users SET pass_hash=$1 WHERE id=$2")
            .bind(pass_hash)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn update_user(&self, u: &User) -> DbResult<()> {
        sqlx::query(
            "UPDATE users SET username=$1, display_name=$2, role=$3, student_id=$4, note=$5, quota_bytes=$6, class_id=$7 WHERE id=$8",
        )
        .bind(&u.username)
        .bind(&u.display_name)
        .bind(u.role as i32)
        .bind(&u.student_id)
        .bind(&u.note)
        .bind(u.quota_bytes)
        .bind(&u.class_id)
        .bind(&u.id)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn set_user_avatar(&self, id: &str, key: &str) -> DbResult<()> {
        sqlx::query("UPDATE users SET avatar=$1 WHERE id=$2")
            .bind(key)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn set_user_disabled(&self, id: &str, disabled: bool) -> DbResult<()> {
        sqlx::query("UPDATE users SET disabled=$1 WHERE id=$2")
            .bind(disabled as i32)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn delete_user(&self, id: &str) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query("DELETE FROM sessions WHERE user_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query(
            "UPDATE users SET class_id='' WHERE class_id IN (SELECT id FROM classes WHERE owner_id=$1)",
        )
        .bind(id)
        .execute(&mut *tx)
        .await
        .map_err(map_err)?;
        sqlx::query(
            "DELETE FROM class_teachers WHERE teacher_id=$1 OR class_id IN (SELECT id FROM classes WHERE owner_id=$1)",
        )
        .bind(id)
        .execute(&mut *tx)
        .await
        .map_err(map_err)?;
        sqlx::query("DELETE FROM classes WHERE owner_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("DELETE FROM users WHERE id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        tx.commit().await.map_err(map_err)
    }

    async fn touch_login(&self, id: &str, ts: i64) -> DbResult<()> {
        sqlx::query("UPDATE users SET last_login=$1 WHERE id=$2")
            .bind(ts)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn owner_count(&self) -> DbResult<i64> {
        sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE role=$1")
            .bind(Role::Owner as i32)
            .fetch_one(&self.pool)
            .await
            .map_err(map_err)
    }

    async fn managed_users(&self, actor: &User) -> DbResult<Vec<User>> {
        sqlx::query(
            "SELECT * FROM users WHERE role < $1 AND (lineage LIKE $2 OR id=$3 OR ($4 >= $5 AND class_id IN (SELECT c.id FROM classes c WHERE c.owner_id=$6 OR EXISTS(SELECT 1 FROM class_teachers ct WHERE ct.class_id=c.id AND ct.teacher_id=$6)))) ORDER BY created_at",
        )
        .bind(actor.role as i32)
        .bind(format!("%/{}/%", actor.id))
        .bind(&actor.id)
        .bind(actor.role as i32)
        .bind(crate::model::Role::Teacher as i32)
        .bind(&actor.id)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_user).collect())
        .map_err(map_err)
    }

    async fn visible_users(&self, actor: &User) -> DbResult<Vec<User>> {
        // Classmates only exist for students: an empty class matches nothing for anyone
        // else (the class_id<>'' guard rejects empty matches).
        sqlx::query(
            "SELECT * FROM users WHERE id<>$1 AND ((role<$2 AND lineage LIKE $3) OR $4 LIKE '%/'||id||'/%' OR (role=$5 AND class_id=$6 AND class_id<>'') OR ((role>=$7 OR $2>=$7) AND EXISTS(SELECT 1 FROM classes k WHERE (k.owner_id=users.id OR users.class_id=k.id OR EXISTS(SELECT 1 FROM class_teachers ct WHERE ct.class_id=k.id AND ct.teacher_id=users.id)) AND (k.owner_id=$1 OR k.id=$8 OR EXISTS(SELECT 1 FROM class_teachers ca WHERE ca.class_id=k.id AND ca.teacher_id=$1))))) ORDER BY created_at",
        )
        .bind(&actor.id)
        .bind(actor.role as i32)
        .bind(format!("%/{}/%", actor.id))
        .bind(format!("/{}/", actor.lineage.trim_matches('/')))
        .bind(crate::model::Role::Student as i32)
        .bind(if actor.role == crate::model::Role::Student { actor.class_id.clone() } else { String::new() })
        .bind(crate::model::Role::Teacher as i32)
        .bind(&actor.class_id)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_user).collect())
        .map_err(map_err)
    }

    async fn classes_for(&self, actor: &User) -> DbResult<Vec<Class>> {
        sqlx::query(&format!(
            "{CLASS_SELECT} WHERE c.owner_id=$1 OR c.id=$2 OR c.owner_id IN (SELECT id FROM users WHERE lineage LIKE $3) OR c.id IN (SELECT class_id FROM class_teachers WHERE teacher_id=$1) ORDER BY c.unmanaged DESC, c.created_at"
        ))
        .bind(&actor.id)
        .bind(&actor.class_id)
        .bind(format!("%/{}/%", actor.id))
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_class).collect())
        .map_err(map_err)
    }

    async fn class_by_id(&self, id: &str) -> DbResult<Class> {
        sqlx::query(&format!("{CLASS_SELECT} WHERE c.id=$1"))
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(row_class)
            .map_err(map_err)
    }

    async fn create_class(&self, c: &Class) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO classes(id,owner_id,name,unmanaged,created_at) VALUES($1,$2,$3,$4,$5)",
        )
        .bind(&c.id)
        .bind(&c.owner_id)
        .bind(&c.name)
        .bind(c.unmanaged as i32)
        .bind(c.created_at)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn rename_class(&self, id: &str, name: &str) -> DbResult<bool> {
        sqlx::query("UPDATE classes SET name=$1 WHERE id=$2")
            .bind(name)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn delete_class(&self, id: &str, fallback: &str) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query("UPDATE users SET class_id=$1 WHERE class_id=$2")
            .bind(fallback)
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("DELETE FROM class_teachers WHERE class_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        let n = sqlx::query("DELETE FROM classes WHERE id=$1 AND unmanaged=0")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?
            .rows_affected();
        if n == 0 {
            return Err(DbError::NotFound);
        }
        tx.commit().await.map_err(map_err)
    }

    async fn unmanaged_class(&self, owner: &User) -> DbResult<Class> {
        sqlx::query(
            "INSERT INTO classes(id,owner_id,name,unmanaged,created_at) VALUES($1,$2,'unmanaged',1,EXTRACT(EPOCH FROM now())::BIGINT) ON CONFLICT DO NOTHING",
        )
        .bind(crate::model::new_id())
        .bind(&owner.id)
        .execute(&self.pool)
        .await
        .map_err(map_err)?;
        let by_flag = format!("{CLASS_SELECT} WHERE c.owner_id=$1 AND c.unmanaged=1");
        match sqlx::query(&by_flag)
            .bind(&owner.id)
            .fetch_optional(&self.pool)
            .await
            .map_err(map_err)?
        {
            Some(r) => Ok(row_class(r)),
            None => {
                // A regular class named "unmanaged" blocked the insert; promote it.
                sqlx::query(
                    "UPDATE classes SET unmanaged=1 WHERE owner_id=$1 AND name='unmanaged'",
                )
                .bind(&owner.id)
                .execute(&self.pool)
                .await
                .map_err(map_err)?;
                sqlx::query(&by_flag)
                    .bind(&owner.id)
                    .fetch_one(&self.pool)
                    .await
                    .map(row_class)
                    .map_err(map_err)
            }
        }
    }

    async fn class_teachers(&self, class_id: &str) -> DbResult<Vec<User>> {
        sqlx::query(
            "SELECT * FROM users WHERE id IN (SELECT teacher_id FROM class_teachers WHERE class_id=$1) ORDER BY created_at",
        )
        .bind(class_id)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_user).collect())
        .map_err(map_err)
    }

    async fn class_teacher_add(&self, class_id: &str, teacher_id: &str, ts: i64) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO class_teachers(class_id,teacher_id,created_at) VALUES($1,$2,$3) ON CONFLICT DO NOTHING",
        )
        .bind(class_id)
        .bind(teacher_id)
        .bind(ts)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn class_teacher_remove(&self, class_id: &str, teacher_id: &str) -> DbResult<bool> {
        sqlx::query("DELETE FROM class_teachers WHERE class_id=$1 AND teacher_id=$2")
            .bind(class_id)
            .bind(teacher_id)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn class_teacher_purge(&self, teacher_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM class_teachers WHERE teacher_id=$1")
            .bind(teacher_id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn co_teaches(&self, class_id: &str, teacher_id: &str) -> DbResult<bool> {
        sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM class_teachers WHERE class_id=$1 AND teacher_id=$2)",
        )
        .bind(class_id)
        .bind(teacher_id)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn teaches_member(&self, actor: &User, target: &User) -> DbResult<bool> {
        if actor.role < Role::Teacher || target.class_id.is_empty() {
            return Ok(false);
        }
        sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM classes WHERE id=$1 AND (owner_id=$2 OR EXISTS(SELECT 1 FROM class_teachers ct WHERE ct.class_id=classes.id AND ct.teacher_id=$2)))",
        )
        .bind(&target.class_id)
        .bind(&actor.id)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn shares_taught_class(&self, a: &User, b: &User) -> DbResult<bool> {
        if a.role < Role::Teacher && b.role < Role::Teacher {
            return Ok(false);
        }
        sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM classes k WHERE (k.owner_id=$1 OR k.id=$2 OR EXISTS(SELECT 1 FROM class_teachers ct WHERE ct.class_id=k.id AND ct.teacher_id=$1)) AND (k.owner_id=$3 OR k.id=$4 OR EXISTS(SELECT 1 FROM class_teachers cb WHERE cb.class_id=k.id AND cb.teacher_id=$3)))",
        )
        .bind(&a.id)
        .bind(&a.class_id)
        .bind(&b.id)
        .bind(&b.class_id)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn create_session(
        &self,
        token_hash: &str,
        user_id: &str,
        csrf: &str,
        expires: i64,
        ip: &str,
        ua: &str,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO sessions(token_hash,user_id,csrf,created_at,expires_at,ip,ua)
             VALUES($1,$2,$3,EXTRACT(EPOCH FROM now())::BIGINT,$4,$5,$6)",
        )
        .bind(token_hash)
        .bind(user_id)
        .bind(csrf)
        .bind(expires)
        .bind(ip)
        .bind(ua)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn session_user(&self, token_hash: &str, now: i64) -> DbResult<(String, String)> {
        let row = sqlx::query("SELECT user_id,csrf,expires_at FROM sessions WHERE token_hash=$1")
            .bind(token_hash)
            .fetch_optional(&self.pool)
            .await
            .map_err(map_err)?;
        match row {
            Some(r) if r.get::<i64, _>("expires_at") > now => {
                sqlx::query("UPDATE sessions SET last_seen=$1 WHERE token_hash=$2")
                    .bind(now)
                    .bind(token_hash)
                    .execute(&self.pool)
                    .await
                    .map_err(map_err)?;
                Ok((r.get("user_id"), r.get("csrf")))
            }
            Some(_) => {
                sqlx::query("DELETE FROM sessions WHERE token_hash=$1")
                    .bind(token_hash)
                    .execute(&self.pool)
                    .await
                    .map_err(map_err)?;
                Err(DbError::NotFound)
            }
            None => Err(DbError::NotFound),
        }
    }

    async fn delete_session(&self, token_hash: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM sessions WHERE token_hash=$1")
            .bind(token_hash)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn delete_user_sessions(&self, user_id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM sessions WHERE user_id=$1")
            .bind(user_id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn list_sessions(&self, user_id: &str) -> DbResult<Vec<SessionInfo>> {
        let rows = sqlx::query(
            "SELECT token_hash,ip,ua,created_at,expires_at,last_seen FROM sessions WHERE user_id=$1 ORDER BY created_at DESC",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)?;
        Ok(rows
            .iter()
            .map(|r| SessionInfo {
                id: r.get("token_hash"),
                ip: r.get("ip"),
                ua: r.get("ua"),
                created_at: r.get("created_at"),
                expires_at: r.get("expires_at"),
                last_seen: r.get("last_seen"),
            })
            .collect())
    }

    async fn delete_user_session(&self, user_id: &str, token_hash: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM sessions WHERE user_id=$1 AND token_hash=$2")
            .bind(user_id)
            .bind(token_hash)
            .execute(&self.pool)
            .await
            .map_err(map_err)?;
        Ok(())
    }

    async fn delete_user_sessions_except(&self, user_id: &str, token_hash: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM sessions WHERE user_id=$1 AND token_hash<>$2")
            .bind(user_id)
            .bind(token_hash)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn clean_sessions(&self, now: i64) -> DbResult<()> {
        sqlx::query("DELETE FROM sessions WHERE expires_at<$1")
            .bind(now)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn create_project(&self, p: &Project) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO projects(id,owner_id,name,display_name,dir,folder_id,created_at,last_activity,pinned,template,status,submitted_at,reviewed_by) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)",
        )
        .bind(&p.id)
        .bind(&p.owner_id)
        .bind(&p.name)
        .bind(&p.display_name)
        .bind(&p.dir)
        .bind(&p.folder_id)
        .bind(p.created_at)
        .bind(p.last_activity)
        .bind(p.pinned as i64)
        .bind(p.template as i64)
        .bind(&p.status)
        .bind(p.submitted_at)
        .bind(&p.reviewed_by)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn project_by_id(&self, id: &str) -> DbResult<Project> {
        sqlx::query("SELECT * FROM projects WHERE id=$1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(|r| row_project(r))
            .map_err(map_err)
    }

    async fn projects_by_owner(&self, owner_id: &str) -> DbResult<Vec<Project>> {
        sqlx::query("SELECT * FROM projects WHERE owner_id=$1 ORDER BY created_at DESC")
            .bind(owner_id)
            .fetch_all(&self.pool)
            .await
            .map(|rows| rows.into_iter().map(row_project).collect())
            .map_err(map_err)
    }

    async fn user_in_subtree(&self, actor: &User, user_id: &str) -> DbResult<bool> {
        sqlx::query("SELECT 1 AS x FROM users WHERE id=$1 AND role < $2 AND lineage LIKE $3")
            .bind(user_id)
            .bind(actor.role as i32)
            .bind(format!("%/{}/%", actor.id))
            .fetch_optional(&self.pool)
            .await
            .map(|r| r.is_some())
            .map_err(map_err)
    }

    async fn set_project_owner(&self, id: &str, owner_id: &str) -> DbResult<()> {
        sqlx::query("UPDATE projects SET owner_id=$1 WHERE id=$2")
            .bind(owner_id)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn update_project(&self, id: &str, display_name: &str, folder_id: &str) -> DbResult<()> {
        sqlx::query("UPDATE projects SET display_name=$1, folder_id=$2 WHERE id=$3")
            .bind(display_name)
            .bind(folder_id)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn touch_project(&self, id: &str, ts: i64) -> DbResult<()> {
        sqlx::query("UPDATE projects SET last_activity=$1 WHERE id=$2 AND last_activity<$3")
            .bind(ts)
            .bind(id)
            .bind(ts - 300)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn set_project_pinned(&self, id: &str, pinned: bool) -> DbResult<()> {
        sqlx::query("UPDATE projects SET pinned=$1 WHERE id=$2")
            .bind(pinned as i64)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn set_project_template(&self, id: &str, template: bool) -> DbResult<()> {
        sqlx::query("UPDATE projects SET template=$1 WHERE id=$2")
            .bind(template as i64)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn set_project_status(
        &self,
        id: &str,
        status: &str,
        submitted_at: i64,
        reviewed_by: &str,
    ) -> DbResult<()> {
        sqlx::query("UPDATE projects SET status=$1,submitted_at=$2,reviewed_by=$3 WHERE id=$4")
            .bind(status)
            .bind(submitted_at)
            .bind(reviewed_by)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn set_project_submit_allowed(&self, id: &str, allowed: bool) -> DbResult<()> {
        sqlx::query("UPDATE projects SET submit_allowed=$1 WHERE id=$2")
            .bind(allowed as i32)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn comment_add(
        &self,
        id: &str,
        project: &str,
        user: &str,
        body: &str,
        parent: &str,
        ts: i64,
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO project_comments(id,project_id,user_id,body,parent_id,created_at) VALUES($1,$2,$3,$4,$5,$6)",
        )
        .bind(id)
        .bind(project)
        .bind(user)
        .bind(body)
        .bind(parent)
        .bind(ts)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn comments_for(&self, project: &str) -> DbResult<Vec<CommentView>> {
        sqlx::query(
            "SELECT c.id,c.project_id,c.user_id,u.username,u.display_name,c.body,c.created_at,c.edited_at,u.avatar,c.parent_id FROM project_comments c JOIN users u ON u.id=c.user_id WHERE c.project_id=$1 ORDER BY c.created_at",
        )
        .bind(project)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_comment).collect())
        .map_err(map_err)
    }

    async fn comment_by_id(&self, id: &str) -> DbResult<CommentView> {
        sqlx::query(
            "SELECT c.id,c.project_id,c.user_id,u.username,u.display_name,c.body,c.created_at,c.edited_at,u.avatar,c.parent_id FROM project_comments c JOIN users u ON u.id=c.user_id WHERE c.id=$1",
        )
        .bind(id)
        .fetch_one(&self.pool)
        .await
        .map(row_comment)
        .map_err(map_err)
    }

    async fn comment_edit(&self, id: &str, body: &str, ts: i64) -> DbResult<bool> {
        sqlx::query("UPDATE project_comments SET body=$1,edited_at=$2 WHERE id=$3")
            .bind(body)
            .bind(ts)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn comment_delete(&self, id: &str) -> DbResult<bool> {
        sqlx::query(
            "UPDATE project_comments SET parent_id=(SELECT parent_id FROM project_comments WHERE id=$1) WHERE parent_id=$1",
        )
        .bind(id)
        .execute(&self.pool)
        .await
        .map_err(map_err)?;
        sqlx::query("DELETE FROM project_comments WHERE id=$1")
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn comments_delete_project(&self, project: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM project_comments WHERE project_id=$1")
            .bind(project)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn delete_project(&self, id: &str) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query("DELETE FROM projects WHERE id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("DELETE FROM locks WHERE project_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("DELETE FROM render_jobs WHERE project_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        tx.commit().await.map_err(map_err)
    }

    async fn create_folder(&self, f: &Folder) -> DbResult<()> {
        sqlx::query("INSERT INTO folders(id,owner_id,name,created_at) VALUES($1,$2,$3,$4)")
            .bind(&f.id)
            .bind(&f.owner_id)
            .bind(&f.name)
            .bind(f.created_at)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn folder_by_id(&self, id: &str) -> DbResult<Folder> {
        sqlx::query("SELECT * FROM folders WHERE id=$1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(row_folder)
            .map_err(map_err)
    }

    async fn folders_by_owner(&self, owner_id: &str) -> DbResult<Vec<Folder>> {
        sqlx::query("SELECT * FROM folders WHERE owner_id=$1 ORDER BY lower(name)")
            .bind(owner_id)
            .fetch_all(&self.pool)
            .await
            .map(|rows| rows.into_iter().map(row_folder).collect())
            .map_err(map_err)
    }

    async fn rename_folder(&self, id: &str, name: &str) -> DbResult<()> {
        sqlx::query("UPDATE folders SET name=$1 WHERE id=$2")
            .bind(name)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn delete_folder(&self, id: &str) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query("DELETE FROM folders WHERE id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("UPDATE projects SET folder_id='' WHERE folder_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        tx.commit().await.map_err(map_err)
    }

    async fn lock_get(&self, project_id: &str, kind: &str) -> DbResult<LockInfo> {
        sqlx::query("SELECT holder,label,expires_at FROM locks WHERE project_id=$1 AND kind=$2")
            .bind(project_id)
            .bind(kind)
            .fetch_one(&self.pool)
            .await
            .map(|r| LockInfo {
                holder: r.get("holder"),
                label: r.get("label"),
                expires_at: r.get("expires_at"),
            })
            .map_err(map_err)
    }

    async fn lock_acquire(
        &self,
        project_id: &str,
        kind: &str,
        holder: &str,
        label: &str,
        expires: i64,
        now: i64,
        force: bool,
    ) -> DbResult<LockOutcome> {
        let cur = sqlx::query(
            "SELECT holder,label,expires_at FROM locks WHERE project_id=$1 AND kind=$2",
        )
        .bind(project_id)
        .bind(kind)
        .fetch_optional(&self.pool)
        .await
        .map_err(map_err)?;
        if let Some(r) = &cur {
            let ch: String = r.get("holder");
            let ce: i64 = r.get("expires_at");
            if ch != holder && ce > now && !force {
                return Ok(LockOutcome::Held(LockInfo {
                    holder: ch,
                    label: r.get("label"),
                    expires_at: ce,
                }));
            }
        }
        sqlx::query(
            "INSERT INTO locks(project_id,kind,holder,label,expires_at) VALUES($1,$2,$3,$4,$5)
             ON CONFLICT(project_id,kind) DO UPDATE SET holder=excluded.holder,label=excluded.label,expires_at=excluded.expires_at",
        )
        .bind(project_id)
        .bind(kind)
        .bind(holder)
        .bind(label)
        .bind(expires)
        .execute(&self.pool)
        .await
        .map_err(map_err)?;
        Ok(LockOutcome::Acquired(LockInfo {
            holder: holder.to_string(),
            label: label.to_string(),
            expires_at: expires,
        }))
    }

    async fn lock_heartbeat(
        &self,
        project_id: &str,
        kind: &str,
        holder: &str,
        expires: i64,
    ) -> DbResult<bool> {
        sqlx::query("UPDATE locks SET expires_at=$1 WHERE project_id=$2 AND kind=$3 AND holder=$4")
            .bind(expires)
            .bind(project_id)
            .bind(kind)
            .bind(holder)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn lock_release(&self, project_id: &str, kind: &str, holder: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM locks WHERE project_id=$1 AND kind=$2 AND holder=$3")
            .bind(project_id)
            .bind(kind)
            .bind(holder)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn clean_locks(&self, now: i64) -> DbResult<()> {
        sqlx::query("DELETE FROM locks WHERE expires_at<$1")
            .bind(now)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn job_create(&self, j: &RenderJob) -> DbResult<()> {
        let r = sqlx::query(
            "INSERT INTO render_jobs(id,project_id,user_id,status,mode,spec,output_name,progress,error,worker,attempts,lease_until,created_at,finished_at)
             SELECT $1,$2,$3,$4,$5,$6,$7,0,'','',0,0,$8,0
             WHERE NOT EXISTS(
               SELECT 1 FROM render_jobs
               WHERE project_id=$2 AND status IN('queued','running'))",
        )
        .bind(&j.id)
        .bind(&j.project_id)
        .bind(&j.user_id)
        .bind(&j.status)
        .bind(&j.mode)
        .bind(&j.spec)
        .bind(&j.output_name)
        .bind(j.created_at)
        .execute(&self.pool)
        .await
        .map_err(map_err)?;
        if r.rows_affected() == 0 {
            return Err(DbError::Conflict);
        }
        Ok(())
    }

    async fn job_by_id(&self, id: &str) -> DbResult<RenderJob> {
        sqlx::query("SELECT * FROM render_jobs WHERE id=$1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(|r| row_job(r))
            .map_err(map_err)
    }

    async fn jobs_by_project(
        &self,
        project_id: &str,
        offset: i64,
        limit: i64,
    ) -> DbResult<Vec<RenderJob>> {
        sqlx::query(
            "SELECT * FROM render_jobs WHERE project_id=$1 ORDER BY created_at DESC LIMIT $2 OFFSET $3",
        )
        .bind(project_id)
        .bind(limit)
        .bind(offset)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_job).collect())
        .map_err(map_err)
    }

    async fn job_delete(&self, id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM render_jobs WHERE id=$1")
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn job_next_queued(&self) -> DbResult<Option<RenderJob>> {
        sqlx::query("SELECT * FROM render_jobs WHERE status='queued' ORDER BY created_at LIMIT 1")
            .fetch_optional(&self.pool)
            .await
            .map(|r| r.map(row_job))
            .map_err(map_err)
    }

    async fn job_claim(&self, id: &str, worker: &str, lease_until: i64) -> DbResult<bool> {
        sqlx::query(
            "UPDATE render_jobs SET status='running', worker=$1, lease_until=$2, attempts=attempts+1 WHERE id=$3 AND status='queued'",
        )
        .bind(worker)
        .bind(lease_until)
        .bind(id)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn job_progress(
        &self,
        id: &str,
        worker: &str,
        progress: f64,
        lease_until: i64,
    ) -> DbResult<bool> {
        sqlx::query(
            "UPDATE render_jobs SET progress=$1, lease_until=$2 WHERE id=$3 AND worker=$4 AND status='running'",
        )
        .bind(progress)
        .bind(lease_until)
        .bind(id)
        .bind(worker)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn job_finish(
        &self,
        id: &str,
        worker: &str,
        status: &str,
        error: &str,
        finished_at: i64,
    ) -> DbResult<()> {
        sqlx::query(
            "UPDATE render_jobs SET status=$1, error=$2, finished_at=$3, progress=CASE WHEN $1='done' THEN 1 ELSE progress END WHERE id=$4 AND worker=$5 AND status IN ('queued','running')",
        )
        .bind(status)
        .bind(error)
        .bind(finished_at)
        .bind(id)
        .bind(worker)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn job_requeue_stale(&self, now: i64) -> DbResult<u64> {
        sqlx::query(
            "UPDATE render_jobs SET status='queued', worker='' WHERE status='running' AND lease_until<$1 AND attempts<3",
        )
        .bind(now)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected())
        .map_err(map_err)
    }

    async fn job_fail_stale(&self, now: i64) -> DbResult<u64> {
        sqlx::query(
            "UPDATE render_jobs SET status='failed', error='worker lost', finished_at=$1 WHERE status='running' AND lease_until<$1 AND attempts>=3",
        )
        .bind(now)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected())
        .map_err(map_err)
    }

    async fn node_create(&self, n: &RenderNode, token_hash: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO render_nodes(id,name,token_hash,disabled,created_at,last_seen)
             SELECT $1,$2,$3,0,$4,0 WHERE NOT EXISTS(
               SELECT 1 FROM render_nodes WHERE lower(name)=lower($5))",
        )
        .bind(&n.id)
        .bind(&n.name)
        .bind(token_hash)
        .bind(n.created_at)
        .bind(&n.name)
        .execute(&self.pool)
        .await
        .map_err(map_err)
        .and_then(|r| {
            if r.rows_affected() == 0 {
                Err(DbError::Conflict)
            } else {
                Ok(())
            }
        })
    }

    async fn node_by_token(&self, token_hash: &str) -> DbResult<RenderNode> {
        sqlx::query("SELECT * FROM render_nodes WHERE token_hash=$1 AND disabled=0")
            .bind(token_hash)
            .fetch_one(&self.pool)
            .await
            .map(|r| row_node(r))
            .map_err(map_err)
    }

    async fn node_list(&self) -> DbResult<Vec<RenderNode>> {
        sqlx::query("SELECT * FROM render_nodes ORDER BY created_at")
            .fetch_all(&self.pool)
            .await
            .map(|rows| rows.into_iter().map(row_node).collect())
            .map_err(map_err)
    }

    async fn node_touch(&self, id: &str, ts: i64) -> DbResult<()> {
        sqlx::query("UPDATE render_nodes SET last_seen=$1, offline_notified=0 WHERE id=$2")
            .bind(ts)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn node_set_disabled(&self, id: &str, disabled: bool) -> DbResult<()> {
        sqlx::query("UPDATE render_nodes SET disabled=$1 WHERE id=$2")
            .bind(disabled as i32)
            .bind(id)
            .execute(&self.pool)
            .await
            .map_err(map_err)
            .and_then(|r| {
                if r.rows_affected() == 0 {
                    Err(DbError::NotFound)
                } else {
                    Ok(())
                }
            })
    }

    async fn node_delete(&self, id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM render_nodes WHERE id=$1")
            .bind(id)
            .execute(&self.pool)
            .await
            .map_err(map_err)
            .and_then(|r| {
                if r.rows_affected() == 0 {
                    Err(DbError::NotFound)
                } else {
                    Ok(())
                }
            })
    }

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
    ) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO audit(ts,scope,actor_id,actor_name,action,target,detail,lineage) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
        )
        .bind(ts)
        .bind(scope)
        .bind(actor_id)
        .bind(actor_name)
        .bind(action)
        .bind(target)
        .bind(detail)
        .bind(lineage)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn audit_list(
        &self,
        scope: &str,
        subtree_user_id: Option<&str>,
        f: &AuditFilter,
    ) -> DbResult<Vec<AuditEntry>> {
        let mut sql = "SELECT * FROM audit WHERE scope=$1".to_string();
        let mut n = 1;
        if subtree_user_id.is_some() {
            sql.push_str(&format!(
                " AND (lineage LIKE ${} OR actor_id=${})",
                n + 1,
                n + 2
            ));
            n += 2;
        }
        if !f.action.is_empty() {
            n += 1;
            sql.push_str(&format!(" AND action=${n}"));
        }
        if !f.actor.is_empty() {
            n += 1;
            sql.push_str(&format!(" AND actor_name LIKE ${n}"));
        }
        if f.from > 0 {
            n += 1;
            sql.push_str(&format!(" AND ts>=${n}"));
        }
        if f.to > 0 {
            n += 1;
            sql.push_str(&format!(" AND ts<=${n}"));
        }
        sql.push_str(&format!(
            " ORDER BY id DESC LIMIT ${} OFFSET ${}",
            n + 1,
            n + 2
        ));
        let mut q = sqlx::query(&sql).bind(scope);
        if let Some(uid) = subtree_user_id {
            q = q.bind(format!("%/{uid}/%")).bind(uid);
        }
        if !f.action.is_empty() {
            q = q.bind(&f.action);
        }
        if !f.actor.is_empty() {
            q = q.bind(format!("%{}%", f.actor));
        }
        if f.from > 0 {
            q = q.bind(f.from);
        }
        if f.to > 0 {
            q = q.bind(f.to);
        }
        let rows = q
            .bind(f.limit)
            .bind(f.offset)
            .fetch_all(&self.pool)
            .await
            .map_err(map_err)?;
        Ok(rows.into_iter().map(row_audit).collect())
    }

    async fn audit_purge(&self, before: i64) -> DbResult<()> {
        sqlx::query("DELETE FROM audit WHERE ts<$1")
            .bind(before)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn audit_wipe(&self, scope: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM audit WHERE scope=$1")
            .bind(scope)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn db_size(&self) -> DbResult<Option<u64>> {
        sqlx::query_scalar::<_, i64>("SELECT pg_database_size(current_database())")
            .fetch_one(&self.pool)
            .await
            .map(|n| Some(n as u64))
            .map_err(map_err)
    }

    async fn invite_create(&self, i: &InviteCode) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO invite_codes(id,code_hash,created_by,role,preset_username,preset_name,used_by,used_at,expires_at,revoked,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)",
        )
        .bind(&i.id)
        .bind(&i.code_hash)
        .bind(&i.created_by)
        .bind(&i.role)
        .bind(&i.preset_username)
        .bind(&i.preset_name)
        .bind(&i.used_by)
        .bind(i.used_at)
        .bind(i.expires_at)
        .bind(i.revoked as i32)
        .bind(i.created_at)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn invite_by_hash(&self, hash: &str) -> DbResult<InviteCode> {
        sqlx::query("SELECT * FROM invite_codes WHERE code_hash=$1")
            .bind(hash)
            .fetch_one(&self.pool)
            .await
            .map(|r| row_invite(r))
            .map_err(map_err)
    }

    async fn invites_by_creator(&self, uid: &str) -> DbResult<Vec<InviteCode>> {
        let rows = sqlx::query(
            "SELECT * FROM invite_codes WHERE created_by=$1 AND revoked=0 ORDER BY created_at DESC",
        )
        .bind(uid)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)?;
        Ok(rows.into_iter().map(row_invite).collect())
    }

    async fn invite_use(&self, hash: &str, uid: &str, ts: i64) -> DbResult<bool> {
        sqlx::query(
            "UPDATE invite_codes SET used_by=$1, used_at=$2 WHERE code_hash=$3 AND used_by='' AND revoked=0 AND expires_at>$4",
        )
        .bind(uid)
        .bind(ts)
        .bind(hash)
        .bind(ts)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn invite_unuse(&self, hash: &str) -> DbResult<()> {
        sqlx::query("UPDATE invite_codes SET used_by='', used_at=0 WHERE code_hash=$1")
            .bind(hash)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn invite_revoke(&self, id: &str, creator: &str) -> DbResult<bool> {
        sqlx::query("DELETE FROM invite_codes WHERE id=$1 AND created_by=$2 AND used_by=''")
            .bind(id)
            .bind(creator)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn setting_get(&self, k: &str) -> DbResult<Option<String>> {
        sqlx::query_scalar("SELECT v FROM wfm_settings WHERE k=$1")
            .bind(k)
            .fetch_optional(&self.pool)
            .await
            .map_err(map_err)
    }

    async fn setting_set(&self, k: &str, v: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO wfm_settings(k,v) VALUES($1,$2) ON CONFLICT(k) DO UPDATE SET v=excluded.v",
        )
        .bind(k)
        .bind(v)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn share_by(&self, project: &str, invitee: &str) -> DbResult<ProjectShare> {
        sqlx::query(
            "SELECT id,project_id,inviter_id,invitee_id,level,status,created_at,responded_at FROM project_shares WHERE project_id=$1 AND invitee_id=$2",
        )
        .bind(project)
        .bind(invitee)
        .map(row_share)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn share_upsert(&self, sh: &ProjectShare) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO project_shares(id,project_id,inviter_id,invitee_id,level,status,created_at,responded_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(project_id,invitee_id) DO UPDATE SET inviter_id=excluded.inviter_id,level=excluded.level,status=excluded.status,created_at=excluded.created_at,responded_at=excluded.responded_at",
        )
        .bind(&sh.id)
        .bind(&sh.project_id)
        .bind(&sh.inviter_id)
        .bind(&sh.invitee_id)
        .bind(&sh.level)
        .bind(&sh.status)
        .bind(sh.created_at)
        .bind(sh.responded_at)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn shares_by_project(&self, project: &str) -> DbResult<Vec<ShareView>> {
        sqlx::query(&format!(
            "{SHARE_VIEW_SELECT} WHERE s.project_id=$1 ORDER BY s.created_at DESC"
        ))
        .bind(project)
        .map(row_share_view)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn shares_for_user(&self, invitee: &str) -> DbResult<Vec<ShareView>> {
        sqlx::query(&format!(
            "{SHARE_VIEW_SELECT} WHERE s.invitee_id=$1 AND s.status!='declined' ORDER BY s.created_at DESC"
        ))
        .bind(invitee)
        .map(row_share_view)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn share_respond(
        &self,
        id: &str,
        invitee: &str,
        status: &str,
        ts: i64,
    ) -> DbResult<bool> {
        sqlx::query(
            "UPDATE project_shares SET status=$1, responded_at=$2 WHERE id=$3 AND invitee_id=$4 AND status='pending'",
        )
        .bind(status)
        .bind(ts)
        .bind(id)
        .bind(invitee)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn share_set_level(&self, id: &str, project: &str, level: &str) -> DbResult<bool> {
        sqlx::query("UPDATE project_shares SET level=$1 WHERE id=$2 AND project_id=$3")
            .bind(level)
            .bind(id)
            .bind(project)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn share_delete(&self, id: &str, project: &str) -> DbResult<bool> {
        sqlx::query("DELETE FROM project_shares WHERE id=$1 AND project_id=$2")
            .bind(id)
            .bind(project)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn shares_delete_project(&self, project: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM project_shares WHERE project_id=$1")
            .bind(project)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn auto_shares_list(&self, owner: &str) -> DbResult<Vec<AutoShareView>> {
        sqlx::query(
            "SELECT a.id,a.invitee_id,u.username AS invitee_username,u.display_name AS invitee_name,o.username AS owner_username,o.display_name AS owner_name,a.level,a.status,a.created_at FROM auto_shares a JOIN users u ON u.id=a.invitee_id JOIN users o ON o.id=a.owner_id WHERE a.owner_id=$1 ORDER BY a.created_at DESC",
        )
        .bind(owner)
        .map(row_auto_share_view)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn auto_shares_for_invitee(&self, invitee: &str) -> DbResult<Vec<AutoShareView>> {
        sqlx::query(
            "SELECT a.id,a.invitee_id,u.username AS invitee_username,u.display_name AS invitee_name,o.username AS owner_username,o.display_name AS owner_name,a.level,a.status,a.created_at FROM auto_shares a JOIN users u ON u.id=a.invitee_id JOIN users o ON o.id=a.owner_id WHERE a.invitee_id=$1 ORDER BY a.created_at DESC",
        )
        .bind(invitee)
        .map(row_auto_share_view)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn auto_share_upsert(&self, owner: &str, invitee: &str, level: &str) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO auto_shares(id,owner_id,invitee_id,level,status,created_at) VALUES($1,$2,$3,$4,'pending',$5) ON CONFLICT(owner_id,invitee_id) DO UPDATE SET level=excluded.level,status='pending'",
        )
        .bind(crate::model::new_id())
        .bind(owner)
        .bind(invitee)
        .bind(level)
        .bind(crate::auth::AppState::now())
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn auto_share_by_id(&self, id: &str) -> DbResult<AutoShare> {
        sqlx::query(
            "SELECT id,owner_id,invitee_id,level,status,created_at FROM auto_shares WHERE id=$1",
        )
        .bind(id)
        .map(row_auto_share)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn auto_share_respond(&self, id: &str, invitee: &str, status: &str) -> DbResult<bool> {
        sqlx::query(
            "UPDATE auto_shares SET status=$1 WHERE id=$2 AND invitee_id=$3 AND status='pending'",
        )
        .bind(status)
        .bind(id)
        .bind(invitee)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn auto_share_delete_any(&self, id: &str, user: &str) -> DbResult<bool> {
        sqlx::query("DELETE FROM auto_shares WHERE id=$1 AND (owner_id=$2 OR invitee_id=$2)")
            .bind(id)
            .bind(user)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn auto_shares_all(&self) -> DbResult<Vec<AutoShare>> {
        sqlx::query("SELECT id,owner_id,invitee_id,level,status,created_at FROM auto_shares")
            .map(row_auto_share)
            .fetch_all(&self.pool)
            .await
            .map_err(map_err)
    }

    async fn share_leave(&self, id: &str, invitee: &str) -> DbResult<bool> {
        sqlx::query(
            "DELETE FROM project_shares WHERE id=$1 AND invitee_id=$2 AND status!='declined'",
        )
        .bind(id)
        .bind(invitee)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn share_by_id(&self, id: &str) -> DbResult<ProjectShare> {
        sqlx::query(
            "SELECT id,project_id,inviter_id,invitee_id,level,status,created_at,responded_at FROM project_shares WHERE id=$1",
        )
        .bind(id)
        .map(row_share)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn create_assignment(&self, a: &Assignment, copies: &[AssignmentCopy]) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query(
            "INSERT INTO assignments(id,project_id,teacher_id,allow_withdraw,max_submissions,due_at,hidden,locked,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)",
        )
        .bind(&a.id)
        .bind(&a.project_id)
        .bind(&a.teacher_id)
        .bind(a.allow_withdraw as i32)
        .bind(a.max_submissions)
        .bind(a.due_at)
        .bind(a.hidden as i32)
        .bind(a.locked as i32)
        .bind(a.created_at)
        .execute(&mut *tx)
        .await
        .map_err(map_err)?;
        for cp in copies {
            sqlx::query(
                "INSERT INTO assignment_copies(project_id,assignment_id,student_id,submissions) VALUES($1,$2,$3,0)",
            )
            .bind(&cp.project_id)
            .bind(&cp.assignment_id)
            .bind(&cp.student_id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        }
        tx.commit().await.map_err(map_err)
    }

    async fn assignment(&self, id: &str) -> DbResult<Assignment> {
        sqlx::query(&format!(
            "SELECT {ASSIGNMENT_COLS} FROM assignments WHERE id=$1"
        ))
        .bind(id)
        .map(|r| row_assignment(&r))
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn assignment_for_source(&self, project: &str) -> DbResult<Assignment> {
        sqlx::query(&format!(
            "SELECT {ASSIGNMENT_COLS} FROM assignments WHERE project_id=$1 ORDER BY created_at DESC"
        ))
        .bind(project)
        .map(|r| row_assignment(&r))
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn assignment_for_project(
        &self,
        project: &str,
    ) -> DbResult<Option<(Assignment, AssignmentCopy)>> {
        sqlx::query(
            "SELECT a.id,a.project_id,a.teacher_id,a.allow_withdraw,a.max_submissions,a.due_at,a.hidden,a.locked,a.created_at,c.project_id AS c_project_id,c.assignment_id,c.student_id,c.submissions FROM assignment_copies c JOIN assignments a ON a.id=c.assignment_id WHERE c.project_id=$1",
        )
        .bind(project)
        .map(|r: sqlx::postgres::PgRow| {
            let a = row_assignment(&r);
            let c = AssignmentCopy {
                project_id: r.get("c_project_id"),
                assignment_id: r.get("assignment_id"),
                student_id: r.get("student_id"),
                submissions: r.get("submissions"),
            };
            (a, c)
        })
        .fetch_optional(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn submissions(&self, assignment: &str) -> DbResult<Vec<SubmissionView>> {
        sqlx::query(
            "SELECT c.project_id,p.display_name AS proj_name,c.student_id,u.username,u.display_name AS student_name,p.status,p.submitted_at,c.submissions,a.due_at FROM assignment_copies c JOIN projects p ON p.id=c.project_id JOIN users u ON u.id=c.student_id JOIN assignments a ON a.id=c.assignment_id WHERE c.assignment_id=$1 ORDER BY u.username",
        )
        .bind(assignment)
        .map(|r: sqlx::postgres::PgRow| {
            let submitted_at: i64 = r.get("submitted_at");
            let due_at: i64 = r.get("due_at");
            SubmissionView {
                project_id: r.get("project_id"),
                project_name: r.get("proj_name"),
                student_id: r.get("student_id"),
                student_username: r.get("username"),
                student_name: r.get("student_name"),
                status: r.get("status"),
                submitted_at,
                submissions: r.get("submissions"),
                late: due_at > 0 && submitted_at > due_at,
            }
        })
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn assignments_for_student(&self, student: &str) -> DbResult<Vec<MyAssignment>> {
        sqlx::query(
            "SELECT a.id,a.project_id AS a_project_id,a.teacher_id,a.allow_withdraw,a.max_submissions,a.due_at,a.hidden,a.locked,a.created_at,c.project_id,c.assignment_id,c.student_id,c.submissions,p.display_name AS proj_name,p.status,COALESCE(NULLIF(u.display_name,''),u.username) AS teacher_name FROM assignment_copies c JOIN assignments a ON a.id=c.assignment_id JOIN projects p ON p.id=c.project_id JOIN users u ON u.id=a.teacher_id WHERE c.student_id=$1 AND a.hidden=0 ORDER BY a.created_at DESC",
        )
        .bind(student)
        .map(|r: sqlx::postgres::PgRow| {
            MyAssignment {
                assignment: Assignment {
                    id: r.get("id"),
                    project_id: r.get("a_project_id"),
                    teacher_id: r.get("teacher_id"),
                    allow_withdraw: r.get::<i32, _>("allow_withdraw") != 0,
                    max_submissions: r.get("max_submissions"),
                    due_at: r.get("due_at"),
                    hidden: r.get::<i32, _>("hidden") != 0,
                    locked: r.get::<i32, _>("locked") != 0,
                    created_at: r.get("created_at"),
                },
                copy: row_copy(&r),
                project_name: r.get("proj_name"),
                teacher_name: r.get("teacher_name"),
                status: r.get("status"),
            }
        })
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn hidden_assignment_projects(&self, student: &str) -> DbResult<Vec<String>> {
        sqlx::query(
            "SELECT c.project_id FROM assignment_copies c JOIN assignments a ON a.id=c.assignment_id WHERE c.student_id=$1 AND a.hidden<>0",
        )
        .bind(student)
        .map(|r: sqlx::postgres::PgRow| r.get("project_id"))
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn update_assignment(&self, a: &Assignment) -> DbResult<()> {
        sqlx::query(
            "UPDATE assignments SET allow_withdraw=$1,max_submissions=$2,due_at=$3,hidden=$4,locked=$5 WHERE id=$6",
        )
        .bind(a.allow_withdraw as i32)
        .bind(a.max_submissions)
        .bind(a.due_at)
        .bind(a.hidden as i32)
        .bind(a.locked as i32)
        .bind(&a.id)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn delete_assignment(&self, id: &str) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query("DELETE FROM assignment_copies WHERE assignment_id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("DELETE FROM assignments WHERE id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        tx.commit().await.map_err(map_err)
    }

    async fn bump_submissions(&self, project: &str) -> DbResult<()> {
        sqlx::query("UPDATE assignment_copies SET submissions=submissions+1 WHERE project_id=$1")
            .bind(project)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn notify(&self, user: &str, kind: &str, payload: &str, ts: i64) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO notifications(id,user_id,kind,payload,read_at,created_at) VALUES($1,$2,$3,$4,0,$5)",
        )
        .bind(crate::model::new_id())
        .bind(user)
        .bind(kind)
        .bind(payload)
        .bind(ts)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn notifications_for(
        &self,
        user: &str,
        before: i64,
        limit: i64,
    ) -> DbResult<Vec<Notification>> {
        let before = if before <= 0 { i64::MAX } else { before };
        sqlx::query(
            "SELECT id,kind,payload,read_at,created_at FROM notifications WHERE user_id=$1 AND created_at<$2 ORDER BY created_at DESC, id DESC LIMIT $3",
        )
        .bind(user)
        .bind(before)
        .bind(limit)
        .map(row_notification)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn notifications_unread(&self, user: &str) -> DbResult<i64> {
        sqlx::query_scalar("SELECT COUNT(*) FROM notifications WHERE user_id=$1 AND read_at=0")
            .bind(user)
            .fetch_one(&self.pool)
            .await
            .map_err(map_err)
    }

    async fn notification_read(&self, user: &str, id: &str, ts: i64) -> DbResult<bool> {
        sqlx::query("UPDATE notifications SET read_at=$1 WHERE id=$2 AND user_id=$3 AND read_at=0")
            .bind(ts)
            .bind(id)
            .bind(user)
            .execute(&self.pool)
            .await
            .map(|r| r.rows_affected() > 0)
            .map_err(map_err)
    }

    async fn notifications_read_all(&self, user: &str, ts: i64) -> DbResult<()> {
        sqlx::query("UPDATE notifications SET read_at=$1 WHERE user_id=$2 AND read_at=0")
            .bind(ts)
            .bind(user)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn staff_ids(&self) -> DbResult<Vec<String>> {
        sqlx::query_scalar("SELECT id FROM users WHERE role>=3 AND disabled=0")
            .fetch_all(&self.pool)
            .await
            .map_err(map_err)
    }

    async fn nodes_newly_offline(&self, stale_before: i64) -> DbResult<Vec<RenderNode>> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        let nodes = sqlx::query(
            "SELECT id,name,disabled,created_at,last_seen FROM render_nodes WHERE disabled=0 AND last_seen>0 AND last_seen<$1 AND offline_notified=0 FOR UPDATE SKIP LOCKED",
        )
        .bind(stale_before)
        .map(row_node)
        .fetch_all(&mut *tx)
        .await
        .map_err(map_err)?;
        for n in &nodes {
            sqlx::query("UPDATE render_nodes SET offline_notified=1 WHERE id=$1")
                .bind(&n.id)
                .execute(&mut *tx)
                .await
                .map_err(map_err)?;
        }
        tx.commit().await.map_err(map_err)?;
        Ok(nodes)
    }

    async fn link_create(&self, l: &ProjectLink) -> DbResult<()> {
        sqlx::query(
            "INSERT INTO project_links(id,token_hash,project_id,scope,created_by,created_at,expires_at,revoked) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
        )
        .bind(&l.id)
        .bind(&l.token_hash)
        .bind(&l.project_id)
        .bind(&l.scope)
        .bind(&l.created_by)
        .bind(l.created_at)
        .bind(l.expires_at)
        .bind(l.revoked as i32)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn link_by_hash(&self, hash: &str) -> DbResult<ProjectLink> {
        sqlx::query(
            "SELECT id,token_hash,project_id,scope,created_by,created_at,expires_at,revoked FROM project_links WHERE token_hash=$1",
        )
        .bind(hash)
        .map(row_link)
        .fetch_one(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn links_by_project(&self, project: &str) -> DbResult<Vec<ProjectLink>> {
        sqlx::query(
            "SELECT id,token_hash,project_id,scope,created_by,created_at,expires_at,revoked FROM project_links WHERE project_id=$1 ORDER BY created_at DESC",
        )
        .bind(project)
        .map(row_link)
        .fetch_all(&self.pool)
        .await
        .map_err(map_err)
    }

    async fn link_revoke(&self, id: &str, project: &str) -> DbResult<bool> {
        sqlx::query(
            "UPDATE project_links SET revoked=1 WHERE id=$1 AND project_id=$2 AND revoked=0",
        )
        .bind(id)
        .bind(project)
        .execute(&self.pool)
        .await
        .map(|r| r.rows_affected() > 0)
        .map_err(map_err)
    }

    async fn links_delete_project(&self, project: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM project_links WHERE project_id=$1")
            .bind(project)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Only runs when WFM_TEST_PG points at a real Postgres (CI service).
    #[tokio::test]
    async fn migrations_and_case_insensitive_users() {
        let url = match std::env::var("WFM_TEST_PG") {
            Ok(u) if !u.is_empty() => u,
            _ => return,
        };
        let db = connect(&url).await.unwrap();
        // Migrations are idempotent; a second connect must succeed.
        connect(&url).await.unwrap();

        let suffix = &crate::model::new_id()[..8];
        let user = |name: &str| User {
            id: crate::model::new_id(),
            username: name.into(),
            display_name: "n".into(),
            role: Role::Student,
            role_name: "student".into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            class_id: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        let mixed = format!("Stu{suffix}");
        let lower = mixed.to_lowercase();
        db.create_user(&user(&mixed), "h").await.unwrap();
        // Lookups are case-insensitive like sqlite COLLATE NOCASE.
        let (found, _) = db.user_by_name(&lower).await.unwrap();
        assert_eq!(found.username, mixed);
        // So is uniqueness.
        assert!(db.create_user(&user(&lower), "h").await.is_err());

        // Render node names are unique case-insensitively.
        let node = |name: &str| RenderNode {
            id: crate::model::new_id(),
            name: name.into(),
            disabled: false,
            created_at: 1,
            last_seen: 0,
        };
        let nname = format!("Node{suffix}");
        db.node_create(&node(&nname), "h1").await.unwrap();
        let dup = db.node_create(&node(&nname.to_lowercase()), "h2").await;
        assert!(matches!(dup, Err(DbError::Conflict)));
    }
}
