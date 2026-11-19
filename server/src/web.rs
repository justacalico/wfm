use std::path::PathBuf;
use std::sync::Arc;

use axum::extract::State;
use axum::http::{header, HeaderValue, StatusCode, Uri};
use axum::middleware::Next;
use axum::response::{IntoResponse, Redirect, Response};
use axum::routing::get;
use axum::{middleware, Router};
use rust_embed::RustEmbed;

use crate::auth::{cookie_token, AppState};
use crate::model;

#[derive(RustEmbed)]
#[folder = "web/"]
struct Embedded;

fn mime(path: &str) -> String {
    mime_guess::from_path(path)
        .first_or_octet_stream()
        .to_string()
}

/// Serve one asset: override dir first, then the embedded copy.
async fn asset(dir: Option<&PathBuf>, prefix: &str, path: &str, spa_fallback: &str) -> Response {
    let clean = path.trim_start_matches('/');
    if clean.split('/').any(|seg| seg == "..") {
        return (StatusCode::BAD_REQUEST, "bad path").into_response();
    }
    if let Some(d) = dir {
        let full = d.join(clean);
        if full.is_file() {
            return file_response(tokio::fs::read(&full).await, clean);
        }
    }
    if let Some(f) = Embedded::get(&format!("{prefix}/{clean}")) {
        return ([(header::CONTENT_TYPE, mime(clean))], f.data.into_owned()).into_response();
    }
    // SPA fallback
    if let Some(d) = dir {
        let full = d.join(spa_fallback);
        if full.is_file() {
            return file_response(tokio::fs::read(&full).await, spa_fallback);
        }
    }
    if let Some(f) = Embedded::get(&format!("{prefix}/{spa_fallback}")) {
        return (
            [(header::CONTENT_TYPE, mime(spa_fallback))],
            f.data.into_owned(),
        )
            .into_response();
    }
    (StatusCode::NOT_FOUND, "not found").into_response()
}

fn file_response(data: Result<Vec<u8>, std::io::Error>, path: &str) -> Response {
    match data {
        Ok(bytes) => ([(header::CONTENT_TYPE, mime(path))], bytes).into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "not found").into_response(),
    }
}

async fn app_asset(State(s): State<Arc<AppState>>, uri: Uri) -> Response {
    let path = uri.path().trim_start_matches("/app");
    asset(s.cfg.web_dir.as_ref(), "app", path, "index.html").await
}

async fn filmcraft_asset(State(s): State<Arc<AppState>>, req: axum::extract::Request) -> Response {
    craft_asset(s.clone(), s.cfg.filmcraft_dir.as_ref(), "filmcraft", req).await
}

async fn scriptcraft_asset(
    State(s): State<Arc<AppState>>,
    req: axum::extract::Request,
) -> Response {
    craft_asset(
        s.clone(),
        s.cfg.scriptcraft_dir.as_ref(),
        "scriptcraft",
        req,
    )
    .await
}

async fn deckcraft_asset(State(s): State<Arc<AppState>>, req: axum::extract::Request) -> Response {
    craft_asset(s.clone(), s.cfg.deckcraft_dir.as_ref(), "deckcraft", req).await
}

async fn craft_asset(
    s: Arc<AppState>,
    dir: Option<&PathBuf>,
    prefix: &str,
    req: axum::extract::Request,
) -> Response {
    let (parts, _) = req.into_parts();
    let path = parts
        .uri
        .path()
        .trim_start_matches(&format!("/{prefix}"))
        .to_string();
    let ok = match cookie_token(&parts) {
        Some(t) => {
            s.db.session_user(&model::token_hash(&t), AppState::now())
                .await
                .is_ok()
        }
        None => false,
    };
    if !ok {
        return Redirect::to("/app/").into_response();
    }
    asset(dir, prefix, &path, "index.html").await
}

async fn root() -> Redirect {
    Redirect::permanent("/app/")
}

/// Security headers on every response. CSP allows the wasm the Flutter
/// renderer and ffmpeg.wasm need, blob workers/media for the editor.
async fn security_headers(req: axum::extract::Request, next: Next) -> Response {
    let path = req.uri().path().to_string();
    let mut resp = next.run(req).await;
    let h = resp.headers_mut();
    h.insert(
        header::X_CONTENT_TYPE_OPTIONS,
        HeaderValue::from_static("nosniff"),
    );
    h.insert(
        header::X_FRAME_OPTIONS,
        HeaderValue::from_static("SAMEORIGIN"),
    );
    h.insert(
        header::REFERRER_POLICY,
        HeaderValue::from_static("same-origin"),
    );
    if path.starts_with("/api/") {
        h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    } else {
        // The craft bundles' index.html and the wfm.html wrappers boot from
        // inline <script> blocks, so that route gets unsafe-inline.
        let csp = if ["/filmcraft/", "/scriptcraft/", "/deckcraft/"]
            .iter()
            .any(|p| path.starts_with(p))
        {
            "default-src 'self'; script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval'; \
             worker-src 'self' blob:; media-src 'self' blob:; \
             img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; \
             font-src 'self' data:; connect-src 'self' blob:; frame-src 'self'"
        } else {
            "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; \
             worker-src 'self' blob:; media-src 'self' blob:; \
             img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; \
             font-src 'self' data:; connect-src 'self'"
        };
        h.insert(
            header::CONTENT_SECURITY_POLICY,
            HeaderValue::from_static(csp),
        );
        if path.contains("/main.dart.js") || path.contains("canvaskit") || path.contains(".wasm") {
            h.insert(
                header::CACHE_CONTROL,
                HeaderValue::from_static("public, max-age=86400"),
            );
        } else {
            h.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-cache"));
        }
    }
    resp
}

