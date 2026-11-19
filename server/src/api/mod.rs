use std::sync::Arc;

use axum::body::Body;
use axum::extract::{Path, Query, State};
use axum::http::{header, HeaderMap, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get, patch, post};
use axum::{Json, Router};
use futures::StreamExt;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::auth::{
    self, client_ip, err, login_failed, login_ok, login_throttle, AppState, NodeSession, Session,
};
use crate::files::{self, FsError};
use crate::model::{self, can_manage, Project, ProjectGroup, RenderJob, RenderSpec, Role, User};
use crate::render;
use crate::store::{DbError, LockOutcome};

fn blob_key(dir: &str, rel: &str) -> String {
    format!("{}/{}", dir.trim_matches('/'), rel.trim_matches('/'))
}

pub fn router(state: Arc<AppState>) -> Router {
    let api = Router::new()
        .route("/health", get(health))
        .route("/version", get(version))
        .route("/setup", get(setup_status).post(setup_owner))
        .route("/login", post(login))
        .route("/logout", post(logout))
        .route("/me", get(me))
        .route("/me/password", post(change_password))
        .route("/sessions", get(list_sessions))
        .route("/sessions/{id}", delete(delete_session))
        .route("/roles", get(roles))
        .route("/accounts", get(list_accounts).post(create_account))
        .route(
            "/accounts/{id}",
            patch(update_account).delete(delete_account),
        )
        .route("/accounts/{id}/password", post(reset_password))
        .route("/accounts/{id}/status", post(set_status))
        .route("/audit", get(audit))
        .route("/projects", get(list_projects).post(create_project))
        .route("/projects/{id}/take-over", post(take_over_project))
        .route(
            "/projects/{id}",
            get(get_project).patch(update_project).delete(delete_project),
        )
        .route("/groups", get(list_groups).post(create_group))
        .route(
            "/groups/{id}",
            patch(rename_group).delete(delete_group),
        )
        .route(
            "/projects/{id}/files",
            get(list_files).put(upload_file).delete(delete_file),
        )
        .route("/projects/{id}/files/mkdir", post(mkdir))
        .route("/projects/{id}/files/move", post(move_file))
        .route("/projects/{id}/download", get(download))
        .route("/projects/{id}/thumb", get(thumb))
        .route("/projects/{id}/locks", post(lock_acquire).delete(lock_release))
        .route("/projects/{id}/locks/release", post(lock_release))
        .route("/projects/{id}/locks/heartbeat", post(lock_heartbeat))
        .route("/projects/{id}/renders", get(list_renders).post(create_render))
        .route("/projects/{id}/render-info", get(render_info))
        .route("/renders/{id}/cancel", post(cancel_render))
        .route("/renders/{id}/retry", post(retry_render))
        .route("/renders/{id}", delete(delete_render))
        .route("/renders/{id}/progress", post(render_progress))
        .route("/renders/{id}/finish", post(render_finish))
        .route("/settings", get(get_settings).put(put_settings))
        .route("/nodes", get(list_nodes).post(create_node))
        .route("/nodes/{id}", patch(update_node).delete(delete_node))
        .route("/worker/poll", post(worker_poll))
        .route("/worker/jobs/{id}/file", get(worker_file))
        .route("/worker/jobs/{id}/progress", post(worker_progress))
        .route("/worker/jobs/{id}/complete", post(worker_complete))
        .route("/worker/jobs/{id}/fail", post(worker_fail))
        .with_state(state);
    Router::new().nest("/api", api)
}

