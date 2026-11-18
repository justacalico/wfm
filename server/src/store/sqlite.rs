use std::sync::Arc;

use async_trait::async_trait;
use rusqlite::{params, OptionalExtension};
use tokio_rusqlite::Connection;

use crate::model::*;
use crate::store::{migration_files, migration_sql, Db, DbError, DbResult, LockOutcome};

pub struct SqliteDb {
    conn: Connection,
}

impl SqliteDb {
    async fn q<T: Send + 'static>(
        &self,
        f: impl FnOnce(&mut rusqlite::Connection) -> rusqlite::Result<T> + Send + 'static,
    ) -> Result<T, tokio_rusqlite::Error> {
        self.conn
            .call(move |c| f(c).map_err(tokio_rusqlite::Error::from))
            .await
    }
}

pub async fn connect(path: &str) -> Result<Arc<dyn Db>, String> {
    let conn = Connection::open(path)
        .await
        .map_err(|e| format!("open sqlite {path}: {e}"))?;
    conn.call(|c| {
        c.execute_batch(
            "PRAGMA journal_mode=WAL;
             PRAGMA busy_timeout=5000;
             PRAGMA foreign_keys=1;
             PRAGMA synchronous=NORMAL;",
        )
        .map_err(tokio_rusqlite::Error::from)
    })
    .await
    .map_err(|e| format!("sqlite pragmas: {e}"))?;
    run_migrations(&conn).await?;
    Ok(Arc::new(SqliteDb { conn }))
}

fn dberr(e: tokio_rusqlite::Error) -> DbError {
    match e {
        tokio_rusqlite::Error::Rusqlite(rusqlite::Error::QueryReturnedNoRows) => {
            DbError::NotFound
        }
        tokio_rusqlite::Error::Rusqlite(rusqlite::Error::SqliteFailure(se, _))
            if se.code == rusqlite::ErrorCode::ConstraintViolation =>
        {
            DbError::Conflict
        }
        other => DbError::Other(other.to_string()),
    }
}

async fn run_migrations(conn: &Connection) -> Result<(), String> {
    conn.call(|c| {
        c.execute_batch(
            "CREATE TABLE IF NOT EXISTS wfm_migrations(
               name TEXT PRIMARY KEY,
               applied_at INTEGER NOT NULL)",
        )
        .map_err(tokio_rusqlite::Error::from)
    })
    .await
    .map_err(|e| e.to_string())?;

    for file in migration_files("sqlite") {
        let sql = migration_sql(&file).ok_or_else(|| format!("migration {file} unreadable"))?;
        let fname = file.clone();
        let applied: i64 = conn
            .call(move |c| {
                c.query_row(
                    "SELECT COUNT(*) FROM wfm_migrations WHERE name=?",
                    [fname],
                    |r| r.get::<_, i64>(0),
                )
                .map_err(tokio_rusqlite::Error::from)
            })
            .await
            .map_err(|e| e.to_string())?;
        if applied > 0 {
            continue;
        }
        let fname = file.clone();
        conn.call(move |c| {
            let tx = c.transaction()?;
            tx.execute_batch(&sql)?;
            tx.execute(
                "INSERT INTO wfm_migrations(name, applied_at) VALUES(?, strftime('%s','now'))",
                [fname],
            )?;
            Ok(tx.commit()?)
        })
        .await
        .map_err(|e| format!("migration {file}: {e}"))?;
        tracing::info!(%file, "applied sqlite migration");
    }
    Ok(())
}

fn map_user(r: &rusqlite::Row<'_>) -> rusqlite::Result<User> {
    let role: i64 = r.get(4)?;
    Ok(User {
        id: r.get(0)?,
        username: r.get(1)?,
        display_name: r.get(2)?,
        role: Role::from_i64(role),
        role_name: Role::from_i64(role).as_str().to_string(),
        student_id: r.get(5)?,
        note: r.get(6)?,
        disabled: r.get::<_, i64>(7)? != 0,
        created_by: r.get(8)?,
        lineage: r.get(9)?,
        created_at: r.get(10)?,
        last_login: r.get(11)?,
    })
}

