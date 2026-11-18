use std::path::PathBuf;
use std::sync::Arc;

use axum::extract::State;
use axum::http::{header, HeaderValue, StatusCode, Uri};
use axum::middleware::Next;
use axum::response::{IntoResponse, Redirect, Response};
use axum::routing::get;
use axum::{middleware, Router};
use rust_embed::RustEmbed;

use crate::auth::AppState;

#[derive(RustEmbed)]
#[folder = "web/"]
struct Embedded;

fn mime(path: &str) -> String {
    mime_guess::from_path(path).first_or_octet_stream().to_string()
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
        return (
            [(header::CONTENT_TYPE, mime(clean))],
            f.data.into_owned(),
        )
            .into_response();
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

fn file_response(
    data: Result<Vec<u8>, std::io::Error>,
    path: &str,
) -> Response {
    match data {
        Ok(bytes) => ([(header::CONTENT_TYPE, mime(path))], bytes).into_response(),
        Err(_) => (StatusCode::NOT_FOUND, "not found").into_response(),
    }
}

async fn app_asset(State(s): State<Arc<AppState>>, uri: Uri) -> Response {
    let path = uri.path().trim_start_matches("/app");
    asset(s.cfg.web_dir.as_ref(), "app", path, "index.html").await
}

async fn filmcraft_asset(State(s): State<Arc<AppState>>, uri: Uri) -> Response {
    let path = uri.path().trim_start_matches("/filmcraft");
    asset(s.cfg.filmcraft_dir.as_ref(), "filmcraft", path, "index.html").await
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
        h.insert(
            header::CACHE_CONTROL,
            HeaderValue::from_static("no-store"),
        );
    } else {
        // FilmCraft's shipped index.html and the wfm.html wrapper boot from
        // inline <script> blocks, so that route gets unsafe-inline.
        let csp = if path.starts_with("/filmcraft/") {
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
