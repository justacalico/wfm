mod api;
mod auth;
mod blobs;
mod config;
mod files;
mod model;
mod render;
mod store;
mod web;
mod zip;
mod worker;

use std::collections::{HashMap, HashSet};
use std::net::SocketAddr;
use std::sync::{Arc, Mutex, RwLock};

use auth::AppState;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let cfg = match config::Config::load() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("wfm: {e}");
            std::process::exit(2);
        }
    };

    if let Some(w) = cfg.worker.clone() {
        if let Err(e) = worker::run(w).await {
            tracing::error!("worker failed: {e}");
            std::process::exit(1);
        }
        return;
    }

    let db = match store::connect(&cfg.effective_db_url()).await {
        Ok(d) => d,
        Err(e) => {
            eprintln!("wfm: database: {e}");
            std::process::exit(1);
        }
    };

    let blobs = match blobs::connect(&cfg).await {
        Ok(b) => b,
        Err(e) => {
            tracing::error!("media storage: {e}");
            std::process::exit(1);
        }
    };

    let state = Arc::new(AppState {
        cfg: cfg.clone(),
        db,
        blobs,
        logins: Mutex::new(HashMap::new()),
        cancels: Mutex::new(HashSet::new()),
        inspect_cache: Mutex::new(HashMap::new()),
        chunk_uploads: Mutex::new(HashMap::new()),
        trusted: RwLock::new(cfg.trusted_proxies.clone()),
    });
    if let Ok(Some(v)) = state.db.setting_get("trusted_proxies").await {
        match auth::parse_nets(&v) {
            Ok(nets) => *state.trusted.write().unwrap() = nets,
            Err(e) => tracing::warn!("stored trusted_proxies invalid: {e}"),
        }
    }

    render::spawn_janitor(state.clone());
    if state.cfg.local_renders {
        render::spawn_workers(state.clone());
    }

    let cors = web::cors_layer(&state);
    let app = api::router(state.clone())
        .merge(web::router(state.clone()))
        .layer(cors);

    let addr: SocketAddr = state
        .cfg
        .addr
        .parse()
        .ok()
        .or_else(|| {
            // Bare "8080" or ":8080" means all interfaces on that port.
            state
                .cfg
                .addr
                .trim_start_matches(':')
                .parse::<u16>()
                .ok()
                .map(|p| SocketAddr::from(([0, 0, 0, 0], p)))
        })
        .or_else(|| format!("0.0.0.0{}", state.cfg.addr).parse().ok())
        .unwrap_or_else(|| {
            tracing::warn!(addr = %state.cfg.addr, "cannot parse listen addr, using 0.0.0.0:8080");
            SocketAddr::from(([0, 0, 0, 0], 8080))
        });
    let listener = match tokio::net::TcpListener::bind(addr).await {
        Ok(l) => l,
        Err(e) => {
            eprintln!("wfm: bind {addr}: {e}");
            std::process::exit(1);
        }
    };
    tracing::info!("wfm listening on http://{addr} (data: {})", state.cfg.data_dir.display());
    if let Err(e) = axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(shutdown())
    .await
    {
        tracing::error!("server error: {e}");
    }
}

async fn shutdown() {
    let _ = tokio::signal::ctrl_c().await;
    tracing::info!("shutting down");
}