const USER_COLS: &str =
    "id,username,display_name,pass_hash,role,student_id,note,disabled,created_by,lineage,created_at,last_login";

const PROJECT_COLS: &str = "id,owner_id,name,display_name,dir,group_id,tags,created_at,last_activity,pinned";

fn map_project(r: &rusqlite::Row<'_>) -> rusqlite::Result<Project> {
    Ok(Project {
        id: r.get(0)?,
        owner_id: r.get(1)?,
        name: r.get(2)?,
        display_name: r.get(3)?,
        dir: r.get(4)?,
        group_id: r.get(5)?,
        tags: tags_split(&r.get::<_, String>(6)?),
        created_at: r.get(7)?,
        last_activity: r.get(8)?,
        pinned: r.get::<_, i64>(9)? != 0,
    })
}

fn map_group(r: &rusqlite::Row<'_>) -> rusqlite::Result<ProjectGroup> {
    Ok(ProjectGroup {
        id: r.get(0)?,
        owner_id: r.get(1)?,
        name: r.get(2)?,
        created_at: r.get(3)?,
    })
}

fn map_job(r: &rusqlite::Row<'_>) -> rusqlite::Result<RenderJob> {
    Ok(RenderJob {
        id: r.get(0)?,
        project_id: r.get(1)?,
        user_id: r.get(2)?,
        status: r.get(3)?,
        mode: r.get(4)?,
        spec: r.get(5)?,
        output_name: r.get(6)?,
        progress: r.get(7)?,
        error: r.get(8)?,
        worker: r.get(9)?,
        attempts: r.get(10)?,
        created_at: r.get(11)?,
        finished_at: r.get(12)?,
    })
}

const JOB_COLS: &str = "id,project_id,user_id,status,mode,spec,output_name,progress,error,worker,attempts,created_at,finished_at";

fn map_node(r: &rusqlite::Row<'_>) -> rusqlite::Result<RenderNode> {
    Ok(RenderNode {
        id: r.get(0)?,
        name: r.get(1)?,
        disabled: r.get::<_, i64>(2)? != 0,
        created_at: r.get(3)?,
        last_seen: r.get(4)?,
    })
}

fn map_audit(r: &rusqlite::Row<'_>) -> rusqlite::Result<AuditEntry> {
    Ok(AuditEntry {
        id: r.get(0)?,
        ts: r.get(1)?,
        scope: r.get(2)?,
        actor_id: r.get(3)?,
        actor_name: r.get(4)?,
        action: r.get(5)?,
        target: r.get(6)?,
        detail: r.get(7)?,
    })
}

