use std::sync::Arc;

use axum::body::Body;
use axum::extract::{Path, Query, State};
use axum::http::{header, HeaderMap, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{get, patch, post};
use axum::{Json, Router};
use futures::StreamExt;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::auth::{
    self, client_ip, err, login_failed, login_ok, login_throttle, AppState, NodeSession, Session,
};
use crate::files::{self, FsError};
use crate::model::{self, can_manage, Project, ProjectGroup, RenderJob, RenderSpec, Role, User};
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
        .route("/roles", get(roles))
        .route("/accounts", get(list_accounts).post(create_account))
        .route("/accounts/{id}", patch(update_account))
        .route("/accounts/{id}/password", post(reset_password))
        .route("/accounts/{id}/status", post(set_status))
        .route("/audit", get(audit))
        .route("/projects", get(list_projects).post(create_project))
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
        .route("/projects/{id}/locks", post(lock_acquire).delete(lock_release))
        .route("/projects/{id}/locks/release", post(lock_release))
        .route("/projects/{id}/locks/heartbeat", post(lock_heartbeat))
        .route("/projects/{id}/renders", get(list_renders).post(create_render))
        .route("/renders/{id}/cancel", post(cancel_render))
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
    if let Err(e) = s.db.create_user(&u, &hash).await {
        return db_resp(e);
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
    match s.db.projects_by_owner(&session.user.id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
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

async fn owned_project(s: &Arc<AppState>, session: &Session, id: &str) -> Result<Project, Response> {
    let p = s
        .db
        .project_by_id(id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such project"))?;
    if p.owner_id != session.user.id && session.user.role != Role::Owner {
        return Err(err(StatusCode::FORBIDDEN, "not your project"));
    }
    Ok(p)
}

async fn get_project(State(s): State<Arc<AppState>>, session: Session, Path(id): Path<String>) -> Response {
    match owned_project(&s, &session, &id).await {
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
}

async fn list_files(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
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
    let _ = std::fs::remove_file(&tmp);
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
    let _ = std::fs::create_dir_all(tmp.parent().unwrap());
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
            Ok(()) => Json(json!({"ok": true})).into_response(),
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
        Err(e) => err(StatusCode::NOT_FOUND, &e),
    }
}

async fn download(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
    headers: HeaderMap,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    serve_blob(&s, &blob_key(&p.dir, &key), &key, &headers, q.dl).await
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
    let v = v.strip_prefix("bytes=")?;
    let (a, b) = v.split_once('-')?;
    let (start, end) = if a.is_empty() {
        let n: u64 = b.parse().ok()?;
        (size.saturating_sub(n), size - 1)
    } else {
        let s: u64 = a.parse().ok()?;
        let e = if b.is_empty() { size - 1 } else { b.parse().ok()? };
        (s, e.min(size - 1))
    };
    if start > end {
        return None;
    }
    Some((start, end))
}

#[cfg(test)]
mod tests {
    use super::parse_range;

    #[test]
    fn ranges() {
        assert_eq!(parse_range("bytes=0-99", 1000), Some((0, 99)));
        assert_eq!(parse_range("bytes=500-", 1000), Some((500, 999)));
        assert_eq!(parse_range("bytes=-100", 1000), Some((900, 999)));
        assert_eq!(parse_range("bytes=0-9999", 1000), Some((0, 999)));
        assert_eq!(parse_range("bytes=2000-3000", 1000), None);
        assert_eq!(parse_range("garbage", 1000), None);
        assert_eq!(parse_range("bytes=50-20", 1000), None);
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

async fn list_renders(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let _p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    match s.db.jobs_by_project(&id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn create_render(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<RenderSpec>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if req.clips.is_empty() || req.clips.len() > 200 {
        return err(StatusCode::BAD_REQUEST, "render needs 1-200 clips");
    }
    for c in &req.clips {
        if files::clean_rel_key(&c.path).is_err() {
            return err(StatusCode::BAD_REQUEST, &format!("bad clip path {}", c.path));
        }
    }
    if let Some(a) = &req.audio {
        if files::clean_rel_key(&a.path).is_err() {
            return err(StatusCode::BAD_REQUEST, "bad audio path");
        }
    }
    let spec = serde_json::to_string(&req).unwrap();
    let job = RenderJob {
        id: model::new_id(),
        project_id: id.clone(),
        user_id: session.user.id.clone(),
        status: "queued".into(),
        mode: "server".into(),
        spec,
        output_name: if req.output.is_empty() {
            "export".into()
        } else {
            req.output.chars().take(80).collect()
        },
        progress: 0.0,
        error: String::new(),
        worker: String::new(),
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

async fn cancel_render(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let job = match s.db.job_by_id(&id).await {
        Ok(j) => j,
        Err(_) => return err(StatusCode::NOT_FOUND, "no such render"),
    };
    let _p = match owned_project(&s, &session, &job.project_id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if job.status != "queued" && job.status != "running" {
        return err(StatusCode::CONFLICT, "render already finished");
    }
    s.cancels.lock().unwrap().insert(id.clone());
    let _ = s
        .db
        .job_finish(&id, "canceled", "", AppState::now())
        .await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
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
    let token = model::new_token();
    let node = model::RenderNode {
        id: model::new_id(),
        name: name.clone(),
        disabled: false,
        created_at: AppState::now(),
        last_seen: 0,
    };
    if let Err(e) = s.db.node_create(&node, &model::token_hash(&token)).await {
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
    match s.db.node_set_disabled(&id, req.disabled).await {
        Ok(()) => Json(json!({"ok": true})).into_response(),
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
    match s.db.node_delete(&id).await {
        Ok(()) => Json(json!({"ok": true})).into_response(),
        Err(e) => db_resp(e),
    }
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
    if job.worker != node.node.name && job.status == "running" {
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
    let _job = match worker_job_guard(&s, &node, &id).await {
        Ok(j) => j,
        Err(r) => return r,
    };
    let canceled = s.cancels.lock().unwrap().contains(&id);
    if canceled {
        return Json(json!({"ok": true, "canceled": true})).into_response();
    }
    let _ = s
        .db
        .job_progress(&id, req.progress.clamp(0.0, 1.0), AppState::now() + 90)
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
    let project = match s.db.project_by_id(&job.project_id).await {
        Ok(p) => p,
        Err(e) => return db_resp(e),
    };
    let name = if q.path.is_empty() {
        format!("{}.mp4", job.output_name)
    } else {
        q.path
    };
    let (tmp, len) = match spool_body(&s, body, s.cfg.max_upload).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let put = async {
        let mut f = tokio::fs::File::open(&tmp).await.map_err(|e| e.to_string())?;
        s.blobs
            .put(&blob_key(&project.dir, &format!("Exports/{name}")), len, &mut f)
            .await
    }
    .await;
    let _ = std::fs::remove_file(&tmp);
    if let Err(e) = put {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
    }
    let _ = s.db.job_finish(&id, "done", "", AppState::now()).await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
    if let Ok(u) = s.db.user_by_id(&job.user_id).await {
        s.audit("project", &u, "render_done", &project.display_name, &name, "")
            .await;
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
    let _ = s.db.job_finish(&id, "failed", &msg, AppState::now()).await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
    Json(json!({"ok": true})).into_response()
}