pub fn router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/", get(root))
        .route("/app/", get(app_asset))
        .route("/app/{*path}", get(app_asset))
        .route("/filmcraft/", get(filmcraft_asset))
        .route("/filmcraft/{*path}", get(filmcraft_asset))
        .route("/scriptcraft/", get(scriptcraft_asset))
        .route("/scriptcraft/{*path}", get(scriptcraft_asset))
        .route("/deckcraft/", get(deckcraft_asset))
        .route("/deckcraft/{*path}", get(deckcraft_asset))
        .with_state(state.clone())
        .layer(tower_http::compression::CompressionLayer::new())
        .layer(middleware::from_fn(security_headers))
}

pub fn cors_layer(state: &AppState) -> tower_http::cors::CorsLayer {
    use tower_http::cors::{AllowHeaders, AllowMethods, AllowOrigin, CorsLayer};
    if state.cfg.cors_origins.is_empty() {
        return CorsLayer::new();
    }
    let origins: Vec<HeaderValue> = state
        .cfg
        .cors_origins
        .iter()
        .filter_map(|o| o.parse().ok())
        .collect();
    CorsLayer::new()
        .allow_origin(AllowOrigin::list(origins))
        .allow_methods(AllowMethods::list([
            axum::http::Method::GET,
            axum::http::Method::POST,
            axum::http::Method::PUT,
            axum::http::Method::PATCH,
            axum::http::Method::DELETE,
            axum::http::Method::OPTIONS,
        ]))
        .allow_headers(AllowHeaders::list([
            header::AUTHORIZATION,
            header::CONTENT_TYPE,
            header::HeaderName::from_static("x-csrf-token"),
        ]))
        .allow_credentials(true)
        .max_age(std::time::Duration::from_secs(600))
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::Request;
    use std::collections::{HashMap, HashSet};
    use std::sync::{Mutex, RwLock};

    fn state(dir: &std::path::Path) -> Arc<AppState> {
        Arc::new(AppState {
            cfg: crate::config::Config {
                addr: String::new(),
                data_dir: dir.to_path_buf(),
                web_dir: None,
                filmcraft_dir: Some(dir.join("filmcraft")),
                scriptcraft_dir: Some(dir.join("scriptcraft")),
                deckcraft_dir: Some(dir.join("deckcraft")),
                max_upload: 0,
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
            trusted: RwLock::new(vec![]),
        })
    }

    #[tokio::test]
    async fn filmcraft_routes_require_a_session() {
        let dir = std::env::temp_dir().join(format!("wfm-web-{}", std::process::id()));
        std::fs::create_dir_all(dir.join("filmcraft/dist")).unwrap();
        std::fs::write(dir.join("filmcraft/dist/index.html"), "fc").unwrap();
        let s = state(&dir);

        let r = filmcraft_asset(
            State(s.clone()),
            Request::get("/filmcraft/dist/index.html")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(r.status(), StatusCode::SEE_OTHER);
        assert_eq!(r.headers()[header::LOCATION], "/app/");

        let u = crate::model::User {
            id: model::new_id(),
            username: "t".into(),
            display_name: "t".into(),
            role: crate::model::Role::Owner,
            role_name: "owner".into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: String::new(),
            lineage: "/".into(),
            created_at: AppState::now(),
            last_login: 0,
        };
        s.db.create_user(&u, "h").await.unwrap();
        s.db.create_session(
            &model::token_hash("tok"),
            &u.id,
            "csrf",
            AppState::now() + 60,
            "",
            "",
        )
        .await
        .unwrap();
        let r = filmcraft_asset(
            State(s.clone()),
            Request::get("/filmcraft/dist/index.html")
                .header(header::COOKIE, "wfm_session=tok")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);

        std::fs::create_dir_all(dir.join("scriptcraft/dist")).unwrap();
        std::fs::write(dir.join("scriptcraft/dist/index.html"), "sc").unwrap();
        let r = scriptcraft_asset(
            State(s.clone()),
            Request::get("/scriptcraft/dist/index.html")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(r.status(), StatusCode::SEE_OTHER);
        let r = scriptcraft_asset(
            State(s.clone()),
            Request::get("/scriptcraft/dist/index.html")
                .header(header::COOKIE, "wfm_session=tok")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);

        std::fs::create_dir_all(dir.join("deckcraft/dist")).unwrap();
        std::fs::write(dir.join("deckcraft/dist/index.html"), "dc").unwrap();
        let r = deckcraft_asset(
            State(s.clone()),
            Request::get("/deckcraft/dist/index.html")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(r.status(), StatusCode::SEE_OTHER);
        let r = deckcraft_asset(
            State(s.clone()),
            Request::get("/deckcraft/dist/index.html")
                .header(header::COOKIE, "wfm_session=tok")
                .body(Body::empty())
                .unwrap(),
        )
        .await;
        assert_eq!(r.status(), StatusCode::OK);
        let _ = std::fs::remove_dir_all(&dir);
    }
}