#[async_trait]
impl Db for SqliteDb {
    async fn user_by_id(&self, id: &str) -> DbResult<User> {
        let id = id.to_string();
        self.q(move |c| {
                c.query_row(
                    &format!("SELECT {USER_COLS} FROM users WHERE id=?"),
                    [id],
                    map_user,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn user_by_name(&self, name: &str) -> DbResult<(User, String)> {
        let name = name.to_string();
        self.q(move |c| {
                c.query_row(
                    &format!("SELECT {USER_COLS} FROM users WHERE username=?"),
                    [name],
                    |r| Ok((map_user(r)?, r.get::<_, String>(3)?)),
                )
            })
            .await
            .map_err(dberr)
    }

    async fn create_user(&self, u: &User, pass_hash: &str) -> DbResult<()> {
        let (u, h) = (u.clone(), pass_hash.to_string());
        self.q(move |c| {
                c.execute(
                    &format!("INSERT INTO users({USER_COLS}) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)"),
                    params![
                        u.id, u.username, u.display_name, h, u.role as i64, u.student_id,
                        u.note, u.disabled as i64, u.created_by, u.lineage, u.created_at,
                        u.last_login
                    ],
                )
                .map(|_| ())
            })
            .await
            .map_err(dberr)
    }

    async fn create_owner(&self, u: &User, pass_hash: &str) -> DbResult<bool> {
        let (u, h) = (u.clone(), pass_hash.to_string());
        self.q(move |c| {
                c.execute(
                    &format!("INSERT INTO users({USER_COLS}) SELECT ?,?,?,?,?,?,?,?,?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM users WHERE role=?)"),
                    params![
                        u.id, u.username, u.display_name, h, u.role as i64, u.student_id,
                        u.note, u.disabled as i64, u.created_by, u.lineage, u.created_at,
                        u.last_login, Role::Owner as i64
                    ],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn set_password(&self, id: &str, pass_hash: &str) -> DbResult<()> {
        let (id, h) = (id.to_string(), pass_hash.to_string());
        self.q(move |c| {
                c.execute("UPDATE users SET pass_hash=? WHERE id=?", params![h, id])
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn update_user(&self, u: &User) -> DbResult<()> {
        let u = u.clone();
        self.q(move |c| {
                c.execute(
                    "UPDATE users SET username=?, display_name=?, role=?, student_id=?, note=? WHERE id=?",
                    params![
                        u.username,
                        u.display_name,
                        u.role as i64,
                        u.student_id,
                        u.note,
                        u.id
                    ],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn set_user_disabled(&self, id: &str, disabled: bool) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                c.execute(
                    "UPDATE users SET disabled=? WHERE id=?",
                    params![disabled as i64, id],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn delete_user(&self, id: &str) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                let tx = c.transaction()?;
                tx.execute("DELETE FROM sessions WHERE user_id=?", [&id])?;
                tx.execute("DELETE FROM users WHERE id=?", [&id])?;
                tx.commit()
            })
            .await
            .map_err(dberr)
    }

    async fn touch_login(&self, id: &str, ts: i64) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                c.execute("UPDATE users SET last_login=? WHERE id=?", params![ts, id])
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn owner_count(&self) -> DbResult<i64> {
        self.q(|c| {
                c.query_row(
                    "SELECT COUNT(*) FROM users WHERE role=?",
                    [Role::Owner as i64],
                    |r| r.get(0),
                )
            })
            .await
            .map_err(dberr)
    }

    async fn managed_users(&self, actor: &User) -> DbResult<Vec<User>> {
        let (role, id, aid) = (
            actor.role as i64,
            format!("%/{}/%", actor.id),
            actor.id.clone(),
        );
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT {USER_COLS} FROM users WHERE role < ? AND (lineage LIKE ? OR id=?) ORDER BY created_at"
                ))?;
                let rows = st.query_map(params![role, id, aid], map_user)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
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
        let v: Vec<String> = [token_hash, user_id, csrf, ip, ua]
            .iter()
            .map(|s| s.to_string())
            .collect();
        self.q(move |c| {
                c.execute(
                    "INSERT INTO sessions(token_hash,user_id,csrf,created_at,expires_at,ip,ua) VALUES(?,?,?,strftime('%s','now'),?,?,?)",
                    params![v[0], v[1], v[2], expires, v[3], v[4]],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn session_user(&self, token_hash: &str, now: i64) -> DbResult<(String, String)> {
        let th = token_hash.to_string();
        self.q(move |c| {
                let row = c
                    .query_row(
                        "SELECT user_id,csrf,expires_at FROM sessions WHERE token_hash=?",
                        [&th],
                        |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, i64>(2)?,
                            ))
                        },
                    )
                    .optional()?;
                match row {
                    Some((uid, csrf, exp)) if exp > now => Ok(Some((uid, csrf))),
                    Some(_) => {
                        c.execute("DELETE FROM sessions WHERE token_hash=?", [&th])?;
                        Ok(None)
                    }
                    None => Ok(None),
                }
            })
            .await
            .map_err(dberr)?
            .ok_or(DbError::NotFound)
    }

    async fn delete_session(&self, token_hash: &str) -> DbResult<()> {
        let th = token_hash.to_string();
        self.q(move |c| c.execute("DELETE FROM sessions WHERE token_hash=?", [th]))
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn delete_user_sessions(&self, user_id: &str) -> DbResult<()> {
        let uid = user_id.to_string();
        self.q(move |c| c.execute("DELETE FROM sessions WHERE user_id=?", [uid]))
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn delete_user_sessions_except(
        &self,
        user_id: &str,
        token_hash: &str,
    ) -> DbResult<()> {
        let uid = user_id.to_string();
        let th = token_hash.to_string();
        self.q(move |c| {
            c.execute(
                "DELETE FROM sessions WHERE user_id=? AND token_hash<>?",
                [uid, th],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn clean_sessions(&self, now: i64) -> DbResult<()> {
        self.q(move |c| c.execute("DELETE FROM sessions WHERE expires_at<?", [now]))
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn create_project(&self, p: &Project) -> DbResult<()> {
        let p = p.clone();
        self.q(move |c| {
                c.execute(
                    "INSERT INTO projects(id,owner_id,name,display_name,dir,group_id,tags,created_at,last_activity,pinned) VALUES(?,?,?,?,?,?,?,?,?,?)",
                    params![p.id, p.owner_id, p.name, p.display_name, p.dir, p.group_id, tags_csv(&p.tags), p.created_at, p.last_activity, p.pinned],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn project_by_id(&self, id: &str) -> DbResult<Project> {
        let id = id.to_string();
        self.q(move |c| {
                c.query_row(
                    &format!("SELECT {PROJECT_COLS} FROM projects WHERE id=?"),
                    [id],
                    map_project,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn projects_by_owner(&self, owner_id: &str) -> DbResult<Vec<Project>> {
        let oid = owner_id.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    &format!("SELECT {PROJECT_COLS} FROM projects WHERE owner_id=? ORDER BY created_at DESC"),
                )?;
                let rows = st.query_map([oid], map_project)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn update_project(
        &self,
        id: &str,
        display_name: &str,
        group_id: &str,
        tags: &str,
    ) -> DbResult<()> {
        let (id, name, gid, tags) = (
            id.to_string(),
            display_name.to_string(),
            group_id.to_string(),
            tags.to_string(),
        );
        self.q(move |c| {
                c.execute(
                    "UPDATE projects SET display_name=?, group_id=?, tags=? WHERE id=?",
                    params![name, gid, tags, id],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn touch_project(&self, id: &str, ts: i64) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE projects SET last_activity=? WHERE id=? AND last_activity<?",
                params![ts, id, ts - 300],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn set_project_pinned(&self, id: &str, pinned: bool) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE projects SET pinned=? WHERE id=?",
                params![pinned as i64, id],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn delete_project(&self, id: &str) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                let tx = c.transaction()?;
                tx.execute("DELETE FROM projects WHERE id=?", [&id])?;
                tx.execute("DELETE FROM locks WHERE project_id=?", [&id])?;
                tx.execute("DELETE FROM render_jobs WHERE project_id=?", [&id])?;
                tx.commit()
            })
            .await
            .map_err(dberr)
    }

    async fn create_group(&self, g: &ProjectGroup) -> DbResult<()> {
        let g = g.clone();
        self.q(move |c| {
                c.execute(
                    "INSERT INTO project_groups(id,owner_id,name,created_at) VALUES(?,?,?,?)",
                    params![g.id, g.owner_id, g.name, g.created_at],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn group_by_id(&self, id: &str) -> DbResult<ProjectGroup> {
        let id = id.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT id,owner_id,name,created_at FROM project_groups WHERE id=?",
                    [id],
                    map_group,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn groups_by_owner(&self, owner_id: &str) -> DbResult<Vec<ProjectGroup>> {
        let oid = owner_id.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT id,owner_id,name,created_at FROM project_groups WHERE owner_id=? ORDER BY name COLLATE NOCASE",
                )?;
                let rows = st.query_map([oid], map_group)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn rename_group(&self, id: &str, name: &str) -> DbResult<()> {
        let (id, name) = (id.to_string(), name.to_string());
        self.q(move |c| {
                c.execute(
                    "UPDATE project_groups SET name=? WHERE id=?",
                    params![name, id],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn delete_group(&self, id: &str) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                let tx = c.transaction()?;
                tx.execute("DELETE FROM project_groups WHERE id=?", [&id])?;
                tx.execute("UPDATE projects SET group_id='' WHERE group_id=?", [&id])?;
                tx.commit()
            })
            .await
            .map_err(dberr)
    }

    async fn lock_get(&self, project_id: &str, kind: &str) -> DbResult<LockInfo> {
        let (p, k) = (project_id.to_string(), kind.to_string());
        self.q(move |c| {
                c.query_row(
                    "SELECT holder,label,expires_at FROM locks WHERE project_id=? AND kind=?",
                    params![p, k],
                    |r| {
                        Ok(LockInfo {
                            holder: r.get(0)?,
                            label: r.get(1)?,
                            expires_at: r.get(2)?,
                        })
                    },
                )
            })
            .await
            .map_err(dberr)
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
        let (p, k, h, l) = (
            project_id.to_string(),
            kind.to_string(),
            holder.to_string(),
            label.to_string(),
        );
        self.q(move |c| {
                let cur = c
                    .query_row(
                        "SELECT holder,label,expires_at FROM locks WHERE project_id=? AND kind=?",
                        params![p, k],
                        |r| {
                            Ok((
                                r.get::<_, String>(0)?,
                                r.get::<_, String>(1)?,
                                r.get::<_, i64>(2)?,
                            ))
                        },
                    )
                    .optional()?;
                if let Some((ch, cl, ce)) = &cur {
                    if ch != &h && *ce > now && !force {
                        return Ok(LockOutcome::Held(LockInfo {
                            holder: ch.clone(),
                            label: cl.clone(),
                            expires_at: *ce,
                        }));
                    }
                }
                c.execute(
                    "INSERT INTO locks(project_id,kind,holder,label,expires_at) VALUES(?,?,?,?,?)
                     ON CONFLICT(project_id,kind) DO UPDATE SET holder=excluded.holder,label=excluded.label,expires_at=excluded.expires_at",
                    params![p, k, h, l, expires],
                )?;
                Ok(LockOutcome::Acquired(LockInfo {
                    holder: h,
                    label: l,
                    expires_at: expires,
                }))
            })
            .await
            .map_err(dberr)
    }

    async fn lock_heartbeat(
        &self,
        project_id: &str,
        kind: &str,
        holder: &str,
        expires: i64,
    ) -> DbResult<bool> {
        let (p, k, h) = (
            project_id.to_string(),
            kind.to_string(),
            holder.to_string(),
        );
        self.q(move |c| {
                c.execute(
                    "UPDATE locks SET expires_at=? WHERE project_id=? AND kind=? AND holder=?",
                    params![expires, p, k, h],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn lock_release(&self, project_id: &str, kind: &str, holder: &str) -> DbResult<()> {
        let (p, k, h) = (
            project_id.to_string(),
            kind.to_string(),
            holder.to_string(),
        );
        self.q(move |c| {
                c.execute(
                    "DELETE FROM locks WHERE project_id=? AND kind=? AND holder=?",
                    params![p, k, h],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn clean_locks(&self, now: i64) -> DbResult<()> {
        self.q(move |c| c.execute("DELETE FROM locks WHERE expires_at<?", [now]))
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn job_create(&self, j: &RenderJob) -> DbResult<()> {
        let j = j.clone();
        self.q(move |c| {
                c.execute(
                    "INSERT INTO render_jobs(id,project_id,user_id,status,mode,spec,output_name,progress,error,worker,attempts,lease_until,created_at,finished_at)
                     VALUES(?,?,?,?,?,?,?,0,'','',0,0,?,0)",
                    params![
                        j.id, j.project_id, j.user_id, j.status, j.mode, j.spec,
                        j.output_name, j.created_at
                    ],
                )
                .map(|_| ())
            })
            .await
            .map_err(dberr)
    }

    async fn job_by_id(&self, id: &str) -> DbResult<RenderJob> {
        let id = id.to_string();
        self.q(move |c| {
                c.query_row(
                    &format!("SELECT {JOB_COLS} FROM render_jobs WHERE id=?"),
                    [id],
                    map_job,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn jobs_by_project(&self, project_id: &str) -> DbResult<Vec<RenderJob>> {
        let pid = project_id.to_string();
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT {JOB_COLS} FROM render_jobs WHERE project_id=? ORDER BY created_at DESC LIMIT 50"
                ))?;
                let rows = st.query_map([pid], map_job)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn job_next_queued(&self) -> DbResult<Option<RenderJob>> {
        self.q(|c| {
                c.query_row(
                    &format!("SELECT {JOB_COLS} FROM render_jobs WHERE status='queued' ORDER BY created_at LIMIT 1"),
                    [],
                    map_job,
                )
                .optional()
            })
            .await
            .map_err(dberr)
    }

    async fn job_claim(&self, id: &str, worker: &str, lease_until: i64) -> DbResult<bool> {
        let (id, w) = (id.to_string(), worker.to_string());
        self.q(move |c| {
                c.execute(
                    "UPDATE render_jobs SET status='running', worker=?, lease_until=?, attempts=attempts+1 WHERE id=? AND status='queued'",
                    params![w, lease_until, id],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn job_progress(
        &self,
        id: &str,
        worker: &str,
        progress: f64,
        lease_until: i64,
    ) -> DbResult<bool> {
        let (id, w) = (id.to_string(), worker.to_string());
        self.q(move |c| {
                c.execute(
                    "UPDATE render_jobs SET progress=?, lease_until=? WHERE id=? AND worker=? AND status='running'",
                    params![progress, lease_until, id, w],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn job_finish(
        &self,
        id: &str,
        worker: &str,
        status: &str,
        error: &str,
        finished_at: i64,
    ) -> DbResult<()> {
        let (id, w, st, e) = (
            id.to_string(),
            worker.to_string(),
            status.to_string(),
            error.to_string(),
        );
        self.q(move |c| {
                c.execute(
                    "UPDATE render_jobs SET status=?, error=?, finished_at=?, progress=CASE WHEN ?='done' THEN 1 ELSE progress END WHERE id=? AND worker=? AND status IN ('queued','running')",
                    params![st, e, finished_at, st, id, w],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn job_requeue_stale(&self, now: i64) -> DbResult<u64> {
        self.q(move |c| {
                c.execute(
                    "UPDATE render_jobs SET status='queued', worker='' WHERE status='running' AND lease_until<? AND attempts<3",
                    [now],
                )
            })
            .await
            .map(|n| n as u64)
            .map_err(dberr)
    }

    async fn job_fail_stale(&self, now: i64) -> DbResult<u64> {
        self.q(move |c| {
                c.execute(
                    "UPDATE render_jobs SET status='failed', error='worker lost', finished_at=? WHERE status='running' AND lease_until<? AND attempts>=3",
                    params![now, now],
                )
            })
            .await
            .map(|n| n as u64)
            .map_err(dberr)
    }

    async fn node_create(&self, n: &RenderNode, token_hash: &str) -> DbResult<()> {
        let (n, th) = (n.clone(), token_hash.to_string());
        self.q(move |c| {
                c.execute(
                    "INSERT INTO render_nodes(id,name,token_hash,disabled,created_at,last_seen)
                     SELECT ?,?,?,0,?,0 WHERE NOT EXISTS(
                       SELECT 1 FROM render_nodes WHERE name=? COLLATE NOCASE)",
                    params![n.id, n.name, th, n.created_at, n.name],
                )
            })
            .await
            .map_err(dberr)
            .and_then(|rows| {
                if rows == 0 {
                    Err(DbError::Conflict)
                } else {
                    Ok(())
                }
            })
    }

    async fn node_by_token(&self, token_hash: &str) -> DbResult<RenderNode> {
        let th = token_hash.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT id,name,disabled,created_at,last_seen FROM render_nodes WHERE token_hash=? AND disabled=0",
                    [th],
                    map_node,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn node_list(&self) -> DbResult<Vec<RenderNode>> {
        self.q(|c| {
                let mut st = c.prepare(
                    "SELECT id,name,disabled,created_at,last_seen FROM render_nodes ORDER BY created_at",
                )?;
                let rows = st.query_map([], map_node)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn node_touch(&self, id: &str, ts: i64) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                c.execute(
                    "UPDATE render_nodes SET last_seen=? WHERE id=?",
                    params![ts, id],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn node_set_disabled(&self, id: &str, disabled: bool) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
                c.execute(
                    "UPDATE render_nodes SET disabled=? WHERE id=?",
                    params![disabled as i64, id],
                )
            })
            .await
            .map_err(dberr)
            .and_then(|rows| if rows == 0 { Err(DbError::NotFound) } else { Ok(()) })
    }

    async fn node_delete(&self, id: &str) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| c.execute("DELETE FROM render_nodes WHERE id=?", [id]))
            .await
            .map_err(dberr)
            .and_then(|rows| if rows == 0 { Err(DbError::NotFound) } else { Ok(()) })
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
        let v: Vec<String> = [scope, actor_id, actor_name, action, target, detail, lineage]
            .iter()
            .map(|s| s.to_string())
            .collect();
        self.q(move |c| {
                c.execute(
                    "INSERT INTO audit(ts,scope,actor_id,actor_name,action,target,detail,lineage) VALUES(?,?,?,?,?,?,?,?)",
                    params![ts, v[0], v[1], v[2], v[3], v[4], v[5], v[6]],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn audit_list(
        &self,
        scope: &str,
        subtree_user_id: Option<&str>,
        limit: i64,
    ) -> DbResult<Vec<AuditEntry>> {
        let scope = scope.to_string();
        let uid = subtree_user_id.map(|u| u.to_string());
        let like = subtree_user_id.map(|u| format!("%/{}/%", u));
        self.q(move |c| {
                match (&like, &uid) {
                    (Some(l), Some(u)) => {
                        let mut st = c.prepare(
                            "SELECT id,ts,scope,actor_id,actor_name,action,target,detail FROM audit WHERE scope=? AND (lineage LIKE ? OR actor_id=?) ORDER BY id DESC LIMIT ?",
                        )?;
                        let rows = st.query_map(params![scope, l, u, limit], map_audit)?;
                        rows.collect::<rusqlite::Result<Vec<_>>>()
                    }
                    _ => {
                        let mut st = c.prepare(
                            "SELECT id,ts,scope,actor_id,actor_name,action,target,detail FROM audit WHERE scope=? ORDER BY id DESC LIMIT ?",
                        )?;
                        let rows = st.query_map(params![scope, limit], map_audit)?;
                        rows.collect::<rusqlite::Result<Vec<_>>>()
                    }
                }
            })
            .await
            .map_err(dberr)
    }

    async fn setting_get(&self, k: &str) -> DbResult<Option<String>> {
        let k = k.to_string();
        self.q(move |c| {
            c.query_row("SELECT v FROM wfm_settings WHERE k=?", [&k], |r| r.get(0))
                .optional()
        })
        .await
        .map_err(dberr)
    }

    async fn setting_set(&self, k: &str, v: &str) -> DbResult<()> {
        let k = k.to_string();
        let v = v.to_string();
        self.q(move |c| {
            c.execute(
                "INSERT INTO wfm_settings(k,v) VALUES(?,?) ON CONFLICT(k) DO UPDATE SET v=excluded.v",
                [&k, &v],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::User;

    #[tokio::test]
    async fn create_owner_only_succeeds_once() {
        let db = connect(":memory:").await.unwrap();
        let u = |id: &str| User {
            id: id.into(),
            username: format!("u{id}"),
            display_name: "n".into(),
            role: Role::Owner,
            role_name: "owner".into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        assert!(db.create_owner(&u("a"), "h").await.unwrap());
        assert!(!db.create_owner(&u("b"), "h").await.unwrap());
        assert_eq!(db.owner_count().await.unwrap(), 1);
    }

    fn job(id: &str) -> RenderJob {
        RenderJob {
            id: id.into(),
            project_id: "p".into(),
            user_id: "u".into(),
            status: "queued".into(),
            mode: "server".into(),
            spec: "{}".into(),
            output_name: "out".into(),
            progress: 0.0,
            error: String::new(),
            worker: String::new(),
            attempts: 0,
            created_at: 1,
            finished_at: 0,
        }
    }

    #[tokio::test]
    async fn job_progress_and_finish_require_the_claiming_worker() {
        let db = connect(":memory:").await.unwrap();
        db.job_create(&job("j")).await.unwrap();
        assert!(db.job_claim("j", "w1", 200).await.unwrap());

        assert!(db.job_progress("j", "w1", 0.5, 300).await.unwrap());
        // A foreign or stale worker can neither report nor finish.
        assert!(!db.job_progress("j", "w2", 0.6, 300).await.unwrap());
        db.job_finish("j", "w2", "failed", "oops", 400).await.unwrap();
        let j = db.job_by_id("j").await.unwrap();
        assert_eq!(j.status, "running");
        assert_eq!(j.progress, 0.5);

        db.job_finish("j", "w1", "done", "", 400).await.unwrap();
        let j = db.job_by_id("j").await.unwrap();
        assert_eq!(j.status, "done");
        // Terminal jobs ignore late completions even from the claimant.
        db.job_finish("j", "w1", "failed", "oops", 500).await.unwrap();
        assert_eq!(db.job_by_id("j").await.unwrap().status, "done");
    }

    #[tokio::test]
    async fn cancel_of_queued_job_still_lands() {
        let db = connect(":memory:").await.unwrap();
        db.job_create(&job("j")).await.unwrap();
        db.job_finish("j", "", "canceled", "", 100).await.unwrap();
        assert_eq!(db.job_by_id("j").await.unwrap().status, "canceled");
        assert!(!db.job_claim("j", "w1", 200).await.unwrap());
    }

    fn node(name: &str) -> crate::model::RenderNode {
        crate::model::RenderNode {
            id: crate::model::new_id(),
            name: name.into(),
            disabled: false,
            created_at: 1,
            last_seen: 0,
        }
    }

    #[tokio::test]
    async fn node_names_are_unique_case_insensitive() {
        let db = connect(":memory:").await.unwrap();
        db.node_create(&node("Farm-1"), "h1").await.unwrap();
        let dup = db.node_create(&node("farm-1"), "h2").await;
        assert!(matches!(dup, Err(DbError::Conflict)));
        db.node_create(&node("farm-2"), "h3").await.unwrap();
        assert_eq!(db.node_list().await.unwrap().len(), 2);
    }

    #[tokio::test]
    async fn touch_project_throttles_updates() {
        let db = connect(":memory:").await.unwrap();
        db.create_project(&Project {
            id: "p".into(),
            owner_id: "u".into(),
            name: "p".into(),
            display_name: "p".into(),
            dir: "d".into(),
            group_id: String::new(),
            tags: vec![],
            created_at: 1,
            last_activity: 1,
            pinned: false,
        })
        .await
        .unwrap();
        db.touch_project("p", 100).await.unwrap();
        assert_eq!(db.project_by_id("p").await.unwrap().last_activity, 1);
        db.touch_project("p", 400).await.unwrap();
        assert_eq!(db.project_by_id("p").await.unwrap().last_activity, 400);
        db.set_project_pinned("p", true).await.unwrap();
        assert!(db.project_by_id("p").await.unwrap().pinned);
        db.set_project_pinned("p", false).await.unwrap();
        assert!(!db.project_by_id("p").await.unwrap().pinned);
    }

    #[tokio::test]
    async fn delete_user_drops_sessions() {
        let db = connect(":memory:").await.unwrap();
        let u = User {
            id: "u".into(),
            username: "u".into(),
            display_name: "n".into(),
            role: Role::Student,
            role_name: "student".into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        db.create_user(&u, "h").await.unwrap();
        db.create_session("t", "u", "c", 9, "", "").await.unwrap();
        assert!(db.session_user("t", 1).await.is_ok());
        db.delete_user("u").await.unwrap();
        assert!(db.user_by_id("u").await.is_err());
        assert!(db.session_user("t", 1).await.is_err());
    }
}
