use std::collections::{HashMap, HashSet};
use std::net::IpAddr;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use rand_core::OsRng;
use argon2::password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString};
use argon2::Argon2;
use axum::extract::FromRequestParts;
use axum::http::request::Parts;
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use axum::Json;
use serde_json::json;
use subtle::ConstantTimeEq;

use crate::model::{self, User};
use crate::store::Db;

pub fn hash_password(pw: &str) -> Result<String, String> {
    let salt = SaltString::generate(OsRng);
    Argon2::default()
        .hash_password(pw.as_bytes(), &salt)
        .map(|h| h.to_string())
        .map_err(|e| e.to_string())
}

pub fn verify_password(hash: &str, pw: &str) -> bool {
    PasswordHash::new(hash)
        .ok()
        .map(|h| Argon2::default().verify_password(pw.as_bytes(), &h).is_ok())
        .unwrap_or(false)
}

pub fn session_cookie(token: &str, secure: bool, max_age: i64) -> String {
    format!(
        "wfm_session={token}; Path=/; HttpOnly; SameSite=Lax; Max-Age={max_age}{}",
        if secure { "; Secure" } else { "" }
    )
}

pub fn clear_cookie(secure: bool) -> String {
    session_cookie("", secure, 0)
}

pub fn cookie_token(parts: &Parts) -> Option<String> {
    parts
        .headers
        .get(axum::http::header::COOKIE)?
        .to_str()
        .ok()?
        .split(';')
        .map(|c| c.trim())
        .find_map(|c| c.strip_prefix("wfm_session=").map(|s| s.to_string()))
}

fn bearer_token(parts: &Parts) -> Option<String> {
    parts
        .headers
        .get(axum::http::header::AUTHORIZATION)?
        .to_str()
        .ok()?
        .strip_prefix("Bearer ")
        .map(|s| s.trim().to_string())
}

pub struct Session {
    pub user: User,
    pub csrf: String,
}

pub fn err(status: StatusCode, msg: &str) -> Response {
    (status, Json(json!({ "error": msg }))).into_response()
}

pub struct AppState {
    pub cfg: crate::config::Config,
    pub db: Arc<dyn Db>,
    pub blobs: Arc<dyn crate::blobs::Blobs>,
    pub logins: Mutex<HashMap<IpAddr, (u32, Instant)>>,
    pub cancels: Mutex<HashSet<String>>,
}

impl AppState {
    pub fn now() -> i64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0)
    }

    pub async fn audit(
        &self,
        scope: &str,
        user: &User,
        action: &str,
        target: &str,
        detail: &str,
        lineage: &str,
    ) {
        let _ = self
            .db
            .audit(
                scope,
                &user.id,
                &user.username,
                action,
                target,
                detail,
                lineage,
                Self::now(),
            )
            .await;
    }
}

/// Extractor: resolves the session cookie or bearer token to a user. For
/// cookie-auth mutating requests the X-CSRF-Token header must match.
impl FromRequestParts<Arc<AppState>> for Session {
    type Rejection = Response;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &Arc<AppState>,
    ) -> Result<Session, Response> {
        let (token, via_cookie) = match cookie_token(parts) {
            Some(t) => (t, true),
            None => match bearer_token(parts) {
                Some(t) => (t, false),
                None => return Err(err(StatusCode::UNAUTHORIZED, "not logged in")),
            },
        };
        let (uid, csrf) = state
            .db
            .session_user(&model::token_hash(&token), AppState::now())
            .await
            .map_err(|_| err(StatusCode::UNAUTHORIZED, "session expired"))?;
        let user = state
            .db
            .user_by_id(&uid)
            .await
            .map_err(|_| err(StatusCode::UNAUTHORIZED, "account unavailable"))?;
        if user.disabled {
            return Err(err(StatusCode::UNAUTHORIZED, "account disabled"));
        }
        let mutating = !matches!(parts.method.as_str(), "GET" | "HEAD" | "OPTIONS");
        if mutating && via_cookie {
            let ok = parts
                .headers
                .get("x-csrf-token")
                .and_then(|v| v.to_str().ok())
                .map(|v| v.as_bytes().ct_eq(csrf.as_bytes()).into())
                .unwrap_or(false);
            if !ok {
                return Err(err(StatusCode::FORBIDDEN, "bad csrf token"));
            }
        }
        Ok(Session { user, csrf })
    }
}

/// Render-node bearer token auth.
pub struct NodeSession {
    pub node: model::RenderNode,
}

impl FromRequestParts<Arc<AppState>> for NodeSession {
    type Rejection = Response;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &Arc<AppState>,
    ) -> Result<NodeSession, Response> {
        let token = bearer_token(parts)
            .ok_or_else(|| err(StatusCode::UNAUTHORIZED, "missing node token"))?;
        let node = state
            .db
            .node_by_token(&model::token_hash(&token))
            .await
            .map_err(|_| err(StatusCode::UNAUTHORIZED, "invalid node token"))?;
        let _ = state.db.node_touch(&node.id, AppState::now()).await;
        Ok(NodeSession { node })
    }
}

const LOGIN_WINDOW: Duration = Duration::from_secs(300);
const LOGIN_MAX_TRIES: u32 = 8;
const LOGIN_LOCKOUT: Duration = Duration::from_secs(60);

/// Sliding-window per-IP login throttle. Returns seconds to wait when blocked.
pub fn login_throttle(state: &AppState, ip: IpAddr) -> Option<u64> {
    let mut m = state.logins.lock().unwrap();
    let now = Instant::now();
    let e = m.entry(ip).or_insert((0, now));
    if e.0 >= LOGIN_MAX_TRIES && now.duration_since(e.1) < LOGIN_LOCKOUT {
        return Some((LOGIN_LOCKOUT - now.duration_since(e.1)).as_secs());
    }
    if now.duration_since(e.1) > LOGIN_WINDOW {
        *e = (0, now);
    }
    None
}

pub fn login_failed(state: &AppState, ip: IpAddr) {
    let mut m = state.logins.lock().unwrap();
    let now = Instant::now();
    let e = m.entry(ip).or_insert((0, now));
    if now.duration_since(e.1) > LOGIN_WINDOW {
        *e = (0, now);
    }
    e.0 += 1;
    if e.0 >= LOGIN_MAX_TRIES {
        e.1 = now;
    }
}

pub fn login_ok(state: &AppState, ip: IpAddr) {
    state.logins.lock().unwrap().remove(&ip);
}

pub fn client_ip(parts: &Parts) -> IpAddr {
    if let Some(v) = parts
        .headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .and_then(|s| s.trim().parse::<IpAddr>().ok())
    {
        return v;
    }
    parts
        .extensions
        .get::<axum::extract::ConnectInfo<std::net::SocketAddr>>()
        .map(|c| c.0.ip())
        .unwrap_or(IpAddr::from([127, 0, 0, 1]))
}
