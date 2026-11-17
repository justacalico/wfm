use std::collections::{HashMap, HashSet};
use std::net::IpAddr;
use std::sync::{Arc, Mutex, RwLock};
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
    pub token_hash: String,
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
    pub trusted: RwLock<Vec<ipnet::IpNet>>,
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
        let th = model::token_hash(&token);
        let (uid, csrf) = state
            .db
            .session_user(&th, AppState::now())
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
        Ok(Session {
            user,
            csrf,
            token_hash: th,
        })
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

/// Drop throttle entries idle longer than the window so the map cannot grow
/// without bound on internet-facing instances.
pub fn login_prune(logins: &Mutex<HashMap<IpAddr, (u32, Instant)>>) {
    let now = Instant::now();
    logins
        .lock()
        .unwrap()
        .retain(|_, e| now.duration_since(e.1) <= LOGIN_WINDOW);
}

/// Parse a comma-separated list of IPs and CIDR ranges into networks.
pub fn parse_nets(list: &str) -> Result<Vec<ipnet::IpNet>, String> {
    list.split(',')
        .map(|s| s.trim())
        .filter(|s| !s.is_empty())
        .map(|s| {
            s.parse::<ipnet::IpNet>()
                .or_else(|_| s.parse::<IpAddr>().map(ipnet::IpNet::from))
                .map_err(|_| format!("bad proxy address '{s}'"))
        })
        .collect()
}

/// Resolve the real client address. X-Forwarded-For is only honored when
/// the direct peer is trusted; the rightmost untrusted hop wins.
pub fn forwarded_ip(peer: IpAddr, xff: Option<&str>, trusted: &[ipnet::IpNet]) -> IpAddr {
    if trusted.is_empty() || !trusted.iter().any(|n| n.contains(&peer)) {
        return peer;
    }
    xff.and_then(|s| {
        s.split(',')
            .filter_map(|h| h.trim().parse::<IpAddr>().ok())
            .collect::<Vec<_>>()
            .into_iter()
            .rev()
            .find(|ip| !trusted.iter().any(|n| n.contains(ip)))
    })
    .unwrap_or(peer)
}

/// Client IP for rate limiting and audit.
pub fn client_ip(state: &AppState, parts: &Parts) -> IpAddr {
    let peer = parts
        .extensions
        .get::<axum::extract::ConnectInfo<std::net::SocketAddr>>()
        .map(|c| c.0.ip())
        .unwrap_or(IpAddr::from([127, 0, 0, 1]));
    let xff = parts
        .headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok());
    forwarded_ip(peer, xff, &state.trusted.read().unwrap())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::net::Ipv4Addr;

    fn v4(a: u8, b: u8, c: u8, d: u8) -> IpAddr {
        IpAddr::V4(Ipv4Addr::new(a, b, c, d))
    }

    #[test]
    fn login_prune_drops_stale_entries() {
        let logins = Mutex::new(HashMap::new());
        let stale = Instant::now() - LOGIN_WINDOW - Duration::from_secs(1);
        logins.lock().unwrap().insert(v4(1, 1, 1, 1), (1, stale));
        logins
            .lock()
            .unwrap()
            .insert(v4(2, 2, 2, 2), (1, Instant::now()));
        login_prune(&logins);
        let m = logins.lock().unwrap();
        assert!(!m.contains_key(&v4(1, 1, 1, 1)));
        assert!(m.contains_key(&v4(2, 2, 2, 2)));
    }

    #[test]
    fn parse_nets_accepts_ips_and_cidrs() {
        let n = parse_nets("10.0.0.1, 192.168.0.0/16 ,::1").unwrap();
        assert_eq!(n.len(), 3);
        assert!(n[0].contains(&v4(10, 0, 0, 1)));
        assert!(!n[0].contains(&v4(10, 0, 0, 2)));
        assert!(n[1].contains(&v4(192, 168, 7, 7)));
        assert!(parse_nets("not-an-ip").is_err());
        assert!(parse_nets("").unwrap().is_empty());
    }

    #[test]
    fn xff_ignored_without_trusted_peer() {
        let trusted = parse_nets("10.0.0.0/8").unwrap();
        // direct client is not a trusted proxy: header ignored entirely
        assert_eq!(
            forwarded_ip(v4(1, 2, 3, 4), Some("9.9.9.9"), &trusted),
            v4(1, 2, 3, 4)
        );
        // empty trusted list: always peer
        assert_eq!(
            forwarded_ip(v4(10, 0, 0, 1), Some("9.9.9.9"), &[]),
            v4(10, 0, 0, 1)
        );
        // missing header
        assert_eq!(forwarded_ip(v4(10, 0, 0, 1), None, &trusted), v4(10, 0, 0, 1));
    }

    #[test]
    fn xff_rightmost_untrusted_wins() {
        let trusted = parse_nets("10.0.0.0/8").unwrap();
        let peer = v4(10, 0, 0, 1);
        // client, untrusted middlebox, trusted proxy
        assert_eq!(
            forwarded_ip(peer, Some("203.0.113.5, 198.51.100.7, 10.0.0.9"), &trusted),
            v4(198, 51, 100, 7)
        );
        // single client hop
        assert_eq!(
            forwarded_ip(peer, Some("203.0.113.5"), &trusted),
            v4(203, 0, 113, 5)
        );
        // whole chain trusted falls back to peer
        assert_eq!(
            forwarded_ip(peer, Some("10.0.0.2, 10.0.0.3"), &trusted),
            peer
        );
        // junk entries are skipped
        assert_eq!(
            forwarded_ip(peer, Some("garbage, 203.0.113.5"), &trusted),
            v4(203, 0, 113, 5)
        );
    }
}
