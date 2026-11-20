use std::sync::Arc;

use async_trait::async_trait;
use rusqlite::{params, OptionalExtension};
use tokio_rusqlite::Connection;

use crate::model::*;
use crate::store::{
    migration_files, migration_sql, AuditFilter, Db, DbError, DbResult, LockOutcome,
};

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
        tokio_rusqlite::Error::Rusqlite(rusqlite::Error::QueryReturnedNoRows) => DbError::NotFound,
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
        avatar: r.get(8)?,
        created_by: r.get(9)?,
        lineage: r.get(10)?,
        created_at: r.get(11)?,
        last_login: r.get(12)?,
        quota_bytes: r.get(13)?,
    })
}

const USER_COLS: &str =
    "id,username,display_name,pass_hash,role,student_id,note,disabled,avatar,created_by,lineage,created_at,last_login,quota_bytes";

const PROJECT_COLS: &str = "id,owner_id,name,display_name,dir,group_id,tags,created_at,last_activity,pinned,template,status,submitted_at,reviewed_by";

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
        template: r.get::<_, i64>(10)? != 0,
        status: r.get(11)?,
        submitted_at: r.get(12)?,
        reviewed_by: r.get(13)?,
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

fn map_invite(r: &rusqlite::Row) -> rusqlite::Result<InviteCode> {
    Ok(InviteCode {
        id: r.get(0)?,
        code_hash: r.get(1)?,
        created_by: r.get(2)?,
        role: r.get(3)?,
        preset_username: r.get(4)?,
        preset_name: r.get(5)?,
        used_by: r.get(6)?,
        used_at: r.get(7)?,
        expires_at: r.get(8)?,
        revoked: r.get::<_, i64>(9)? != 0,
        created_at: r.get(10)?,
    })
}

fn map_share(r: &rusqlite::Row) -> rusqlite::Result<ProjectShare> {
    Ok(ProjectShare {
        id: r.get(0)?,
        project_id: r.get(1)?,
        inviter_id: r.get(2)?,
        invitee_id: r.get(3)?,
        level: r.get(4)?,
        status: r.get(5)?,
        created_at: r.get(6)?,
        responded_at: r.get(7)?,
    })
}

fn map_link(r: &rusqlite::Row) -> rusqlite::Result<ProjectLink> {
    Ok(ProjectLink {
        id: r.get(0)?,
        token_hash: r.get(1)?,
        project_id: r.get(2)?,
        scope: r.get(3)?,
        created_by: r.get(4)?,
        created_at: r.get(5)?,
        expires_at: r.get(6)?,
        revoked: r.get::<_, i64>(7)? != 0,
    })
}

fn map_notification(r: &rusqlite::Row) -> rusqlite::Result<Notification> {
    let payload: String = r.get(2)?;
    Ok(Notification {
        id: r.get(0)?,
        kind: r.get(1)?,
        payload: serde_json::from_str(&payload).unwrap_or(serde_json::Value::Null),
        read_at: r.get(3)?,
        created_at: r.get(4)?,
    })
}

fn map_share_view(r: &rusqlite::Row) -> rusqlite::Result<ShareView> {
    Ok(ShareView {
        id: r.get(0)?,
        project_id: r.get(1)?,
        inviter_id: r.get(2)?,
        invitee_id: r.get(3)?,
        level: r.get(4)?,
        status: r.get(5)?,
        created_at: r.get(6)?,
        responded_at: r.get(7)?,
        project_name: r.get(8)?,
        inviter_username: r.get(9)?,
        invitee_username: r.get(10)?,
        invitee_name: r.get(11)?,
        template: r.get::<_, i64>(12)? != 0,
    })
}

fn map_comment(r: &rusqlite::Row) -> rusqlite::Result<CommentView> {
    Ok(CommentView {
        id: r.get(0)?,
        project_id: r.get(1)?,
        user_id: r.get(2)?,
        username: r.get(3)?,
        display_name: r.get(4)?,
        avatar: r.get(8)?,
        body: r.get(5)?,
        created_at: r.get(6)?,
        edited_at: r.get(7)?,
    })
}