fn fs_resp(e: FsError) -> Response {
    match e {
        FsError::BadPath => err(StatusCode::BAD_REQUEST, "bad path"),
        FsError::NotFound => err(StatusCode::NOT_FOUND, "not found"),
        FsError::Exists => err(StatusCode::CONFLICT, "already exists"),
        FsError::Forbidden => err(StatusCode::FORBIDDEN, "forbidden"),
        FsError::Io(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    }
}

fn db_resp(e: DbError) -> Response {
    match e {
        DbError::NotFound => err(StatusCode::NOT_FOUND, "not found"),
        DbError::Conflict => err(StatusCode::CONFLICT, "conflict"),
        DbError::Other(m) => err(StatusCode::INTERNAL_SERVER_ERROR, &m),
    }
}

async fn health() -> Json<Value> {
    Json(json!({"ok": true}))
}

async fn version() -> Json<Value> {
    Json(json!({
        "version": env!("CARGO_PKG_VERSION"),
        "name": "wfm",
    }))
}

async fn setup_status(State(s): State<Arc<AppState>>) -> Json<Value> {
    let n = s.db.owner_count().await.unwrap_or(0);
    Json(json!({"needsSetup": n == 0}))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SetupReq {
    username: String,
    password: String,
    name: String,
    trusted_proxies: Option<String>,
}

async fn setup_owner(
    State(s): State<Arc<AppState>>,
    parts: axum::http::request::Parts,
    Json(req): Json<SetupReq>,
) -> Response {
    match s.db.owner_count().await {
        Ok(0) => {}
        Ok(_) => return err(StatusCode::CONFLICT, "setup already done"),
        Err(e) => return db_resp(e),
    }
    if !model::valid_username(&req.username) {
        return err(StatusCode::BAD_REQUEST, "invalid username");
    }
    if !model::valid_password(&req.password) {
        return err(StatusCode::BAD_REQUEST, "password must be at least 8 characters");
    }
    let name = req.name.trim();
    if name.is_empty() || name.len() > 64 {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    let proxies = req
        .trusted_proxies
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty());
    let nets = match proxies.map(auth::parse_nets).transpose() {
        Ok(n) => n,
        Err(e) => return err(StatusCode::BAD_REQUEST, &e),
    };
    let hash = match auth::hash_password(&req.password) {
        Ok(h) => h,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let u = User {
        id: model::new_id(),
        username: req.username.clone(),
        display_name: name.to_string(),
        role: Role::Owner,
        role_name: "owner".into(),
        student_id: String::new(),
        note: String::new(),
        disabled: false,
        created_by: String::new(),
        lineage: "/".into(),
        created_at: AppState::now(),
        last_login: 0,
    };
    match s.db.create_owner(&u, &hash).await {
        Ok(true) => {}
        Ok(false) => return err(StatusCode::CONFLICT, "setup already done"),
        Err(e) => {
            if s.db.owner_count().await.unwrap_or(0) > 0 {
                return err(StatusCode::CONFLICT, "setup already done");
            }
            return db_resp(e);
        }
    }
    if let (Some(list), Some(nets)) = (proxies, nets) {
        if let Err(e) = s.db.setting_set("trusted_proxies", list).await {
            return db_resp(e);
        }
        *s.trusted.write().unwrap() = nets;
    }
    s.audit("account", &u, "setup_owner", &u.username, "", "/")
        .await;
    let token = model::new_token();
    let csrf = model::new_token();
    let expires = AppState::now() + s.cfg.session_ttl;
    let ip = client_ip(&s, &parts).to_string();
    if let Err(e) = s
        .db
        .create_session(&model::token_hash(&token), &u.id, &csrf, expires, &ip, "")
        .await
    {
        return db_resp(e);
    }
    let mut r = Json(json!({"ok": true, "user": u, "csrf": csrf, "token": token})).into_response();
    r.headers_mut().insert(
        header::SET_COOKIE,
        HeaderValue::from_str(&auth::session_cookie(
            &token,
            s.cfg.secure_cookies,
            s.cfg.session_ttl,
        ))
        .unwrap(),
    );
    r
}

#[derive(Deserialize)]
struct LoginReq {
    username: String,
    password: String,
}

async fn login(
    State(s): State<Arc<AppState>>,
    parts: axum::http::request::Parts,
    Json(req): Json<LoginReq>,
) -> Response {
    let ip = client_ip(&s, &parts);
    if let Some(wait) = login_throttle(&s, ip) {
        return err(
            StatusCode::TOO_MANY_REQUESTS,
            &format!("too many attempts, retry in {wait}s"),
        );
    }
    let (user, hash) = match s.db.user_by_name(&req.username).await {
        Ok(v) => v,
        Err(_) => {
            login_failed(&s, ip);
            return err(StatusCode::UNAUTHORIZED, "invalid username or password");
        }
    };
    if user.disabled {
        login_failed(&s, ip);
        return err(StatusCode::FORBIDDEN, "account disabled");
    }
    if !auth::verify_password(&hash, &req.password) {
        login_failed(&s, ip);
        return err(StatusCode::UNAUTHORIZED, "invalid username or password");
    }
    login_ok(&s, ip);
    let token = model::new_token();
    let csrf = model::new_token();
    let expires = AppState::now() + s.cfg.session_ttl;
    let ua = parts
        .headers
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("")
        .chars()
        .take(200)
        .collect::<String>();
    if let Err(e) = s
        .db
        .create_session(
            &model::token_hash(&token),
            &user.id,
            &csrf,
            expires,
            &ip.to_string(),
            &ua,
        )
        .await
    {
        return db_resp(e);
    }
    let _ = s.db.touch_login(&user.id, AppState::now()).await;
    s.audit("account", &user, "login", &user.username, "", &user.lineage)
        .await;
    let mut r = Json(json!({"user": user, "csrf": csrf, "token": token})).into_response();
    r.headers_mut().insert(
        header::SET_COOKIE,
        HeaderValue::from_str(&auth::session_cookie(
            &token,
            s.cfg.secure_cookies,
            s.cfg.session_ttl,
        ))
        .unwrap(),
    );
    r
}

async fn list_sessions(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.list_sessions(&session.user.id).await {
        Ok(rows) => {
            let out: Vec<_> = rows
                .into_iter()
                .map(|r| {
                    let mut v = serde_json::to_value(&r).unwrap_or_default();
                    v["current"] = json!(r.id == session.token_hash);
                    v
                })
                .collect();
            Json(json!(out)).into_response()
        }
        Err(e) => db_resp(e),
    }
}

async fn delete_session(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    if id == session.token_hash {
        return err(StatusCode::BAD_REQUEST, "cannot revoke the current session");
    }
    if let Err(e) = s.db.delete_user_session(&session.user.id, &id).await {
        return db_resp(e);
    }
    Json(json!({"ok": true})).into_response()
}

async fn logout(State(s): State<Arc<AppState>>, parts: axum::http::request::Parts) -> Response {
    if let Some(t) = auth::cookie_token(&parts) {
        let _ = s.db.delete_session(&model::token_hash(&t)).await;
    }
    let mut r = Json(json!({"ok": true})).into_response();
    r.headers_mut().insert(
        header::SET_COOKIE,
        HeaderValue::from_str(&auth::clear_cookie(s.cfg.secure_cookies)).unwrap(),
    );
    r
}

async fn me(session: Session) -> Json<Value> {
    Json(json!({"user": session.user, "csrf": session.csrf}))
}

#[derive(Deserialize)]
struct PasswordReq {
    current: String,
    next: String,
}

async fn change_password(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<PasswordReq>,
) -> Response {
    if !model::valid_password(&req.next) {
        return err(StatusCode::BAD_REQUEST, "password must be at least 8 characters");
    }
    let (_, hash) = match s.db.user_by_name(&session.user.username).await {
        Ok(v) => v,
        Err(e) => return db_resp(e),
    };
    if !auth::verify_password(&hash, &req.current) {
        return err(StatusCode::FORBIDDEN, "current password wrong");
    }
    let h = match auth::hash_password(&req.next) {
        Ok(h) => h,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    if let Err(e) = s.db.set_password(&session.user.id, &h).await {
        return db_resp(e);
    }
    let _ = s
        .db
        .delete_user_sessions_except(&session.user.id, &session.token_hash)
        .await;
    s.audit(
        "account",
        &session.user,
        "change_password",
        &session.user.username,
        "",
        &session.user.lineage,
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

async fn roles(session: Session) -> Json<Value> {
    let me = session.user.role;
    let all = ["student", "mod", "teacher", "admin"];
    let creatable: Vec<&str> = if me.can_create() {
        all.iter()
            .filter(|r| Role::parse(r).unwrap() < me)
            .copied()
            .collect()
    } else {
        Vec::new()
    };
    Json(json!({
        "creatable": creatable,
        "canManage": me.can_create() || me == Role::Mod,
        "canAudit": me.can_see_audit(),
    }))
}

async fn require_manager(s: &Arc<AppState>, session: &Session, target_id: &str) -> Result<User, Response> {
    let t = s
        .db
        .user_by_id(target_id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such account"))?;
    if !can_manage(&session.user, &t) {
        return Err(err(StatusCode::FORBIDDEN, "cannot manage this account"));
    }
    Ok(t)
}

async fn list_accounts(State(s): State<Arc<AppState>>, session: Session) -> Response {
    if !session.user.role.can_see_audit() && !session.user.role.can_create() {
        return err(StatusCode::FORBIDDEN, "not allowed");
    }
    match s.db.managed_users(&session.user).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct CreateAccountReq {
    username: String,
    password: String,
    name: String,
    role: String,
    #[serde(default, rename = "studentId")]
    student_id: String,
    #[serde(default)]
    note: String,
}

async fn create_account(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<CreateAccountReq>,
) -> Response {
    if !session.user.role.can_create() {
        return err(StatusCode::FORBIDDEN, "not allowed");
    }
    let role = match Role::parse(&req.role) {
        Some(r) if r < session.user.role && r != Role::Owner => r,
        _ => return err(StatusCode::BAD_REQUEST, "cannot create that role"),
    };
    if !model::valid_username(&req.username) {
        return err(StatusCode::BAD_REQUEST, "invalid username");
    }
    if !model::valid_password(&req.password) {
        return err(StatusCode::BAD_REQUEST, "password must be at least 8 characters");
    }
    let name = req.name.trim();
    if name.is_empty() || name.len() > 64 {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    let note: String = req.note.chars().take(20).collect();
    let student_id: String = req.student_id.trim().chars().take(32).collect();
    let hash = match auth::hash_password(&req.password) {
        Ok(h) => h,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let u = User {
        id: model::new_id(),
        username: req.username.clone(),
        display_name: name.to_string(),
        role,
        role_name: role.as_str().into(),
        student_id,
        note,
        disabled: false,
        created_by: session.user.id.clone(),
        lineage: format!("{}{}/", session.user.lineage, session.user.id),
        created_at: AppState::now(),
        last_login: 0,
    };
    if let Err(e) = s.db.create_user(&u, &hash).await {
        return match e {
            DbError::Conflict => err(StatusCode::CONFLICT, "username taken"),
            other => db_resp(other),
        };
    }
    s.audit(
        "account",
        &session.user,
        "create_account",
        &u.username,
        &format!("role={}", u.role_name),
        &u.lineage,
    )
    .await;
    Json(json!(u)).into_response()
}

#[derive(Deserialize)]
struct ResetReq {
    password: String,
}

async fn reset_password(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<ResetReq>,
) -> Response {
    let target = match require_manager(&s, &session, &id).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    if !model::valid_password(&req.password) {
        return err(StatusCode::BAD_REQUEST, "password must be at least 8 characters");
    }
    let h = match auth::hash_password(&req.password) {
        Ok(h) => h,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    if let Err(e) = s.db.set_password(&id, &h).await {
        return db_resp(e);
    }
    let _ = s.db.delete_user_sessions(&id).await;
    s.audit(
        "account",
        &session.user,
        "reset_password",
        &target.username,
        "",
        &target.lineage,
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

async fn delete_account(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let target = match require_manager(&s, &session, &id).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    match s.db.projects_by_owner(&id).await {
        Ok(ps) if !ps.is_empty() => {
            return err(StatusCode::CONFLICT, "account still has projects");
        }
        Ok(_) => {}
        Err(e) => return db_resp(e),
    }
    if let Err(e) = s.db.delete_user(&id).await {
        return db_resp(e);
    }
    s.audit(
        "account",
        &session.user,
        "delete",
        &target.username,
        "",
        &target.lineage,
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

#[derive(Deserialize)]
struct StatusReq {
    disabled: bool,
}

async fn set_status(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<StatusReq>,
) -> Response {
    let target = match require_manager(&s, &session, &id).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    if let Err(e) = s.db.set_user_disabled(&id, req.disabled).await {
        return db_resp(e);
    }
    if req.disabled {
        let _ = s.db.delete_user_sessions(&id).await;
    }
    s.audit(
        "account",
        &session.user,
        if req.disabled { "disable" } else { "enable" },
        &target.username,
        "",
        &target.lineage,
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct UpdateAccountReq {
    username: Option<String>,
    name: Option<String>,
    role: Option<String>,
    student_id: Option<String>,
    note: Option<String>,
}

async fn update_account(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<UpdateAccountReq>,
) -> Response {
    let mut target = match require_manager(&s, &session, &id).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    let mut detail: Vec<&str> = Vec::new();
    if let Some(username) = req.username {
        let username = username.trim();
        if !model::valid_username(username) {
            return err(StatusCode::BAD_REQUEST, "invalid username");
        }
        if username != target.username {
            target.username = username.to_string();
            detail.push("username");
        }
    }
    if let Some(name) = req.name {
        let name = name.trim();
        if name.is_empty() || name.len() > 64 {
            return err(StatusCode::BAD_REQUEST, "invalid name");
        }
        if name != target.display_name {
            target.display_name = name.to_string();
            detail.push("name");
        }
    }
    if let Some(role) = req.role {
        let role = match Role::parse(&role) {
            Some(r) if r < session.user.role && r != Role::Owner => r,
            _ => return err(StatusCode::BAD_REQUEST, "cannot set that role"),
        };
        if role != target.role {
            target.role = role;
            target.role_name = role.as_str().into();
            detail.push("role");
        }
    }
    if let Some(student_id) = req.student_id {
        let student_id: String = student_id.trim().chars().take(32).collect();
        if student_id != target.student_id {
            target.student_id = student_id;
            detail.push("studentId");
        }
    }
    if let Some(note) = req.note {
        let note: String = note.chars().take(20).collect();
        if note != target.note {
            target.note = note;
            detail.push("note");
        }
    }
    if !detail.is_empty() {
        if let Err(e) = s.db.update_user(&target).await {
            return match e {
                DbError::Conflict => err(StatusCode::CONFLICT, "username taken"),
                other => db_resp(other),
            };
        }
        s.audit(
            "account",
            &session.user,
            "update_account",
            &target.username,
            &detail.join(","),
            &target.lineage,
        )
        .await;
    }
    Json(json!(target)).into_response()
}

#[derive(Deserialize)]
struct AuditQuery {
    #[serde(default = "dscope")]
    scope: String,
    #[serde(default = "dlimit")]
    limit: i64,
}
fn dscope() -> String {
    "account".into()
}
fn dlimit() -> i64 {
    200
}

async fn audit(
    State(s): State<Arc<AppState>>,
    session: Session,
    Query(q): Query<AuditQuery>,
) -> Response {
    if !session.user.role.can_see_audit() {
        return err(StatusCode::FORBIDDEN, "not allowed");
    }
    let scope = match q.scope.as_str() {
        "account" => "account",
        "project" => {
            if session.user.role != Role::Owner {
                return err(StatusCode::FORBIDDEN, "project logs are owner only");
            }
            "project"
        }
        _ => return err(StatusCode::BAD_REQUEST, "bad scope"),
    };
    let subtree = if session.user.role == Role::Owner {
        None
    } else {
        Some(session.user.id.as_str())
    };
    let limit = q.limit.clamp(1, 1000);
    match s.db.audit_list(scope, subtree, limit).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

// ---------- projects ----------

async fn list_projects(State(s): State<Arc<AppState>>, session: Session) -> Response {
    let mut v = match s.db.projects_by_owner(&session.user.id).await {
        Ok(v) => v,
        Err(e) => return db_resp(e),
    };
    if session.user.role.can_see_audit() {
        let names: std::collections::HashMap<String, String> = s
            .db
            .managed_users(&session.user)
            .await
            .unwrap_or_default()
            .into_iter()
            .map(|u| {
                (u.id, if u.display_name.is_empty() {
                    u.username
                } else {
                    u.display_name
                })
            })
            .collect();
        match s.db.managed_projects(&session.user).await {
            Ok(managed) => {
                let mut out: Vec<_> = v
                    .drain(..)
                    .map(|p| serde_json::to_value(&p).unwrap_or_default())
                    .collect();
                for p in managed {
                    let mut j = serde_json::to_value(&p).unwrap_or_default();
                    j["ownerName"] = json!(names
                        .get(&p.owner_id)
                        .cloned()
                        .unwrap_or_default());
                    out.push(j);
                }
                return Json(json!(out)).into_response();
            }
            Err(e) => return db_resp(e),
        }
    }
    Json(json!(v)).into_response()
}

#[derive(Deserialize)]
struct CreateProjectReq {
    name: String,
    #[serde(default, rename = "displayName")]
    display_name: String,
    #[serde(default, rename = "groupId")]
    group_id: String,
    #[serde(default)]
    tags: Vec<String>,
}

async fn create_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<CreateProjectReq>,
) -> Response {
    let name = match files::valid_project_name_or_err(&req.name) {
        Ok(n) => n,
        Err(_) => {
            return err(
                StatusCode::BAD_REQUEST,
                "project name: letters, digits, space, _ . - (max 64)",
            )
        }
    };
    if name.starts_with('.') || name.starts_with('-') {
        return err(StatusCode::BAD_REQUEST, "project name cannot start with . or -");
    }
    let display = if req.display_name.trim().is_empty() {
        name.clone()
    } else {
        req.display_name.trim().chars().take(100).collect()
    };
    let group_id = req.group_id.trim().to_string();
    if !group_id.is_empty() {
        match s.db.group_by_id(&group_id).await {
            Ok(g) if g.owner_id == session.user.id => {}
            Ok(_) => return err(StatusCode::FORBIDDEN, "not your group"),
            Err(_) => return err(StatusCode::NOT_FOUND, "no such group"),
        }
    }
    let tags = model::norm_tags(&req.tags);
    let id = model::new_id();
    let dir = files::rel_project_dir(&session.user.username, &session.user.id, &name, &id);
    for f in files::PROJECT_FOLDERS {
        if let Err(e) = s.blobs.mkdir(&format!("{dir}/{f}")).await {
            return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
        }
    }
    let p = Project {
        id: id.clone(),
        owner_id: session.user.id.clone(),
        name,
        display_name: display,
        dir,
        group_id,
        tags,
        created_at: AppState::now(),
        last_activity: AppState::now(),
        pinned: false,
    };
    if let Err(e) = s.db.create_project(&p).await {
        let _ = s.blobs.delete_prefix(&p.dir).await;
        return db_resp(e);
    }
    s.audit(
        "project",
        &session.user,
        "create_project",
        &p.display_name,
        "",
        "",
    )
    .await;
    Json(json!(p)).into_response()
}

async fn fetch_project(s: &Arc<AppState>, id: &str) -> Result<Project, Response> {
    s.db.project_by_id(id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such project"))
}

async fn owned_project(s: &Arc<AppState>, session: &Session, id: &str) -> Result<Project, Response> {
    let p = fetch_project(s, id).await?;
    if p.owner_id != session.user.id && session.user.role != Role::Owner {
        return Err(err(StatusCode::FORBIDDEN, "not your project"));
    }
    let _ = s.db.touch_project(&p.id, AppState::now()).await;
    Ok(p)
}

async fn read_project(s: &Arc<AppState>, session: &Session, id: &str) -> Result<Project, Response> {
    let p = fetch_project(s, id).await?;
    if p.owner_id != session.user.id && session.user.role != Role::Owner {
        let in_subtree = s
            .db
            .user_in_subtree(&session.user, &p.owner_id)
            .await
            .unwrap_or(false);
        if !in_subtree {
            return Err(err(StatusCode::FORBIDDEN, "not your project"));
        }
    }
    let _ = s.db.touch_project(&p.id, AppState::now()).await;
    Ok(p)
}

async fn take_over_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let p = match fetch_project(&s, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if p.owner_id == session.user.id {
        return err(StatusCode::BAD_REQUEST, "already your project");
    }
    let allowed = session.user.role == Role::Owner
        || s.db
            .user_in_subtree(&session.user, &p.owner_id)
            .await
            .unwrap_or(false);
    if !allowed {
        return err(StatusCode::FORBIDDEN, "not your project");
    }
    if let Err(e) = s.db.set_project_owner(&id, &session.user.id).await {
        return db_resp(e);
    }
    s.audit(
        "project",
        &session.user,
        "take_over",
        &p.display_name,
        &format!("from {}", p.owner_id),
        "",
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

async fn get_project(State(s): State<Arc<AppState>>, session: Session, Path(id): Path<String>) -> Response {
    match read_project(&s, &session, &id).await {
        Ok(p) => Json(json!(p)).into_response(),
        Err(r) => r,
    }
}

#[derive(Deserialize)]
struct UpdateProjectReq {
    #[serde(default, rename = "displayName")]
    display_name: Option<String>,
    #[serde(default, rename = "groupId")]
    group_id: Option<String>,
    #[serde(default)]
    tags: Option<Vec<String>>,
    #[serde(default)]
    pinned: Option<bool>,
}

async fn update_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<UpdateProjectReq>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let name = match req.display_name {
        Some(n) => {
            let n: String = n.trim().chars().take(100).collect();
            if n.is_empty() {
                return err(StatusCode::BAD_REQUEST, "empty name");
            }
            n
        }
        None => p.display_name.clone(),
    };
    let group_id = match req.group_id {
        Some(g) => {
            let g = g.trim().to_string();
            if !g.is_empty() {
                match s.db.group_by_id(&g).await {
                    Ok(gr) if gr.owner_id == p.owner_id => {}
                    Ok(_) => return err(StatusCode::FORBIDDEN, "not your group"),
                    Err(_) => return err(StatusCode::NOT_FOUND, "no such group"),
                }
            }
            g
        }
        None => p.group_id.clone(),
    };
    let tags = model::norm_tags(req.tags.as_deref().unwrap_or(&p.tags));
    if let Err(e) = s
        .db
        .update_project(&id, &name, &group_id, &model::tags_csv(&tags))
        .await
    {
        return db_resp(e);
    }
    if let Some(pin) = req.pinned {
        if let Err(e) = s.db.set_project_pinned(&id, pin).await {
            return db_resp(e);
        }
    }
    s.audit("project", &session.user, "update_project", &name, "", "")
        .await;
    Json(json!({"ok": true})).into_response()
}

async fn owned_group(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<ProjectGroup, Response> {
    let g = s
        .db
        .group_by_id(id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such group"))?;
    if g.owner_id != session.user.id && session.user.role != Role::Owner {
        return Err(err(StatusCode::FORBIDDEN, "not your group"));
    }
    Ok(g)
}

async fn list_groups(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.groups_by_owner(&session.user.id).await {
        Ok(groups) => Json(json!(groups)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct GroupReq {
    name: String,
}

async fn create_group(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<GroupReq>,
) -> Response {
    let name: String = req.name.trim().chars().take(64).collect();
    if name.is_empty() {
        return err(StatusCode::BAD_REQUEST, "empty group name");
    }
    let g = ProjectGroup {
        id: model::new_id(),
        owner_id: session.user.id.clone(),
        name: name.clone(),
        created_at: AppState::now(),
    };
    if let Err(e) = s.db.create_group(&g).await {
        return db_resp(e);
    }
    s.audit("project", &session.user, "create_group", &name, "", "")
        .await;
    Json(json!(g)).into_response()
}

async fn rename_group(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<GroupReq>,
) -> Response {
    if let Err(r) = owned_group(&s, &session, &id).await {
        return r;
    }
    let name: String = req.name.trim().chars().take(64).collect();
    if name.is_empty() {
        return err(StatusCode::BAD_REQUEST, "empty group name");
    }
    if let Err(e) = s.db.rename_group(&id, &name).await {
        return db_resp(e);
    }
    s.audit("project", &session.user, "rename_group", &name, "", "")
        .await;
    Json(json!({"ok": true})).into_response()
}

async fn delete_group(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let g = match owned_group(&s, &session, &id).await {
        Ok(g) => g,
        Err(r) => return r,
    };
    if let Err(e) = s.db.delete_group(&id).await {
        return db_resp(e);
    }
    s.audit("project", &session.user, "delete_group", &g.name, "", "")
        .await;
    Json(json!({"ok": true})).into_response()
}

async fn delete_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if let Err(e) = s.db.delete_project(&id).await {
        return db_resp(e);
    }
    let _ = s.blobs.delete_prefix(&p.dir).await;
    let _ = s.blobs.delete_prefix(&format!("{}.thumbs", p.dir)).await;
    s.audit(
        "project",
        &session.user,
        "delete_project",
        &p.display_name,
        "",
        "",
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

#[derive(Deserialize)]
struct FileQuery {
    #[serde(default)]
    path: String,
    #[serde(default)]
    dl: bool,
    #[serde(default)]
    done: bool,
    #[serde(rename = "clientId", default)]
    client_id: String,
}

async fn list_files(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
) -> Response {
    let p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let rel = q.path.trim_matches('/');
    if rel.is_empty() {
        let out: Vec<files::FileEntry> = files::ROOT_FOLDERS
            .iter()
            .map(|f| files::FileEntry {
                name: f.to_string(),
                path: f.to_string(),
                kind: "dir".into(),
                size: 0,
                modified: 0,
            })
            .collect();
        return Json(json!(out)).into_response();
    }
    let key = match files::clean_rel_key(rel) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    match s.blobs.list(&blob_key(&p.dir, &key)).await {
        Ok((folders, objects)) => {
            let strip = format!("{}/", p.dir);
            let rel = |k: &str| k.strip_prefix(&strip).unwrap_or(k).to_string();
            let mut out: Vec<files::FileEntry> = folders
                .iter()
                .map(|f| {
                    let r = rel(f);
                    files::FileEntry {
                        name: r.rsplit('/').next().unwrap_or(&r).to_string(),
                        path: r,
                        kind: "dir".into(),
                        size: 0,
                        modified: 0,
                    }
                })
                .collect();
            out.extend(objects.iter().map(|o| {
                let r = rel(&o.key);
                files::FileEntry {
                    name: r.rsplit('/').next().unwrap_or(&r).to_string(),
                    path: r,
                    kind: "file".into(),
                    size: o.size,
                    modified: o.modified,
                }
            }));
            out.sort_by(|a, b| (b.kind == "dir").cmp(&(a.kind == "dir")).then(a.name.cmp(&b.name)));
            Json(json!(out)).into_response()
        }
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    }
}

async fn upload_file(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
    headers: HeaderMap,
    body: Body,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let len = headers
        .get(header::CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(0);
    if len > s.cfg.max_upload {
        return err(StatusCode::PAYLOAD_TOO_LARGE, "file too large");
    }
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    if key == "project.fcproj" && !q.client_id.is_empty() {
        match s.db.lock_get(&id, "edit").await {
            Ok(l) if l.holder != q.client_id && l.expires_at > AppState::now() => {
                return err(StatusCode::CONFLICT, "lock lost");
            }
            _ => {}
        }
    }
    let (tmp, written) = match spool_body(&s, body, s.cfg.max_upload).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let put = async {
        let mut f = tokio::fs::File::open(&tmp).await.map_err(|e| e.to_string())?;
        s.blobs
            .put(&blob_key(&p.dir, &key), written, &mut f)
            .await
    }
    .await;
    let _ = tokio::fs::remove_file(&tmp).await;
    if let Err(e) = put {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
    }
    s.audit(
        "project",
        &session.user,
        "upload",
        &p.display_name,
        &q.path,
        "",
    )
    .await;
    Json(json!({"ok": true, "size": written})).into_response()
}

/// Spool a request body to a temp file with a size cap. Returns the temp path
/// and bytes written; the caller moves or deletes the file.
async fn spool_body(s: &AppState, body: Body, max: u64) -> Result<(std::path::PathBuf, u64), Response> {
    let tmp = s.cfg.data_dir.join("tmp").join(format!("up-{}", model::new_id()));
    let _ = tokio::fs::create_dir_all(tmp.parent().unwrap()).await;
    let mut f = tokio::fs::File::create(&tmp).await.map_err(|e| fs_resp(e.into()))?;
    let mut stream = body.into_data_stream();
    let mut written: u64 = 0;
    let mut failed: Option<Response> = None;
    while let Some(chunk) = stream.next().await {
        match chunk {
            Ok(b) => {
                written += b.len() as u64;
                if written > max {
                    failed = Some(err(StatusCode::PAYLOAD_TOO_LARGE, "file too large"));
                    break;
                }
                if let Err(e) = tokio::io::AsyncWriteExt::write_all(&mut f, &b).await {
                    failed = Some(fs_resp(e.into()));
                    break;
                }
            }
            Err(e) => {
                failed = Some(err(StatusCode::BAD_REQUEST, &e.to_string()));
                break;
            }
        }
    }
    drop(f);
    if let Some(r) = failed {
        let _ = tokio::fs::remove_file(&tmp).await;
        return Err(r);
    }
    Ok((tmp, written))
}

#[derive(Deserialize)]
struct PathReq {
    path: String,
}

async fn mkdir(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<PathReq>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    match files::clean_rel_key(&req.path) {
        Ok(k) => match s.blobs.mkdir(&blob_key(&p.dir, &k)).await {
            Ok(()) => {
                s.audit("project", &session.user, "mkdir", &p.display_name, &k, "")
                    .await;
                Json(json!({"ok": true})).into_response()
            }
            Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &e),
        },
        Err(e) => fs_resp(e),
    }
}

#[derive(Deserialize)]
struct MoveReq {
    from: String,
    to: String,
}

async fn move_file(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<MoveReq>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let (fk, tk) = match (files::clean_rel_key(&req.from), files::clean_rel_key(&req.to)) {
        (Ok(a), Ok(b)) => (a, b),
        _ => return err(StatusCode::BAD_REQUEST, "bad path"),
    };
    match s.blobs.rename(&blob_key(&p.dir, &fk), &blob_key(&p.dir, &tk)).await {
        Ok(()) => {
            s.audit("project", &session.user, "move", &p.display_name, &format!("{} -> {}", req.from, req.to), "").await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) => err(StatusCode::BAD_REQUEST, &e),
    }
}

async fn delete_file(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) if k.split('/').count() > 1 => k,
        _ => return err(StatusCode::FORBIDDEN, "cannot delete root folder"),
    };
    match s.blobs.delete(&blob_key(&p.dir, &key)).await {
        Ok(()) => {
            s.audit("project", &session.user, "delete_file", &p.display_name, &q.path, "").await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) if e == "not found" => err(StatusCode::NOT_FOUND, &e),
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    }
}

async fn download(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
    headers: HeaderMap,
) -> Response {
    let p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    serve_blob(&s, &blob_key(&p.dir, &key), &key, &headers, q.dl).await
}

fn thumb_key(dir: &str, rel: &str, size: u64) -> String {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in rel.as_bytes() {
        h = (h ^ *b as u64).wrapping_mul(0x100000001b3);
    }
    format!("{dir}.thumbs/{h:016x}-{size:x}.jpg")
}

async fn make_thumb(s: &Arc<AppState>, src: &str, dst: &str) -> Result<(), String> {
    use tokio::io::AsyncWriteExt;
    let (_, stream) = s.blobs.get(src).await?;
    let mut reader = tokio_util::io::StreamReader::new(stream);
    let tmp = std::env::temp_dir().join(format!("wfm-thumb-{}", rand::random::<u64>()));
    {
        let mut f = tokio::fs::File::create(&tmp)
            .await
            .map_err(|e| e.to_string())?;
        tokio::io::copy(&mut reader, &mut f)
            .await
            .map_err(|e| e.to_string())?;
        f.flush().await.map_err(|e| e.to_string())?;
    }
    let out = tmp.with_extension("jpg");
    let st = tokio::time::timeout(
        std::time::Duration::from_secs(30),
        tokio::process::Command::new(&s.cfg.ffmpeg)
            .arg("-y")
            .arg("-loglevel")
            .arg("error")
            .arg("-i")
            .arg(&tmp)
            .arg("-frames:v")
            .arg("1")
            .arg("-vf")
            .arg("scale=320:-2")
            .arg("-q:v")
            .arg("4")
            .arg(&out)
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .status(),
    )
    .await
    .map_err(|_| "thumbnail timed out".to_string())?
    .map_err(|e| e.to_string())?;
    let _ = tokio::fs::remove_file(&tmp).await;
    if !st.success() {
        let _ = tokio::fs::remove_file(&out).await;
        return Err("thumbnail failed".into());
    }
    let bytes = tokio::fs::read(&out).await.map_err(|e| e.to_string())?;
    let _ = tokio::fs::remove_file(&out).await;
    let len = bytes.len() as u64;
    let mut cur = std::io::Cursor::new(bytes);
    s.blobs.put(dst, len, &mut cur).await
}

async fn thumb(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
) -> Response {
    let p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) if files::thumbable(&k) => k,
        _ => return err(StatusCode::NOT_FOUND, "no thumbnail"),
    };
    let size = match s.blobs.head(&blob_key(&p.dir, &key)).await {
        Ok(v) => v,
        Err(_) => return err(StatusCode::NOT_FOUND, "not found"),
    };
    let tk = thumb_key(&p.dir, &key, size);
    if s.blobs.head(&tk).await.is_err() {
        if let Err(e) = make_thumb(&s, &blob_key(&p.dir, &key), &tk).await {
            return err(StatusCode::NOT_FOUND, &e);
        }
    }
    serve_blob(&s, &tk, "thumb.jpg", &HeaderMap::new(), false).await
}

async fn serve_blob(s: &Arc<AppState>, key: &str, name: &str, headers: &HeaderMap, attachment: bool) -> Response {
    let size = match s.blobs.head(key).await {
        Ok(v) => v,
        Err(_) => return err(StatusCode::NOT_FOUND, "not found"),
    };
    let (start, end, partial) = match headers.get(header::RANGE).and_then(|v| v.to_str().ok()) {
        Some(r) => match parse_range(r, size) {
            Some((a, b)) => (a, b, true),
            None => (0u64, size.saturating_sub(1), false),
        },
        None => (0u64, size.saturating_sub(1), false),
    };
    if size == 0 {
        let mut r = Response::new(Body::empty());
        *r.status_mut() = StatusCode::OK;
        return r;
    }
    let (_, end, stream) = match s.blobs.get_range(key, start, end).await {
        Ok(v) => v,
        Err(e) => return err(StatusCode::NOT_FOUND, &e),
    };
    let mime = mime_guess::from_path(name).first_or_octet_stream().to_string();
    let len = end.saturating_sub(start) + 1;
    let status = if partial { StatusCode::PARTIAL_CONTENT } else { StatusCode::OK };
    let mut r = Response::new(Body::from_stream(stream));
    *r.status_mut() = status;
    let h = r.headers_mut();
    h.insert(header::CONTENT_TYPE, HeaderValue::from_str(&mime).unwrap());
    h.insert(header::CONTENT_LENGTH, HeaderValue::from_str(&len.to_string()).unwrap());
    h.insert(header::ACCEPT_RANGES, HeaderValue::from_static("bytes"));
    if partial {
        h.insert(
            header::CONTENT_RANGE,
            HeaderValue::from_str(&format!("bytes {start}-{end}/{size}")).unwrap(),
        );
    }
    if attachment {
        let fname = name.rsplit('/').next().unwrap_or(name);
        let safe: String = fname
            .chars()
            .map(|c| if c.is_ascii_alphanumeric() || "._- ".contains(c) { c } else { '_' })
            .collect();
        h.insert(
            header::CONTENT_DISPOSITION,
            HeaderValue::from_str(&format!("attachment; filename=\"{safe}\"")).unwrap(),
        );
    }
    r
}

fn parse_range(v: &str, size: u64) -> Option<(u64, u64)> {
    if size == 0 {
        return None;
    }
    let v = v.strip_prefix("bytes=")?;
    let (a, b) = v.split_once('-')?;
    let last = size - 1;
    let (start, end) = if a.is_empty() {
        let n: u64 = b.parse().ok()?;
        (size.saturating_sub(n), last)
    } else {
        let s: u64 = a.parse().ok()?;
        let e = if b.is_empty() { last } else { b.parse().ok()? };
        (s, e.min(last))
    };
    if start > end {
        return None;
    }
    Some((start, end))
}

#[cfg(test)]
mod tests {
    use super::{parse_range, reserved_worker_name};

    #[test]
    fn reserved_names() {
        assert!(reserved_worker_name("device"));
        assert!(reserved_worker_name("DEVICE"));
        assert!(reserved_worker_name("local-0"));
        assert!(reserved_worker_name("Local-9"));
        assert!(!reserved_worker_name("render-node-1"));
        assert!(!reserved_worker_name("localnode"));
        assert!(!reserved_worker_name("device-2"));
    }

    #[test]
    fn ranges() {
        assert_eq!(parse_range("bytes=0-99", 1000), Some((0, 99)));
        assert_eq!(parse_range("bytes=500-", 1000), Some((500, 999)));
        assert_eq!(parse_range("bytes=-100", 1000), Some((900, 999)));
        assert_eq!(parse_range("bytes=0-9999", 1000), Some((0, 999)));
        assert_eq!(parse_range("bytes=2000-3000", 1000), None);
        assert_eq!(parse_range("garbage", 1000), None);
        assert_eq!(parse_range("bytes=50-20", 1000), None);
        assert_eq!(parse_range("bytes=-100", 0), None);
        assert_eq!(parse_range("bytes=0-", 0), None);
        assert_eq!(parse_range("bytes=0-0", 0), None);
    }
}

// ---------- locks ----------

#[derive(Deserialize)]
struct LockReq {
    kind: String,
    #[serde(rename = "clientId")]
    client_id: String,
    #[serde(default)]
    force: bool,
}

async fn lock_acquire(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<LockReq>,
) -> Response {
    let _p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let kind = match req.kind.as_str() {
        "edit" | "render" => req.kind.clone(),
        _ => return err(StatusCode::BAD_REQUEST, "bad lock kind"),
    };
    if req.client_id.is_empty() || req.client_id.len() > 64 {
        return err(StatusCode::BAD_REQUEST, "bad clientId");
    }
    let now = AppState::now();
    match s
        .db
        .lock_acquire(
            &id,
            &kind,
            &req.client_id,
            &session.user.username,
            now + s.cfg.lock_ttl,
            now,
            req.force,
        )
        .await
    {
        Ok(LockOutcome::Acquired(l)) => Json(json!({"acquired": true, "lock": l})).into_response(),
        Ok(LockOutcome::Held(l)) => (
            StatusCode::CONFLICT,
            Json(json!({"acquired": false, "lock": l})),
        )
            .into_response(),
        Err(e) => db_resp(e),
    }
}

async fn lock_heartbeat(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<LockReq>,
) -> Response {
    let _p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    match s
        .db
        .lock_heartbeat(
            &id,
            &req.kind,
            &req.client_id,
            AppState::now() + s.cfg.lock_ttl,
        )
        .await
    {
        Ok(true) => Json(json!({"ok": true})).into_response(),
        Ok(false) => err(StatusCode::CONFLICT, "lock lost"),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct LockDelQuery {
    kind: String,
    #[serde(rename = "clientId")]
    client_id: String,
}

async fn lock_release(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<LockDelQuery>,
) -> Response {
    let _p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let _ = s.db.lock_release(&id, &q.kind, &q.client_id).await;
    Json(json!({"ok": true})).into_response()
}

// ---------- renders ----------

#[derive(Deserialize)]
struct ListRendersQuery {
    #[serde(default)]
    offset: i64,
    limit: Option<i64>,
}

async fn list_renders(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<ListRendersQuery>,
) -> Response {
    let _p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let limit = q.limit.unwrap_or(50).clamp(1, 200);
    match s.db.jobs_by_project(&id, q.offset.max(0), limit).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct RenderReq {
    #[serde(default = "mode_server")]
    mode: String,
    #[serde(default)]
    sequence: u64,
    #[serde(default)]
    output: String,
    #[serde(default)]
    params: Value,
}

fn mode_server() -> String {
    "server".into()
}

/// True when something on this deployment can run a queued render: local
/// workers, or a render node that checked in recently.
async fn server_render_capacity(s: &Arc<AppState>) -> bool {
    if s.cfg.local_renders && s.cfg.render_workers > 0 {
        return true;
    }
    let fresh = AppState::now() - 120;
    s.db
        .node_list()
        .await
        .map(|ns| ns.iter().any(|n| !n.disabled && n.last_seen > fresh))
        .unwrap_or(false)
}

/// Strip params a job submitter may not control, so a device job requeued to
/// a server worker still renders where the worker says.
fn sanitize_export_params(params: &Value) -> Result<Value, String> {
    let mut p = match params {
        Value::Null => json!({}),
        Value::Object(_) => params.clone(),
        _ => return Err("params must be an object".into()),
    };
    let o = p.as_object_mut().unwrap();
    for k in ["path", "wait", "sequence"] {
        o.remove(k);
    }
    if let Some(settings) = o.get_mut("settings").and_then(Value::as_object_mut) {
        for k in ["path", "sink", "output_file"] {
            settings.remove(k);
        }
    }
    if serde_json::to_string(&p).map_err(|e| e.to_string())?.len() > 32 * 1024 {
        return Err("params too large".into());
    }
    Ok(p)
}

async fn create_render(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<RenderReq>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if req.mode != "server" && req.mode != "device" {
        return err(StatusCode::BAD_REQUEST, "mode must be server or device");
    }
    if req.mode == "server" && !server_render_capacity(&s).await {
        return err(StatusCode::CONFLICT, "no server render capacity");
    }
    let params = match sanitize_export_params(&req.params) {
        Ok(p) => p,
        Err(e) => return err(StatusCode::BAD_REQUEST, &e),
    };
    let output = req.output.trim().chars().take(80).collect::<String>();
    let output = if output.is_empty() {
        "export".into()
    } else if files::valid_project_name_or_err(&output).is_err() {
        return err(StatusCode::BAD_REQUEST, "bad output name");
    } else {
        output
    };
    let paths = match render::project_files(&s, &p.dir).await {
        Ok(v) => v,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let spec = RenderSpec {
        sequence: req.sequence,
        output: output.clone(),
        params,
        media: render::stage_media(&paths),
    };
    let spec = match serde_json::to_string(&spec) {
        Ok(s) => s,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    };
    let device = req.mode == "device";
    let job = RenderJob {
        id: model::new_id(),
        project_id: id.clone(),
        user_id: session.user.id.clone(),
        status: if device { "running".into() } else { "queued".into() },
        mode: req.mode.clone(),
        spec,
        output_name: output,
        progress: 0.0,
        error: String::new(),
        worker: if device { "device".into() } else { String::new() },
        attempts: 0,
        created_at: AppState::now(),
        finished_at: 0,
    };
    if let Err(e) = s.db.job_create(&job).await {
        return match e {
            DbError::Conflict => err(
                StatusCode::CONFLICT,
                "a render is already queued or running for this project",
            ),
            other => db_resp(other),
        };
    }
    if device {
        let _ = s
            .db
            .job_progress(&job.id, &job.worker, 0.0, AppState::now() + 90)
            .await;
    }
    let _ = s
        .db
        .lock_acquire(
            &id,
            "render",
            &job.id,
            &session.user.username,
            AppState::now() + 86_400,
            AppState::now(),
            false,
        )
        .await;
    s.audit(
        "project",
        &session.user,
        "render_queued",
        &p.display_name,
        &job.output_name,
        "",
    )
    .await;
    Json(json!(job)).into_response()
}

/// Sequences in the project's FilmCraft file plus whether server renders are
/// possible, for the render dialog.
async fn render_info(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let server_render = server_render_capacity(&s).await;
    let fc_key = format!("{}/{}", p.dir, files::PROJECT_FILE);
    // The inspect is only as fresh as the fcproj blob; reuse it while the
    // blob's mtime and size are unchanged.
    let meta = s
        .blobs
        .list(&p.dir)
        .await
        .ok()
        .and_then(|(_, objs)| objs.into_iter().find(|o| o.key == fc_key))
        .map(|o| (o.modified, o.size));
    if let Some((m, sz)) = meta {
        if let Some((cm, cs, cached)) = s.inspect_cache.lock().unwrap().get(&fc_key) {
            if *cm == m && *cs == sz {
                let mut out = cached.clone();
                out["serverRender"] = json!(server_render);
                return Json(out).into_response();
            }
        }
    }
    let dir = s
        .cfg
        .data_dir
        .join("inspect")
        .join(model::new_id());
    if tokio::fs::create_dir_all(&dir).await.is_err() {
        return err(StatusCode::INTERNAL_SERVER_ERROR, "stage failed");
    }
    let fcproj = dir.join(files::PROJECT_FILE);
    let got = match render::blob_download(
        &s.blobs,
        &format!("{}/{}", p.dir, files::PROJECT_FILE),
        &fcproj,
    )
    .await
    {
        Ok(()) => true,
        Err(_) => false,
    };
    if !got {
        let _ = tokio::fs::remove_dir_all(&dir).await;
        return Json(json!({"sequences": [], "serverRender": server_render, "project": false}))
            .into_response();
    }
    let cli = s.cfg.filmcraft_cli.clone();
    let inspect = async move {
        let mut mcp = render::Mcp::spawn(&cli, &fcproj).await?;
        mcp.request(
            "tools/call",
            json!({"name": "command_run", "arguments": {"id": "project.inspect", "params": {}}}),
        )
        .await
    };
    let res = tokio::time::timeout(std::time::Duration::from_secs(30), inspect).await;
    let _ = tokio::fs::remove_dir_all(&dir).await;
    let text = match res {
        Ok(Ok(v)) => v["content"]
            .as_array()
            .and_then(|c| c.first())
            .and_then(|c| c["text"].as_str())
            .unwrap_or("")
            .to_string(),
        Ok(Err(e)) => return err(StatusCode::BAD_GATEWAY, &format!("filmcraft: {e}")),
        Err(_) => return err(StatusCode::BAD_GATEWAY, "filmcraft inspect timed out"),
    };
    let info: Value = match serde_json::from_str(&text) {
        Ok(v) => v,
        Err(e) => return err(StatusCode::BAD_GATEWAY, &format!("inspect: {e}")),
    };
    fn seqs(bin: &Value, out: &mut Vec<Value>) {
        if let Some(children) = bin["children"].as_array() {
            for c in children {
                match c["type"].as_str() {
                    Some("Sequence")
                    | Some("Multi-Camera Source Sequence")
                    | Some("Merged Clip") => out.push(json!({
                        "id": c["item"], "name": c["name"] })),
                    _ => seqs(c, out),
                }
            }
        }
    }
    let mut sequences = Vec::new();
    seqs(&info["root"], &mut sequences);
    let out = json!({
        "sequences": sequences,
        "activeSequence": info["activeSequence"],
        "serverRender": server_render,
        "project": true,
    });
    if let Some((m, sz)) = meta {
        let mut cache = s.inspect_cache.lock().unwrap();
        if cache.len() >= 512 {
            cache.clear();
        }
        cache.insert(fc_key, (m, sz, out.clone()));
    }
    Json(out).into_response()
}

/// A device-mode render posting its progress; the response tells the page
/// whether the job was canceled so it can stop.
async fn render_progress(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<Value>,
) -> Response {
    let job = match device_render_job(&s, &session, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    if job.status != "running" {
        return Json(json!({"ok": true, "canceled": true})).into_response();
    }
    let canceled = s.cancels.lock().unwrap().contains(&id);
    if !canceled {
        let p = req["progress"].as_f64().unwrap_or(0.0).clamp(0.0, 1.0);
        let _ = s
            .db
            .job_progress(&id, &job.worker, p, AppState::now() + 90)
            .await;
    }
    Json(json!({"ok": true, "canceled": canceled})).into_response()
}

/// A device-mode render reporting success or failure; the output upload is a
/// normal project file PUT, done by the page before this call.
async fn render_finish(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<Value>,
) -> Response {
    let job = match device_render_job(&s, &session, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    if job.status != "running" {
        return Json(json!({"ok": true})).into_response();
    }
    let e = req["error"].as_str().unwrap_or("").chars().take(500).collect::<String>();
    let status = if e.is_empty() { "done" } else { "failed" };
    let _ = s
        .db
        .job_finish(&id, &job.worker, status, &e, AppState::now())
        .await;
    let _ = s
        .db
        .lock_release(&job.project_id, "render", &job.id)
        .await;
    if e.is_empty() {
        if let Ok(p) = s.db.project_by_id(&job.project_id).await {
            s.audit(
                "project",
                &session.user,
                "render_done",
                &p.display_name,
                &job.output_name,
                "",
            )
            .await;
        }
    }
    Json(json!({"ok": true})).into_response()
}

async fn device_render_job(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<RenderJob, Response> {
    let job = s
        .db
        .job_by_id(id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such render"))?;
    if job.mode != "device" {
        return Err(err(StatusCode::BAD_REQUEST, "not a device render"));
    }
    if job.user_id != session.user.id {
        return Err(err(StatusCode::FORBIDDEN, "not your render"));
    }
    Ok(job)
}

async fn cancel_render(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let job = match s.db.job_by_id(&id).await {
        Ok(j) => j,
        Err(_) => return err(StatusCode::NOT_FOUND, "no such render"),
    };
    let p = match owned_project(&s, &session, &job.project_id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if job.status != "queued" && job.status != "running" {
        return err(StatusCode::CONFLICT, "render already finished");
    }
    if job.status == "running" {
        s.cancels.lock().unwrap().insert(id.clone());
    }
    let _ = s
        .db
        .job_finish(&id, &job.worker, "canceled", "", AppState::now())
        .await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
    s.audit(
        "project",
        &session.user,
        "render_canceled",
        &p.display_name,
        &job.output_name,
        "",
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

/// Resubmit a finished render with the same sequence, output and params. The
/// media list is re-staged from the current project files.
async fn retry_render(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let job = match s.db.job_by_id(&id).await {
        Ok(j) => j,
        Err(_) => return err(StatusCode::NOT_FOUND, "no such render"),
    };
    let p = match owned_project(&s, &session, &job.project_id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if job.status == "queued" || job.status == "running" {
        return err(StatusCode::CONFLICT, "render still active");
    }
    if job.mode == "server" && !server_render_capacity(&s).await {
        return err(StatusCode::CONFLICT, "no server render capacity");
    }
    let spec: Value = match serde_json::from_str(&job.spec) {
        Ok(v) => v,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    };
    let paths = match render::project_files(&s, &p.dir).await {
        Ok(v) => v,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let spec = RenderSpec {
        sequence: spec["sequence"].as_u64().unwrap_or(0),
        output: job.output_name.clone(),
        params: spec["params"].clone(),
        media: render::stage_media(&paths),
    };
    let spec = match serde_json::to_string(&spec) {
        Ok(s) => s,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    };
    let device = job.mode == "device";
    let next = RenderJob {
        id: model::new_id(),
        project_id: job.project_id.clone(),
        user_id: session.user.id.clone(),
        status: if device { "running".into() } else { "queued".into() },
        mode: job.mode.clone(),
        spec,
        output_name: job.output_name.clone(),
        progress: 0.0,
        error: String::new(),
        worker: if device { "device".into() } else { String::new() },
        attempts: 0,
        created_at: AppState::now(),
        finished_at: 0,
    };
    if let Err(e) = s.db.job_create(&next).await {
        return match e {
            DbError::Conflict => err(
                StatusCode::CONFLICT,
                "a render is already queued or running for this project",
            ),
            other => db_resp(other),
        };
    }
    if device {
        let _ = s
            .db
            .job_progress(&next.id, &next.worker, 0.0, AppState::now() + 90)
            .await;
    }
    let _ = s
        .db
        .lock_acquire(
            &job.project_id,
            "render",
            &next.id,
            &session.user.username,
            AppState::now() + 86_400,
            AppState::now(),
            false,
        )
        .await;
    s.audit(
        "project",
        &session.user,
        "render_queued",
        &p.display_name,
        &next.output_name,
        "",
    )
    .await;
    Json(json!(next)).into_response()
}

/// Delete a finished render's history row. Active renders must be canceled
/// first; the exported files stay in the project.
async fn delete_render(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let job = match s.db.job_by_id(&id).await {
        Ok(j) => j,
        Err(_) => return err(StatusCode::NOT_FOUND, "no such render"),
    };
    let p = match owned_project(&s, &session, &job.project_id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if job.status == "queued" || job.status == "running" {
        return err(StatusCode::CONFLICT, "render still active");
    }
    match s.db.job_delete(&id).await {
        Ok(()) => {}
        Err(e) => return db_resp(e),
    }
    s.audit(
        "project",
        &session.user,
        "render_deleted",
        &p.display_name,
        &job.output_name,
        "",
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

// ---------- server settings ----------

async fn get_settings(State(s): State<Arc<AppState>>, session: Session) -> Response {
    if session.user.role != Role::Owner {
        return err(StatusCode::FORBIDDEN, "owner only");
    }
    let effective = match s.db.setting_get("trusted_proxies").await {
        Ok(Some(v)) => v,
        _ => s
            .cfg
            .trusted_proxies
            .iter()
            .map(|n| n.to_string())
            .collect::<Vec<_>>()
            .join(", "),
    };
    Json(json!({"trustedProxies": effective})).into_response()
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct SettingsReq {
    trusted_proxies: String,
}

async fn put_settings(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<SettingsReq>,
) -> Response {
    if session.user.role != Role::Owner {
        return err(StatusCode::FORBIDDEN, "owner only");
    }
    let list = req.trusted_proxies.trim();
    let nets = match auth::parse_nets(list) {
        Ok(n) => n,
        Err(e) => return err(StatusCode::BAD_REQUEST, &e),
    };
    if let Err(e) = s.db.setting_set("trusted_proxies", list).await {
        return db_resp(e);
    }
    *s.trusted.write().unwrap() = nets;
    s.audit("account", &session.user, "update_settings", "trusted_proxies", list, "")
        .await;
    Json(json!({"ok": true})).into_response()
}

// ---------- render nodes ----------

async fn list_nodes(State(s): State<Arc<AppState>>, session: Session) -> Response {
    if session.user.role < Role::Admin {
        return err(StatusCode::FORBIDDEN, "admin only");
    }
    match s.db.node_list().await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct NodeReq {
    name: String,
}

/// Worker identities that are synthesized by the server itself ("device"
/// jobs and the built-in "local-N" workers). A remote node taking one of
/// these names could claim and finish those jobs, so they are reserved.
fn reserved_worker_name(name: &str) -> bool {
    let n = name.to_ascii_lowercase();
    n == "device" || n.starts_with("local-")
}

async fn create_node(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<NodeReq>,
) -> Response {
    if session.user.role < Role::Admin {
        return err(StatusCode::FORBIDDEN, "admin only");
    }
    let name: String = req.name.trim().chars().take(64).collect();
    if name.is_empty() {
        return err(StatusCode::BAD_REQUEST, "name required");
    }
    if reserved_worker_name(&name) {
        return err(StatusCode::BAD_REQUEST, "reserved worker name");
    }
    let token = model::new_token();
    let node = model::RenderNode {
        id: model::new_id(),
        name: name.clone(),
        disabled: false,
        created_at: AppState::now(),
        last_seen: 0,
    };
    if let Err(e) = s.db.node_create(&node, &model::token_hash(&token)).await {
        if matches!(e, DbError::Conflict) {
            return err(StatusCode::CONFLICT, "node name already in use");
        }
        return db_resp(e);
    }
    s.audit("account", &session.user, "create_node", &name, "", "")
        .await;
    Json(json!({"id": node.id, "name": node.name, "token": token})).into_response()
}

#[derive(Deserialize)]
struct NodeUpdateReq {
    disabled: bool,
}

async fn update_node(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<NodeUpdateReq>,
) -> Response {
    if session.user.role < Role::Admin {
        return err(StatusCode::FORBIDDEN, "admin only");
    }
    let name = node_name(&s, &id).await;
    match s.db.node_set_disabled(&id, req.disabled).await {
        Ok(()) => {
            s.audit(
                "account",
                &session.user,
                "update_node",
                &name,
                &format!("disabled={}", req.disabled),
                "",
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) => db_resp(e),
    }
}

async fn delete_node(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    if session.user.role < Role::Admin {
        return err(StatusCode::FORBIDDEN, "admin only");
    }
    let name = node_name(&s, &id).await;
    match s.db.node_delete(&id).await {
        Ok(()) => {
            s.audit("account", &session.user, "delete_node", &name, "", "")
                .await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) => db_resp(e),
    }
}

/// Best-effort node name for audit entries; falls back to the id.
async fn node_name(s: &Arc<AppState>, id: &str) -> String {
    s.db.node_list()
        .await
        .ok()
        .and_then(|ns| ns.into_iter().find(|n| n.id == id).map(|n| n.name))
        .unwrap_or_else(|| id.to_string())
}

// ---------- worker (remote render nodes) ----------

async fn worker_poll(State(s): State<Arc<AppState>>, node: NodeSession) -> Response {
    let job = match s.db.job_next_queued().await {
        Ok(Some(j)) => j,
        _ => return Json(json!({"job": null})).into_response(),
    };
    let lease = AppState::now() + 90;
    match s.db.job_claim(&job.id, &node.node.name, lease).await {
        Ok(true) => Json(json!({"job": job})).into_response(),
        _ => Json(json!({"job": null})).into_response(),
    }
}

async fn worker_job_guard(
    s: &Arc<AppState>,
    node: &NodeSession,
    id: &str,
) -> Result<RenderJob, Response> {
    let job = s
        .db
        .job_by_id(id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such job"))?;
    if job.worker != node.node.name {
        return Err(err(StatusCode::FORBIDDEN, "not your job"));
    }
    Ok(job)
}

#[derive(Deserialize)]
struct WorkerFileQuery {
    path: String,
}

async fn worker_file(
    State(s): State<Arc<AppState>>,
    node: NodeSession,
    Path(id): Path<String>,
    Query(q): Query<WorkerFileQuery>,
    headers: HeaderMap,
) -> Response {
    let job = match worker_job_guard(&s, &node, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    if job.status != "running" {
        return err(StatusCode::CONFLICT, "job not running");
    }
    let project = match s.db.project_by_id(&job.project_id).await {
        Ok(p) => p,
        Err(e) => return db_resp(e),
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    serve_blob(&s, &blob_key(&project.dir, &key), &key, &headers, false).await
}

#[derive(Deserialize)]
struct ProgressReq {
    progress: f64,
}

async fn worker_progress(
    State(s): State<Arc<AppState>>,
    node: NodeSession,
    Path(id): Path<String>,
    Json(req): Json<ProgressReq>,
) -> Response {
    let job = match worker_job_guard(&s, &node, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    let canceled =
        job.status == "canceled" || s.cancels.lock().unwrap().contains(&id);
    if canceled {
        return Json(json!({"ok": true, "canceled": true})).into_response();
    }
    let _ = s
        .db
        .job_progress(
            &id,
            &job.worker,
            req.progress.clamp(0.0, 1.0),
            AppState::now() + 90,
        )
        .await;
    Json(json!({"ok": true})).into_response()
}

async fn worker_complete(
    State(s): State<Arc<AppState>>,
    node: NodeSession,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
    body: Body,
) -> Response {
    let job = match worker_job_guard(&s, &node, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    if job.status != "running" {
        return err(StatusCode::CONFLICT, "job not running");
    }
    let project = match s.db.project_by_id(&job.project_id).await {
        Ok(p) => p,
        Err(e) => return db_resp(e),
    };
    let name = if q.path.is_empty() {
        format!("{}.mp4", job.output_name)
    } else {
        q.path
    };
    let key = match files::export_key(&name) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    let (tmp, len) = match spool_body(&s, body, s.cfg.max_upload).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let put = async {
        let mut f = tokio::fs::File::open(&tmp).await.map_err(|e| e.to_string())?;
        s.blobs.put(&blob_key(&project.dir, &key), len, &mut f).await
    }
    .await;
    let _ = tokio::fs::remove_file(&tmp).await;
    if let Err(e) = put {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
    }
    if q.done {
        let _ = s
            .db
            .job_finish(&id, &job.worker, "done", "", AppState::now())
            .await;
        let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
        s.cancels.lock().unwrap().remove(&id);
        if let Ok(u) = s.db.user_by_id(&job.user_id).await {
            s.audit("project", &u, "render_done", &project.display_name, &name, "")
                .await;
        }
    }
    Json(json!({"ok": true})).into_response()
}

#[derive(Deserialize)]
struct FailReq {
    error: String,
}

async fn worker_fail(
    State(s): State<Arc<AppState>>,
    node: NodeSession,
    Path(id): Path<String>,
    Json(req): Json<FailReq>,
) -> Response {
    let job = match worker_job_guard(&s, &node, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    let msg: String = req.error.chars().take(500).collect();
    let _ = s
        .db
        .job_finish(&id, &job.worker, "failed", &msg, AppState::now())
        .await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
    s.cancels.lock().unwrap().remove(&id);
    Json(json!({"ok": true})).into_response()
}
