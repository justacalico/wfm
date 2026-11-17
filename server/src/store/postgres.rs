use std::sync::Arc;

use async_trait::async_trait;
use sqlx::postgres::PgPoolOptions;
use sqlx::{PgPool, Row};

use crate::model::*;
use crate::store::{migration_files, migration_sql, Db, DbError, DbResult, LockOutcome};

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
        let applied: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM wfm_migrations WHERE name=$1",
        )
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
        created_by: r.get("created_by"),
        lineage: r.get("lineage"),
        created_at: r.get("created_at"),
        last_login: r.get("last_login"),
    }
}

fn row_project(r: sqlx::postgres::PgRow) -> Project {
    Project {
        id: r.get("id"),
        owner_id: r.get("owner_id"),
        name: r.get("name"),
        display_name: r.get("display_name"),
        dir: r.get("dir"),
        group_id: r.get("group_id"),
        tags: tags_split(&r.get::<String, _>("tags")),
        created_at: r.get("created_at"),
    }
}

fn row_group(r: sqlx::postgres::PgRow) -> ProjectGroup {
    ProjectGroup {
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
        sqlx::query("SELECT * FROM users WHERE username=$1")
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
            "INSERT INTO users(id,username,display_name,pass_hash,role,student_id,note,disabled,created_by,lineage,created_at,last_login)
             VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)",
        )
        .bind(&u.id)
        .bind(&u.username)
        .bind(&u.display_name)
        .bind(pass_hash)
        .bind(u.role as i32)
        .bind(&u.student_id)
        .bind(&u.note)
        .bind(u.disabled as i32)
        .bind(&u.created_by)
        .bind(&u.lineage)
        .bind(u.created_at)
        .bind(u.last_login)
        .execute(&self.pool)
        .await
        .map(|_| ())
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
            "UPDATE users SET username=$1, display_name=$2, role=$3, student_id=$4, note=$5 WHERE id=$6",
        )
        .bind(&u.username)
        .bind(&u.display_name)
        .bind(u.role as i32)
        .bind(&u.student_id)
        .bind(&u.note)
        .bind(&u.id)
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
            "SELECT * FROM users WHERE role < $1 AND (lineage LIKE $2 OR id=$3) ORDER BY created_at",
        )
        .bind(actor.role as i32)
        .bind(format!("%/{}/%", actor.id))
        .bind(&actor.id)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_user).collect())
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
        let row = sqlx::query(
            "SELECT user_id,csrf,expires_at FROM sessions WHERE token_hash=$1",
        )
        .bind(token_hash)
        .fetch_optional(&self.pool)
        .await
        .map_err(map_err)?;
        match row {
            Some(r) if r.get::<i64, _>("expires_at") > now => {
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
            "INSERT INTO projects(id,owner_id,name,display_name,dir,group_id,tags,created_at) VALUES($1,$2,$3,$4,$5,$6,$7,$8)",
        )
        .bind(&p.id)
        .bind(&p.owner_id)
        .bind(&p.name)
        .bind(&p.display_name)
        .bind(&p.dir)
        .bind(&p.group_id)
        .bind(tags_csv(&p.tags))
        .bind(p.created_at)
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

    async fn update_project(
        &self,
        id: &str,
        display_name: &str,
        group_id: &str,
        tags: &str,
    ) -> DbResult<()> {
        sqlx::query("UPDATE projects SET display_name=$1, group_id=$2, tags=$3 WHERE id=$4")
            .bind(display_name)
            .bind(group_id)
            .bind(tags)
            .bind(id)
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

    async fn create_group(&self, g: &ProjectGroup) -> DbResult<()> {
        sqlx::query("INSERT INTO project_groups(id,owner_id,name,created_at) VALUES($1,$2,$3,$4)")
            .bind(&g.id)
            .bind(&g.owner_id)
            .bind(&g.name)
            .bind(g.created_at)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn group_by_id(&self, id: &str) -> DbResult<ProjectGroup> {
        sqlx::query("SELECT * FROM project_groups WHERE id=$1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(row_group)
            .map_err(map_err)
    }

    async fn groups_by_owner(&self, owner_id: &str) -> DbResult<Vec<ProjectGroup>> {
        sqlx::query("SELECT * FROM project_groups WHERE owner_id=$1 ORDER BY lower(name)")
            .bind(owner_id)
            .fetch_all(&self.pool)
            .await
            .map(|rows| rows.into_iter().map(row_group).collect())
            .map_err(map_err)
    }

    async fn rename_group(&self, id: &str, name: &str) -> DbResult<()> {
        sqlx::query("UPDATE project_groups SET name=$1 WHERE id=$2")
            .bind(name)
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }

    async fn delete_group(&self, id: &str) -> DbResult<()> {
        let mut tx = self.pool.begin().await.map_err(map_err)?;
        sqlx::query("DELETE FROM project_groups WHERE id=$1")
            .bind(id)
            .execute(&mut *tx)
            .await
            .map_err(map_err)?;
        sqlx::query("UPDATE projects SET group_id='' WHERE group_id=$1")
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
        sqlx::query(
            "UPDATE locks SET expires_at=$1 WHERE project_id=$2 AND kind=$3 AND holder=$4",
        )
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
        sqlx::query(
            "DELETE FROM locks WHERE project_id=$1 AND kind=$2 AND holder=$3",
        )
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
        sqlx::query(
            "INSERT INTO render_jobs(id,project_id,user_id,status,mode,spec,output_name,progress,error,worker,attempts,lease_until,created_at,finished_at)
             VALUES($1,$2,$3,$4,$5,$6,$7,0,'','',0,0,$8,0)",
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
        .map(|_| ())
        .map_err(map_err)
    }

    async fn job_by_id(&self, id: &str) -> DbResult<RenderJob> {
        sqlx::query("SELECT * FROM render_jobs WHERE id=$1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map(|r| row_job(r))
            .map_err(map_err)
    }

    async fn jobs_by_project(&self, project_id: &str) -> DbResult<Vec<RenderJob>> {
        sqlx::query(
            "SELECT * FROM render_jobs WHERE project_id=$1 ORDER BY created_at DESC LIMIT 50",
        )
        .bind(project_id)
        .fetch_all(&self.pool)
        .await
        .map(|rows| rows.into_iter().map(row_job).collect())
        .map_err(map_err)
    }

    async fn job_next_queued(&self) -> DbResult<Option<RenderJob>> {
        sqlx::query(
            "SELECT * FROM render_jobs WHERE status='queued' ORDER BY created_at LIMIT 1",
        )
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

    async fn job_progress(&self, id: &str, progress: f64, lease_until: i64) -> DbResult<()> {
        sqlx::query(
            "UPDATE render_jobs SET progress=$1, lease_until=$2 WHERE id=$3 AND status='running'",
        )
        .bind(progress)
        .bind(lease_until)
        .bind(id)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn job_finish(&self, id: &str, status: &str, error: &str, finished_at: i64) -> DbResult<()> {
        sqlx::query(
            "UPDATE render_jobs SET status=$1, error=$2, finished_at=$3, progress=CASE WHEN $1='done' THEN 1 ELSE progress END WHERE id=$4",
        )
        .bind(status)
        .bind(error)
        .bind(finished_at)
        .bind(id)
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
            "INSERT INTO render_nodes(id,name,token_hash,disabled,created_at,last_seen) VALUES($1,$2,$3,0,$4,0)",
        )
        .bind(&n.id)
        .bind(&n.name)
        .bind(token_hash)
        .bind(n.created_at)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(map_err)
    }

    async fn node_by_token(&self, token_hash: &str) -> DbResult<RenderNode> {
        sqlx::query(
            "SELECT * FROM render_nodes WHERE token_hash=$1 AND disabled=0",
        )
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
        sqlx::query("UPDATE render_nodes SET last_seen=$1 WHERE id=$2")
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
            .map(|_| ())
            .map_err(map_err)
    }

    async fn node_delete(&self, id: &str) -> DbResult<()> {
        sqlx::query("DELETE FROM render_nodes WHERE id=$1")
            .bind(id)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
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
        limit: i64,
    ) -> DbResult<Vec<AuditEntry>> {
        let rows = match subtree_user_id {
            Some(uid) => sqlx::query(
                "SELECT * FROM audit WHERE scope=$1 AND (lineage LIKE $2 OR actor_id=$3) ORDER BY id DESC LIMIT $4",
            )
            .bind(scope)
            .bind(format!("%/{}/%", uid))
            .bind(uid)
            .bind(limit)
            .fetch_all(&self.pool)
            .await,
            None => sqlx::query(
                "SELECT * FROM audit WHERE scope=$1 ORDER BY id DESC LIMIT $2",
            )
            .bind(scope)
            .bind(limit)
            .fetch_all(&self.pool)
            .await,
        }
        .map_err(map_err)?;
        Ok(rows.into_iter().map(row_audit).collect())
    }

    async fn setting_get(&self, k: &str) -> DbResult<Option<String>> {
        sqlx::query_scalar("SELECT v FROM wfm_settings WHERE k=$1")
            .bind(k)
            .fetch_optional(&self.pool)
            .await
            .map_err(map_err)
    }

    async fn setting_set(&self, k: &str, v: &str) -> DbResult<()> {
        sqlx::query("INSERT INTO wfm_settings(k,v) VALUES($1,$2) ON CONFLICT(k) DO UPDATE SET v=excluded.v")
            .bind(k)
            .bind(v)
            .execute(&self.pool)
            .await
            .map(|_| ())
            .map_err(map_err)
    }
}