const SHARE_VIEW_COLS: &str = "s.id,s.project_id,s.inviter_id,s.invitee_id,s.level,s.status,s.created_at,s.responded_at,p.name,iv.username,ie.username,ie.display_name,p.template";
const SHARE_VIEW_JOINS: &str = "JOIN projects p ON p.id=s.project_id JOIN users iv ON iv.id=s.inviter_id JOIN users ie ON ie.id=s.invitee_id";

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
                &format!("INSERT INTO users({USER_COLS}) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)"),
                params![
                    u.id,
                    u.username,
                    u.display_name,
                    h,
                    u.role as i64,
                    u.student_id,
                    u.note,
                    u.disabled as i64,
                    u.avatar,
                    u.created_by,
                    u.lineage,
                    u.created_at,
                    u.last_login,
                    u.quota_bytes
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
                    &format!("INSERT INTO users({USER_COLS}) SELECT ?,?,?,?,?,?,?,?,?,?,?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM users WHERE role=?)"),
                    params![
                        u.id, u.username, u.display_name, h, u.role as i64, u.student_id,
                        u.note, u.disabled as i64, u.avatar, u.created_by, u.lineage, u.created_at,
                        u.last_login, u.quota_bytes, Role::Owner as i64
                    ],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn set_password(&self, id: &str, pass_hash: &str) -> DbResult<()> {
        let (id, h) = (id.to_string(), pass_hash.to_string());
        self.q(move |c| c.execute("UPDATE users SET pass_hash=? WHERE id=?", params![h, id]))
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn update_user(&self, u: &User) -> DbResult<()> {
        let u = u.clone();
        self.q(move |c| {
                c.execute(
                    "UPDATE users SET username=?, display_name=?, role=?, student_id=?, note=?, quota_bytes=? WHERE id=?",
                    params![
                        u.username,
                        u.display_name,
                        u.role as i64,
                        u.student_id,
                        u.note,
                        u.quota_bytes,
                        u.id
                    ],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn set_user_avatar(&self, id: &str, key: &str) -> DbResult<()> {
        let (id, key) = (id.to_string(), key.to_string());
        self.q(move |c| {
            c.execute("UPDATE users SET avatar=? WHERE id=?", params![key, id])
                .map(|_| ())
        })
        .await
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
        self.q(move |c| c.execute("UPDATE users SET last_login=? WHERE id=?", params![ts, id]))
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

    async fn visible_users(&self, actor: &User) -> DbResult<Vec<User>> {
        // Classmates only exist for students: a sentinel parent matches nothing for
        // anyone else (created_by is never empty on a real account except the seed owner).
        let (role, sub, lin, sib, sid) = (
            actor.role as i64,
            format!("%/{}/%", actor.id),
            format!("/{}/", actor.lineage.trim_matches('/')),
            if actor.role == crate::model::Role::Student { actor.created_by.clone() } else { String::new() },
            actor.id.clone(),
        );
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT {USER_COLS} FROM users WHERE id<>? AND ((role<? AND lineage LIKE ?) OR ? LIKE '%/'||id||'/%' OR (role=? AND created_by=? AND created_by<>'')) ORDER BY created_at"
                ))?;
                let rows = st.query_map(params![sid, role, sub, lin, Role::Student as i64, sib], map_user)?;
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
                Some((uid, csrf, exp)) if exp > now => {
                    c.execute(
                        "UPDATE sessions SET last_seen=? WHERE token_hash=?",
                        params![now, th],
                    )?;
                    Ok(Some((uid, csrf)))
                }
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

    async fn list_sessions(&self, user_id: &str) -> DbResult<Vec<SessionInfo>> {
        let uid = user_id.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT token_hash,ip,ua,created_at,expires_at,last_seen FROM sessions WHERE user_id=? ORDER BY created_at DESC",
                )?;
                let rows = st
                    .query_map([&uid], |r| {
                        Ok(SessionInfo {
                            id: r.get(0)?,
                            ip: r.get(1)?,
                            ua: r.get(2)?,
                            created_at: r.get(3)?,
                            expires_at: r.get(4)?,
                            last_seen: r.get(5)?,
                        })
                    })?
                    .collect::<rusqlite::Result<Vec<_>>>()?;
                Ok(rows)
            })
            .await
            .map_err(dberr)
    }

    async fn delete_user_session(&self, user_id: &str, token_hash: &str) -> DbResult<()> {
        let (uid, th) = (user_id.to_string(), token_hash.to_string());
        self.q(move |c| {
            c.execute(
                "DELETE FROM sessions WHERE user_id=? AND token_hash=?",
                params![uid, th],
            )
        })
        .await
        .map_err(dberr)?;
        Ok(())
    }

    async fn delete_user_sessions_except(&self, user_id: &str, token_hash: &str) -> DbResult<()> {
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
                    "INSERT INTO projects(id,owner_id,name,display_name,dir,group_id,tags,created_at,last_activity,pinned,template,status,submitted_at,reviewed_by) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                    params![p.id, p.owner_id, p.name, p.display_name, p.dir, p.group_id, tags_csv(&p.tags), p.created_at, p.last_activity, p.pinned, p.template, p.status, p.submitted_at, p.reviewed_by],
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
            let mut st = c.prepare(&format!(
                "SELECT {PROJECT_COLS} FROM projects WHERE owner_id=? ORDER BY created_at DESC"
            ))?;
            let rows = st.query_map([oid], map_project)?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .await
        .map_err(dberr)
    }

    async fn managed_projects(&self, actor: &User) -> DbResult<Vec<Project>> {
        let (role, pat) = (actor.role as i64, format!("%/{}/%", actor.id));
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT p.id,p.owner_id,p.name,p.display_name,p.dir,p.group_id,p.tags,p.created_at,p.last_activity,p.pinned,p.template,p.status,p.submitted_at,p.reviewed_by FROM projects p JOIN users u ON p.owner_id=u.id WHERE u.role < ? AND u.lineage LIKE ? ORDER BY p.created_at DESC"
                ))?;
                let rows = st.query_map(params![role, pat], map_project)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn user_in_subtree(&self, actor: &User, user_id: &str) -> DbResult<bool> {
        let (role, pat, uid) = (
            actor.role as i64,
            format!("%/{}/%", actor.id),
            user_id.to_string(),
        );
        self.q(move |c| {
            c.query_row(
                "SELECT 1 FROM users WHERE id=? AND role < ? AND lineage LIKE ?",
                params![uid, role, pat],
                |_| Ok(()),
            )
            .map(|_| true)
            .or_else(|e| match e {
                rusqlite::Error::QueryReturnedNoRows => Ok(false),
                e => Err(e),
            })
        })
        .await
        .map_err(dberr)
    }

    async fn set_project_owner(&self, id: &str, owner_id: &str) -> DbResult<()> {
        let (id, oid) = (id.to_string(), owner_id.to_string());
        self.q(move |c| {
            c.execute(
                "UPDATE projects SET owner_id=? WHERE id=?",
                params![oid, id],
            )?;
            Ok(())
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

    async fn set_project_template(&self, id: &str, template: bool) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE projects SET template=? WHERE id=?",
                params![template as i64, id],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn set_project_status(
        &self,
        id: &str,
        status: &str,
        submitted_at: i64,
        reviewed_by: &str,
    ) -> DbResult<()> {
        let id = id.to_string();
        let status = status.to_string();
        let reviewed_by = reviewed_by.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE projects SET status=?,submitted_at=?,reviewed_by=? WHERE id=?",
                params![status, submitted_at, reviewed_by, id],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn comment_add(
        &self,
        id: &str,
        project: &str,
        user: &str,
        body: &str,
        ts: i64,
    ) -> DbResult<()> {
        let (id, project, user, body) = (
            id.to_string(),
            project.to_string(),
            user.to_string(),
            body.to_string(),
        );
        self.q(move |c| {
            c.execute(
                "INSERT INTO project_comments(id,project_id,user_id,body,created_at) VALUES(?,?,?,?,?)",
                params![id, project, user, body, ts],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn comments_for(&self, project: &str) -> DbResult<Vec<CommentView>> {
        let project = project.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT c.id,c.project_id,c.user_id,u.username,u.display_name,c.body,c.created_at,c.edited_at,u.avatar FROM project_comments c JOIN users u ON u.id=c.user_id WHERE c.project_id=? ORDER BY c.created_at"
                )?;
                let rows = st.query_map(params![project], map_comment)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn comment_by_id(&self, id: &str) -> DbResult<CommentView> {
        let id = id.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT c.id,c.project_id,c.user_id,u.username,u.display_name,c.body,c.created_at,c.edited_at,u.avatar FROM project_comments c JOIN users u ON u.id=c.user_id WHERE c.id=?",
                    params![id],
                    map_comment,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn comment_edit(&self, id: &str, body: &str, ts: i64) -> DbResult<bool> {
        let (id, body) = (id.to_string(), body.to_string());
        self.q(move |c| {
            c.execute(
                "UPDATE project_comments SET body=?,edited_at=? WHERE id=?",
                params![body, ts, id],
            )
        })
        .await
        .map(|n| n > 0)
        .map_err(dberr)
    }

    async fn comment_delete(&self, id: &str) -> DbResult<bool> {
        let id = id.to_string();
        self.q(move |c| c.execute("DELETE FROM project_comments WHERE id=?", params![id]))
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn comments_delete_project(&self, project: &str) -> DbResult<()> {
        let project = project.to_string();
        self.q(move |c| {
            c.execute(
                "DELETE FROM project_comments WHERE project_id=?",
                params![project],
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
        let (p, k, h) = (project_id.to_string(), kind.to_string(), holder.to_string());
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
        let (p, k, h) = (project_id.to_string(), kind.to_string(), holder.to_string());
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
                     SELECT ?,?,?,?,?,?,?,0,'','',0,0,?,0
                     WHERE NOT EXISTS(
                       SELECT 1 FROM render_jobs
                       WHERE project_id=? AND status IN('queued','running'))",
                    params![
                        j.id, j.project_id, j.user_id, j.status, j.mode, j.spec,
                        j.output_name, j.created_at, j.project_id
                    ],
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

    async fn jobs_by_project(
        &self,
        project_id: &str,
        offset: i64,
        limit: i64,
    ) -> DbResult<Vec<RenderJob>> {
        let pid = project_id.to_string();
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT {JOB_COLS} FROM render_jobs WHERE project_id=? ORDER BY created_at DESC LIMIT ? OFFSET ?"
                ))?;
                let rows = st.query_map(params![pid, limit, offset], map_job)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn job_delete(&self, id: &str) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| c.execute("DELETE FROM render_jobs WHERE id=?", [id]))
            .await
            .map(|_| ())
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
                "UPDATE render_nodes SET last_seen=?, offline_notified=0 WHERE id=?",
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
        .and_then(|rows| {
            if rows == 0 {
                Err(DbError::NotFound)
            } else {
                Ok(())
            }
        })
    }

    async fn node_delete(&self, id: &str) -> DbResult<()> {
        let id = id.to_string();
        self.q(move |c| c.execute("DELETE FROM render_nodes WHERE id=?", [id]))
            .await
            .map_err(dberr)
            .and_then(|rows| {
                if rows == 0 {
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
        f: &AuditFilter,
    ) -> DbResult<Vec<AuditEntry>> {
        let scope = scope.to_string();
        let uid = subtree_user_id.map(|u| u.to_string());
        let f = AuditFilter {
            action: f.action.clone(),
            actor: f.actor.clone(),
            from: f.from,
            to: f.to,
            limit: f.limit,
            offset: f.offset,
        };
        self.q(move |c| {
                let mut sql =
                    "SELECT id,ts,scope,actor_id,actor_name,action,target,detail FROM audit WHERE scope=?"
                        .to_string();
                let mut v: Vec<rusqlite::types::Value> = vec![scope.into()];
                if let Some(u) = &uid {
                    sql.push_str(" AND (lineage LIKE ? OR actor_id=?)");
                    v.push(format!("%/{u}/%").into());
                    v.push(u.clone().into());
                }
                if !f.action.is_empty() {
                    sql.push_str(" AND action=?");
                    v.push(f.action.clone().into());
                }
                if !f.actor.is_empty() {
                    sql.push_str(" AND actor_name LIKE ?");
                    v.push(format!("%{}%", f.actor).into());
                }
                if f.from > 0 {
                    sql.push_str(" AND ts>=?");
                    v.push(f.from.into());
                }
                if f.to > 0 {
                    sql.push_str(" AND ts<=?");
                    v.push(f.to.into());
                }
                sql.push_str(" ORDER BY id DESC LIMIT ? OFFSET ?");
                v.push(f.limit.into());
                v.push(f.offset.into());
                let mut st = c.prepare(&sql)?;
                let rows = st.query_map(rusqlite::params_from_iter(v), map_audit)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn audit_purge(&self, before: i64) -> DbResult<()> {
        self.q(move |c| {
            c.execute("DELETE FROM audit WHERE ts<?", params![before])
                .map(|_| ())
        })
        .await
        .map_err(dberr)
    }

    async fn invite_create(&self, i: &InviteCode) -> DbResult<()> {
        let v: Vec<String> = [
            &i.id,
            &i.code_hash,
            &i.created_by,
            &i.role,
            &i.preset_username,
            &i.preset_name,
            &i.used_by,
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        let (used_at, expires_at, revoked, created_at) =
            (i.used_at, i.expires_at, i.revoked, i.created_at);
        self.q(move |c| {
                c.execute(
                    "INSERT INTO invite_codes(id,code_hash,created_by,role,preset_username,preset_name,used_by,used_at,expires_at,revoked,created_at) VALUES(?,?,?,?,?,?,?,?,?,?,?)",
                    params![v[0], v[1], v[2], v[3], v[4], v[5], v[6], used_at, expires_at, revoked as i64, created_at],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn invite_by_hash(&self, hash: &str) -> DbResult<InviteCode> {
        let hash = hash.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT id,code_hash,created_by,role,preset_username,preset_name,used_by,used_at,expires_at,revoked,created_at FROM invite_codes WHERE code_hash=?",
                    params![hash],
                    map_invite,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn invites_by_creator(&self, uid: &str) -> DbResult<Vec<InviteCode>> {
        let uid = uid.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT id,code_hash,created_by,role,preset_username,preset_name,used_by,used_at,expires_at,revoked,created_at FROM invite_codes WHERE created_by=? ORDER BY created_at DESC",
                )?;
                let rows = st.query_map(params![uid], map_invite)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn invite_use(&self, hash: &str, uid: &str, ts: i64) -> DbResult<bool> {
        let hash = hash.to_string();
        let uid = uid.to_string();
        self.q(move |c| {
                c.execute(
                    "UPDATE invite_codes SET used_by=?, used_at=? WHERE code_hash=? AND used_by='' AND revoked=0 AND expires_at>?",
                    params![uid, ts, hash, ts],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn invite_unuse(&self, hash: &str) -> DbResult<()> {
        let hash = hash.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE invite_codes SET used_by='', used_at=0 WHERE code_hash=?",
                params![hash],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn invite_revoke(&self, id: &str, creator: &str) -> DbResult<bool> {
        let id = id.to_string();
        let creator = creator.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE invite_codes SET revoked=1 WHERE id=? AND created_by=? AND used_by=''",
                params![id, creator],
            )
        })
        .await
        .map(|n| n > 0)
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

    async fn share_by(&self, project: &str, invitee: &str) -> DbResult<ProjectShare> {
        let project = project.to_string();
        let invitee = invitee.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT id,project_id,inviter_id,invitee_id,level,status,created_at,responded_at FROM project_shares WHERE project_id=? AND invitee_id=?",
                    params![project, invitee],
                    map_share,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn share_upsert(&self, sh: &ProjectShare) -> DbResult<()> {
        let v: Vec<String> = [
            &sh.id,
            &sh.project_id,
            &sh.inviter_id,
            &sh.invitee_id,
            &sh.level,
            &sh.status,
        ]
        .iter()
        .map(|s| s.to_string())
        .collect();
        let (created_at, responded_at) = (sh.created_at, sh.responded_at);
        self.q(move |c| {
                c.execute(
                    "INSERT INTO project_shares(id,project_id,inviter_id,invitee_id,level,status,created_at,responded_at) VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(project_id,invitee_id) DO UPDATE SET inviter_id=excluded.inviter_id,level=excluded.level,status=excluded.status,created_at=excluded.created_at,responded_at=excluded.responded_at",
                    params![v[0], v[1], v[2], v[3], v[4], v[5], created_at, responded_at],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn shares_by_project(&self, project: &str) -> DbResult<Vec<ShareView>> {
        let project = project.to_string();
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT {SHARE_VIEW_COLS} FROM project_shares s {SHARE_VIEW_JOINS} WHERE s.project_id=? ORDER BY s.created_at DESC"
                ))?;
                let rows = st.query_map(params![project], map_share_view)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn shares_for_user(&self, invitee: &str) -> DbResult<Vec<ShareView>> {
        let invitee = invitee.to_string();
        self.q(move |c| {
                let mut st = c.prepare(&format!(
                    "SELECT {SHARE_VIEW_COLS} FROM project_shares s {SHARE_VIEW_JOINS} WHERE s.invitee_id=? AND s.status!='declined' ORDER BY s.created_at DESC"
                ))?;
                let rows = st.query_map(params![invitee], map_share_view)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn share_respond(
        &self,
        id: &str,
        invitee: &str,
        status: &str,
        ts: i64,
    ) -> DbResult<bool> {
        let id = id.to_string();
        let invitee = invitee.to_string();
        let status = status.to_string();
        self.q(move |c| {
                c.execute(
                    "UPDATE project_shares SET status=?, responded_at=? WHERE id=? AND invitee_id=? AND status='pending'",
                    params![status, ts, id, invitee],
                )
            })
            .await
            .map(|n| n > 0)
            .map_err(dberr)
    }

    async fn share_set_level(&self, id: &str, project: &str, level: &str) -> DbResult<bool> {
        let id = id.to_string();
        let project = project.to_string();
        let level = level.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE project_shares SET level=? WHERE id=? AND project_id=?",
                params![level, id, project],
            )
        })
        .await
        .map(|n| n > 0)
        .map_err(dberr)
    }

    async fn share_delete(&self, id: &str, project: &str) -> DbResult<bool> {
        let id = id.to_string();
        let project = project.to_string();
        self.q(move |c| {
            c.execute(
                "DELETE FROM project_shares WHERE id=? AND project_id=?",
                params![id, project],
            )
        })
        .await
        .map(|n| n > 0)
        .map_err(dberr)
    }

    async fn shares_delete_project(&self, project: &str) -> DbResult<()> {
        let project = project.to_string();
        self.q(move |c| {
            c.execute(
                "DELETE FROM project_shares WHERE project_id=?",
                params![project],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn auto_shares_list(&self, owner: &str) -> DbResult<Vec<AutoShareView>> {
        let owner = owner.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT a.id,a.invitee_id,u.username,u.display_name,a.level,a.created_at FROM auto_shares a JOIN users u ON u.id=a.invitee_id WHERE a.owner_id=? ORDER BY a.created_at DESC"
                )?;
                let rows = st.query_map(params![owner], |r| {
                    Ok(AutoShareView {
                        id: r.get(0)?,
                        invitee_id: r.get(1)?,
                        invitee_username: r.get(2)?,
                        invitee_name: r.get(3)?,
                        level: r.get(4)?,
                        created_at: r.get(5)?,
                    })
                })?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn auto_share_upsert(&self, owner: &str, invitee: &str, level: &str) -> DbResult<()> {
        let owner = owner.to_string();
        let invitee = invitee.to_string();
        let level = level.to_string();
        self.q(move |c| {
                c.execute(
                    "INSERT INTO auto_shares(id,owner_id,invitee_id,level,created_at) VALUES(?,?,?,?,?) ON CONFLICT(owner_id,invitee_id) DO UPDATE SET level=excluded.level",
                    params![crate::model::new_id(), owner, invitee, level, crate::auth::AppState::now()],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn auto_share_delete(&self, owner: &str, id: &str) -> DbResult<bool> {
        let owner = owner.to_string();
        let id = id.to_string();
        self.q(move |c| {
            c.execute(
                "DELETE FROM auto_shares WHERE id=? AND owner_id=?",
                params![id, owner],
            )
        })
        .await
        .map(|n| n > 0)
        .map_err(dberr)
    }

    async fn auto_shares_all(&self) -> DbResult<Vec<AutoShare>> {
        self.q(move |c| {
            let mut st =
                c.prepare("SELECT id,owner_id,invitee_id,level,created_at FROM auto_shares")?;
            let rows = st.query_map([], |r| {
                Ok(AutoShare {
                    id: r.get(0)?,
                    owner_id: r.get(1)?,
                    invitee_id: r.get(2)?,
                    level: r.get(3)?,
                    created_at: r.get(4)?,
                })
            })?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .await
        .map_err(dberr)
    }

    async fn share_by_id(&self, id: &str) -> DbResult<ProjectShare> {
        let id = id.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT id,project_id,inviter_id,invitee_id,level,status,created_at,responded_at FROM project_shares WHERE id=?",
                    params![id],
                    map_share,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn notify(&self, user: &str, kind: &str, payload: &str, ts: i64) -> DbResult<()> {
        let (id, user, kind, payload) = (
            crate::model::new_id(),
            user.to_string(),
            kind.to_string(),
            payload.to_string(),
        );
        self.q(move |c| {
                c.execute(
                    "INSERT INTO notifications(id,user_id,kind,payload,read_at,created_at) VALUES(?,?,?,?,0,?)",
                    params![id, user, kind, payload, ts],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn notifications_for(
        &self,
        user: &str,
        before: i64,
        limit: i64,
    ) -> DbResult<Vec<Notification>> {
        let (user, before) = (
            user.to_string(),
            if before <= 0 { i64::MAX } else { before },
        );
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT id,kind,payload,read_at,created_at FROM notifications WHERE user_id=? AND created_at<? ORDER BY created_at DESC, id DESC LIMIT ?"
                )?;
                let rows = st.query_map(params![user, before, limit], map_notification)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn notifications_unread(&self, user: &str) -> DbResult<i64> {
        let user = user.to_string();
        self.q(move |c| {
            c.query_row(
                "SELECT COUNT(*) FROM notifications WHERE user_id=? AND read_at=0",
                params![user],
                |r| r.get(0),
            )
        })
        .await
        .map_err(dberr)
    }

    async fn notification_read(&self, user: &str, id: &str, ts: i64) -> DbResult<bool> {
        let (user, id) = (user.to_string(), id.to_string());
        self.q(move |c| {
            c.execute(
                "UPDATE notifications SET read_at=? WHERE id=? AND user_id=? AND read_at=0",
                params![ts, id, user],
            )
        })
        .await
        .map(|n| n > 0)
        .map_err(dberr)
    }

    async fn notifications_read_all(&self, user: &str, ts: i64) -> DbResult<()> {
        let user = user.to_string();
        self.q(move |c| {
            c.execute(
                "UPDATE notifications SET read_at=? WHERE user_id=? AND read_at=0",
                params![ts, user],
            )
        })
        .await
        .map(|_| ())
        .map_err(dberr)
    }

    async fn staff_ids(&self) -> DbResult<Vec<String>> {
        self.q(move |c| {
            let mut st = c.prepare("SELECT id FROM users WHERE role>=3 AND disabled=0")?;
            let rows = st.query_map([], |r| r.get(0))?;
            rows.collect::<rusqlite::Result<Vec<_>>>()
        })
        .await
        .map_err(dberr)
    }

    async fn nodes_newly_offline(&self, stale_before: i64) -> DbResult<Vec<RenderNode>> {
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT id,name,disabled,created_at,last_seen FROM render_nodes WHERE disabled=0 AND last_seen>0 AND last_seen<? AND offline_notified=0"
                )?;
                let nodes = st
                    .query_map(params![stale_before], map_node)?
                    .collect::<rusqlite::Result<Vec<_>>>()?;
                for n in &nodes {
                    c.execute(
                        "UPDATE render_nodes SET offline_notified=1 WHERE id=?",
                        params![n.id],
                    )?;
                }
                Ok(nodes)
            })
            .await
            .map_err(dberr)
    }

    async fn link_create(&self, l: &ProjectLink) -> DbResult<()> {
        let v: Vec<String> = [&l.id, &l.token_hash, &l.project_id, &l.scope, &l.created_by]
            .iter()
            .map(|s| s.to_string())
            .collect();
        let (created_at, expires_at, revoked) = (l.created_at, l.expires_at, l.revoked as i64);
        self.q(move |c| {
                c.execute(
                    "INSERT INTO project_links(id,token_hash,project_id,scope,created_by,created_at,expires_at,revoked) VALUES(?,?,?,?,?,?,?,?)",
                    params![v[0], v[1], v[2], v[3], v[4], created_at, expires_at, revoked],
                )
            })
            .await
            .map(|_| ())
            .map_err(dberr)
    }

    async fn link_by_hash(&self, hash: &str) -> DbResult<ProjectLink> {
        let hash = hash.to_string();
        self.q(move |c| {
                c.query_row(
                    "SELECT id,token_hash,project_id,scope,created_by,created_at,expires_at,revoked FROM project_links WHERE token_hash=?",
                    params![hash],
                    map_link,
                )
            })
            .await
            .map_err(dberr)
    }

    async fn links_by_project(&self, project: &str) -> DbResult<Vec<ProjectLink>> {
        let project = project.to_string();
        self.q(move |c| {
                let mut st = c.prepare(
                    "SELECT id,token_hash,project_id,scope,created_by,created_at,expires_at,revoked FROM project_links WHERE project_id=? ORDER BY created_at DESC"
                )?;
                let rows = st.query_map(params![project], map_link)?;
                rows.collect::<rusqlite::Result<Vec<_>>>()
            })
            .await
            .map_err(dberr)
    }

    async fn link_revoke(&self, id: &str, project: &str) -> DbResult<bool> {
        let (id, project) = (id.to_string(), project.to_string());
        self.q(move |c| {
            c.execute(
                "UPDATE project_links SET revoked=1 WHERE id=? AND project_id=? AND revoked=0",
                params![id, project],
            )
        })
        .await
        .map(|n| n > 0)
        .map_err(dberr)
    }

    async fn links_delete_project(&self, project: &str) -> DbResult<()> {
        let project = project.to_string();
        self.q(move |c| {
            c.execute(
                "DELETE FROM project_links WHERE project_id=?",
                params![project],
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
            avatar: String::new(),
            quota_bytes: 0,
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
        db.job_finish("j", "w2", "failed", "oops", 400)
            .await
            .unwrap();
        let j = db.job_by_id("j").await.unwrap();
        assert_eq!(j.status, "running");
        assert_eq!(j.progress, 0.5);

        db.job_finish("j", "w1", "done", "", 400).await.unwrap();
        let j = db.job_by_id("j").await.unwrap();
        assert_eq!(j.status, "done");
        // Terminal jobs ignore late completions even from the claimant.
        db.job_finish("j", "w1", "failed", "oops", 500)
            .await
            .unwrap();
        assert_eq!(db.job_by_id("j").await.unwrap().status, "done");
    }

    #[tokio::test]
    async fn jobs_by_project_paginates_and_delete_removes() {
        let db = connect(":memory:").await.unwrap();
        for i in 0..3 {
            let mut j = job(&format!("j{i}"));
            j.status = "done".into();
            j.created_at = i;
            db.job_create(&j).await.unwrap();
        }
        let ids = |v: Vec<RenderJob>| v.iter().map(|j| j.id.clone()).collect::<Vec<_>>();
        assert_eq!(
            ids(db.jobs_by_project("p", 0, 2).await.unwrap()),
            ["j2", "j1"]
        );
        assert_eq!(ids(db.jobs_by_project("p", 2, 2).await.unwrap()), ["j0"]);
        db.job_delete("j0").await.unwrap();
        assert!(db.job_by_id("j0").await.is_err());
        assert_eq!(db.jobs_by_project("p", 0, 50).await.unwrap().len(), 2);
    }

    #[tokio::test]
    async fn only_one_active_render_per_project() {
        let db = connect(":memory:").await.unwrap();
        db.job_create(&job("j1")).await.unwrap();
        assert!(matches!(
            db.job_create(&job("j2")).await,
            Err(DbError::Conflict)
        ));
        let mut running = job("j3");
        running.status = "running".into();
        assert!(matches!(
            db.job_create(&running).await,
            Err(DbError::Conflict)
        ));
        db.job_finish("j1", "", "done", "", 100).await.unwrap();
        db.job_create(&job("j2")).await.unwrap();
        let mut other = job("j4");
        other.project_id = "p2".into();
        db.job_create(&other).await.unwrap();
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
            template: false,
            status: "draft".into(),
            submitted_at: 0,
            reviewed_by: String::new(),
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
    async fn managed_projects_and_take_over() {
        let db = connect(":memory:").await.unwrap();
        let u = |id: &str, role: Role, lineage: &str| User {
            id: id.into(),
            username: format!("u{id}"),
            display_name: String::new(),
            role,
            role_name: role.as_str().into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: lineage.into(),
            created_at: 1,
            last_login: 0,
        };
        let teacher = u("t", Role::Teacher, "/o/");
        let student = u("s", Role::Student, "/o/t/");
        let other = u("x", Role::Student, "/o/");
        db.create_user(&teacher, "h").await.unwrap();
        db.create_user(&student, "h").await.unwrap();
        db.create_user(&other, "h").await.unwrap();
        let p = |id: &str, owner: &str| Project {
            id: id.into(),
            owner_id: owner.into(),
            name: id.into(),
            display_name: id.into(),
            dir: "d".into(),
            group_id: String::new(),
            tags: vec![],
            created_at: 1,
            last_activity: 1,
            pinned: false,
            template: false,
            status: "draft".into(),
            submitted_at: 0,
            reviewed_by: String::new(),
        };
        db.create_project(&p("sp", "s")).await.unwrap();
        db.create_project(&p("xp", "x")).await.unwrap();
        db.create_project(&p("tp", "t")).await.unwrap();
        let managed = db.managed_projects(&teacher).await.unwrap();
        assert_eq!(managed.len(), 1);
        assert_eq!(managed[0].id, "sp");
        assert!(db.user_in_subtree(&teacher, "s").await.unwrap());
        assert!(!db.user_in_subtree(&teacher, "x").await.unwrap());
        assert!(!db.user_in_subtree(&student, "x").await.unwrap());
        db.set_project_owner("sp", "t").await.unwrap();
        assert_eq!(db.project_by_id("sp").await.unwrap().owner_id, "t");
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
            avatar: String::new(),
            quota_bytes: 0,
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

    #[tokio::test]
    async fn set_user_avatar_round_trips() {
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
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        db.create_user(&u, "h").await.unwrap();
        assert!(db.user_by_id("u").await.unwrap().avatar.is_empty());
        db.set_user_avatar("u", "avatars/u/x.png").await.unwrap();
        assert_eq!(db.user_by_id("u").await.unwrap().avatar, "avatars/u/x.png");
    }

    #[tokio::test]
    async fn list_and_delete_own_sessions() {
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
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        db.create_user(&u, "h").await.unwrap();
        db.create_session("t1", "u", "c", 9, "1.2.3.4", "ua")
            .await
            .unwrap();
        db.create_session("t2", "u", "c", 9, "", "").await.unwrap();
        let rows = db.list_sessions("u").await.unwrap();
        assert_eq!(rows.len(), 2);
        assert_eq!(rows[0].ip, "1.2.3.4");
        db.session_user("t1", 1).await.unwrap();
        assert_eq!(db.list_sessions("u").await.unwrap()[0].last_seen, 1);
        db.delete_user_session("u", "t1").await.unwrap();
        let rows = db.list_sessions("u").await.unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].id, "t2");
    }

    #[tokio::test]
    async fn invite_lifecycle() {
        let db = connect(":memory:").await.unwrap();
        let inv = InviteCode {
            id: "i1".into(),
            code_hash: "h1".into(),
            created_by: "t1".into(),
            role: "student".into(),
            preset_username: "".into(),
            preset_name: "".into(),
            used_by: "".into(),
            used_at: 0,
            expires_at: 1000,
            revoked: false,
            created_at: 1,
        };
        db.invite_create(&inv).await.unwrap();
        assert_eq!(db.invite_by_hash("h1").await.unwrap().id, "i1");
        assert_eq!(db.invites_by_creator("t1").await.unwrap().len(), 1);
        assert!(!db.invite_use("h1", "u1", 2000).await.unwrap());
        assert!(db.invite_use("h1", "u1", 500).await.unwrap());
        assert!(!db.invite_use("h1", "u2", 600).await.unwrap());
        assert!(!db.invite_revoke("i1", "t1").await.unwrap());
        db.invite_unuse("h1").await.unwrap();
        assert!(db.invite_by_hash("h1").await.unwrap().used_by.is_empty());
        assert!(!db.invite_revoke("i1", "other").await.unwrap());
        assert!(db.invite_revoke("i1", "t1").await.unwrap());
        assert!(!db.invite_use("h1", "u1", 500).await.unwrap());
    }

    #[tokio::test]
    async fn share_lifecycle() {
        let db = connect(":memory:").await.unwrap();
        let u = |id: &str, role: Role| User {
            id: id.into(),
            username: format!("u{id}"),
            display_name: "n".into(),
            role,
            role_name: String::new(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        db.create_user(&u("o1", Role::Teacher), "h").await.unwrap();
        db.create_user(&u("v1", Role::Student), "h").await.unwrap();
        db.create_project(&Project {
            id: "p1".into(),
            owner_id: "o1".into(),
            name: "p1".into(),
            display_name: "P1".into(),
            dir: "d".into(),
            group_id: String::new(),
            tags: vec![],
            created_at: 1,
            last_activity: 1,
            pinned: false,
            template: false,
            status: "draft".into(),
            submitted_at: 0,
            reviewed_by: String::new(),
        })
        .await
        .unwrap();
        let sh = ProjectShare {
            id: "s1".into(),
            project_id: "p1".into(),
            inviter_id: "o1".into(),
            invitee_id: "v1".into(),
            level: "view".into(),
            status: "pending".into(),
            created_at: 1,
            responded_at: 0,
        };
        db.share_upsert(&sh).await.unwrap();
        assert_eq!(db.share_by("p1", "v1").await.unwrap().status, "pending");
        assert_eq!(db.shares_by_project("p1").await.unwrap().len(), 1);
        assert_eq!(db.shares_for_user("v1").await.unwrap().len(), 1);
        assert!(!db
            .share_respond("s1", "other", "accepted", 2)
            .await
            .unwrap());
        assert!(db.share_respond("s1", "v1", "accepted", 2).await.unwrap());
        assert!(!db.share_respond("s1", "v1", "declined", 3).await.unwrap());
        assert_eq!(db.share_by("p1", "v1").await.unwrap().status, "accepted");
        assert!(db.share_set_level("s1", "p1", "edit").await.unwrap());
        assert_eq!(db.share_by("p1", "v1").await.unwrap().level, "edit");
        db.share_upsert(&ProjectShare {
            status: "pending".into(),
            responded_at: 0,
            ..sh.clone()
        })
        .await
        .unwrap();
        assert_eq!(db.share_by("p1", "v1").await.unwrap().status, "pending");
        db.set_project_template("p1", true).await.unwrap();
        assert!(db.project_by_id("p1").await.unwrap().template);
        assert!(db.shares_for_user("v1").await.unwrap()[0].template);
        db.set_project_template("p1", false).await.unwrap();
        assert!(!db.project_by_id("p1").await.unwrap().template);
        assert!(db.share_delete("s1", "p1").await.unwrap());
        assert!(!db.share_delete("s1", "p1").await.unwrap());
        db.share_upsert(&sh).await.unwrap();
        db.shares_delete_project("p1").await.unwrap();
        assert!(db.shares_by_project("p1").await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn comments_and_status() {
        let db = connect(":memory:").await.unwrap();
        db.create_user(
            &User {
                id: "u1".into(),
                username: "ada".into(),
                display_name: "Ada".into(),
                role: Role::Student,
                role_name: String::new(),
                student_id: String::new(),
                note: String::new(),
                disabled: false,
                avatar: String::new(),
                quota_bytes: 0,
                created_by: String::new(),
                lineage: "/".into(),
                created_at: 1,
                last_login: 0,
            },
            "h",
        )
        .await
        .unwrap();
        db.create_project(&Project {
            id: "p1".into(),
            owner_id: "u1".into(),
            name: "p1".into(),
            display_name: "P1".into(),
            dir: "d".into(),
            group_id: String::new(),
            tags: vec![],
            created_at: 1,
            last_activity: 1,
            pinned: false,
            template: false,
            status: "draft".into(),
            submitted_at: 0,
            reviewed_by: String::new(),
        })
        .await
        .unwrap();
        db.comment_add("c1", "p1", "u1", "hi", 10).await.unwrap();
        db.comment_add("c2", "p1", "u1", "again", 20).await.unwrap();
        let list = db.comments_for("p1").await.unwrap();
        assert_eq!(list.len(), 2);
        assert_eq!(list[0].username, "ada");
        assert_eq!(list[0].body, "hi");
        assert!(db.comment_edit("c1", "edited", 30).await.unwrap());
        let c = db.comment_by_id("c1").await.unwrap();
        assert_eq!(c.body, "edited");
        assert_eq!(c.edited_at, 30);
        assert!(!db.comment_edit("nope", "x", 1).await.unwrap());
        assert!(db.comment_delete("c1").await.unwrap());
        assert!(!db.comment_delete("c1").await.unwrap());
        db.set_project_status("p1", "submitted", 40, "")
            .await
            .unwrap();
        let p = db.project_by_id("p1").await.unwrap();
        assert_eq!(p.status, "submitted");
        assert_eq!(p.submitted_at, 40);
        db.set_project_status("p1", "reviewed", 40, "t1")
            .await
            .unwrap();
        assert_eq!(db.project_by_id("p1").await.unwrap().reviewed_by, "t1");
        db.comments_delete_project("p1").await.unwrap();
        assert!(db.comments_for("p1").await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn auto_share_lifecycle() {
        let db = connect(":memory:").await.unwrap();
        let u = |id: &str| User {
            id: id.into(),
            username: format!("u{id}"),
            display_name: format!("N{id}"),
            role: Role::Student,
            role_name: String::new(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        db.create_user(&u("t1"), "h").await.unwrap();
        db.create_user(&u("a1"), "h").await.unwrap();
        db.create_user(&u("a2"), "h").await.unwrap();
        db.auto_share_upsert("t1", "a1", "edit").await.unwrap();
        db.auto_share_upsert("t1", "a2", "view").await.unwrap();
        db.auto_share_upsert("t2", "a2", "edit").await.unwrap();
        let l = db.auto_shares_list("t1").await.unwrap();
        assert_eq!(l.len(), 2);
        let e = l.iter().find(|e| e.invitee_id == "a2").unwrap();
        assert_eq!(e.invitee_username, "ua2");
        assert_eq!(e.invitee_name, "Na2");
        db.auto_share_upsert("t1", "a1", "view").await.unwrap();
        let l = db.auto_shares_list("t1").await.unwrap();
        assert_eq!(l.len(), 2);
        assert!(l.iter().any(|e| e.invitee_id == "a1" && e.level == "view"));
        assert_eq!(db.auto_shares_all().await.unwrap().len(), 3);
        let id = l.iter().find(|e| e.invitee_id == "a1").unwrap().id.clone();
        assert!(!db.auto_share_delete("t2", &id).await.unwrap());
        assert!(db.auto_share_delete("t1", &id).await.unwrap());
        assert_eq!(db.auto_shares_list("t1").await.unwrap().len(), 1);
    }

    #[tokio::test]
    async fn audit_filters_pagination_and_purge() {
        let db = connect(":memory:").await.unwrap();
        db.audit("account", "u1", "alice", "login", "t", "d", "/u1/", 100)
            .await
            .unwrap();
        db.audit("account", "u2", "bob", "upload", "t", "d", "/u2/", 200)
            .await
            .unwrap();
        db.audit("account", "u1", "alice", "delete", "t", "d", "/u1/", 300)
            .await
            .unwrap();
        let all = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    limit: 10,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        assert_eq!(all.len(), 3);
        let v = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    action: "login".into(),
                    limit: 10,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        assert_eq!(v.len(), 1);
        assert_eq!(v[0].action, "login");
        let v = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    actor: "ali".into(),
                    limit: 10,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        assert_eq!(v.len(), 2);
        let v = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    from: 150,
                    to: 250,
                    limit: 10,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        assert_eq!(v.len(), 1);
        assert_eq!(v[0].ts, 200);
        let p1 = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    limit: 2,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        let p2 = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    limit: 2,
                    offset: 2,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        assert_eq!(p1.len(), 2);
        assert_eq!(p2.len(), 1);
        assert_ne!(p1[0].id, p2[0].id);
        db.audit_purge(250).await.unwrap();
        let v = db
            .audit_list(
                "account",
                None,
                &AuditFilter {
                    limit: 10,
                    ..Default::default()
                },
            )
            .await
            .unwrap();
        assert_eq!(v.len(), 1);
        assert_eq!(v[0].ts, 300);
    }

    #[tokio::test]
    async fn notifications_lifecycle() {
        let db = connect(":memory:").await.unwrap();
        db.notify("u1", "share_invite", "{\"a\":1}", 10)
            .await
            .unwrap();
        db.notify("u1", "render_done", "{\"b\":2}", 20)
            .await
            .unwrap();
        db.notify("u2", "node_offline", "{}", 30).await.unwrap();

        assert_eq!(db.notifications_unread("u1").await.unwrap(), 2);
        let v = db.notifications_for("u1", 0, 50).await.unwrap();
        assert_eq!(v.len(), 2);
        assert_eq!(v[0].created_at, 20);
        assert_eq!(v[0].payload["b"], 2);
        assert_eq!(v[1].kind, "share_invite");

        let page = db
            .notifications_for("u1", v[0].created_at, 50)
            .await
            .unwrap();
        assert_eq!(page.len(), 1);
        assert_eq!(page[0].id, v[1].id);

        assert!(!db.notification_read("u2", &v[0].id, 40).await.unwrap());
        assert!(db.notification_read("u1", &v[0].id, 40).await.unwrap());
        assert!(!db.notification_read("u1", &v[0].id, 41).await.unwrap());
        assert_eq!(db.notifications_unread("u1").await.unwrap(), 1);

        db.notifications_read_all("u1", 50).await.unwrap();
        assert_eq!(db.notifications_unread("u1").await.unwrap(), 0);

        assert_eq!(db.share_by_id("nope").await.is_err(), true);
        assert!(db.staff_ids().await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn nodes_offline_report_once() {
        let db = connect(":memory:").await.unwrap();
        let mut n = node("Farm-1");
        db.node_create(&n, "h").await.unwrap();
        assert!(db.nodes_newly_offline(100).await.unwrap().is_empty());

        db.node_touch(&n.id, 50).await.unwrap();
        let off = db.nodes_newly_offline(100).await.unwrap();
        assert_eq!(off.len(), 1);
        assert_eq!(off[0].name, "Farm-1");
        assert!(db.nodes_newly_offline(100).await.unwrap().is_empty());

        db.node_touch(&n.id, 500).await.unwrap();
        let off = db.nodes_newly_offline(600).await.unwrap();
        assert_eq!(off.len(), 1);

        n.disabled = true;
        db.node_set_disabled(&n.id, true).await.unwrap();
        db.node_touch(&n.id, 10).await.unwrap();
        assert!(db.nodes_newly_offline(100).await.unwrap().is_empty());
    }

    #[tokio::test]
    async fn staff_ids_skips_students() {
        let db = connect(":memory:").await.unwrap();
        let u = |id: &str, role: Role| User {
            id: id.into(),
            username: format!("u{id}"),
            display_name: "n".into(),
            role,
            role_name: "x".into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: 1,
            last_login: 0,
        };
        db.create_user(&u("t1", Role::Teacher), "h").await.unwrap();
        db.create_user(&u("s1", Role::Student), "h").await.unwrap();
        let mut d = u("d1", Role::Admin);
        d.disabled = true;
        db.create_user(&d, "h").await.unwrap();
        let staff = db.staff_ids().await.unwrap();
        assert!(staff.contains(&"t1".to_string()));
        assert!(!staff.contains(&"s1".to_string()));
        assert!(!staff.contains(&"d1".to_string()));
    }

    #[tokio::test]
    async fn project_link_lifecycle() {
        let db = connect(":memory:").await.unwrap();
        let l = crate::model::ProjectLink {
            id: "l1".into(),
            token_hash: "h1".into(),
            project_id: "p1".into(),
            scope: "renders".into(),
            created_by: "u1".into(),
            created_at: 10,
            expires_at: 0,
            revoked: false,
        };
        db.link_create(&l).await.unwrap();
        let got = db.link_by_hash("h1").await.unwrap();
        assert_eq!(got.scope, "renders");
        assert_eq!(got.id, "l1");
        let list = db.links_by_project("p1").await.unwrap();
        assert_eq!(list.len(), 1);
        assert!(db.links_by_project("p2").await.unwrap().is_empty());

        assert!(!db.link_revoke("l1", "p2").await.unwrap());
        assert!(db.link_revoke("l1", "p1").await.unwrap());
        assert!(!db.link_revoke("l1", "p1").await.unwrap());
        assert!(db.link_by_hash("h1").await.unwrap().revoked);

        db.link_create(&crate::model::ProjectLink {
            id: "l2".into(),
            token_hash: "h2".into(),
            ..l.clone()
        })
        .await
        .unwrap();
        db.links_delete_project("p1").await.unwrap();
        assert!(db.links_by_project("p1").await.unwrap().is_empty());
    }
}
