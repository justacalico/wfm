use std::sync::Arc;

use axum::body::{Body, Bytes};
use axum::extract::{Path, Query, State};
use axum::http::{header, HeaderMap, HeaderValue, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::{delete, get, patch, post, put};
use axum::{Json, Router};
use futures::StreamExt;
use serde::Deserialize;
use serde_json::{json, Value};

use crate::auth::{
    self, client_ip, err, link_throttle, login_failed, login_ok, login_throttle, AppState,
    ChunkUpload, NodeSession, Session,
};
use crate::files::{self, FsError};
use crate::model::{
    self, can_manage, lineage_has, Assignment, AssignmentCopy, InviteCode, Project, ProjectGroup,
    ProjectLink, ProjectShare, RenderJob, RenderSpec, Role, User,
};
use crate::render;
use crate::store::{AuditFilter, DbError, LockOutcome};

fn blob_key(dir: &str, rel: &str) -> String {
    format!("{}/{}", dir.trim_matches('/'), rel.trim_matches('/'))
}

fn key_ext(key: &str) -> Option<String> {
    let name = key.rsplit('/').next().unwrap_or(key);
    if !name.contains('.') {
        return None;
    }
    name.rsplit('.').next().map(|e| e.to_lowercase())
}

pub fn router(state: Arc<AppState>) -> Router {
    let api = Router::new()
        .route("/health", get(health))
        .route("/version", get(version))
        .route("/update-check", get(update_check))
        .route("/setup", get(setup_status).post(setup_owner))
        .route("/login", post(login))
        .route("/logout", post(logout))
        .route("/handoff", get(handoff_redeem).post(handoff_create))
        .route("/me", get(me))
        .route("/me/avatar", put(upload_avatar))
        .route("/users/{id}/avatar", get(avatar))
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
        .route("/accounts/{id}/projects", get(account_projects))
        .route("/share-targets", get(share_targets))
        .route("/classes", get(list_classes).post(create_class))
        .route("/classes/{id}", patch(rename_class).delete(delete_class))
        .route(
            "/classes/{id}/teachers",
            get(list_class_teachers).post(add_class_teacher),
        )
        .route("/classes/{id}/teachers/{uid}", delete(remove_class_teacher))
        .route("/invites", get(list_invites).post(create_invite))
        .route("/invites/{id}", get(invite_preview).delete(revoke_invite))
        .route("/invites/{id}/redeem", post(redeem_invite))
        .route("/audit", get(audit))
        .route("/projects", get(list_projects).post(create_project))
        .route("/projects/{id}/take-over", post(take_over_project))
        .route("/projects/{id}/duplicate", post(duplicate_project))
        .route(
            "/projects/{id}/comments",
            get(list_comments).post(add_comment),
        )
        .route(
            "/projects/{id}/comments/{cid}",
            patch(edit_comment).delete(delete_comment),
        )
        .route("/projects/{id}/submit", post(submit_project))
        .route("/projects/{id}/review", post(review_project))
        .route("/projects/{id}/assign", post(assign_project))
        .route("/projects/{id}/assignment", get(project_assignment))
        .route("/assignments", get(my_assignments))
        .route(
            "/assignments/{id}",
            patch(update_assignment).delete(delete_assignment),
        )
        .route(
            "/projects/{id}/shares",
            get(list_project_shares).post(create_share),
        )
        .route(
            "/projects/{id}/shares/{sid}",
            patch(update_share).delete(delete_share),
        )
        .route("/shares", get(list_my_shares))
        .route("/shares/{sid}/accept", post(accept_share))
        .route("/shares/{sid}/decline", post(decline_share))
        .route("/auto-shares", get(list_auto_shares).post(add_auto_share))
        .route("/auto-shares/{id}", delete(delete_auto_share))
        .route("/notifications", get(my_notifications))
        .route("/notifications/read-all", post(notifications_read_all))
        .route("/notifications/{id}/read", post(notification_read))
        .route("/projects/{id}/links", get(list_links).post(create_link))
        .route("/projects/{id}/links/{lid}", delete(revoke_link))
        .route("/link/{token}", get(link_resolve))
        .route("/link/{token}/file", get(link_file))
        .route("/projects/{id}/usage", get(project_usage))
        .route("/accounts/{id}/usage", get(account_usage))
        .route(
            "/projects/{id}",
            get(get_project)
                .patch(update_project)
                .delete(delete_project),
        )
        .route("/groups", get(list_groups).post(create_group))
        .route("/groups/{id}", patch(rename_group).delete(delete_group))
        .route(
            "/projects/{id}/files",
            get(list_files).put(upload_file).delete(delete_file),
        )
        .route("/projects/{id}/manifest", get(project_manifest))
        .route("/projects/{id}/files/upload", post(upload_start))
        .route("/projects/{id}/files/mkdir", post(mkdir))
        .route("/projects/{id}/files/move", post(move_file))
        .route("/uploads/{id}", get(upload_status).delete(upload_cancel))
        .route("/uploads/{id}/chunk", put(upload_chunk))
        .route("/uploads/{id}/complete", post(upload_complete))
        .route("/projects/{id}/download", get(download))
        .route("/projects/{id}/thumb", get(thumb))
        .route("/projects/{id}/zip", get(zip_download))
        .route(
            "/projects/{id}/locks",
            post(lock_acquire).delete(lock_release),
        )
        .route("/projects/{id}/locks/release", post(lock_release))
        .route("/projects/{id}/locks/heartbeat", post(lock_heartbeat))
        .route(
            "/projects/{id}/renders",
            get(list_renders).post(create_render),
        )
        .route("/projects/{id}/render-info", get(render_info))
        .route("/renders/{id}/cancel", post(cancel_render))
        .route("/renders/{id}/retry", post(retry_render))
        .route("/renders/{id}", delete(delete_render))
        .route("/renders/{id}/progress", post(render_progress))
        .route("/renders/{id}/finish", post(render_finish))
        .route("/settings", get(get_settings).put(put_settings))
        .route("/shortcuts", get(get_shortcuts).put(put_shortcuts))
        .route("/shortcuts/catalog", get(shortcut_catalog))
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

fn parse_semver(s: &str) -> Option<(u64, u64, u64)> {
    let v = s.trim().trim_start_matches(['v', 'V']);
    let core = v.split(['-', '+']).next()?;
    let parts: Option<Vec<u64>> = core.split('.').map(|p| p.parse().ok()).collect();
    match parts?.as_slice() {
        [a, b] => Some((*a, *b, 0)),
        [a, b, c] => Some((*a, *b, *c)),
        _ => None,
    }
}

async fn fetch_update_check() -> Result<Value, String> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .map_err(|e| e.to_string())?;
    let r = client
        .get("https://gitlab.com/api/v4/projects/HttpAnimations%2Fwfm/releases?per_page=100&order_by=released_at&sort=desc")
        .header(reqwest::header::USER_AGENT, "wfm")
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !r.status().is_success() {
        return Err(format!("releases: {}", r.status()));
    }
    let items: Vec<Value> = r.json().await.map_err(|e| e.to_string())?;
    let mut best: Option<((u64, u64, u64), String)> = None;
    for e in &items {
        let tag = e["tag_name"].as_str().unwrap_or("");
        if let Some(v) = parse_semver(tag) {
            if best.as_ref().is_none_or(|(b, _)| v > *b) {
                best = Some((v, tag.to_string()));
            }
        }
    }
    let Some((v, tag)) = best else {
        return Err("no releases".to_string());
    };
    if let Some(now) = parse_semver(env!("CARGO_PKG_VERSION")) {
        if v <= now {
            return Ok(json!({"upToDate": true}));
        }
    }
    Ok(json!({
        "latest": format!("{}.{}.{}", v.0, v.1, v.2),
        "tag": tag,
        "url": format!("https://gitlab.com/HttpAnimations/wfm/-/releases/{tag}"),
    }))
}

async fn update_check(State(s): State<Arc<AppState>>, _session: Session) -> Response {
    if let Some((at, v)) = s.update_check.lock().unwrap().clone() {
        if at.elapsed() < std::time::Duration::from_secs(300) {
            return Json(v).into_response();
        }
    }
    match fetch_update_check().await {
        Ok(v) => {
            *s.update_check.lock().unwrap() = Some((std::time::Instant::now(), v.clone()));
            Json(v).into_response()
        }
        Err(e) => err(StatusCode::BAD_GATEWAY, &e),
    }
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
        return err(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        );
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
        avatar: String::new(),
        quota_bytes: 0,
        created_by: String::new(),
        class_id: String::new(),
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
    if let Err(e) =
        s.db.create_session(&model::token_hash(&token), &u.id, &csrf, expires, &ip, "")
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
    s.audit("account", &user, "login", &user.username, "", &user.lineage)
        .await;
    session_response(&s, &parts, &user, &ip).await
}

async fn session_response(
    s: &Arc<AppState>,
    parts: &axum::http::request::Parts,
    user: &User,
    ip: &std::net::IpAddr,
) -> Response {
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
    if let Err(e) =
        s.db.create_session(
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

fn handoff_to(to: &str) -> Option<String> {
    if to.starts_with('/') && !to.starts_with("//") && to.len() <= 2000 {
        Some(to.to_string())
    } else {
        None
    }
}

#[derive(Deserialize)]
struct HandoffReq {
    to: String,
}

// The desktop client trades a session for a one-time URL a webview (or the
// system browser) can open: GET /handoff mints the cookie, then redirects.
async fn handoff_create(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<HandoffReq>,
) -> Response {
    if handoff_to(&req.to).is_none() {
        return err(StatusCode::BAD_REQUEST, "bad destination");
    }
    let t = model::new_token();
    s.handoffs
        .lock()
        .unwrap()
        .insert(t.clone(), (session.user.id, AppState::now() + 60));
    Json(json!({"t": t})).into_response()
}

#[derive(Deserialize)]
struct HandoffQuery {
    t: String,
    to: Option<String>,
}

async fn handoff_redeem(
    State(s): State<Arc<AppState>>,
    parts: axum::http::request::Parts,
    Query(q): Query<HandoffQuery>,
) -> Response {
    let to =
        q.to.as_deref()
            .and_then(handoff_to)
            .unwrap_or_else(|| "/".to_string());
    let hit = s.handoffs.lock().unwrap().remove(&q.t);
    let Some((uid, exp)) = hit else {
        return err(StatusCode::UNAUTHORIZED, "expired link");
    };
    if exp < AppState::now() {
        return err(StatusCode::UNAUTHORIZED, "expired link");
    }
    let token = model::new_token();
    let csrf = model::new_token();
    let expires = AppState::now() + s.cfg.session_ttl;
    let ip = client_ip(&s, &parts).to_string();
    if let Err(e) =
        s.db.create_session(&model::token_hash(&token), &uid, &csrf, expires, &ip, "")
            .await
    {
        return db_resp(e);
    }
    let mut r = axum::response::Redirect::to(&to).into_response();
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

const AVATAR_MAX: u64 = 128 << 20;

fn avatar_ext(head: &[u8]) -> Option<&'static str> {
    if head.starts_with(b"\x89PNG") {
        Some("png")
    } else if head.starts_with(b"\xff\xd8\xff") {
        Some("jpg")
    } else if head.starts_with(b"GIF8") {
        Some("gif")
    } else if head.len() >= 12 && head.starts_with(b"RIFF") && &head[8..12] == b"WEBP" {
        Some("webp")
    } else {
        None
    }
}

async fn upload_avatar(
    State(s): State<Arc<AppState>>,
    session: Session,
    headers: HeaderMap,
    body: Body,
) -> Response {
    let len = headers
        .get(header::CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(0);
    if len > AVATAR_MAX {
        return err(StatusCode::PAYLOAD_TOO_LARGE, "image too large");
    }
    let (tmp, written) = match spool_body(&s, body, AVATAR_MAX).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let out = async {
        use tokio::io::{AsyncReadExt, AsyncSeekExt};
        let mut f = tokio::fs::File::open(&tmp)
            .await
            .map_err(|e| e.to_string())?;
        let mut head = [0u8; 12];
        let n = f.read(&mut head).await.map_err(|e| e.to_string())?;
        let ext = avatar_ext(&head[..n])
            .ok_or_else(|| "not a png, jpeg, gif or webp image".to_string())?;
        f.seek(std::io::SeekFrom::Start(0))
            .await
            .map_err(|e| e.to_string())?;
        let key = format!("avatars/{}/{}.{}", session.user.id, model::new_id(), ext);
        s.blobs.put(&key, written, &mut f).await?;
        if let Err(e) = s.db.set_user_avatar(&session.user.id, &key).await {
            let _ = s.blobs.delete(&key).await;
            return Err(e.to_string());
        }
        Ok(key)
    }
    .await;
    let _ = tokio::fs::remove_file(&tmp).await;
    let key = match out {
        Ok(k) => k,
        Err(e) => {
            if e.starts_with("not a png") {
                return err(StatusCode::UNSUPPORTED_MEDIA_TYPE, &e);
            }
            return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
        }
    };
    if !session.user.avatar.is_empty() && session.user.avatar != key {
        let _ = s.blobs.delete(&session.user.avatar).await;
    }
    s.audit(
        "account",
        &session.user,
        "avatar",
        &session.user.username,
        "",
        &session.user.lineage,
    )
    .await;
    Json(json!({"ok": true, "avatar": key})).into_response()
}

async fn avatar(
    State(s): State<Arc<AppState>>,
    _session: Session,
    Path(id): Path<String>,
    headers: HeaderMap,
) -> Response {
    let u = match s.db.user_by_id(&id).await {
        Ok(u) => u,
        Err(e) => return db_resp(e),
    };
    if u.avatar.is_empty() {
        return err(StatusCode::NOT_FOUND, "no avatar");
    }
    serve_blob(&s, &u.avatar, &u.avatar, &headers, false, None).await
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
        return err(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        );
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
    let _ =
        s.db.delete_user_sessions_except(&session.user.id, &session.token_hash)
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

async fn require_manager(
    s: &Arc<AppState>,
    session: &Session,
    target_id: &str,
) -> Result<User, Response> {
    let t =
        s.db.user_by_id(target_id)
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such account"))?;
    // A class's teachers administrate its members exactly like the chain that
    // created them, so co-teachers can run a co-taught class.
    let allowed = can_manage(&session.user, &t)
        || s.db
            .teaches_member(&session.user, &t)
            .await
            .unwrap_or(false);
    if !allowed {
        return Err(err(StatusCode::FORBIDDEN, "cannot manage this account"));
    }
    Ok(t)
}

/// Fetch a class the actor may put accounts into: theirs, or one owned by an
/// account they manage.
async fn require_class(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<model::Class, Response> {
    let c =
        s.db.class_by_id(id)
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such class"))?;
    if c.owner_id == session.user.id {
        return Ok(c);
    }
    let owner =
        s.db.user_by_id(&c.owner_id)
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such class"))?;
    if !can_manage(&session.user, &owner) {
        return Err(err(StatusCode::FORBIDDEN, "cannot manage this class"));
    }
    Ok(c)
}

/// Fetch a class the actor may put members into: theirs, one they co-teach, or
/// one owned by an account they manage.
async fn require_class_open(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<model::Class, Response> {
    let forbidden = match require_class(s, session, id).await {
        Ok(c) => return Ok(c),
        Err(r) if r.status() == StatusCode::FORBIDDEN => {
            drop(r);
            true
        }
        Err(r) => return Err(r),
    };
    if forbidden && s.db.co_teaches(id, &session.user.id).await.unwrap_or(false) {
        return s
            .db
            .class_by_id(id)
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such class"));
    }
    Err(err(StatusCode::FORBIDDEN, "cannot manage this class"))
}

/// Whether the actor may view a class's roster: owner, co-teacher, member, or
/// anyone who manages the owner.
async fn class_visible(s: &Arc<AppState>, session: &Session, c: &model::Class) -> bool {
    if c.owner_id == session.user.id || session.user.class_id == c.id {
        return true;
    }
    if s.db
        .co_teaches(&c.id, &session.user.id)
        .await
        .unwrap_or(false)
    {
        return true;
    }
    match s.db.user_by_id(&c.owner_id).await {
        Ok(owner) => can_manage(&session.user, &owner),
        Err(_) => false,
    }
}

/// `model::can_see` plus the database side of visibility: co-taught classes
/// link staff to members and to each other.
async fn can_see_db(s: &Arc<AppState>, actor: &User, target: &User) -> bool {
    model::can_see(actor, target)
        || s.db
            .shares_taught_class(actor, target)
            .await
            .unwrap_or(false)
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

/// Users the caller may share with: their subtree, their ancestry, and classmates.
async fn share_targets(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.visible_users(&session.user).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn list_classes(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.classes_for(&session.user).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct ClassReq {
    name: String,
}

async fn create_class(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<ClassReq>,
) -> Response {
    if !session.user.role.can_create() {
        return err(StatusCode::FORBIDDEN, "teachers only");
    }
    let name = req.name.trim();
    if !model::valid_project_name(name) {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    let c = model::Class {
        id: model::new_id(),
        owner_id: session.user.id.clone(),
        name: name.to_string(),
        unmanaged: false,
        members: 0,
        teachers: 0,
        created_at: AppState::now(),
    };
    if let Err(e) = s.db.create_class(&c).await {
        return match e {
            DbError::Conflict => err(StatusCode::CONFLICT, "name taken"),
            other => db_resp(other),
        };
    }
    s.audit(
        "account",
        &session.user,
        "class_create",
        &c.name,
        "",
        &session.user.lineage,
    )
    .await;
    Json(json!(c)).into_response()
}

async fn rename_class(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<ClassReq>,
) -> Response {
    let c = match require_class(&s, &session, &id).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    if c.unmanaged {
        return err(StatusCode::BAD_REQUEST, "cannot rename the unmanaged class");
    }
    let name = req.name.trim();
    if !model::valid_project_name(name) {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    match s.db.rename_class(&id, name).await {
        Ok(true) => {
            s.audit(
                "account",
                &session.user,
                "class_rename",
                name,
                "",
                &session.user.lineage,
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Ok(false) => err(StatusCode::NOT_FOUND, "no such class"),
        Err(DbError::Conflict) => err(StatusCode::CONFLICT, "name taken"),
        Err(e) => db_resp(e),
    }
}

async fn delete_class(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let c = match require_class(&s, &session, &id).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    if c.unmanaged {
        return err(StatusCode::BAD_REQUEST, "cannot delete the unmanaged class");
    }
    let owner = match s.db.user_by_id(&c.owner_id).await {
        Ok(u) => u,
        Err(e) => return db_resp(e),
    };
    let fallback = match s.db.unmanaged_class(&owner).await {
        Ok(c) => c,
        Err(e) => return db_resp(e),
    };
    match s.db.delete_class(&id, &fallback.id).await {
        Ok(()) => {
            s.audit(
                "account",
                &session.user,
                "class_delete",
                &c.name,
                "",
                &session.user.lineage,
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) => db_resp(e),
    }
}

async fn list_class_teachers(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let c = match s.db.class_by_id(&id).await {
        Ok(c) => c,
        Err(_) => return err(StatusCode::NOT_FOUND, "no such class"),
    };
    if !class_visible(&s, &session, &c).await {
        return err(StatusCode::FORBIDDEN, "cannot see this class");
    }
    match s.db.class_teachers(&id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct CoTeacherReq {
    username: String,
}

/// Attach an existing teacher account to the class as a co-teacher. Only the
/// main teacher (or anyone who can manage them) does this.
async fn add_class_teacher(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<CoTeacherReq>,
) -> Response {
    let c = match require_class(&s, &session, &id).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    let t = match s.db.user_by_name(req.username.trim()).await {
        Ok((u, _)) => u,
        Err(_) => return err(StatusCode::NOT_FOUND, "unknown user"),
    };
    if t.role < Role::Teacher {
        return err(StatusCode::BAD_REQUEST, "teachers only");
    }
    if t.id == c.owner_id {
        return err(StatusCode::BAD_REQUEST, "already the main teacher");
    }
    if let Err(e) = s.db.class_teacher_add(&c.id, &t.id, AppState::now()).await {
        return db_resp(e);
    }
    s.audit(
        "account",
        &session.user,
        "class_teacher_add",
        &t.username,
        &c.name,
        &session.user.lineage,
    )
    .await;
    s.notify(
        &t.id,
        "co_teacher",
        json!({
            "class": c.id,
            "className": c.name,
            "from": session.user.username,
        }),
    )
    .await;
    Json(json!(t)).into_response()
}

async fn remove_class_teacher(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path((id, uid)): Path<(String, String)>,
) -> Response {
    let c = match require_class(&s, &session, &id).await {
        Ok(c) => c,
        Err(r) => return r,
    };
    match s.db.class_teacher_remove(&c.id, &uid).await {
        Ok(true) => {
            s.audit(
                "account",
                &session.user,
                "class_teacher_remove",
                &uid,
                &c.name,
                &session.user.lineage,
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Ok(false) => err(StatusCode::NOT_FOUND, "not a co-teacher"),
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
    #[serde(default, rename = "classId")]
    class_id: String,
}

async fn create_account(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<CreateAccountReq>,
) -> Response {
    if !session.user.role.can_create() {
        return err(StatusCode::FORBIDDEN, "not allowed");
    }
    let want_class = req.class_id.trim();
    let role = match Role::parse(&req.role) {
        Some(r) if r < session.user.role && r != Role::Owner => r,
        // A teacher creates same-rank accounts only as co-teachers of a class
        // they own; without a class the usual rank rule applies.
        Some(Role::Teacher) if session.user.role == Role::Teacher && !want_class.is_empty() => {
            Role::Teacher
        }
        _ => return err(StatusCode::BAD_REQUEST, "cannot create that role"),
    };
    if !model::valid_username(&req.username) {
        return err(StatusCode::BAD_REQUEST, "invalid username");
    }
    if !model::valid_password(&req.password) {
        return err(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        );
    }
    let name = req.name.trim();
    if name.is_empty() || name.len() > 64 {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    let note: String = req.note.chars().take(20).collect();
    let student_id: String = req.student_id.trim().chars().take(32).collect();
    let mut co_class: Option<model::Class> = None;
    let class_id = if !want_class.is_empty() {
        if role >= Role::Teacher {
            // Staff never join a class as members; a class id means the new
            // account co-teaches it, which only the main teacher may set up.
            let c = match require_class(&s, &session, want_class).await {
                Ok(c) => c,
                Err(r) => return r,
            };
            co_class = Some(c);
            String::new()
        } else {
            match require_class_open(&s, &session, want_class).await {
                Ok(c) => c.id,
                Err(r) => return r,
            }
        }
    } else if role == Role::Student {
        match s.db.unmanaged_class(&session.user).await {
            Ok(c) => c.id,
            Err(e) => return db_resp(e),
        }
    } else {
        String::new()
    };
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
        avatar: String::new(),
        quota_bytes: 0,
        created_by: session.user.id.clone(),
        class_id,
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
    if let Some(c) = co_class {
        if let Err(e) = s.db.class_teacher_add(&c.id, &u.id, AppState::now()).await {
            return db_resp(e);
        }
        s.notify(
            &u.id,
            "co_teacher",
            json!({
                "class": c.id,
                "className": c.name,
                "from": session.user.username,
            }),
        )
        .await;
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
struct InviteReq {
    role: String,
    #[serde(default)]
    username: String,
    #[serde(default)]
    name: String,
}

async fn create_invite(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<InviteReq>,
) -> Response {
    if !session.user.role.can_create() {
        return err(StatusCode::FORBIDDEN, "not allowed");
    }
    let role = match Role::parse(&req.role) {
        Some(r) if r < session.user.role && r != Role::Owner => r,
        _ => return err(StatusCode::BAD_REQUEST, "cannot create that role"),
    };
    let username = req.username.trim();
    if !username.is_empty() && !model::valid_username(username) {
        return err(StatusCode::BAD_REQUEST, "invalid username");
    }
    let name = req.name.trim();
    if name.len() > 64 {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    let code = model::new_token();
    let now = AppState::now();
    let inv = InviteCode {
        id: model::new_id(),
        code_hash: model::token_hash(&code),
        created_by: session.user.id.clone(),
        role: role.as_str().into(),
        preset_username: username.into(),
        preset_name: name.into(),
        used_by: String::new(),
        used_at: 0,
        expires_at: now + 7 * 86400,
        revoked: false,
        created_at: now,
    };
    if let Err(e) = s.db.invite_create(&inv).await {
        return db_resp(e);
    }
    s.audit(
        "account",
        &session.user,
        "invite",
        &inv.preset_username,
        &format!("role={}", inv.role),
        &session.user.lineage,
    )
    .await;
    Json(json!({"code": code, "invite": inv})).into_response()
}

async fn list_invites(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.invites_by_creator(&session.user.id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn revoke_invite(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match s.db.invite_revoke(&id, &session.user.id).await {
        Ok(true) => {
            s.audit(
                "account",
                &session.user,
                "invite_revoke",
                &id,
                "",
                &session.user.lineage,
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Ok(false) => err(StatusCode::NOT_FOUND, "unknown invite"),
        Err(e) => db_resp(e),
    }
}

async fn invite_preview(
    State(s): State<Arc<AppState>>,
    parts: axum::http::request::Parts,
    Path(code): Path<String>,
) -> Response {
    let ip = client_ip(&s, &parts);
    if let Some(wait) = login_throttle(&s, ip) {
        return err(
            StatusCode::TOO_MANY_REQUESTS,
            &format!("too many attempts, retry in {wait}s"),
        );
    }
    match s.db.invite_by_hash(&model::token_hash(&code)).await {
        Ok(i) if i.used_by.is_empty() && !i.revoked && i.expires_at > AppState::now() => {
            Json(json!({"username": i.preset_username, "name": i.preset_name})).into_response()
        }
        Ok(_) => err(StatusCode::GONE, "invite expired"),
        Err(_) => {
            login_failed(&s, ip);
            err(StatusCode::NOT_FOUND, "unknown invite")
        }
    }
}

#[derive(Deserialize)]
struct RedeemReq {
    #[serde(default)]
    username: String,
    #[serde(default)]
    name: String,
    password: String,
}

async fn redeem_invite(
    State(s): State<Arc<AppState>>,
    parts: axum::http::request::Parts,
    Path(code): Path<String>,
    Json(req): Json<RedeemReq>,
) -> Response {
    let ip = client_ip(&s, &parts);
    if let Some(wait) = login_throttle(&s, ip) {
        return err(
            StatusCode::TOO_MANY_REQUESTS,
            &format!("too many attempts, retry in {wait}s"),
        );
    }
    let hash = model::token_hash(&code);
    let inv = match s.db.invite_by_hash(&hash).await {
        Ok(i) => i,
        Err(_) => {
            login_failed(&s, ip);
            return err(StatusCode::NOT_FOUND, "unknown invite");
        }
    };
    let now = AppState::now();
    if !inv.used_by.is_empty() || inv.revoked || inv.expires_at <= now {
        return err(StatusCode::GONE, "invite expired");
    }
    let inviter = match s.db.user_by_id(&inv.created_by).await {
        Ok(u) => u,
        Err(e) => return db_resp(e),
    };
    let username = if inv.preset_username.is_empty() {
        req.username.trim().to_string()
    } else {
        inv.preset_username.clone()
    };
    let name = if inv.preset_name.is_empty() {
        req.name.trim().to_string()
    } else {
        inv.preset_name.clone()
    };
    if !model::valid_username(&username) {
        return err(StatusCode::BAD_REQUEST, "invalid username");
    }
    if name.is_empty() {
        return err(StatusCode::BAD_REQUEST, "invalid name");
    }
    if !model::valid_password(&req.password) {
        return err(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        );
    }
    if s.db.user_by_name(&username).await.is_ok() {
        return err(StatusCode::CONFLICT, "username taken");
    }
    let uid = model::new_id();
    match s.db.invite_use(&hash, &uid, now).await {
        Ok(true) => {}
        Ok(false) => return err(StatusCode::GONE, "invite expired"),
        Err(e) => return db_resp(e),
    }
    let pw = match auth::hash_password(&req.password) {
        Ok(h) => h,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    };
    let role = Role::parse(&inv.role).unwrap_or(Role::Student);
    let class_id = if role == Role::Student {
        match s.db.unmanaged_class(&inviter).await {
            Ok(c) => c.id,
            Err(e) => return db_resp(e),
        }
    } else {
        String::new()
    };
    let u = User {
        id: uid,
        username: username.clone(),
        display_name: name,
        role,
        role_name: inv.role.clone(),
        student_id: String::new(),
        note: String::new(),
        disabled: false,
        avatar: String::new(),
        quota_bytes: 0,
        created_by: inv.created_by.clone(),
        class_id,
        lineage: format!("{}{}/", inviter.lineage, inviter.id),
        created_at: now,
        last_login: 0,
    };
    if let Err(e) = s.db.create_user(&u, &pw).await {
        let _ = s.db.invite_unuse(&hash).await;
        return match e {
            DbError::Conflict => err(StatusCode::CONFLICT, "username taken"),
            other => db_resp(other),
        };
    }
    login_ok(&s, ip);
    s.audit(
        "account",
        &u,
        "redeem",
        &u.username,
        &format!("invite by {}", inviter.username),
        &u.lineage,
    )
    .await;
    session_response(&s, &parts, &u, &ip).await
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
        return err(
            StatusCode::BAD_REQUEST,
            "password must be at least 8 characters",
        );
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
        Ok(ps) => {
            for p in &ps {
                purge_project(&s, p).await;
            }
        }
        Err(e) => return db_resp(e),
    }
    match s.db.groups_by_owner(&id).await {
        Ok(gs) => {
            for g in &gs {
                let _ = s.db.delete_group(&g.id).await;
            }
        }
        Err(e) => return db_resp(e),
    }
    if let Err(e) = s.db.delete_user(&id).await {
        return db_resp(e);
    }
    if !target.avatar.is_empty() {
        let _ = s.blobs.delete(&target.avatar).await;
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
    #[serde(rename = "quotaBytes")]
    quota_bytes: Option<i64>,
    #[serde(rename = "classId")]
    class_id: Option<String>,
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
            if target.role >= Role::Teacher && role < Role::Teacher {
                let _ = s.db.class_teacher_purge(&target.id).await;
            }
            target.role = role;
            target.role_name = role.as_str().into();
            if role >= Role::Teacher && !target.class_id.is_empty() {
                target.class_id = String::new();
                detail.push("class");
            }
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
    if let Some(q) = req.quota_bytes {
        if q < 0 {
            return err(StatusCode::BAD_REQUEST, "quota must be zero or more");
        }
        if q != target.quota_bytes {
            target.quota_bytes = q;
            detail.push("quota");
        }
    }
    if let Some(cid) = req.class_id {
        if target.role >= Role::Teacher {
            return err(
                StatusCode::BAD_REQUEST,
                "only students and mods join classes",
            );
        }
        let c = match require_class_open(&s, &session, cid.trim()).await {
            Ok(c) => c,
            Err(r) => return r,
        };
        if c.id != target.class_id {
            target.class_id = c.id;
            detail.push("class");
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
    #[serde(default)]
    offset: i64,
    #[serde(default)]
    action: String,
    #[serde(default)]
    actor: String,
    #[serde(default)]
    from: i64,
    #[serde(default)]
    to: i64,
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
    let f = AuditFilter {
        action: q.action,
        actor: q.actor,
        from: q.from,
        to: q.to,
        limit: q.limit.clamp(1, 1000),
        offset: q.offset.max(0),
    };
    match s.db.audit_list(scope, subtree, &f).await {
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
    let hidden: std::collections::HashSet<String> =
        s.db.hidden_assignment_projects(&session.user.id)
            .await
            .unwrap_or_default()
            .into_iter()
            .collect();
    if !hidden.is_empty() {
        v.retain(|p| !hidden.contains(&p.id));
    }
    Json(json!(v)).into_response()
}

/// A managed account's projects, for the Manage > Accounts drill-down. Entries
/// are read-only for the caller; taking over is the only write path into them.
async fn account_projects(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let target = match require_manager(&s, &session, &id).await {
        Ok(t) => t,
        Err(r) => return r,
    };
    let ps = match s.db.projects_by_owner(&target.id).await {
        Ok(v) => v,
        Err(e) => return db_resp(e),
    };
    let take_over = session.user.role == Role::Owner
        || s.db
            .user_in_subtree(&session.user, &target.id)
            .await
            .unwrap_or(false);
    let out: Vec<Value> = ps
        .iter()
        .map(|p| {
            let mut j = serde_json::to_value(p).unwrap_or_default();
            j["access"] = json!("view");
            j["takeOver"] = json!(take_over);
            j
        })
        .collect();
    Json(json!(out)).into_response()
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
        return err(
            StatusCode::BAD_REQUEST,
            "project name cannot start with . or -",
        );
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
        template: false,
        status: "draft".into(),
        submitted_at: 0,
        reviewed_by: String::new(),
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
    auto_share_apply(&s, &p, &session.user).await;
    Json(json!(p)).into_response()
}

async fn auto_share_apply(s: &Arc<AppState>, p: &Project, creator: &User) {
    let lists = match s.db.auto_shares_all().await {
        Ok(v) => v,
        Err(_) => return,
    };
    let now = AppState::now();
    for a in lists {
        if a.invitee_id == creator.id {
            continue;
        }
        let accepted = a.owner_id == creator.id || lineage_has(&creator.lineage, &a.owner_id);
        let sh = ProjectShare {
            id: model::new_id(),
            project_id: p.id.clone(),
            inviter_id: a.owner_id.clone(),
            invitee_id: a.invitee_id.clone(),
            level: a.level.clone(),
            status: if accepted {
                "accepted".into()
            } else {
                "pending".into()
            },
            created_at: now,
            responded_at: if accepted { now } else { 0 },
        };
        if s.db.share_upsert(&sh).await.is_err() {
            continue;
        }
        if let Ok(invitee) = s.db.user_by_id(&a.invitee_id).await {
            s.audit(
                "project",
                creator,
                "share_invite",
                &invitee.username,
                &format!("auto {} level={}", p.display_name, a.level),
                &p.id,
            )
            .await;
        }
        let from =
            s.db.user_by_id(&a.owner_id)
                .await
                .map(|u| u.username)
                .unwrap_or_default();
        s.notify(
            &a.invitee_id,
            if accepted {
                "share_auto"
            } else {
                "share_invite"
            },
            json!({
                "project": p.id,
                "projectName": p.display_name,
                "from": from,
                "level": a.level,
            }),
        )
        .await;
    }
}

async fn fetch_project(s: &Arc<AppState>, id: &str) -> Result<Project, Response> {
    s.db.project_by_id(id)
        .await
        .map_err(|_| err(StatusCode::NOT_FOUND, "no such project"))
}

#[derive(Deserialize)]
struct ShareReq {
    username: String,
    #[serde(default)]
    level: String,
}

async fn create_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<ShareReq>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if req.level != "view" && req.level != "edit" {
        return err(StatusCode::BAD_REQUEST, "level must be view or edit");
    }
    let invitee = match s.db.user_by_name(&req.username.trim()).await {
        Ok((u, _)) => u,
        Err(_) => return err(StatusCode::NOT_FOUND, "unknown user"),
    };
    if !can_see_db(&s, &session.user, &invitee).await {
        return err(StatusCode::NOT_FOUND, "unknown user");
    }
    if invitee.id == session.user.id {
        return err(StatusCode::BAD_REQUEST, "cannot share with yourself");
    }
    if invitee.disabled {
        return err(StatusCode::BAD_REQUEST, "user is disabled");
    }
    let now = AppState::now();
    let sh = ProjectShare {
        id: model::new_id(),
        project_id: p.id.clone(),
        inviter_id: session.user.id.clone(),
        invitee_id: invitee.id.clone(),
        level: req.level.clone(),
        status: "pending".into(),
        created_at: now,
        responded_at: 0,
    };
    if let Err(e) = s.db.share_upsert(&sh).await {
        return db_resp(e);
    }
    s.audit(
        "project",
        &session.user,
        "share_invite",
        &invitee.username,
        &format!("{} level={}", p.display_name, req.level),
        &p.id,
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

async fn list_project_shares(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match owned_project(&s, &session, &id).await {
        Ok(p) => match s.db.shares_by_project(&p.id).await {
            Ok(v) => Json(json!(v)).into_response(),
            Err(e) => db_resp(e),
        },
        Err(r) => r,
    }
}

#[derive(Deserialize)]
struct ShareLevelReq {
    level: String,
}

async fn update_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path((pid, sid)): Path<(String, String)>,
    Json(req): Json<ShareLevelReq>,
) -> Response {
    match owned_project(&s, &session, &pid).await {
        Ok(p) => {
            if req.level != "view" && req.level != "edit" {
                return err(StatusCode::BAD_REQUEST, "level must be view or edit");
            }
            match s.db.share_set_level(&sid, &p.id, &req.level).await {
                Ok(true) => {
                    s.audit(
                        "project",
                        &session.user,
                        "share_update",
                        &p.display_name,
                        &format!("level={}", req.level),
                        &p.id,
                    )
                    .await;
                    Json(json!({"ok": true})).into_response()
                }
                Ok(false) => err(StatusCode::NOT_FOUND, "unknown share"),
                Err(e) => db_resp(e),
            }
        }
        Err(r) => r,
    }
}

async fn delete_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path((pid, sid)): Path<(String, String)>,
) -> Response {
    match owned_project(&s, &session, &pid).await {
        Ok(p) => match s.db.share_delete(&sid, &p.id).await {
            Ok(true) => {
                s.audit(
                    "project",
                    &session.user,
                    "share_revoke",
                    &p.display_name,
                    &sid,
                    &p.id,
                )
                .await;
                Json(json!({"ok": true})).into_response()
            }
            Ok(false) => err(StatusCode::NOT_FOUND, "unknown share"),
            Err(e) => db_resp(e),
        },
        Err(r) => r,
    }
}

async fn list_my_shares(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.shares_for_user(&session.user.id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn list_auto_shares(State(s): State<Arc<AppState>>, session: Session) -> Response {
    if session.user.role < Role::Teacher {
        return err(StatusCode::FORBIDDEN, "teachers only");
    }
    match s.db.auto_shares_list(&session.user.id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn add_auto_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<ShareReq>,
) -> Response {
    if session.user.role < Role::Teacher {
        return err(StatusCode::FORBIDDEN, "teachers only");
    }
    if req.level != "view" && req.level != "edit" {
        return err(StatusCode::BAD_REQUEST, "level must be view or edit");
    }
    let invitee = match s.db.user_by_name(&req.username.trim()).await {
        Ok((u, _)) => u,
        Err(_) => return err(StatusCode::NOT_FOUND, "unknown user"),
    };
    if !can_see_db(&s, &session.user, &invitee).await {
        return err(StatusCode::NOT_FOUND, "unknown user");
    }
    if invitee.id == session.user.id {
        return err(StatusCode::BAD_REQUEST, "cannot share with yourself");
    }
    if invitee.disabled {
        return err(StatusCode::BAD_REQUEST, "user is disabled");
    }
    match s
        .db
        .auto_share_upsert(&session.user.id, &invitee.id, &req.level)
        .await
    {
        Ok(()) => {
            s.audit(
                "settings",
                &session.user,
                "auto_share_add",
                &invitee.username,
                &format!("level={}", req.level),
                "",
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) => db_resp(e),
    }
}

async fn delete_auto_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    if session.user.role < Role::Teacher {
        return err(StatusCode::FORBIDDEN, "teachers only");
    }
    match s.db.auto_share_delete(&session.user.id, &id).await {
        Ok(true) => {
            s.audit("settings", &session.user, "auto_share_remove", &id, "", "")
                .await;
            Json(json!({"ok": true})).into_response()
        }
        Ok(false) => err(StatusCode::NOT_FOUND, "unknown auto-share"),
        Err(e) => db_resp(e),
    }
}

async fn respond_share(s: &Arc<AppState>, session: &Session, sid: &str, status: &str) -> Response {
    let sh = s.db.share_by_id(sid).await.ok();
    match s
        .db
        .share_respond(sid, &session.user.id, status, AppState::now())
        .await
    {
        Ok(true) => {
            s.audit(
                "project",
                &session.user,
                if status == "accepted" {
                    "share_accept"
                } else {
                    "share_decline"
                },
                sid,
                "",
                &session.user.lineage,
            )
            .await;
            if let Some(sh) = sh {
                let name =
                    s.db.project_by_id(&sh.project_id)
                        .await
                        .map(|p| p.display_name)
                        .unwrap_or_default();
                s.notify(
                    &sh.inviter_id,
                    if status == "accepted" {
                        "share_accepted"
                    } else {
                        "share_declined"
                    },
                    json!({
                        "project": sh.project_id,
                        "projectName": name,
                        "from": session.user.username,
                    }),
                )
                .await;
            }
            Json(json!({"ok": true})).into_response()
        }
        Ok(false) => err(StatusCode::NOT_FOUND, "no pending invite"),
        Err(e) => db_resp(e),
    }
}

async fn accept_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(sid): Path<String>,
) -> Response {
    respond_share(&s, &session, &sid, "accepted").await
}

async fn decline_share(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(sid): Path<String>,
) -> Response {
    respond_share(&s, &session, &sid, "declined").await
}

#[derive(Deserialize)]
struct LinkReq {
    scope: String,
    #[serde(rename = "expiresAt")]
    expires_at: Option<i64>,
}

async fn create_link(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<LinkReq>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if req.scope != "project" && req.scope != "renders" {
        return err(StatusCode::BAD_REQUEST, "scope must be project or renders");
    }
    let token = model::new_token();
    let l = ProjectLink {
        id: model::new_id(),
        token_hash: model::token_hash(&token),
        project_id: p.id.clone(),
        scope: req.scope,
        created_by: session.user.id.clone(),
        created_at: AppState::now(),
        expires_at: req.expires_at.unwrap_or(0),
        revoked: false,
    };
    if let Err(e) = s.db.link_create(&l).await {
        return db_resp(e);
    }
    s.audit(
        "project",
        &session.user,
        "share_link_create",
        &p.display_name,
        &format!("scope={}", l.scope),
        &p.id,
    )
    .await;
    Json(json!({"id": l.id, "token": token})).into_response()
}

async fn list_links(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    match s.db.links_by_project(&p.id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn revoke_link(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path((pid, lid)): Path<(String, String)>,
) -> Response {
    let p = match owned_project(&s, &session, &pid).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    match s.db.link_revoke(&lid, &p.id).await {
        Ok(true) => {
            s.audit(
                "project",
                &session.user,
                "share_link_revoke",
                &p.display_name,
                &lid,
                &p.id,
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Ok(false) => err(StatusCode::NOT_FOUND, "unknown link"),
        Err(e) => db_resp(e),
    }
}

async fn link_valid(s: &Arc<AppState>, token: &str) -> Result<(ProjectLink, Project), Response> {
    let l =
        s.db.link_by_hash(&model::token_hash(token))
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such link"))?;
    if l.revoked || (l.expires_at > 0 && l.expires_at < AppState::now()) {
        return Err(err(StatusCode::NOT_FOUND, "no such link"));
    }
    let p =
        s.db.project_by_id(&l.project_id)
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such link"))?;
    Ok((l, p))
}

async fn link_resolve(
    State(s): State<Arc<AppState>>,
    parts: axum::http::request::Parts,
    Path(token): Path<String>,
) -> Response {
    if link_throttle(&s, client_ip(&s, &parts)) {
        return err(StatusCode::TOO_MANY_REQUESTS, "rate limited");
    }
    let (l, p) = match link_valid(&s, &token).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let root = if l.scope == "renders" {
        format!("{}/Exports", p.dir)
    } else {
        p.dir.clone()
    };
    let strip = format!("{}/", p.dir);
    let mut files = vec![];
    let mut stack = vec![root];
    let mut guard = 0usize;
    while let Some(pre) = stack.pop() {
        guard += 1;
        if guard > 2000 {
            break;
        }
        if let Ok((dirs, objs)) = s.blobs.list(&pre).await {
            stack.extend(dirs);
            for o in objs {
                let rel = o.key.strip_prefix(&strip).unwrap_or(&o.key);
                files.push(json!({"path": rel, "size": o.size}));
            }
        }
    }
    files.sort_by(|a, b| a["path"].as_str().cmp(&b["path"].as_str()));
    Json(json!({
        "name": p.display_name,
        "scope": l.scope,
        "files": files,
    }))
    .into_response()
}

#[derive(Deserialize)]
struct LinkFileQuery {
    path: String,
}

async fn link_file(
    State(s): State<Arc<AppState>>,
    Path(token): Path<String>,
    Query(q): Query<LinkFileQuery>,
    headers: HeaderMap,
    parts: axum::http::request::Parts,
) -> Response {
    if link_throttle(&s, client_ip(&s, &parts)) {
        return err(StatusCode::TOO_MANY_REQUESTS, "rate limited");
    }
    let (l, p) = match link_valid(&s, &token).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    if l.scope == "renders" && !key.starts_with("Exports/") {
        return err(StatusCode::NOT_FOUND, "not found");
    }
    serve_blob(&s, &blob_key(&p.dir, &key), &key, &headers, false, None).await
}

#[derive(Deserialize)]
struct NotifQuery {
    before: Option<i64>,
    limit: Option<i64>,
}

async fn my_notifications(
    State(s): State<Arc<AppState>>,
    session: Session,
    Query(q): Query<NotifQuery>,
) -> Response {
    let limit = q.limit.unwrap_or(50).clamp(1, 200);
    match s
        .db
        .notifications_for(&session.user.id, q.before.unwrap_or(0), limit)
        .await
    {
        Ok(v) => match s.db.notifications_unread(&session.user.id).await {
            Ok(unread) => Json(json!({"list": v, "unread": unread})).into_response(),
            Err(e) => db_resp(e),
        },
        Err(e) => db_resp(e),
    }
}

async fn notification_read(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match s
        .db
        .notification_read(&session.user.id, &id, AppState::now())
        .await
    {
        Ok(true) => Json(json!({"ok": true})).into_response(),
        Ok(false) => err(StatusCode::NOT_FOUND, "no such notification"),
        Err(e) => db_resp(e),
    }
}

async fn notifications_read_all(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s
        .db
        .notifications_read_all(&session.user.id, AppState::now())
        .await
    {
        Ok(()) => Json(json!({"ok": true})).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn owned_project(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<Project, Response> {
    let p = fetch_project(s, id).await?;
    if p.owner_id != session.user.id {
        return Err(err(StatusCode::FORBIDDEN, "not your project"));
    }
    let _ = s.db.touch_project(&p.id, AppState::now()).await;
    Ok(p)
}

async fn project_access(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<(Project, &'static str), Response> {
    let p = fetch_project(s, id).await?;
    if p.owner_id == session.user.id {
        if let Ok(Some((a, _))) = s.db.assignment_for_project(&p.id).await {
            if a.hidden {
                return Err(err(StatusCode::NOT_FOUND, "not found"));
            }
        }
        return Ok((p, "owner"));
    }
    if let Ok(share) = s.db.share_by(&p.id, &session.user.id).await {
        if share.status == "accepted" {
            let level = if share.level == "edit" && !p.template {
                "edit"
            } else {
                "view"
            };
            return Ok((p, level));
        }
    }
    let owner_user = s.db.user_by_id(&p.owner_id).await.ok();
    let in_subtree =
        s.db.user_in_subtree(&session.user, &p.owner_id)
            .await
            .unwrap_or(false)
            || match &owner_user {
                Some(o) => s.db.teaches_member(&session.user, o).await.unwrap_or(false),
                None => false,
            };
    if in_subtree {
        return Ok((p, "view"));
    }
    Err(err(StatusCode::FORBIDDEN, "not your project"))
}

async fn read_project(s: &Arc<AppState>, session: &Session, id: &str) -> Result<Project, Response> {
    let (p, _) = project_access(s, session, id).await?;
    Ok(p)
}

async fn edit_project(s: &Arc<AppState>, session: &Session, id: &str) -> Result<Project, Response> {
    let (p, level) = project_access(s, session, id).await?;
    if level == "view" {
        return Err(err(StatusCode::FORBIDDEN, "read only"));
    }
    if p.status == "submitted" {
        return Err(err(StatusCode::FORBIDDEN, "submitted for review"));
    }
    if p.owner_id == session.user.id {
        if let Ok(Some((a, _))) = s.db.assignment_for_project(&p.id).await {
            if a.locked {
                return Err(err(StatusCode::FORBIDDEN, "assignment locked"));
            }
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

async fn get_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match project_access(&s, &session, &id).await {
        Ok((p, level)) => {
            let mut v = serde_json::to_value(&p).unwrap_or_default();
            if let Some(o) = v.as_object_mut() {
                o.insert("access".into(), json!(level));
            }
            Json(v).into_response()
        }
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
    #[serde(default)]
    template: Option<bool>,
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
    if req.template.is_some() && session.user.role < Role::Teacher {
        return err(StatusCode::FORBIDDEN, "teachers only");
    }
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
    if let Err(e) =
        s.db.update_project(&id, &name, &group_id, &model::tags_csv(&tags))
            .await
    {
        return db_resp(e);
    }
    if let Some(pin) = req.pinned {
        if let Err(e) = s.db.set_project_pinned(&id, pin).await {
            return db_resp(e);
        }
    }
    if let Some(t) = req.template {
        if let Err(e) = s.db.set_project_template(&id, t).await {
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
    let g =
        s.db.group_by_id(id)
            .await
            .map_err(|_| err(StatusCode::NOT_FOUND, "no such group"))?;
    if g.owner_id != session.user.id {
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

/// Remove a project's row, its dependents and its stored blobs.
async fn purge_project(s: &Arc<AppState>, p: &Project) {
    let _ = s.db.delete_project(&p.id).await;
    let _ = s.db.shares_delete_project(&p.id).await;
    let _ = s.db.links_delete_project(&p.id).await;
    let _ = s.db.comments_delete_project(&p.id).await;
    let _ = s.blobs.delete_prefix(&p.dir).await;
    let _ = s.blobs.delete_prefix(&format!("{}.thumbs", p.dir)).await;
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
    purge_project(&s, &p).await;
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

/// Copy every blob under `src.dir` into a fresh project dir for `owner` and
/// insert the project row. Cleans up the new dir on failure.
async fn clone_project(
    s: &Arc<AppState>,
    src: &Project,
    owner: &User,
    name: String,
    display: String,
) -> Result<Project, Response> {
    let bytes = usage_bytes(s, &src.dir).await;
    if quota_exceeded(s, &owner.id, bytes).await {
        return Err(err(StatusCode::PAYLOAD_TOO_LARGE, "storage quota exceeded"));
    }
    let id2 = model::new_id();
    let dir = files::rel_project_dir(&owner.username, &owner.id, &name, &id2);
    for f in files::PROJECT_FOLDERS {
        if let Err(e) = s.blobs.mkdir(&format!("{dir}/{f}")).await {
            return Err(err(StatusCode::INTERNAL_SERVER_ERROR, &e));
        }
    }
    let mut stack = vec![src.dir.clone()];
    let mut guard = 0usize;
    while let Some(pre) = stack.pop() {
        guard += 1;
        if guard > 10000 {
            let _ = s.blobs.delete_prefix(&dir).await;
            return Err(err(StatusCode::INTERNAL_SERVER_ERROR, "too many files"));
        }
        match s.blobs.list(&pre).await {
            Ok((folders, objects)) => {
                stack.extend(folders);
                for o in objects {
                    let rel = o.key.strip_prefix(&src.dir).unwrap_or(&o.key);
                    let dst = format!("{dir}{rel}");
                    match s.blobs.get(&o.key).await {
                        Ok((_, stream)) => {
                            let mut r = tokio_util::io::StreamReader::new(stream);
                            if let Err(e) = s.blobs.put(&dst, o.size, &mut r).await {
                                let _ = s.blobs.delete_prefix(&dir).await;
                                return Err(err(StatusCode::INTERNAL_SERVER_ERROR, &e));
                            }
                        }
                        Err(e) => {
                            let _ = s.blobs.delete_prefix(&dir).await;
                            return Err(err(StatusCode::INTERNAL_SERVER_ERROR, &e));
                        }
                    }
                }
            }
            Err(e) => {
                let _ = s.blobs.delete_prefix(&dir).await;
                return Err(err(StatusCode::INTERNAL_SERVER_ERROR, &e));
            }
        }
    }
    let p = Project {
        id: id2,
        owner_id: owner.id.clone(),
        name,
        display_name: display,
        dir,
        group_id: String::new(),
        tags: src.tags.clone(),
        created_at: AppState::now(),
        last_activity: AppState::now(),
        pinned: false,
        template: false,
        status: "draft".into(),
        submitted_at: 0,
        reviewed_by: String::new(),
    };
    if let Err(e) = s.db.create_project(&p).await {
        let _ = s.blobs.delete_prefix(&p.dir).await;
        return Err(db_resp(e));
    }
    Ok(p)
}

async fn duplicate_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let src = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let name = format!("{} copy", src.name.chars().take(58).collect::<String>());
    let display: String = format!("{} (copy)", src.display_name)
        .chars()
        .take(100)
        .collect();
    let p = match clone_project(&s, &src, &session.user, name, display).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    s.audit(
        "project",
        &session.user,
        if src.template {
            "use_template"
        } else {
            "duplicate_project"
        },
        &p.display_name,
        &format!("from {}", src.display_name),
        "",
    )
    .await;
    auto_share_apply(&s, &p, &session.user).await;
    Json(json!(p)).into_response()
}

async fn list_comments(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    if let Err(r) = project_access(&s, &session, &id).await {
        return r;
    }
    match s.db.comments_for(&id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct CommentReq {
    body: String,
}

fn clean_comment(body: &str) -> Result<String, Response> {
    let b = body.trim();
    if b.is_empty() {
        return Err(err(StatusCode::BAD_REQUEST, "empty comment"));
    }
    Ok(b.chars().take(4000).collect())
}

async fn add_comment(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<CommentReq>,
) -> Response {
    let p = match project_access(&s, &session, &id).await {
        Ok((p, _)) => p,
        Err(r) => return r,
    };
    let body = match clean_comment(&req.body) {
        Ok(b) => b,
        Err(r) => return r,
    };
    if let Err(e) =
        s.db.comment_add(
            &model::new_id(),
            &id,
            &session.user.id,
            &body,
            AppState::now(),
        )
        .await
    {
        return db_resp(e);
    }
    if p.owner_id != session.user.id {
        s.notify(
            &p.owner_id,
            "comment",
            json!({
                "project": p.id,
                "projectName": p.display_name,
                "from": session.user.username,
            }),
        )
        .await;
    }
    Json(json!({"ok": true})).into_response()
}

async fn edit_comment(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path((id, cid)): Path<(String, String)>,
    Json(req): Json<CommentReq>,
) -> Response {
    let c = match s.db.comment_by_id(&cid).await {
        Ok(c) if c.project_id == id => c,
        _ => return err(StatusCode::NOT_FOUND, "no such comment"),
    };
    if c.user_id != session.user.id {
        return err(StatusCode::FORBIDDEN, "not your comment");
    }
    if let Err(r) = project_access(&s, &session, &id).await {
        return r;
    }
    let body = match clean_comment(&req.body) {
        Ok(b) => b,
        Err(r) => return r,
    };
    match s.db.comment_edit(&cid, &body, AppState::now()).await {
        Ok(_) => Json(json!({"ok": true})).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn delete_comment(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path((id, cid)): Path<(String, String)>,
) -> Response {
    let c = match s.db.comment_by_id(&cid).await {
        Ok(c) if c.project_id == id => c,
        _ => return err(StatusCode::NOT_FOUND, "no such comment"),
    };
    let p = match fetch_project(&s, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if c.user_id != session.user.id && p.owner_id != session.user.id {
        return err(StatusCode::FORBIDDEN, "not your comment");
    }
    match s.db.comment_delete(&cid).await {
        Ok(_) => Json(json!({"ok": true})).into_response(),
        Err(e) => db_resp(e),
    }
}

async fn submit_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let p = match owned_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let submitted = p.status == "submitted";
    if p.owner_id == session.user.id {
        if let Ok(Some((a, c))) = s.db.assignment_for_project(&id).await {
            if a.locked {
                return err(StatusCode::FORBIDDEN, "assignment locked");
            }
            if submitted && !a.allow_withdraw {
                return err(StatusCode::FORBIDDEN, "withdraw not allowed");
            }
            if !submitted && a.max_submissions > 0 && c.submissions >= a.max_submissions {
                return err(StatusCode::FORBIDDEN, "submission limit reached");
            }
        }
    }
    let (status, submitted_at, action) = if submitted {
        ("draft", 0, "project_withdraw")
    } else {
        ("submitted", AppState::now(), "project_submit")
    };
    if let Err(e) = s.db.set_project_status(&id, status, submitted_at, "").await {
        return db_resp(e);
    }
    if !submitted {
        let _ = s.db.bump_submissions(&id).await;
    }
    s.audit("project", &session.user, action, &p.display_name, "", "")
        .await;
    if !submitted {
        if let Ok(list) = s.db.shares_by_project(&id).await {
            for sh in list {
                if sh.status == "accepted" && sh.invitee_id != session.user.id {
                    s.notify(
                        &sh.invitee_id,
                        "submit",
                        json!({
                            "project": p.id,
                            "projectName": p.display_name,
                            "from": session.user.username,
                        }),
                    )
                    .await;
                }
            }
        }
    }
    Json(json!({"ok": true, "status": status})).into_response()
}

#[derive(Deserialize)]
struct ReviewReq {
    status: String,
}

async fn review_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<ReviewReq>,
) -> Response {
    if session.user.role < Role::Teacher {
        return err(StatusCode::FORBIDDEN, "staff only");
    }
    let p = match project_access(&s, &session, &id).await {
        Ok((p, _)) => p,
        Err(r) => return r,
    };
    if p.status != "submitted" {
        return err(StatusCode::BAD_REQUEST, "not submitted");
    }
    let status = req.status.trim();
    if status != "reviewed" && status != "draft" {
        return err(StatusCode::BAD_REQUEST, "status: reviewed|draft");
    }
    if let Err(e) =
        s.db.set_project_status(&id, status, p.submitted_at, &session.user.id)
            .await
    {
        return db_resp(e);
    }
    s.audit(
        "project",
        &session.user,
        if status == "reviewed" {
            "project_review"
        } else {
            "project_return"
        },
        &p.display_name,
        "",
        "",
    )
    .await;
    if p.owner_id != session.user.id {
        s.notify(
            &p.owner_id,
            "review",
            json!({
                "project": p.id,
                "projectName": p.display_name,
                "from": session.user.username,
                "status": status,
            }),
        )
        .await;
    }
    Json(json!({"ok": true, "status": status})).into_response()
}

// ---------- assignments ----------

#[derive(Deserialize)]
struct AssignReq {
    #[serde(default)]
    students: Vec<String>,
    #[serde(default = "yes", rename = "allowWithdraw")]
    allow_withdraw: bool,
    #[serde(default, rename = "maxSubmissions")]
    max_submissions: i64,
    #[serde(default, rename = "dueAt")]
    due_at: i64,
    #[serde(default)]
    hidden: bool,
    #[serde(default)]
    locked: bool,
}

fn yes() -> bool {
    true
}

/// Hand out per-student copies of a project as an assignment.
async fn assign_project(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<AssignReq>,
) -> Response {
    if session.user.role < Role::Teacher {
        return err(StatusCode::FORBIDDEN, "staff only");
    }
    let src = match edit_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if s.db
        .assignment_for_project(&id)
        .await
        .unwrap_or(None)
        .is_some()
    {
        return err(StatusCode::BAD_REQUEST, "already an assignment copy");
    }
    if s.db.assignment_for_source(&id).await.is_ok() {
        return err(StatusCode::CONFLICT, "already assigned");
    }
    if req.students.is_empty() || req.students.len() > 200 {
        return err(StatusCode::BAD_REQUEST, "students: 1-200 ids");
    }
    if req.max_submissions < 0 || req.due_at < 0 {
        return err(StatusCode::BAD_REQUEST, "invalid options");
    }
    let mut seen = std::collections::HashSet::new();
    let mut students = Vec::new();
    for sid in &req.students {
        if !seen.insert(sid.clone()) {
            continue;
        }
        let st = match s.db.user_by_id(sid).await {
            Ok(u) => u,
            Err(_) => return err(StatusCode::NOT_FOUND, "unknown user"),
        };
        if st.role != Role::Student {
            return err(StatusCode::BAD_REQUEST, "students only");
        }
        if !can_see_db(&s, &session.user, &st).await {
            return err(StatusCode::NOT_FOUND, "unknown user");
        }
        students.push(st);
    }
    let aid = model::new_id();
    let assignment = Assignment {
        id: aid.clone(),
        project_id: src.id.clone(),
        teacher_id: session.user.id.clone(),
        allow_withdraw: req.allow_withdraw,
        max_submissions: req.max_submissions,
        due_at: req.due_at,
        hidden: req.hidden,
        locked: req.locked,
        created_at: AppState::now(),
    };
    let mut copies = Vec::new();
    let mut made = Vec::new();
    let mut failed = Vec::new();
    for st in students {
        let name: String = format!("{}-{}", src.name, st.username)
            .chars()
            .take(58)
            .collect();
        let who = if st.display_name.is_empty() {
            &st.username
        } else {
            &st.display_name
        };
        let display: String = format!("{} - {}", src.display_name, who)
            .chars()
            .take(100)
            .collect();
        match clone_project(&s, &src, &st, name, display).await {
            Ok(p) => {
                copies.push(AssignmentCopy {
                    project_id: p.id.clone(),
                    assignment_id: aid.clone(),
                    student_id: st.id.clone(),
                    submissions: 0,
                });
                made.push(p);
            }
            Err(_) => failed.push(st.username.clone()),
        }
    }
    if let Err(e) = s.db.create_assignment(&assignment, &copies).await {
        return db_resp(e);
    }
    s.audit(
        "project",
        &session.user,
        "project_assign",
        &src.display_name,
        &format!("{} students", copies.len()),
        "",
    )
    .await;
    for (p, cp) in made.iter().zip(copies.iter()) {
        auto_share_apply(&s, p, &session.user).await;
        s.notify(
            &cp.student_id,
            "assign",
            json!({
                "assignment": aid,
                "project": p.id,
                "projectName": p.display_name,
                "from": session.user.username,
                "dueAt": req.due_at,
            }),
        )
        .await;
    }
    Json(json!({"assignment": assignment, "copies": made, "failed": failed})).into_response()
}

/// Assignment info for a project: submissions for staff on the source, the
/// caller's own copy state on a student copy.
async fn project_assignment(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    if let Ok(Some((a, c))) = s.db.assignment_for_project(&id).await {
        let mine = c.student_id == session.user.id;
        let student_user = s.db.user_by_id(&c.student_id).await.ok();
        let staff = session.user.role == Role::Owner
            || (session.user.role >= Role::Teacher
                && (s
                    .db
                    .user_in_subtree(&session.user, &c.student_id)
                    .await
                    .unwrap_or(false)
                    || match &student_user {
                        Some(st) => {
                            s.db.teaches_member(&session.user, st)
                                .await
                                .unwrap_or(false)
                        }
                        None => false,
                    }));
        if !mine && !staff {
            return err(StatusCode::NOT_FOUND, "not found");
        }
        if mine && a.hidden {
            return err(StatusCode::NOT_FOUND, "not found");
        }
        return Json(json!({
            "assignment": a,
            "copy": c,
        }))
        .into_response();
    }
    if let Ok(a) = s.db.assignment_for_source(&id).await {
        if session.user.role < Role::Teacher {
            return err(StatusCode::FORBIDDEN, "staff only");
        }
        if project_access(&s, &session, &id).await.is_err() {
            return err(StatusCode::NOT_FOUND, "not found");
        }
        let subs = match s.db.submissions(&a.id).await {
            Ok(v) => v,
            Err(e) => return db_resp(e),
        };
        return Json(json!({
            "assignment": a,
            "submissions": subs,
        }))
        .into_response();
    }
    err(StatusCode::NOT_FOUND, "not an assignment")
}

/// Revealed assignments assigned to the caller (student view).
async fn my_assignments(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.assignments_for_student(&session.user.id).await {
        Ok(v) => Json(json!(v)).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct AssignmentPatch {
    #[serde(rename = "allowWithdraw")]
    allow_withdraw: Option<bool>,
    #[serde(rename = "maxSubmissions")]
    max_submissions: Option<i64>,
    #[serde(rename = "dueAt")]
    due_at: Option<i64>,
    hidden: Option<bool>,
    locked: Option<bool>,
}

async fn assignment_editable(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<Assignment, Response> {
    let a = match s.db.assignment(id).await {
        Ok(a) => a,
        Err(e) => return Err(db_resp(e)),
    };
    if a.teacher_id != session.user.id && session.user.role != Role::Owner {
        return Err(err(StatusCode::FORBIDDEN, "not your assignment"));
    }
    Ok(a)
}

async fn update_assignment(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<AssignmentPatch>,
) -> Response {
    let mut a = match assignment_editable(&s, &session, &id).await {
        Ok(a) => a,
        Err(r) => return r,
    };
    if let Some(v) = req.allow_withdraw {
        a.allow_withdraw = v;
    }
    if let Some(v) = req.max_submissions {
        if v < 0 {
            return err(StatusCode::BAD_REQUEST, "maxSubmissions >= 0");
        }
        a.max_submissions = v;
    }
    if let Some(v) = req.due_at {
        if v < 0 {
            return err(StatusCode::BAD_REQUEST, "dueAt >= 0");
        }
        a.due_at = v;
    }
    if let Some(v) = req.hidden {
        a.hidden = v;
    }
    if let Some(v) = req.locked {
        a.locked = v;
    }
    if let Err(e) = s.db.update_assignment(&a).await {
        return db_resp(e);
    }
    s.audit(
        "assignment",
        &session.user,
        "assignment_update",
        &a.id,
        "",
        "",
    )
    .await;
    Json(json!(a)).into_response()
}

/// Unlink an assignment: copies stay as ordinary student projects.
async fn delete_assignment(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let a = match assignment_editable(&s, &session, &id).await {
        Ok(a) => a,
        Err(r) => return r,
    };
    if let Err(e) = s.db.delete_assignment(&a.id).await {
        return db_resp(e);
    }
    s.audit(
        "assignment",
        &session.user,
        "assignment_delete",
        &a.id,
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
    #[serde(default)]
    base: String,
    start: Option<u64>,
    end: Option<u64>,
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
                rev: String::new(),
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
                        rev: String::new(),
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
                    rev: o.rev.clone(),
                }
            }));
            out.sort_by(|a, b| {
                (b.kind == "dir")
                    .cmp(&(a.kind == "dir"))
                    .then(a.name.cmp(&b.name))
            });
            Json(json!(out)).into_response()
        }
        Err(e) => err(StatusCode::INTERNAL_SERVER_ERROR, &e),
    }
}

/// One flat listing of the whole project tree: the desktop client's sync
/// engine diffs it against its local checkout instead of walking folders.
async fn project_manifest(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    let p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let strip = format!("{}/", p.dir);
    let mut out: Vec<files::FileEntry> = Vec::new();
    let mut stack = vec![p.dir.clone()];
    let mut guard = 0usize;
    while let Some(pre) = stack.pop() {
        guard += 1;
        if guard > 10000 {
            return err(StatusCode::INTERNAL_SERVER_ERROR, "tree too deep");
        }
        match s.blobs.list(&pre).await {
            Ok((folders, objects)) => {
                stack.extend(folders);
                for o in objects {
                    let rel = o
                        .key
                        .strip_prefix(&strip)
                        .unwrap_or(&o.key)
                        .to_string();
                    if files::clean_rel_key(&rel).is_err() {
                        continue;
                    }
                    out.push(files::FileEntry {
                        name: rel.rsplit('/').next().unwrap_or(&rel).to_string(),
                        path: rel,
                        kind: "file".into(),
                        size: o.size,
                        modified: o.modified,
                        rev: o.rev,
                    });
                }
            }
            Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e),
        }
    }
    out.sort_by(|a, b| a.path.cmp(&b.path));
    Json(json!(out)).into_response()
}

/// The blob's current rev, or None when it does not exist. Lists the parent
/// prefix so no extra backend call shape is needed.
async fn blob_rev(s: &AppState, dir: &str, key: &str) -> Result<Option<String>, String> {
    let full = blob_key(dir, key);
    let parent = full.rsplit_once('/').map(|(p, _)| p).unwrap_or("");
    let (_, objects) = s.blobs.list(parent).await?;
    Ok(objects
        .into_iter()
        .find(|o| o.key == full)
        .map(|o| o.rev))
}

/// `base` is the rev the client last synced. `"none"` means the file must
/// not exist yet. An empty base skips the check (legacy callers).
async fn check_base(
    s: &AppState,
    dir: &str,
    key: &str,
    base: &str,
) -> Result<(), Response> {
    if base.is_empty() {
        return Ok(());
    }
    let cur = blob_rev(s, dir, key)
        .await
        .map_err(|e| err(StatusCode::INTERNAL_SERVER_ERROR, &e))?;
    let ok = match (cur.as_deref(), base) {
        (None, "none") => true,
        (Some(r), b) => r == b,
        _ => false,
    };
    if ok {
        Ok(())
    } else {
        Err((
            StatusCode::CONFLICT,
            Json(json!({"error": "stale", "rev": cur})),
        )
            .into_response())
    }
}

/// Lock kind guarding `key`: ScriptCraft owns Script/, DeckCraft owns
/// Boards/, everything else falls under FilmCraft's "edit".
fn write_lock_kind(key: &str) -> &'static str {
    if key.starts_with("Script/") {
        "script"
    } else if key.starts_with("Boards/") {
        "deck"
    } else {
        "edit"
    }
}

/// Reject a write made by a client that lost the edit lock for this file's
/// domain. Callers without a clientId skip the check (legacy behaviour).
async fn check_write_lock(
    s: &AppState,
    project_id: &str,
    key: &str,
    client_id: &str,
) -> Result<(), Response> {
    if client_id.is_empty() {
        return Ok(());
    }
    match s.db.lock_get(project_id, write_lock_kind(key)).await {
        Ok(l) if l.holder != client_id && l.expires_at > AppState::now() => {
            Err(err(StatusCode::CONFLICT, "lock lost"))
        }
        _ => Ok(()),
    }
}

async fn usage_bytes(s: &AppState, prefix: &str) -> u64 {
    let mut total = 0u64;
    let mut stack = vec![prefix.trim_matches('/').to_string()];
    let mut guard = 0usize;
    while let Some(p) = stack.pop() {
        guard += 1;
        if guard > 10000 {
            break;
        }
        match s.blobs.list(&p).await {
            Ok((dirs, objs)) => {
                for o in objs {
                    total = total.saturating_add(o.size);
                }
                stack.extend(dirs);
            }
            Err(_) => break,
        }
    }
    total
}

async fn quota_exceeded(s: &AppState, owner_id: &str, incoming: u64) -> bool {
    let owner = match s.db.user_by_id(owner_id).await {
        Ok(u) => u,
        Err(_) => return false,
    };
    if owner.quota_bytes <= 0 {
        return false;
    }
    let used = usage_bytes(s, &format!("{}/{}", owner.username, owner.id)).await;
    used.saturating_add(incoming) > owner.quota_bytes as u64
}

async fn project_usage(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match read_project(&s, &session, &id).await {
        Ok(p) => {
            let bytes = usage_bytes(&s, &p.dir).await;
            Json(json!({"bytes": bytes})).into_response()
        }
        Err(r) => r,
    }
}

async fn account_usage(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match require_manager(&s, &session, &id).await {
        Ok(t) => {
            let bytes = usage_bytes(&s, &format!("{}/{}", t.username, t.id)).await;
            Json(json!({"bytes": bytes})).into_response()
        }
        Err(r) => r,
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
    let p = match edit_project(&s, &session, &id).await {
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
    if quota_exceeded(&s, &p.owner_id, len).await {
        return err(StatusCode::PAYLOAD_TOO_LARGE, "storage quota exceeded");
    }
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    if !files::upload_allowed(&key) {
        return err(StatusCode::UNSUPPORTED_MEDIA_TYPE, "unsupported file type");
    }
    if let Err(r) = check_write_lock(&s, &id, &key, &q.client_id).await {
        return r;
    }
    if let Err(r) = check_base(&s, &p.dir, &key, &q.base).await {
        return r;
    }
    let (tmp, written) = match spool_body(&s, body, s.cfg.max_upload).await {
        Ok(v) => v,
        Err(r) => return r,
    };
    if let Err(r) = sniff_spool(&tmp, &key).await {
        return r;
    }
    let put = async {
        let mut f = tokio::fs::File::open(&tmp)
            .await
            .map_err(|e| e.to_string())?;
        s.blobs.put(&blob_key(&p.dir, &key), written, &mut f).await
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

#[derive(Deserialize)]
struct UploadStart {
    path: String,
    #[serde(default, rename = "clientId")]
    client_id: String,
    #[serde(default)]
    base: String,
}

#[derive(Deserialize)]
struct ChunkQuery {
    offset: u64,
}

fn chunk_upload(s: &AppState, session: &Session, uid: &str) -> Option<ChunkUpload> {
    s.chunk_uploads
        .lock()
        .unwrap()
        .get(uid)
        .filter(|u| u.user == session.user.id)
        .cloned()
}

async fn upload_start(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(b): Json<UploadStart>,
) -> Response {
    let p = match edit_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&b.path) {
        Ok(k) => k,
        Err(e) => return fs_resp(e),
    };
    if !files::upload_allowed(&key) {
        return err(StatusCode::UNSUPPORTED_MEDIA_TYPE, "unsupported file type");
    }
    if let Err(r) = check_write_lock(&s, &id, &key, &b.client_id).await {
        return r;
    }
    if let Err(r) = check_base(&s, &p.dir, &key, &b.base).await {
        return r;
    }
    let uid = model::new_id();
    let tmp = s.cfg.data_dir.join("tmp").join(format!("chunk-{uid}"));
    let _ = tokio::fs::create_dir_all(tmp.parent().unwrap()).await;
    if let Err(e) = tokio::fs::File::create(&tmp).await {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string());
    }
    s.chunk_uploads.lock().unwrap().insert(
        uid.clone(),
        ChunkUpload {
            project: p.id,
            dir: p.dir,
            display_name: p.display_name,
            user: session.user.id,
            key,
            client_id: b.client_id,
            tmp,
            received: 0,
            touched: AppState::now(),
        },
    );
    Json(json!({"id": uid})).into_response()
}

async fn upload_status(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(uid): Path<String>,
) -> Response {
    match chunk_upload(&s, &session, &uid) {
        Some(u) => Json(json!({"received": u.received})).into_response(),
        None => err(StatusCode::NOT_FOUND, "unknown upload"),
    }
}

async fn upload_chunk(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(uid): Path<String>,
    Query(q): Query<ChunkQuery>,
    headers: HeaderMap,
    body: Body,
) -> Response {
    let u = match chunk_upload(&s, &session, &uid) {
        Some(u) => u,
        None => return err(StatusCode::NOT_FOUND, "unknown upload"),
    };
    if q.offset != u.received {
        return (StatusCode::CONFLICT, Json(json!({"received": u.received}))).into_response();
    }
    if headers
        .get(header::CONTENT_LENGTH)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(0)
        > s.cfg.max_upload
    {
        return err(StatusCode::PAYLOAD_TOO_LARGE, "chunk too large");
    }
    let mut f = match tokio::fs::OpenOptions::new()
        .append(true)
        .open(&u.tmp)
        .await
    {
        Ok(f) => f,
        Err(e) => return err(StatusCode::INTERNAL_SERVER_ERROR, &e.to_string()),
    };
    let mut stream = body.into_data_stream();
    let mut n: u64 = 0;
    let mut failed = false;
    let first = u.received == 0;
    let mut head: Vec<u8> = Vec::new();
    let mut bad_type = false;
    while let Some(c) = stream.next().await {
        match c {
            Ok(b) => {
                if first && head.len() < 512 {
                    head.extend_from_slice(&b[..(512 - head.len()).min(b.len())]);
                    if head.len() >= 512 && !files::sniff_ok(&u.key, &head) {
                        bad_type = true;
                        break;
                    }
                }
                n += b.len() as u64;
                if n > s.cfg.max_upload
                    || tokio::io::AsyncWriteExt::write_all(&mut f, &b)
                        .await
                        .is_err()
                {
                    failed = true;
                    break;
                }
            }
            Err(_) => {
                failed = true;
                break;
            }
        }
    }
    if first && !bad_type && head.len() < 512 && !files::sniff_ok(&u.key, &head) {
        bad_type = true;
    }
    if bad_type {
        drop(f);
        let _ = tokio::fs::remove_file(&u.tmp).await;
        s.chunk_uploads.lock().unwrap().remove(&uid);
        return err(
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
            "file content doesn't match its type",
        );
    }
    if failed {
        let _ = f.set_len(u.received).await;
        return err(StatusCode::PAYLOAD_TOO_LARGE, "chunk too large");
    }
    let mut m = s.chunk_uploads.lock().unwrap();
    if let Some(v) = m.get_mut(&uid) {
        v.received += n;
        v.touched = AppState::now();
    }
    Json(json!({"received": u.received + n})).into_response()
}

async fn upload_complete(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(uid): Path<String>,
) -> Response {
    let u = match chunk_upload(&s, &session, &uid) {
        Some(u) => u,
        None => return err(StatusCode::NOT_FOUND, "unknown upload"),
    };
    if let Err(r) = check_write_lock(&s, &u.project, &u.key, &u.client_id).await {
        return r;
    }
    if let Ok(p) = s.db.project_by_id(&u.project).await {
        if quota_exceeded(&s, &p.owner_id, u.received).await {
            let _ = tokio::fs::remove_file(&u.tmp).await;
            s.chunk_uploads.lock().unwrap().remove(&uid);
            return err(StatusCode::PAYLOAD_TOO_LARGE, "storage quota exceeded");
        }
    }
    if let Err(r) = sniff_spool(&u.tmp, &u.key).await {
        s.chunk_uploads.lock().unwrap().remove(&uid);
        return r;
    }
    let put = async {
        let mut f = tokio::fs::File::open(&u.tmp)
            .await
            .map_err(|e| e.to_string())?;
        s.blobs
            .put(&blob_key(&u.dir, &u.key), u.received, &mut f)
            .await
    }
    .await;
    let _ = tokio::fs::remove_file(&u.tmp).await;
    s.chunk_uploads.lock().unwrap().remove(&uid);
    if let Err(e) = put {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
    }
    s.audit(
        "project",
        &session.user,
        "upload",
        &u.display_name,
        &u.key,
        "",
    )
    .await;
    Json(json!({"ok": true, "size": u.received})).into_response()
}

async fn upload_cancel(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(uid): Path<String>,
) -> Response {
    let u = match chunk_upload(&s, &session, &uid) {
        Some(u) => u,
        None => return err(StatusCode::NOT_FOUND, "unknown upload"),
    };
    s.chunk_uploads.lock().unwrap().remove(&uid);
    let _ = tokio::fs::remove_file(&u.tmp).await;
    Json(json!({"ok": true})).into_response()
}

/// Check a spooled upload's first bytes against the type its extension
/// claims. Removes the spool file on rejection.
async fn sniff_spool(tmp: &std::path::Path, key: &str) -> Result<(), Response> {
    use tokio::io::AsyncReadExt;
    let mut head = [0u8; 512];
    let n = match tokio::fs::File::open(tmp).await {
        Ok(mut f) => match f.read(&mut head).await {
            Ok(n) => n,
            Err(e) => return Err(fs_resp(e.into())),
        },
        Err(e) => return Err(fs_resp(e.into())),
    };
    if files::sniff_ok(key, &head[..n]) {
        Ok(())
    } else {
        let _ = tokio::fs::remove_file(tmp).await;
        Err(err(
            StatusCode::UNSUPPORTED_MEDIA_TYPE,
            "file content doesn't match its type",
        ))
    }
}

/// Spool a request body to a temp file with a size cap. Returns the temp path
/// and bytes written; the caller moves or deletes the file.
async fn spool_body(
    s: &AppState,
    body: Body,
    max: u64,
) -> Result<(std::path::PathBuf, u64), Response> {
    let tmp = s
        .cfg
        .data_dir
        .join("tmp")
        .join(format!("up-{}", model::new_id()));
    let _ = tokio::fs::create_dir_all(tmp.parent().unwrap()).await;
    let mut f = tokio::fs::File::create(&tmp)
        .await
        .map_err(|e| fs_resp(e.into()))?;
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
    #[serde(default, rename = "clientId")]
    client_id: String,
}

async fn mkdir(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<PathReq>,
) -> Response {
    let p = match edit_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if let Ok(k) = files::clean_rel_key(&req.path) {
        if let Err(r) = check_write_lock(&s, &id, &k, &req.client_id).await {
            return r;
        }
    }
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
    #[serde(default, rename = "clientId")]
    client_id: String,
    #[serde(default)]
    base: String,
}

async fn move_file(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Json(req): Json<MoveReq>,
) -> Response {
    let p = match edit_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let (fk, tk) = match (
        files::clean_rel_key(&req.from),
        files::clean_rel_key(&req.to),
    ) {
        (Ok(a), Ok(b)) => (a, b),
        _ => return err(StatusCode::BAD_REQUEST, "bad path"),
    };
    if fk == tk {
        return Json(json!({"ok": true})).into_response();
    }
    if let Err(r) = check_write_lock(&s, &id, &fk, &req.client_id).await {
        return r;
    }
    if let Err(r) = check_write_lock(&s, &id, &tk, &req.client_id).await {
        return r;
    }
    if let Err(r) = check_base(&s, &p.dir, &fk, &req.base).await {
        return r;
    }
    if let Some(from_ext) = key_ext(&fk) {
        if s.blobs.head(&blob_key(&p.dir, &fk)).await.is_ok()
            && key_ext(&tk).as_deref() != Some(from_ext.as_str())
        {
            return err(StatusCode::BAD_REQUEST, "extension change is not allowed");
        }
    }
    match s
        .blobs
        .rename(&blob_key(&p.dir, &fk), &blob_key(&p.dir, &tk))
        .await
    {
        Ok(()) => {
            s.audit(
                "project",
                &session.user,
                "move",
                &p.display_name,
                &format!("{} -> {}", req.from, req.to),
                "",
            )
            .await;
            Json(json!({"ok": true})).into_response()
        }
        Err(e) if e == "exists" => err(StatusCode::CONFLICT, &e),
        Err(e) => err(StatusCode::BAD_REQUEST, &e),
    }
}

async fn delete_file(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<FileQuery>,
) -> Response {
    let p = match edit_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let key = match files::clean_rel_key(&q.path) {
        Ok(k) if k.split('/').count() > 1 => k,
        _ => return err(StatusCode::FORBIDDEN, "cannot delete root folder"),
    };
    if let Err(r) = check_write_lock(&s, &id, &key, &q.client_id).await {
        return r;
    }
    if let Err(r) = check_base(&s, &p.dir, &key, &q.base).await {
        return r;
    }
    match s.blobs.delete(&blob_key(&p.dir, &key)).await {
        Ok(()) => {
            s.audit(
                "project",
                &session.user,
                "delete_file",
                &p.display_name,
                &q.path,
                "",
            )
            .await;
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
    let range = q.start.map(|a| (a, q.end.unwrap_or(u64::MAX)));
    serve_blob(&s, &blob_key(&p.dir, &key), &key, &headers, q.dl, range).await
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

#[derive(Deserialize)]
struct ZipQuery {
    paths: String,
}

async fn collect_zip(s: &Arc<AppState>, dir: &str, rel: &str, out: &mut Vec<(String, String)>) {
    let key = blob_key(dir, rel);
    if s.blobs.head(&key).await.is_ok() {
        out.push((rel.to_string(), key));
        return;
    }
    let mut stack = vec![key];
    while let Some(pre) = stack.pop() {
        if let Ok((folders, objects)) = s.blobs.list(&pre).await {
            stack.extend(folders);
            for o in objects {
                let name = o.key.strip_prefix(&format!("{dir}/")).unwrap_or(&o.key);
                out.push((name.to_string(), o.key));
            }
        }
    }
}

async fn zip_download(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
    Query(q): Query<ZipQuery>,
) -> Response {
    let p = match read_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let mut entries: Vec<(String, String)> = Vec::new();
    for raw in q.paths.split(',') {
        let rel = match files::clean_rel_key(raw.trim()) {
            Ok(k) => k,
            Err(e) => return fs_resp(e),
        };
        collect_zip(&s, &p.dir, &rel, &mut entries).await;
    }
    if entries.is_empty() {
        return err(StatusCode::NOT_FOUND, "nothing to zip");
    }
    let blobs = s.blobs.clone();
    let stream: std::pin::Pin<
        Box<dyn futures::Stream<Item = Result<Bytes, std::io::Error>> + Send>,
    > = Box::pin(async_stream::try_stream! {
        let mut recs: Vec<crate::zip::Rec> = Vec::with_capacity(entries.len());
        let mut off: u64 = 0;
        for (name, key) in entries {
            let size = blobs
                .head(&key)
                .await
                .map_err(std::io::Error::other)?;
            let h = crate::zip::local_header(&name, size);
            let rec_off = off;
            off += h.len() as u64 + size + 24;
            yield Bytes::from(h);
            let (_, mut data) = blobs
                .get(&key)
                .await
                .map_err(|e| std::io::Error::other(e))?;
            let mut crc = crc32fast::Hasher::new();
            while let Some(chunk) = data.next().await {
                let b = chunk.map_err(|e| std::io::Error::other(e))?;
                crc.update(&b);
                yield b;
            }
            let c = crc.finalize();
            let dd = crate::zip::data_desc(c, size);
            yield Bytes::from(dd);
            recs.push(crate::zip::Rec { name, crc: c, size, offset: rec_off });
        }
        let cd_off = off;
        yield Bytes::from(crate::zip::end(&recs, cd_off));
    });
    Response::builder()
        .header(header::CONTENT_TYPE, "application/zip")
        .header(
            header::CONTENT_DISPOSITION,
            format!("attachment; filename=\"{}.zip\"", p.name),
        )
        .body(Body::from_stream(stream))
        .unwrap_or_else(|_| err(StatusCode::INTERNAL_SERVER_ERROR, "zip"))
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
    serve_blob(&s, &tk, "thumb.jpg", &HeaderMap::new(), false, None).await
}

async fn serve_blob(
    s: &Arc<AppState>,
    key: &str,
    name: &str,
    headers: &HeaderMap,
    attachment: bool,
    range: Option<(u64, u64)>,
) -> Response {
    let size = match s.blobs.head(key).await {
        Ok(v) => v,
        Err(_) => return err(StatusCode::NOT_FOUND, "not found"),
    };
    // A `start`/`end` query pair asks for a range without the `Range` header, which some
    // browsers cannot send on fetch and some proxies drop.
    let (start, end, partial) = match range
        .map(|(a, b)| (a, b.min(size.saturating_sub(1))))
        .filter(|(a, b)| a <= b)
    {
        Some((a, b)) => (a, b, true),
        None => match headers.get(header::RANGE).and_then(|v| v.to_str().ok()) {
            Some(r) => match parse_range(r, size) {
                Some((a, b)) => (a, b, true),
                None => (0u64, size.saturating_sub(1), false),
            },
            None => (0u64, size.saturating_sub(1), false),
        },
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
    let mime = mime_guess::from_path(name)
        .first_or_octet_stream()
        .to_string();
    let len = end.saturating_sub(start) + 1;
    let status = if partial {
        StatusCode::PARTIAL_CONTENT
    } else {
        StatusCode::OK
    };
    let mut r = Response::new(Body::from_stream(stream));
    *r.status_mut() = status;
    let h = r.headers_mut();
    h.insert(header::CONTENT_TYPE, HeaderValue::from_str(&mime).unwrap());
    h.insert(
        header::CONTENT_LENGTH,
        HeaderValue::from_str(&len.to_string()).unwrap(),
    );
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
            .map(|c| {
                if c.is_ascii_alphanumeric() || "._- ".contains(c) {
                    c
                } else {
                    '_'
                }
            })
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
    use super::*;
    use std::collections::{HashMap, HashSet};
    use std::sync::{Mutex, RwLock};

    fn state(dir: &std::path::Path) -> Arc<AppState> {
        Arc::new(AppState {
            cfg: crate::config::Config {
                addr: String::new(),
                data_dir: dir.to_path_buf(),
                web_dir: None,
                filmcraft_dir: None,
                scriptcraft_dir: None,
                deckcraft_dir: None,
                max_upload: u64::MAX,
                secure_cookies: false,
                cors_origins: vec![],
                render_workers: 0,
                filmcraft_cli: String::new(),
                ffmpeg: String::new(),
                local_renders: false,
                db_url: None,
                session_ttl: 86400,
                audit_days: 0,
                lock_ttl: 45,
                worker: None,
                media_kind: "local".into(),
                media_path: None,
                s3_endpoint: String::new(),
                s3_region: String::new(),
                s3_bucket: String::new(),
                s3_access: String::new(),
                s3_secret: String::new(),
                s3_prefix: String::new(),
                trusted_proxies: vec![],
            },
            db: futures::executor::block_on(crate::store::sqlite::connect(":memory:")).unwrap(),
            blobs: Arc::new(crate::blobs::LocalBlobs::new(dir.join("blobs"))),
            logins: Mutex::new(HashMap::new()),
            link_hits: Mutex::new(HashMap::new()),
            cancels: Mutex::new(HashSet::new()),
            inspect_cache: Mutex::new(HashMap::new()),
            chunk_uploads: Mutex::new(HashMap::new()),
            handoffs: Mutex::new(HashMap::new()),
            update_check: Mutex::new(None),
            trusted: RwLock::new(vec![]),
        })
    }

    fn user(role: Role) -> User {
        User {
            id: model::new_id(),
            username: model::new_id(),
            display_name: "u".into(),
            role,
            role_name: role.as_str().into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            class_id: String::new(),
            lineage: "/".into(),
            created_at: AppState::now(),
            last_login: 0,
        }
    }

    fn project(owner: &User) -> Project {
        Project {
            id: model::new_id(),
            owner_id: owner.id.clone(),
            name: "p".into(),
            display_name: "p".into(),
            dir: format!("d/{}", model::new_id()),
            group_id: String::new(),
            tags: vec![],
            created_at: AppState::now(),
            last_activity: AppState::now(),
            pinned: false,
            template: false,
            status: "draft".into(),
            submitted_at: 0,
            reviewed_by: String::new(),
        }
    }

    fn session(u: &User) -> Session {
        Session {
            user: u.clone(),
            csrf: "c".into(),
            token_hash: "t".into(),
        }
    }

    fn patch_body(template: Option<bool>) -> Json<UpdateProjectReq> {
        Json(UpdateProjectReq {
            display_name: None,
            group_id: None,
            tags: None,
            pinned: None,
            template,
        })
    }

    #[tokio::test]
    async fn template_flag_is_staff_only() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);

        let student = user(Role::Student);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        let r = update_project(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            patch_body(Some(true)),
        )
        .await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN);
        assert!(!s.db.project_by_id(&p.id).await.unwrap().template);

        let teacher = user(Role::Teacher);
        let p = project(&teacher);
        s.db.create_project(&p).await.unwrap();
        let r = update_project(
            State(s.clone()),
            session(&teacher),
            Path(p.id.clone()),
            patch_body(Some(true)),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        assert!(s.db.project_by_id(&p.id).await.unwrap().template);
    }

    #[tokio::test]
    async fn students_can_still_patch_other_fields() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);

        let student = user(Role::Student);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        let r = update_project(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            Json(UpdateProjectReq {
                display_name: Some("new name".into()),
                group_id: None,
                tags: None,
                pinned: Some(true),
                template: None,
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let p = s.db.project_by_id(&p.id).await.unwrap();
        assert_eq!(p.display_name, "new name");
        assert!(p.pinned);
    }

    fn upload_req(path: &str, body: &'static [u8]) -> (Query<FileQuery>, HeaderMap, Body) {
        (
            Query(FileQuery {
                path: path.into(),
                dl: false,
                done: false,
                client_id: String::new(),
                base: String::new(),
                start: None,
                end: None,
            }),
            HeaderMap::new(),
            Body::from(body),
        )
    }

    #[tokio::test]
    async fn upload_rejects_bad_types_and_fakes() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);

        let student = user(Role::Student);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();

        let (q, h, b) = upload_req("Raw/run.exe", b"MZ\x90\x00exe");
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::UNSUPPORTED_MEDIA_TYPE);
        assert!(s
            .blobs
            .head(&format!("{}/Raw/run.exe", p.dir))
            .await
            .is_err());

        // An allowed extension whose bytes do not match is refused too.
        let (q, h, b) = upload_req("Raw/fake.mp4", b"MZ\x90\x00exe");
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::UNSUPPORTED_MEDIA_TYPE);
        assert!(s
            .blobs
            .head(&format!("{}/Raw/fake.mp4", p.dir))
            .await
            .is_err());

        let (q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomrest");
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        assert_eq!(
            s.blobs
                .head(&format!("{}/Raw/clip.mp4", p.dir))
                .await
                .unwrap(),
            16
        );

        // The managed doc paths the host editors write to work end to end.
        let (q, h, b) = upload_req("Script/script.fountain", b"Title: T\n\nINT. ROOM");
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
    }

    #[test]
    fn write_lock_domains() {
        assert_eq!(write_lock_kind("Script/script.fountain"), "script");
        assert_eq!(write_lock_kind("Script/notes/t.txt"), "script");
        assert_eq!(write_lock_kind("Boards/boards.deckcraft"), "deck");
        assert_eq!(write_lock_kind("project.fcproj"), "edit");
        assert_eq!(write_lock_kind("Raw/a.mp4"), "edit");
        assert_eq!(write_lock_kind("Exports/cut.mp4"), "edit");
    }

    #[tokio::test]
    async fn manifest_lists_everything_with_revs() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);

        let student = user(Role::Student);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();

        let put = |key: &str, body: &'static [u8]| {
            let s = s.clone();
            let pdir = p.dir.clone();
            let key = key.to_string();
            async move {
                let mut c = std::io::Cursor::new(body);
                s.blobs
                    .put(&format!("{pdir}/{key}"), body.len() as u64, &mut c)
                    .await
                    .unwrap();
            }
        };
        put("project.fcproj", b"{\"format\":\"filmcraft.project\"}").await;
        put("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomrest").await;
        put("Script/script.fountain", b"Title: T\n\nINT. ROOM").await;

        let r = project_manifest(State(s.clone()), session(&student), Path(p.id.clone()))
            .await;
        assert_eq!(r.status(), StatusCode::OK);
        let body = axum::body::to_bytes(r.into_body(), usize::MAX)
            .await
            .unwrap();
        let list: Vec<Value> = serde_json::from_slice(&body).unwrap();
        let paths: Vec<&str> = list.iter().filter_map(|e| e["path"].as_str()).collect();
        assert_eq!(
            paths,
            vec!["Raw/clip.mp4", "Script/script.fountain", "project.fcproj"]
        );
        for e in &list {
            assert!(!e["rev"].as_str().unwrap_or_default().is_empty());
        }
    }

    #[tokio::test]
    async fn base_precondition_guards_writes() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);

        let student = user(Role::Student);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();

        // A write claiming a base on a file that does not exist is stale.
        let (mut q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomrest");
        q.base = "deadbeef-10".into();
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h.clone(),
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::CONFLICT);

        // `base=none` allows the create.
        let (mut q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomrest");
        q.base = "none".into();
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);

        let rev = blob_rev(&s, &p.dir, "Raw/clip.mp4").await.unwrap().unwrap();

        // Rewriting with the right base works; with a stale one it is refused.
        let (mut q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomv2");
        q.base = "wrong".into();
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::CONFLICT);

        let (mut q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomv2");
        q.base = rev;
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn lock_holder_blocks_other_writers() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);

        let student = user(Role::Student);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        s.db
            .lock_acquire(
                &p.id,
                "script",
                "web-tab-1",
                &student.username,
                AppState::now() + 60,
                AppState::now(),
                false,
            )
            .await
            .unwrap();

        // Another client writing into Script/ is refused; the holder is not.
        let (mut q, h, b) = upload_req("Script/script.fountain", b"Title: T\n\nINT. ROOM");
        q.client_id = "native-run-9".into();
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h.clone(),
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::CONFLICT);

        let (mut q, h, b) = upload_req("Script/script.fountain", b"Title: T\n\nINT. ROOM");
        q.client_id = "web-tab-1".into();
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);

        // A different lock kind does not guard Raw/ writes.
        let (mut q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomrest");
        q.client_id = "native-run-9".into();
        let r = upload_file(
            State(s.clone()),
            session(&student),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
    }

    #[test]
    fn file_extensions_compare_case_insensitively() {
        assert_eq!(key_ext("dir/KDR_9751.MOV"), Some("mov".to_string()));
        assert_eq!(key_ext("a/b/clip.mp4"), Some("mp4".to_string()));
        assert_eq!(key_ext("dir/noext"), None);
        assert_eq!(key_ext("archive.tar.gz"), Some("gz".to_string()));
    }

    #[test]
    fn semver_parses_tags() {
        assert_eq!(parse_semver("v1.2.3"), Some((1, 2, 3)));
        assert_eq!(parse_semver("1.5"), Some((1, 5, 0)));
        assert_eq!(parse_semver("V2.0.1-rc1"), Some((2, 0, 1)));
        assert_eq!(parse_semver("nightly"), None);
        assert_eq!(parse_semver("1"), None);
        assert_eq!(parse_semver("1.2.3.4"), None);
        assert_eq!(parse_semver("1.x.3"), None);
    }

    #[test]
    fn handoff_destinations() {
        assert_eq!(
            handoff_to("/filmcraft/wfm.html?project=p1").as_deref(),
            Some("/filmcraft/wfm.html?project=p1")
        );
        assert_eq!(handoff_to("/").as_deref(), Some("/"));
        assert_eq!(handoff_to("https://evil.example"), None);
        assert_eq!(handoff_to("//evil.example"), None);
        assert_eq!(handoff_to(""), None);
        assert_eq!(handoff_to(&"/".repeat(2001)), None);
    }

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
    fn lock_kinds() {
        for k in ["edit", "render", "docs", "script", "deck"] {
            assert!(lock_kind(k), "{k}");
        }
        for k in ["", "Edit", "doc", "write", "scriptcraft"] {
            assert!(!lock_kind(k), "{k}");
        }
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

    #[tokio::test]
    async fn shortcut_catalog_selects_app() {
        let u = user(Role::Student);
        for (app, want, not) in [
            (None, "file.newSequence", "ui.save"),
            (Some("filmcraft"), "file.newSequence", "ui.save"),
            (Some("scriptcraft"), "ui.save", "file.newSequence"),
            (Some("bogus"), "file.newSequence", "ui.save"),
        ] {
            let r = shortcut_catalog(
                session(&u),
                Query(CatalogQuery {
                    app: app.map(str::to_string),
                }),
            )
            .await;
            let b = axum::body::to_bytes(r.into_body(), usize::MAX)
                .await
                .unwrap();
            let s = String::from_utf8_lossy(&b);
            assert!(s.contains(want), "{app:?} should serve {want}");
            assert!(!s.contains(not), "{app:?} should not serve {not}");
        }
    }

    fn school(s: &Arc<AppState>) -> (User, User, User, User, User, User) {
        let owner = user(Role::Owner);
        let mut teacher = user(Role::Teacher);
        teacher.created_by = owner.id.clone();
        teacher.lineage = format!("/{}/", owner.id);
        let mut teacher2 = user(Role::Teacher);
        teacher2.created_by = owner.id.clone();
        teacher2.lineage = teacher.lineage.clone();
        let mut student = user(Role::Student);
        student.created_by = teacher.id.clone();
        student.lineage = format!("{}{}/", teacher.lineage, teacher.id);
        student.class_id = futures::executor::block_on(s.db.unmanaged_class(&teacher))
            .unwrap()
            .id;
        let mut classmate = user(Role::Student);
        classmate.created_by = teacher.id.clone();
        classmate.lineage = student.lineage.clone();
        classmate.class_id = student.class_id.clone();
        let mut outsider = user(Role::Student);
        outsider.created_by = teacher2.id.clone();
        outsider.lineage = format!("{}{}/", teacher2.lineage, teacher2.id);
        outsider.class_id = futures::executor::block_on(s.db.unmanaged_class(&teacher2))
            .unwrap()
            .id;
        for u in [&owner, &teacher, &teacher2, &student, &classmate, &outsider] {
            futures::executor::block_on(s.db.create_user(u, "h")).unwrap();
        }
        (owner, teacher, teacher2, student, classmate, outsider)
    }

    #[tokio::test]
    async fn share_only_reaches_visible_users() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, teacher2, student, classmate, outsider) = school(&s);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        let share = |to: &User| {
            Json(ShareReq {
                username: to.username.clone(),
                level: "view".into(),
            })
        };
        for (to, want) in [
            (&outsider, StatusCode::NOT_FOUND),
            (&teacher2, StatusCode::NOT_FOUND),
            (&teacher, StatusCode::OK),
            (&classmate, StatusCode::OK),
        ] {
            let r = create_share(
                State(s.clone()),
                session(&student),
                Path(p.id.clone()),
                share(to),
            )
            .await;
            assert_eq!(r.status(), want, "share to {}", to.username);
        }
    }

    #[tokio::test]
    async fn share_targets_returns_the_visibility_set() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (owner, teacher, teacher2, student, classmate, outsider) = school(&s);
        let body = |r: Response| async move {
            String::from_utf8_lossy(
                &axum::body::to_bytes(r.into_body(), usize::MAX)
                    .await
                    .unwrap(),
            )
            .to_string()
        };
        let t = body(share_targets(State(s.clone()), session(&student)).await).await;
        for u in [&teacher, &classmate, &owner] {
            assert!(t.contains(&u.username), "student sees {}", u.username);
        }
        for u in [&teacher2, &outsider] {
            assert!(!t.contains(&u.username), "student hides {}", u.username);
        }
        let t = body(share_targets(State(s.clone()), session(&teacher)).await).await;
        assert!(t.contains(&student.username) && t.contains(&owner.username));
        assert!(
            !t.contains(&teacher2.username),
            "a teacher's peers stay hidden"
        );
        assert!(
            !t.contains(&outsider.username),
            "other trees' students stay hidden"
        );
    }

    async fn body_json(r: Response) -> Value {
        serde_json::from_slice(
            &axum::body::to_bytes(r.into_body(), usize::MAX)
                .await
                .unwrap(),
        )
        .unwrap()
    }

    fn class_req(name: &str) -> Json<ClassReq> {
        Json(ClassReq { name: name.into() })
    }

    fn move_class(class_id: &str) -> Json<UpdateAccountReq> {
        Json(UpdateAccountReq {
            username: None,
            name: None,
            role: None,
            student_id: None,
            note: None,
            quota_bytes: None,
            class_id: Some(class_id.into()),
        })
    }

    #[tokio::test]
    async fn classes_crud_scoped_to_the_owner() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, teacher2, student, _classmate, _outsider) = school(&s);
        let r = create_class(State(s.clone()), session(&student), class_req("x")).await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN);
        let r = create_class(State(s.clone()), session(&teacher), class_req("!!")).await;
        assert_eq!(r.status(), StatusCode::BAD_REQUEST);
        let r = create_class(State(s.clone()), session(&teacher), class_req("Period 1")).await;
        assert_eq!(r.status(), StatusCode::OK);
        let cid = body_json(r).await["id"].as_str().unwrap().to_string();
        let r = create_class(State(s.clone()), session(&teacher), class_req("Period 1")).await;
        assert_eq!(
            r.status(),
            StatusCode::CONFLICT,
            "names are unique per owner"
        );

        let v = body_json(list_classes(State(s.clone()), session(&teacher)).await).await;
        let mine = v.as_array().unwrap();
        assert!(mine.iter().any(|c| c["id"] == json!(cid)));
        let v = body_json(list_classes(State(s.clone()), session(&teacher2)).await).await;
        assert!(
            !v.as_array().unwrap().iter().any(|c| c["id"] == json!(cid)),
            "other teachers' classes stay hidden"
        );
        let v = body_json(list_classes(State(s.clone()), session(&student)).await).await;
        let v = v.as_array().unwrap();
        assert_eq!(v.len(), 1, "a student sees only their own class");
        assert_eq!(v[0]["id"], json!(student.class_id));

        for (who, want) in [
            (&teacher2, StatusCode::FORBIDDEN),
            (&student, StatusCode::FORBIDDEN),
        ] {
            let r = rename_class(
                State(s.clone()),
                session(who),
                Path(cid.clone()),
                class_req("nope"),
            )
            .await;
            assert_eq!(r.status(), want);
            let r = delete_class(State(s.clone()), session(who), Path(cid.clone())).await;
            assert_eq!(r.status(), want);
        }
        let r = rename_class(
            State(s.clone()),
            session(&teacher),
            Path(cid.clone()),
            class_req("Period 2"),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn class_moves_gate_sharing() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (owner, teacher, teacher2, student, classmate, outsider) = school(&s);
        let r = create_class(State(s.clone()), session(&teacher), class_req("Period 1")).await;
        let cid = body_json(r).await["id"].as_str().unwrap().to_string();

        let r = update_account(
            State(s.clone()),
            session(&teacher),
            Path(student.id.clone()),
            move_class(&cid),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let student = s.db.user_by_id(&student.id).await.unwrap();
        assert_eq!(student.class_id, cid);

        let t = body_json(share_targets(State(s.clone()), session(&student)).await).await;
        let t = t.to_string();
        assert!(t.contains(&teacher.username), "staff stay visible");
        assert!(
            !t.contains(&classmate.username),
            "former classmates in other classes stay hidden"
        );
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        let r = create_share(
            State(s.clone()),
            session(&student),
            Path(p.id),
            Json(ShareReq {
                username: classmate.username.clone(),
                level: "view".into(),
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::NOT_FOUND, "cross-class shares fail");

        let r = update_account(
            State(s.clone()),
            session(&teacher),
            Path(student.id.clone()),
            move_class(&outsider.class_id),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "cannot move a student into another teacher's class"
        );
        let r = update_account(
            State(s.clone()),
            session(&owner),
            Path(teacher2.id.clone()),
            move_class(&cid),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::BAD_REQUEST,
            "teachers do not join classes"
        );

        let r = delete_class(State(s.clone()), session(&teacher), Path(cid)).await;
        assert_eq!(r.status(), StatusCode::OK);
        let student = s.db.user_by_id(&student.id).await.unwrap();
        let unmanaged = s.db.unmanaged_class(&teacher).await.unwrap();
        assert_eq!(student.class_id, unmanaged.id, "members land in unmanaged");

        let r = delete_class(
            State(s.clone()),
            session(&teacher),
            Path(unmanaged.id.clone()),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::BAD_REQUEST,
            "unmanaged cannot be deleted"
        );
        let r = rename_class(
            State(s.clone()),
            session(&teacher),
            Path(unmanaged.id),
            class_req("x"),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::BAD_REQUEST,
            "unmanaged cannot be renamed"
        );
    }

    #[tokio::test]
    async fn co_teachers_run_the_class() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, teacher2, student, _classmate, _outsider) = school(&s);
        let r = create_class(State(s.clone()), session(&teacher), class_req("Period 1")).await;
        let cid = body_json(r).await["id"].as_str().unwrap().to_string();

        let r = add_class_teacher(
            State(s.clone()),
            session(&teacher),
            Path(cid.clone()),
            Json(CoTeacherReq {
                username: teacher2.username.clone(),
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);

        let v = body_json(list_classes(State(s.clone()), session(&teacher2)).await).await;
        assert!(
            v.as_array().unwrap().iter().any(|c| c["id"] == json!(cid)),
            "co-taught classes are listed"
        );
        let r = list_class_teachers(State(s.clone()), session(&teacher2), Path(cid.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);

        let r = update_account(
            State(s.clone()),
            session(&teacher),
            Path(student.id.clone()),
            move_class(&cid),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let student = s.db.user_by_id(&student.id).await.unwrap();

        let accounts = body_json(list_accounts(State(s.clone()), session(&teacher2)).await).await;
        assert!(
            accounts
                .as_array()
                .unwrap()
                .iter()
                .any(|a| a["id"] == json!(student.id)),
            "co-teachers manage the roster"
        );
        let t = body_json(share_targets(State(s.clone()), session(&teacher2)).await)
            .await
            .to_string();
        assert!(t.contains(&student.username), "members are share targets");

        let r = update_account(
            State(s.clone()),
            session(&teacher2),
            Path(student.id.clone()),
            Json(UpdateAccountReq {
                username: None,
                name: Some("Renamed".into()),
                role: None,
                student_id: None,
                note: None,
                quota_bytes: None,
                class_id: None,
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK, "co-teachers edit members");

        let r = rename_class(
            State(s.clone()),
            session(&teacher2),
            Path(cid.clone()),
            class_req("nope"),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "co-teachers do not rename"
        );
        let r = delete_class(State(s.clone()), session(&teacher2), Path(cid.clone())).await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "co-teachers do not delete"
        );
        let r = add_class_teacher(
            State(s.clone()),
            session(&teacher2),
            Path(cid.clone()),
            Json(CoTeacherReq {
                username: "whoever".into(),
            }),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "co-teachers do not add co-teachers"
        );
        let r = remove_class_teacher(
            State(s.clone()),
            session(&teacher2),
            Path((cid.clone(), teacher2.id.clone())),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "co-teachers do not remove themselves"
        );

        let r = create_share(
            State(s.clone()),
            session(&student),
            Path({
                let p = project(&student);
                s.db.create_project(&p).await.unwrap();
                p.id
            }),
            Json(ShareReq {
                username: teacher2.username.clone(),
                level: "view".into(),
            }),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::OK,
            "students can share work with their co-teacher"
        );
    }

    #[tokio::test]
    async fn new_students_land_in_unmanaged() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, teacher2, student, _classmate, _outsider) = school(&s);
        let unmanaged = student.class_id.clone();
        let account = |username: &str, class_id: &str| {
            Json(CreateAccountReq {
                username: username.into(),
                password: "password1".into(),
                name: "N".into(),
                role: "student".into(),
                student_id: String::new(),
                note: String::new(),
                class_id: class_id.into(),
            })
        };
        let r = create_account(State(s.clone()), session(&teacher), account("newst", "")).await;
        assert_eq!(r.status(), StatusCode::OK);
        assert_eq!(
            body_json(r).await["classId"],
            json!(unmanaged),
            "students default to the creator's unmanaged class"
        );
        let r = create_class(State(s.clone()), session(&teacher), class_req("Period 1")).await;
        let cid = body_json(r).await["id"].as_str().unwrap().to_string();
        let r = create_account(State(s.clone()), session(&teacher), account("newst2", &cid)).await;
        assert_eq!(r.status(), StatusCode::OK);
        assert_eq!(body_json(r).await["classId"], json!(cid));

        let mut staff = account("newt", &cid);
        staff.role = "teacher".into();
        let r = create_account(State(s.clone()), session(&teacher), staff).await;
        assert_eq!(r.status(), StatusCode::OK, "owner creates a co-teacher");
        let body = body_json(r).await;
        assert_eq!(
            body["classId"],
            json!(""),
            "co-teachers never become class members"
        );
        assert!(
            s.db.co_teaches(&cid, body["id"].as_str().unwrap())
                .await
                .unwrap(),
            "the new account co-teaches the class"
        );

        let r = list_class_teachers(State(s.clone()), session(&teacher), Path(cid.clone())).await;
        let list = body_json(r).await;
        assert_eq!(list.as_array().unwrap().len(), 1);

        let other = create_class(State(s.clone()), session(&teacher2), class_req("P2")).await;
        let cid2 = body_json(other).await["id"].as_str().unwrap().to_string();
        let mut staff = account("newt2", &cid2);
        staff.role = "teacher".into();
        let r = create_account(State(s.clone()), session(&teacher), staff).await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "cannot seed co-teachers into a class owned by someone else"
        );

        let r = add_class_teacher(
            State(s.clone()),
            session(&teacher),
            Path(cid.clone()),
            Json(CoTeacherReq {
                username: "newt".into(),
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK, "existing staff can join too");

        let r = remove_class_teacher(
            State(s.clone()),
            session(&teacher2),
            Path((cid.clone(), "whatever".into())),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "only the main teacher manages co-teachers"
        );

        let r = remove_class_teacher(
            State(s.clone()),
            session(&teacher),
            Path((cid.clone(), "nope".into())),
        )
        .await;
        assert_eq!(r.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn list_projects_only_returns_own() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, _teacher2, student, classmate, outsider) = school(&s);
        let mine = project(&teacher);
        s.db.create_project(&mine).await.unwrap();
        for owner in [&student, &classmate, &outsider] {
            s.db.create_project(&project(owner)).await.unwrap();
        }
        let body = |r: Response| async move {
            String::from_utf8_lossy(
                &axum::body::to_bytes(r.into_body(), usize::MAX)
                    .await
                    .unwrap(),
            )
            .to_string()
        };
        let t = body(list_projects(State(s.clone()), session(&teacher)).await).await;
        let v: Vec<serde_json::Value> = serde_json::from_str(&t).unwrap();
        assert_eq!(v.len(), 1, "managed projects stay off the list");
        assert_eq!(v[0]["id"], json!(mine.id));
    }

    #[tokio::test]
    async fn account_projects_lists_a_managed_users_projects() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, teacher2, student, _classmate, _outsider) = school(&s);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        let r = account_projects(
            State(s.clone()),
            session(&teacher),
            Path(student.id.clone()),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let t = String::from_utf8_lossy(
            &axum::body::to_bytes(r.into_body(), usize::MAX)
                .await
                .unwrap(),
        )
        .to_string();
        let v: Vec<serde_json::Value> = serde_json::from_str(&t).unwrap();
        assert_eq!(v.len(), 1);
        assert_eq!(v[0]["id"], json!(p.id));
        assert_eq!(v[0]["access"], json!("view"));
        assert_eq!(v[0]["takeOver"], json!(true));

        for (who, target) in [
            (&student, &student),
            (&teacher2, &student),
            (&teacher, &teacher),
        ] {
            let r = account_projects(State(s.clone()), session(who), Path(target.id.clone())).await;
            assert_eq!(
                r.status(),
                StatusCode::FORBIDDEN,
                "{} cannot list {}'s projects",
                who.username,
                target.username
            );
        }
    }

    #[tokio::test]
    async fn higher_rank_cannot_alter_foreign_projects() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (owner, _teacher, _t2, student, _classmate, _outsider) = school(&s);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();

        let (q, h, b) = upload_req("Raw/clip.mp4", b"\x00\x00\x00\x18ftypisomrest");
        let r = upload_file(
            State(s.clone()),
            session(&owner),
            Path(p.id.clone()),
            q,
            h,
            b,
        )
        .await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN, "view only");
        let r = update_project(
            State(s.clone()),
            session(&owner),
            Path(p.id.clone()),
            patch_body(None),
        )
        .await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN);
        let r = submit_project(State(s.clone()), session(&owner), Path(p.id.clone())).await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN);
        let r = delete_project(State(s.clone()), session(&owner), Path(p.id.clone())).await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN);
        assert!(s.db.project_by_id(&p.id).await.is_ok());

        // The owner can still read it and take it over explicitly.
        let (_p, level) = project_access(&s, &session(&owner), &p.id).await.unwrap();
        assert_eq!(level, "view");
        let r = take_over_project(State(s.clone()), session(&owner), Path(p.id.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);
        let r = delete_project(State(s.clone()), session(&owner), Path(p.id.clone())).await;
        assert_eq!(
            r.status(),
            StatusCode::OK,
            "yours to delete after take-over"
        );
    }

    #[tokio::test]
    async fn delete_account_purges_projects_and_groups() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, _t2, student, _classmate, _outsider) = school(&s);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        s.db.create_group(&ProjectGroup {
            id: model::new_id(),
            owner_id: student.id.clone(),
            name: "g".into(),
            created_at: AppState::now(),
        })
        .await
        .unwrap();
        let r = delete_account(
            State(s.clone()),
            session(&teacher),
            Path(student.id.clone()),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        assert!(s.db.project_by_id(&p.id).await.is_err());
        assert!(s.db.groups_by_owner(&student.id).await.unwrap().is_empty());
        assert!(s.db.user_by_id(&student.id).await.is_err());
    }

    #[tokio::test]
    async fn comment_delete_is_author_or_project_owner_only() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (owner, _teacher, _t2, student, _classmate, _outsider) = school(&s);
        let p = project(&student);
        s.db.create_project(&p).await.unwrap();
        s.db.comment_add("c1", &p.id, &student.id, "hi", AppState::now())
            .await
            .unwrap();
        let r = delete_comment(
            State(s.clone()),
            session(&owner),
            Path((p.id.clone(), "c1".into())),
        )
        .await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN);
        let r = delete_comment(
            State(s.clone()),
            session(&student),
            Path((p.id.clone(), "c1".into())),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
    }

    fn assign_req(students: Vec<String>) -> Json<AssignReq> {
        Json(AssignReq {
            students,
            allow_withdraw: false,
            max_submissions: 1,
            due_at: 0,
            hidden: false,
            locked: false,
        })
    }

    #[tokio::test]
    async fn assign_copies_and_enforces_policies() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, _t2, student, classmate, _out) = school(&s);
        let p = project(&teacher);
        s.db.create_project(&p).await.unwrap();

        let r = assign_project(
            State(s.clone()),
            session(&teacher),
            Path(p.id.clone()),
            assign_req(vec![
                student.id.clone(),
                classmate.id.clone(),
                student.id.clone(),
            ]),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let mine = s.db.assignments_for_student(&student.id).await.unwrap();
        assert_eq!(mine.len(), 1, "one copy per student");
        let copy = mine[0].copy.project_id.clone();
        let a = mine[0].assignment.clone();
        assert_eq!(mine[0].status, "draft");
        let cp = fetch_project(&s, &copy).await.unwrap();
        assert_eq!(cp.owner_id, student.id);

        // submissions view for the teacher
        let r = project_assignment(State(s.clone()), session(&teacher), Path(p.id.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);
        let t = body(r).await;
        assert!(t.contains(&student.username) && t.contains(&classmate.username));

        // the student sees their own copy info; classmates do not see each other's
        let r = project_assignment(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);
        let r = project_assignment(State(s.clone()), session(&classmate), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::NOT_FOUND);

        // submit once, then the cap and withdraw rules bite
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN, "withdraw disabled");
        s.db.set_project_status(&copy, "draft", 0, "")
            .await
            .unwrap();
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN, "submission cap reached");

        // allow withdraw again, submit + withdraw now works
        let r = update_assignment(
            State(s.clone()),
            session(&teacher),
            Path(a.id.clone()),
            Json(AssignmentPatch {
                allow_withdraw: Some(true),
                max_submissions: Some(0),
                due_at: None,
                hidden: None,
                locked: None,
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::OK, "withdraw allowed now");

        // hidden: the copy vanishes for the student only
        let r = update_assignment(
            State(s.clone()),
            session(&teacher),
            Path(a.id.clone()),
            Json(AssignmentPatch {
                allow_withdraw: None,
                max_submissions: None,
                due_at: None,
                hidden: Some(true),
                locked: None,
            }),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let r = project_assignment(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::NOT_FOUND);
        let t = body(list_projects(State(s.clone()), session(&student)).await).await;
        assert!(!t.contains(&copy), "hidden copy stays out of the list");
        let r = project_assignment(State(s.clone()), session(&teacher), Path(p.id.clone())).await;
        assert_eq!(r.status(), StatusCode::OK, "staff still see hidden copies");

        // locked: submit and edit are refused
        let _ = update_assignment(
            State(s.clone()),
            session(&teacher),
            Path(a.id.clone()),
            Json(AssignmentPatch {
                allow_withdraw: None,
                max_submissions: None,
                due_at: None,
                hidden: Some(false),
                locked: Some(true),
            }),
        )
        .await;
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::FORBIDDEN, "locked blocks submit");
        match edit_project(&s, &session(&student), &copy).await {
            Err(r) => assert_eq!(r.status(), StatusCode::FORBIDDEN),
            Ok(_) => panic!("locked edit should fail"),
        }

        // delete unlinks; the copy becomes an ordinary project
        let r = delete_assignment(State(s.clone()), session(&teacher), Path(a.id.clone())).await;
        assert_eq!(r.status(), StatusCode::OK);
        assert!(s.db.assignment_for_project(&copy).await.unwrap().is_none());
        let r = submit_project(State(s.clone()), session(&student), Path(copy.clone())).await;
        assert_eq!(r.status(), StatusCode::OK, "unlinked copy submits freely");
    }

    #[tokio::test]
    async fn assign_validates_targets_and_source() {
        let dir = std::env::temp_dir().join(format!("wfm-api-{}", model::new_id()));
        std::fs::create_dir_all(&dir).unwrap();
        let s = state(&dir);
        let (_owner, teacher, teacher2, student, classmate, outsider) = school(&s);
        let p = project(&teacher);
        s.db.create_project(&p).await.unwrap();
        let call = |u: &User, req: Json<AssignReq>| {
            assign_project(State(s.clone()), session(u), Path(p.id.clone()), req)
        };

        assert_eq!(
            call(&student, assign_req(vec![student.id.clone()]))
                .await
                .status(),
            StatusCode::FORBIDDEN
        );
        assert_eq!(
            call(&teacher, assign_req(vec![])).await.status(),
            StatusCode::BAD_REQUEST
        );
        assert_eq!(
            call(&teacher, assign_req(vec![teacher2.id.clone()]))
                .await
                .status(),
            StatusCode::BAD_REQUEST,
            "non-student"
        );
        assert_eq!(
            call(&teacher, assign_req(vec![outsider.id.clone()]))
                .await
                .status(),
            StatusCode::NOT_FOUND,
            "invisible student"
        );
        assert_eq!(
            call(&teacher, assign_req(vec!["nope".into()]))
                .await
                .status(),
            StatusCode::NOT_FOUND
        );
        assert_eq!(
            call(&teacher, assign_req(vec![student.id.clone()]))
                .await
                .status(),
            StatusCode::OK
        );
        assert_eq!(
            call(&teacher, assign_req(vec![classmate.id.clone()]))
                .await
                .status(),
            StatusCode::CONFLICT,
            "one assignment per source"
        );

        let aid = s.db.assignment_for_source(&p.id).await.unwrap().id;
        let r = update_assignment(
            State(s.clone()),
            session(&teacher2),
            Path(aid.clone()),
            Json(AssignmentPatch {
                allow_withdraw: None,
                max_submissions: None,
                due_at: None,
                hidden: Some(true),
                locked: None,
            }),
        )
        .await;
        assert_eq!(
            r.status(),
            StatusCode::FORBIDDEN,
            "only the assigning teacher edits"
        );
        let r = my_assignments(State(s.clone()), session(&student)).await;
        assert_eq!(r.status(), StatusCode::OK);
        let t = body(r).await;
        assert!(t.contains(&student.id.as_str()) || t.contains("projectName"));
    }

    fn body(r: Response) -> impl std::future::Future<Output = String> {
        async move {
            String::from_utf8_lossy(
                &axum::body::to_bytes(r.into_body(), usize::MAX)
                    .await
                    .unwrap(),
            )
            .to_string()
        }
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
    let _p = match edit_project(&s, &session, &id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    let kind = match req.kind.as_str() {
        _ if lock_kind(&req.kind) => req.kind.clone(),
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
    let _p = match edit_project(&s, &session, &id).await {
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

/// Lock kinds each app mutexes independently: FilmCraft edits under `"edit"`, renders under
/// `"render"`, ScriptCraft under `"script"`, DeckCraft under `"deck"`; `"docs"` stays accepted for
/// pre-split clients until they are gone.
fn lock_kind(kind: &str) -> bool {
    matches!(kind, "edit" | "render" | "docs" | "script" | "deck")
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
    let _p = match edit_project(&s, &session, &id).await {
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
    s.db.node_list()
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
    let p = match edit_project(&s, &session, &id).await {
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
        status: if device {
            "running".into()
        } else {
            "queued".into()
        },
        mode: req.mode.clone(),
        spec,
        output_name: output,
        progress: 0.0,
        error: String::new(),
        worker: if device {
            "device".into()
        } else {
            String::new()
        },
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
        let _ =
            s.db.job_progress(&job.id, &job.worker, 0.0, AppState::now() + 90)
                .await;
    }
    let _ =
        s.db.lock_acquire(
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
    let dir = s.cfg.data_dir.join("inspect").join(model::new_id());
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
        Ok(()) => tokio::fs::metadata(&fcproj)
            .await
            .map(|m| m.len() > 0)
            .unwrap_or(false),
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
        let _ =
            s.db.job_progress(&id, &job.worker, p, AppState::now() + 90)
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
    let e = req["error"]
        .as_str()
        .unwrap_or("")
        .chars()
        .take(500)
        .collect::<String>();
    let status = if e.is_empty() { "done" } else { "failed" };
    let _ =
        s.db.job_finish(&id, &job.worker, status, &e, AppState::now())
            .await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
    if let Ok(p) = s.db.project_by_id(&job.project_id).await {
        if e.is_empty() {
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
        s.notify(
            &job.user_id,
            if e.is_empty() {
                "render_done"
            } else {
                "render_failed"
            },
            json!({
                "project": p.id,
                "projectName": p.display_name,
                "name": job.output_name,
                "error": e,
            }),
        )
        .await;
    }
    Json(json!({"ok": true})).into_response()
}

async fn device_render_job(
    s: &Arc<AppState>,
    session: &Session,
    id: &str,
) -> Result<RenderJob, Response> {
    let job =
        s.db.job_by_id(id)
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
    let p = match edit_project(&s, &session, &job.project_id).await {
        Ok(p) => p,
        Err(r) => return r,
    };
    if job.status != "queued" && job.status != "running" {
        return err(StatusCode::CONFLICT, "render already finished");
    }
    if job.status == "running" {
        s.cancels.lock().unwrap().insert(id.clone());
    }
    let _ =
        s.db.job_finish(&id, &job.worker, "canceled", "", AppState::now())
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
    let p = match edit_project(&s, &session, &job.project_id).await {
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
        status: if device {
            "running".into()
        } else {
            "queued".into()
        },
        mode: job.mode.clone(),
        spec,
        output_name: job.output_name.clone(),
        progress: 0.0,
        error: String::new(),
        worker: if device {
            "device".into()
        } else {
            String::new()
        },
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
        let _ =
            s.db.job_progress(&next.id, &next.worker, 0.0, AppState::now() + 90)
                .await;
    }
    let _ =
        s.db.lock_acquire(
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
    let p = match edit_project(&s, &session, &job.project_id).await {
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
    s.audit(
        "account",
        &session.user,
        "update_settings",
        "trusted_proxies",
        list,
        "",
    )
    .await;
    Json(json!({"ok": true})).into_response()
}

// ---------- keyboard shortcuts ----------

const SHORTCUT_CATALOG: &str = include_str!("../../../filmcraft/shortcuts.json");
const SCRIPTCRAFT_CATALOG: &str = include_str!("../../../scriptcraft/shortcuts.json");

#[derive(Deserialize)]
struct CatalogQuery {
    app: Option<String>,
}

async fn shortcut_catalog(_session: Session, Query(q): Query<CatalogQuery>) -> Response {
    let body = if q.app.as_deref() == Some("scriptcraft") {
        SCRIPTCRAFT_CATALOG
    } else {
        SHORTCUT_CATALOG
    };
    (
        [(header::CONTENT_TYPE, "application/json; charset=utf-8")],
        body,
    )
        .into_response()
}

fn shortcuts_key(session: &Session) -> String {
    format!("shortcuts:{}", session.user.id)
}

async fn get_shortcuts(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.setting_get(&shortcuts_key(&session)).await {
        Ok(Some(v)) => (
            [(header::CONTENT_TYPE, "application/json; charset=utf-8")],
            v,
        )
            .into_response(),
        Ok(None) => Json(json!({"bindings": {}})).into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
struct ShortcutsReq {
    bindings: serde_json::Map<String, Value>,
}

async fn put_shortcuts(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<ShortcutsReq>,
) -> Response {
    if req.bindings.len() > 2000 {
        return err(StatusCode::BAD_REQUEST, "too many bindings");
    }
    for (k, v) in &req.bindings {
        if k.is_empty() || k.chars().count() > 300 {
            return err(StatusCode::BAD_REQUEST, "bad action id");
        }
        match v {
            Value::String(k2) if k2.chars().count() <= 100 => {}
            _ => return err(StatusCode::BAD_REQUEST, "bad binding"),
        }
    }
    let body = serde_json::to_string(&json!({"bindings": req.bindings})).unwrap_or_default();
    if let Err(e) = s.db.setting_set(&shortcuts_key(&session), &body).await {
        return db_resp(e);
    }
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
    let job =
        s.db.job_by_id(id)
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
    serve_blob(
        &s,
        &blob_key(&project.dir, &key),
        &key,
        &headers,
        false,
        None,
    )
    .await
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
    let canceled = job.status == "canceled" || s.cancels.lock().unwrap().contains(&id);
    if canceled {
        return Json(json!({"ok": true, "canceled": true})).into_response();
    }
    let _ =
        s.db.job_progress(
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
    if let Err(r) = sniff_spool(&tmp, &key).await {
        return r;
    }
    let put = async {
        let mut f = tokio::fs::File::open(&tmp)
            .await
            .map_err(|e| e.to_string())?;
        s.blobs
            .put(&blob_key(&project.dir, &key), len, &mut f)
            .await
    }
    .await;
    let _ = tokio::fs::remove_file(&tmp).await;
    if let Err(e) = put {
        return err(StatusCode::INTERNAL_SERVER_ERROR, &e);
    }
    if q.done {
        let _ =
            s.db.job_finish(&id, &job.worker, "done", "", AppState::now())
                .await;
        let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
        s.cancels.lock().unwrap().remove(&id);
        if let Ok(u) = s.db.user_by_id(&job.user_id).await {
            s.audit(
                "project",
                &u,
                "render_done",
                &project.display_name,
                &name,
                "",
            )
            .await;
        }
        s.notify(
            &job.user_id,
            "render_done",
            json!({
                "project": project.id,
                "projectName": project.display_name,
                "name": name,
            }),
        )
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
    let _ =
        s.db.job_finish(&id, &job.worker, "failed", &msg, AppState::now())
            .await;
    let _ = s.db.lock_release(&job.project_id, "render", &job.id).await;
    s.cancels.lock().unwrap().remove(&id);
    let pname =
        s.db.project_by_id(&job.project_id)
            .await
            .map(|p| p.display_name)
            .unwrap_or_default();
    s.notify(
        &job.user_id,
        "render_failed",
        json!({
            "project": job.project_id,
            "projectName": pname,
            "name": job.output_name,
            "error": msg,
        }),
    )
    .await;
    Json(json!({"ok": true})).into_response()
}
