//! Streamable-HTTP MCP endpoint. Agent calls come in as JSON-RPC and are
//! dispatched through the same axum router the web app uses (via oneshot),
//! so tools can never drift from the human API. Project edits run through
//! `filmcraft-cli mcp`, the same engine the in-browser editor uses.

use std::collections::HashMap;
use std::sync::Arc;

use axum::body::{Body, Bytes};
use axum::extract::{Path, State};
use axum::http::{header, HeaderMap, Method, Request, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::Json;
use base64::Engine;
use percent_encoding::{utf8_percent_encode, NON_ALPHANUMERIC};
use serde::Deserialize;
use serde_json::{json, Value};
use tower::ServiceExt;

use crate::auth::{AppState, Session};
use crate::files;
use crate::model;
use crate::render;
use crate::store::LockOutcome;

use super::{blob_key, blob_rev, db_resp, edit_project, err};

const MAX_REPLY: usize = 64 * 1024 * 1024;
const READ_MAX: u64 = 8 * 1024 * 1024;
const TOKEN_TTL: i64 = 400 * 86400;
const TOKEN_MARK: &str = "wfm-mcp";

// ---------- endpoints ----------

/// Unauthenticated discovery document so clients (and humans) can verify the
/// endpoint exists and see what to send.
pub async fn info() -> Json<Value> {
    Json(json!({
        "name": "wfm",
        "version": env!("CARGO_PKG_VERSION"),
        "endpoint": "/api/mcp",
        "transport": "streamable-http",
        "auth": "Authorization: Bearer <token>",
        "tokens": "create one in the app: Settings > AI assistant",
    }))
}

/// JSON-RPC entry point: POST /api/mcp with a session cookie or bearer token.
/// Single messages get a JSON object reply, batches a JSON array; pure
/// notifications return 202.
pub async fn rpc(
    State(s): State<Arc<AppState>>,
    session: Session,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    let auth = forward_auth(&headers);
    let msgs: Vec<Value> = match serde_json::from_slice::<Value>(&body) {
        Ok(Value::Array(v)) => v,
        Ok(v) => vec![v],
        Err(e) => {
            return Json(json!({
                "jsonrpc": "2.0", "id": Value::Null,
                "error": {"code": -32700, "message": format!("parse error: {e}")},
            }))
            .into_response()
        }
    };
    let mut out = Vec::new();
    for m in msgs {
        if let Some(r) = handle(&s, &session, &auth, m).await {
            out.push(r);
        }
    }
    if out.is_empty() {
        StatusCode::ACCEPTED.into_response()
    } else if out.len() == 1 {
        Json(out.pop().unwrap()).into_response()
    } else {
        Json(json!(out)).into_response()
    }
}

/// The headers a synthetic API request needs to authenticate exactly like the
/// incoming one (cookie sessions bring their CSRF token along).
fn forward_auth(h: &HeaderMap) -> HeaderMap {
    let mut out = HeaderMap::new();
    for k in [
        header::AUTHORIZATION,
        header::COOKIE,
        header::HeaderName::from_static("x-csrf-token"),
    ] {
        if let Some(v) = h.get(&k) {
            out.insert(k, v.clone());
        }
    }
    out
}

async fn handle(s: &Arc<AppState>, session: &Session, auth: &HeaderMap, m: Value) -> Option<Value> {
    if !m.is_object() {
        return Some(json!({
            "jsonrpc": "2.0", "id": Value::Null,
            "error": {"code": -32600, "message": "invalid request"},
        }));
    }
    let id = match m.get("id") {
        Some(v) => v.clone(),
        None => return None,
    };
    let method = m.get("method").and_then(Value::as_str).unwrap_or("");
    let result: Result<Value, (i64, String)> = match method {
        "initialize" => Ok(json!({
            "protocolVersion": m["params"]["protocolVersion"].as_str()
                .unwrap_or("2024-11-05"),
            "capabilities": {"tools": {}},
            "serverInfo": {"name": "wfm", "version": env!("CARGO_PKG_VERSION")},
            "instructions": concat!(
                "WFM film manager: projects hold footage (Raw/), audio (Audio/), ",
                "images (Images/), scripts (Script/), boards (Boards/) and exports ",
                "(Exports/). Create and organize projects with the project_* and ",
                "file_* tools. Edit a project's FilmCraft timeline with ",
                "project_command (it proxies the editor's own command engine; ",
                "project_commands lists what it can do). To put a project file on ",
                "the timeline: upload it first (file_write, or upload_start + ",
                "upload_chunk + upload_finish for large media), then import it in ",
                "the edit with project_command files=[<project path>]. Render a ",
                "finished cut with render_start. Anything without a dedicated ",
                "tool is reachable through `api`, which calls any /api endpoint ",
                "with your permissions."
            ),
        })),
        "ping" => Ok(json!({})),
        "tools/list" => Ok(json!({"tools": tools()})),
        "tools/call" => tool_call(s, session, auth, &m["params"]).await,
        "resources/list" => Ok(json!({"resources": []})),
        "resources/templates/list" => Ok(json!({"resourceTemplates": []})),
        "prompts/list" => Ok(json!({"prompts": []})),
        "logging/setLevel" => Ok(json!({})),
        _ if method.starts_with("notifications/") || method.starts_with("cancelled") => {
            return None
        }
        _ => Err((-32601, format!("method not found: {method}"))),
    };
    Some(match result {
        Ok(r) => json!({"jsonrpc": "2.0", "id": id, "result": r}),
        Err((code, message)) => {
            json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
        }
    })
}

// ---------- tools ----------

fn text_result(v: &Value) -> Value {
    json!({"content": [{"type": "text", "text":
        serde_json::to_string_pretty(v).unwrap_or_default()}]})
}

fn err_result(msg: impl Into<String>) -> Value {
    json!({"content": [{"type": "text", "text": msg.into()}], "isError": true})
}

fn arg<'a>(a: &'a Value, k: &str) -> Result<&'a str, Value> {
    a.get(k)
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .ok_or_else(|| err_result(format!("missing required parameter: {k}")))
}

fn enc(s: &str) -> String {
    utf8_percent_encode(s, NON_ALPHANUMERIC).to_string()
}

fn qs(pairs: &[(&str, String)]) -> String {
    pairs
        .iter()
        .filter(|(_, v)| !v.is_empty())
        .map(|(k, v)| format!("{k}={}", enc(v)))
        .collect::<Vec<_>>()
        .join("&")
}

/// Run a request through the same router the web app talks to. Rebuilt per
/// call: route registration is cheap and there is no shared state to drift.
async fn call_api(
    s: &Arc<AppState>,
    auth: &HeaderMap,
    method: Method,
    uri: &str,
    body: Body,
    content_type: &str,
) -> Result<(StatusCode, HeaderMap, Bytes), String> {
    let mut b = Request::builder().method(method).uri(uri);
    for (k, v) in auth.iter() {
        b = b.header(k, v);
    }
    if !content_type.is_empty() {
        b = b.header(header::CONTENT_TYPE, content_type);
    }
    let req = b.body(body).map_err(|e| e.to_string())?;
    let resp = super::router(s.clone())
        .oneshot(req)
        .await
        .map_err(|e| e.to_string())?;
    let status = resp.status();
    let headers = resp.headers().clone();
    let bytes = axum::body::to_bytes(resp.into_body(), MAX_REPLY)
        .await
        .map_err(|e| e.to_string())?;
    Ok((status, headers, bytes))
}

async fn api_json(
    s: &Arc<AppState>,
    auth: &HeaderMap,
    method: Method,
    uri: &str,
    body: Value,
) -> Result<Value, String> {
    let body = if body.is_null() {
        Body::empty()
    } else {
        Body::from(serde_json::to_vec(&body).map_err(|e| e.to_string())?)
    };
    let (status, _, bytes) = call_api(s, auth, method, uri, body, "application/json").await?;
    let v: Value = serde_json::from_slice(&bytes)
        .unwrap_or_else(|_| json!({"raw": String::from_utf8_lossy(&bytes)}));
    if !status.is_success() {
        let msg = v
            .get("error")
            .and_then(Value::as_str)
            .map(str::to_string)
            .unwrap_or_else(|| format!("http {status}"));
        return Err(format!("{msg} (status {status})"));
    }
    Ok(v)
}

/// GET via the api tool's path rules; used for binary responses too.
async fn api_get(
    s: &Arc<AppState>,
    auth: &HeaderMap,
    uri: &str,
) -> Result<(StatusCode, HeaderMap, Bytes), String> {
    call_api(s, auth, Method::GET, uri, Body::empty(), "").await
}

async fn jcall(
    s: &Arc<AppState>,
    auth: &HeaderMap,
    method: Method,
    uri: String,
    body: Value,
) -> Result<Value, Value> {
    api_json(s, auth, method, &uri, body)
        .await
        .map_err(err_result)
}

async fn tool_call(
    s: &Arc<AppState>,
    session: &Session,
    auth: &HeaderMap,
    params: &Value,
) -> Result<Value, (i64, String)> {
    let name = params["name"].as_str().unwrap_or("");
    let a = params.get("arguments").cloned().unwrap_or(json!({}));
    if tools()
        .as_array()
        .map(|t| !t.iter().any(|t| t["name"] == name))
        .unwrap_or(true)
    {
        return Err((-32602, format!("unknown tool: {name}")));
    }
    Ok(dispatch(s, session, auth, name, &a).await)
}

async fn dispatch(
    s: &Arc<AppState>,
    session: &Session,
    auth: &HeaderMap,
    name: &str,
    a: &Value,
) -> Value {
    match run_tool(s, session, auth, name, a).await {
        Ok(v) => text_result(&v),
        Err(e) => e,
    }
}

async fn run_tool(
    s: &Arc<AppState>,
    session: &Session,
    auth: &HeaderMap,
    name: &str,
    a: &Value,
) -> Result<Value, Value> {
    match name {
        "projects" => jcall(s, auth, Method::GET, "/api/projects".into(), json!(null)).await,
        "project" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::GET,
                format!("/api/projects/{id}"),
                json!(null),
            )
            .await
        }
        "project_create" => {
            let name = arg(a, "name")?;
            let mut b = json!({"name": name});
            for k in ["displayName", "folderId"] {
                if let Some(v) = a.get(k) {
                    b[k] = v.clone();
                }
            }
            jcall(s, auth, Method::POST, "/api/projects".into(), b).await
        }
        "project_update" => {
            let id = arg(a, "projectId")?;
            let mut b = json!({});
            for k in ["displayName", "folderId", "pinned", "template"] {
                if let Some(v) = a.get(k) {
                    b[k] = v.clone();
                }
            }
            jcall(s, auth, Method::PATCH, format!("/api/projects/{id}"), b).await
        }
        "project_delete" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::DELETE,
                format!("/api/projects/{id}"),
                json!(null),
            )
            .await
        }
        "project_duplicate" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/duplicate"),
                json!(null),
            )
            .await
        }
        "project_submit" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/submit"),
                json!(null),
            )
            .await
        }
        "project_review" => {
            let id = arg(a, "projectId")?;
            let status = arg(a, "status")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/review"),
                json!({"status": status}),
            )
            .await
        }
        "folders" => jcall(s, auth, Method::GET, "/api/folders".into(), json!(null)).await,
        "folder_create" => {
            let name = arg(a, "name")?;
            jcall(
                s,
                auth,
                Method::POST,
                "/api/folders".into(),
                json!({"name": name}),
            )
            .await
        }
        "folder_rename" => {
            let id = arg(a, "folderId")?;
            let name = arg(a, "name")?;
            jcall(
                s,
                auth,
                Method::PATCH,
                format!("/api/folders/{id}"),
                json!({"name": name}),
            )
            .await
        }
        "folder_delete" => {
            let id = arg(a, "folderId")?;
            jcall(
                s,
                auth,
                Method::DELETE,
                format!("/api/folders/{id}"),
                json!(null),
            )
            .await
        }
        "files" => {
            let id = arg(a, "projectId")?;
            let path = a["path"].as_str().unwrap_or("");
            jcall(
                s,
                auth,
                Method::GET,
                format!("/api/projects/{id}/files?{}", qs(&[("path", path.into())])),
                json!(null),
            )
            .await
        }
        "file_tree" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::GET,
                format!("/api/projects/{id}/manifest"),
                json!(null),
            )
            .await
        }
        "file_read" => file_read(s, auth, a).await,
        "file_write" => file_write(s, session, auth, a).await,
        "file_delete" => {
            let id = arg(a, "projectId")?;
            let path = arg(a, "path")?;
            jcall(
                s,
                auth,
                Method::DELETE,
                format!(
                    "/api/projects/{id}/files?{}",
                    qs(&[("path", path.into()), ("clientId", client_id(session, a))])
                ),
                json!(null),
            )
            .await
        }
        "file_move" => {
            let id = arg(a, "projectId")?;
            let (from, to) = (arg(a, "from")?, arg(a, "to")?);
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/files/move"),
                json!({"from": from, "to": to, "clientId": client_id(session, a)}),
            )
            .await
        }
        "dir_create" => {
            let id = arg(a, "projectId")?;
            let path = arg(a, "path")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/files/mkdir"),
                json!({"path": path, "clientId": client_id(session, a)}),
            )
            .await
        }
        "upload_start" => {
            let id = arg(a, "projectId")?;
            let path = arg(a, "path")?;
            match jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/files/upload"),
                json!({"path": path, "clientId": client_id(session, a)}),
            )
            .await
            {
                Ok(mut v) => {
                    if let Some(uid) = v["id"].as_str().map(str::to_string) {
                        v["uploadId"] = json!(uid);
                    }
                    Ok(v)
                }
                Err(e) => Err(e),
            }
        }
        "upload_chunk" => {
            let uid = arg(a, "uploadId")?;
            let offset = a["offset"].as_u64().unwrap_or(0);
            let data = a["base64"].as_str().unwrap_or("");
            let bytes = match base64::engine::general_purpose::STANDARD.decode(data) {
                Ok(b) => b,
                Err(e) => return Err(err_result(format!("bad base64: {e}"))),
            };
            match call_api(
                s,
                auth,
                Method::PUT,
                &format!("/api/uploads/{}/chunk?offset={offset}", enc(uid)),
                Body::from(bytes),
                "application/octet-stream",
            )
            .await
            {
                Ok((st, _, b)) if st.is_success() => {
                    Ok(serde_json::from_slice(&b).unwrap_or(json!({"ok": true})))
                }
                Ok((st, _, b)) => Err(err_result(format!(
                    "upload failed (status {st}): {}",
                    String::from_utf8_lossy(&b)
                ))),
                Err(e) => Err(err_result(e)),
            }
        }
        "upload_finish" => {
            let uid = arg(a, "uploadId")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/uploads/{}/complete", enc(uid)),
                json!(null),
            )
            .await
        }
        "upload_abort" => {
            let uid = arg(a, "uploadId")?;
            jcall(
                s,
                auth,
                Method::DELETE,
                format!("/api/uploads/{}", enc(uid)),
                json!(null),
            )
            .await
        }
        "comments" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::GET,
                format!("/api/projects/{id}/comments"),
                json!(null),
            )
            .await
        }
        "comment_add" => {
            let id = arg(a, "projectId")?;
            let body = arg(a, "body")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/comments"),
                json!({"body": body}),
            )
            .await
        }
        "render_info" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::GET,
                format!("/api/projects/{id}/render-info"),
                json!(null),
            )
            .await
        }
        "renders" => {
            let id = arg(a, "projectId")?;
            jcall(
                s,
                auth,
                Method::GET,
                format!("/api/projects/{id}/renders"),
                json!(null),
            )
            .await
        }
        "render_start" => {
            let id = arg(a, "projectId")?;
            let mut b = json!({});
            for k in ["mode", "sequence", "output", "params"] {
                if let Some(v) = a.get(k) {
                    b[k] = v.clone();
                }
            }
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/projects/{id}/renders"),
                b,
            )
            .await
        }
        "render_cancel" => {
            let id = arg(a, "renderId")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/renders/{id}/cancel"),
                json!(null),
            )
            .await
        }
        "render_retry" => {
            let id = arg(a, "renderId")?;
            jcall(
                s,
                auth,
                Method::POST,
                format!("/api/renders/{id}/retry"),
                json!(null),
            )
            .await
        }
        "render_delete" => {
            let id = arg(a, "renderId")?;
            jcall(
                s,
                auth,
                Method::DELETE,
                format!("/api/renders/{id}"),
                json!(null),
            )
            .await
        }
        "project_commands" => project_commands(s, a).await,
        "project_command" => project_command(s, session, auth, a).await,
        "api" => api_tool(s, auth, a).await,
        _ => Err(err_result(format!("unknown tool: {name}"))),
    }
}

fn client_id(session: &Session, a: &Value) -> String {
    a["clientId"]
        .as_str()
        .filter(|s| !s.is_empty())
        .map(str::to_string)
        .unwrap_or_else(|| format!("mcp-{}", &session.token_hash[..8]))
}

async fn file_read(s: &Arc<AppState>, auth: &HeaderMap, a: &Value) -> Result<Value, Value> {
    let id = arg(a, "projectId")?;
    let path = arg(a, "path")?;
    let offset = a["offset"].as_u64().unwrap_or(0);
    let limit = a["limit"].as_u64().unwrap_or(READ_MAX).min(READ_MAX);
    let end = offset + limit - 1;
    let uri = format!(
        "/api/projects/{id}/download?{}",
        qs(&[
            ("path", path.into()),
            ("start", offset.to_string()),
            ("end", end.to_string()),
        ])
    );
    let (status, headers, bytes) = api_get(s, auth, &uri).await.map_err(err_result)?;
    if !status.is_success() {
        let v: Value = serde_json::from_slice(&bytes).unwrap_or(json!({}));
        return Err(err_result(format!(
            "{} (status {status})",
            v["error"].as_str().unwrap_or("download failed")
        )));
    }
    let total = headers
        .get(header::CONTENT_RANGE)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.rsplit('/').next())
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(bytes.len() as u64);
    let (encoding, content) = match String::from_utf8(bytes.to_vec()) {
        Ok(t) => ("utf8", t),
        Err(_) => (
            "base64",
            base64::engine::general_purpose::STANDARD.encode(&bytes),
        ),
    };
    Ok(json!({
        "path": path,
        "offset": offset,
        "size": total,
        "returned": bytes.len(),
        "encoding": encoding,
        "content": content,
    }))
}

async fn file_write(
    s: &Arc<AppState>,
    session: &Session,
    auth: &HeaderMap,
    a: &Value,
) -> Result<Value, Value> {
    let id = arg(a, "projectId")?;
    let path = arg(a, "path")?;
    let bytes = if let Some(t) = a["text"].as_str() {
        t.as_bytes().to_vec()
    } else if let Some(b) = a["base64"].as_str() {
        match base64::engine::general_purpose::STANDARD.decode(b) {
            Ok(v) => v,
            Err(e) => return Err(err_result(format!("bad base64: {e}"))),
        }
    } else {
        return Err(err_result("file_write needs `text` or `base64`"));
    };
    let base = a["base"].as_str().unwrap_or("");
    let uri = format!(
        "/api/projects/{id}/files?{}",
        qs(&[
            ("path", path.into()),
            ("clientId", client_id(session, a)),
            ("base", base.into()),
        ])
    );
    match call_api(
        s,
        auth,
        Method::PUT,
        &uri,
        Body::from(bytes),
        "application/octet-stream",
    )
    .await
    {
        Ok((st, _, b)) if st.is_success() => {
            Ok(serde_json::from_slice(&b).unwrap_or(json!({"ok": true})))
        }
        Ok((st, _, b)) => Err(err_result(format!(
            "write failed (status {st}): {}",
            String::from_utf8_lossy(&b)
        ))),
        Err(e) => Err(err_result(e)),
    }
}

/// Escape hatch: any /api endpoint with the caller's permissions, so nothing
/// the app can do is out of reach for the agent.
async fn api_tool(s: &Arc<AppState>, auth: &HeaderMap, a: &Value) -> Result<Value, Value> {
    let method = a["method"].as_str().unwrap_or("GET").to_ascii_uppercase();
    let method = match method.parse::<Method>() {
        Ok(m) => m,
        Err(_) => return Err(err_result(format!("bad method: {method}"))),
    };
    let path = a["path"].as_str().unwrap_or("");
    if !path.starts_with('/') || path.contains("..") || path.contains("://") {
        return Err(err_result(
            "path must be an /api-relative path like /projects",
        ));
    }
    let mut uri = format!("/api{path}");
    if let Some(q) = a["query"].as_object() {
        let pairs: Vec<String> = q
            .iter()
            .map(|(k, v)| {
                let vs = v
                    .as_str()
                    .map(str::to_string)
                    .unwrap_or_else(|| v.to_string());
                format!("{}={}", enc(k), enc(&vs))
            })
            .collect();
        if !pairs.is_empty() {
            uri = format!("{uri}?{}", pairs.join("&"));
        }
    }
    let (body, ct) = if let Some(b64) = a["bodyBase64"].as_str() {
        match base64::engine::general_purpose::STANDARD.decode(b64) {
            Ok(b) => (Body::from(b), "application/octet-stream"),
            Err(e) => return Err(err_result(format!("bad base64: {e}"))),
        }
    } else if a.get("body").is_some() {
        match serde_json::to_vec(&a["body"]) {
            Ok(b) => (Body::from(b), "application/json"),
            Err(e) => return Err(err_result(e.to_string())),
        }
    } else {
        (Body::empty(), "")
    };
    let (status, _, bytes) = call_api(s, auth, method, &uri, body, ct)
        .await
        .map_err(err_result)?;
    let v: Value = serde_json::from_slice(&bytes)
        .unwrap_or_else(|_| json!({"raw": String::from_utf8_lossy(&bytes)}));
    let mut out = json!({"status": status.as_u16(), "body": v});
    if !status.is_success() {
        out["isError"] = json!(true);
    }
    Ok(out)
}

// ---------- craft pass-through ----------

/// List the FilmCraft engine's commands (what the editor's menus/shortcuts
/// map to). Runs on a blank headless session; no project needed.
async fn project_commands(s: &Arc<AppState>, a: &Value) -> Result<Value, Value> {
    let filter = a["filter"].as_str().unwrap_or("");
    let mut mcp = match render::Mcp::spawn_blank(&s.cfg.filmcraft_cli).await {
        Ok(m) => m,
        Err(e) => return Err(err_result(e)),
    };
    match mcp
        .request(
            "tools/call",
            json!({"name": "command_list", "arguments": {"filter": filter}}),
        )
        .await
    {
        Ok(v) => match v["content"][0]["text"].as_str() {
            Some(t) => Ok(serde_json::from_str(t).unwrap_or_else(|_| json!(t))),
            None => Ok(v),
        },
        Err(e) => Err(err_result(e)),
    }
}

/// Run one craft-engine tool (command_run, command_batch, media_import,
/// doc_inspect, render_frame, …) on a project's FilmCraft document. The doc
/// is staged under a scratch dir, the requested project files copied in as
/// `/files` media, and the result saved back through the normal upload path
/// (edit lock + base rev, same as the web editor).
async fn project_command(
    s: &Arc<AppState>,
    session: &Session,
    auth: &HeaderMap,
    a: &Value,
) -> Result<Value, Value> {
    let pid = arg(a, "projectId")?;
    let tool = arg(a, "tool")?;
    let cargs = a.get("arguments").cloned().unwrap_or(json!({}));
    let timeout = a["timeoutSec"].as_u64().unwrap_or(120).clamp(1, 600);
    let files: Vec<String> = a["files"]
        .as_array()
        .map(|v| {
            v.iter()
                .filter_map(|x| x.as_str().map(str::to_string))
                .collect()
        })
        .unwrap_or_default();
    let p = match edit_project(s, session, pid).await {
        Ok(p) => p,
        Err(r) => {
            let (st, b) = resp_text(r).await;
            return Err(err_result(format!("{b} (status {st})")));
        }
    };
    let cid = client_id(session, a);
    let now = AppState::now();
    match s
        .db
        .lock_acquire(
            pid,
            "edit",
            &cid,
            &session.user.username,
            now + s.cfg.lock_ttl,
            now,
            false,
        )
        .await
    {
        Ok(LockOutcome::Acquired(_)) => {}
        Ok(LockOutcome::Held(l)) => {
            return Err(err_result(format!(
                "project is being edited by {}",
                l.label
            )));
        }
        Err(e) => return Err(err_result(format!("lock: {e}"))),
    }
    let dir = s.cfg.data_dir.join("mcp").join(model::new_id());
    let files_dir = dir.join("files");
    if let Err(e) = tokio::fs::create_dir_all(&files_dir).await {
        let _ = s.db.lock_release(pid, "edit", &cid).await;
        return Err(err_result(e.to_string()));
    }
    let fcproj = dir.join(files::PROJECT_FILE);
    let old = match render::blob_download(&s.blobs, &blob_key(&p.dir, files::PROJECT_FILE), &fcproj)
        .await
    {
        Ok(()) => tokio::fs::read(&fcproj).await.unwrap_or_default(),
        Err(_) => Vec::new(),
    };
    let have_doc = !old.is_empty();
    let base = match blob_rev(s, &p.dir, files::PROJECT_FILE).await {
        Ok(Some(r)) => r,
        _ => "none".into(),
    };
    if let Err(e) = stage_media(s, &p.dir, &files_dir, &files).await {
        let _ = s.db.lock_release(pid, "edit", &cid).await;
        let _ = tokio::fs::remove_dir_all(&dir).await;
        return Err(err_result(e));
    }
    let hb = {
        let (s, pid, cid) = (s.clone(), pid.to_string(), cid.clone());
        let ttl = s.cfg.lock_ttl;
        tokio::spawn(async move {
            let mut t =
                tokio::time::interval(std::time::Duration::from_secs((ttl / 2).max(5) as u64));
            t.tick().await;
            loop {
                t.tick().await;
                let _ =
                    s.db.lock_heartbeat(&pid, "edit", &cid, AppState::now() + ttl)
                        .await;
            }
        })
    };
    let run = craft_run(s, &p.name, &dir, have_doc, tool, cargs, !files.is_empty());
    let out = tokio::time::timeout(std::time::Duration::from_secs(timeout), run).await;
    hb.abort();
    let mut out = out.unwrap_or_else(|_| Err("command timed out".into()));
    let mut saved = false;
    if let Ok(new) = tokio::fs::read(&fcproj).await {
        if !new.is_empty() && new != old {
            match put_fcproj(s, auth, pid, &dir, &new, &cid, &base).await {
                Ok(()) => saved = true,
                Err(e) => out = Err(e),
            }
        }
    }
    let _ = s.db.lock_release(pid, "edit", &cid).await;
    let _ = tokio::fs::remove_dir_all(&dir).await;
    let tool_result = match out {
        Ok(v) => v,
        Err(e) => return Err(err_result(e)),
    };
    let inner_err = tool_result["isError"].as_bool().unwrap_or(false);
    let inner = match tool_result["content"][0]["text"].as_str() {
        Some(t) => serde_json::from_str(t).unwrap_or_else(|_| json!(t)),
        None => tool_result.clone(),
    };
    if inner_err {
        Err(err_result(format!(
            "craft command failed{}: {}",
            if saved { " (saved)" } else { "" },
            match &inner {
                Value::String(s) => s.clone(),
                v => v.to_string(),
            }
        )))
    } else {
        Ok(json!({"saved": saved, "result": inner}))
    }
}

/// Stage project media under `<dir>` with the same `/files` names the web
/// editor registers, so doc references resolve inside the CLI session.
async fn stage_media(
    s: &Arc<AppState>,
    dir: &str,
    files_dir: &std::path::Path,
    paths: &[String],
) -> Result<(), String> {
    let mut done: HashMap<String, String> = HashMap::new();
    for m in render::stage_media(paths) {
        let dest = files_dir.join(&m.name);
        if dest.exists() {
            continue;
        }
        if let Some(first) = done.get(&m.path) {
            match std::fs::hard_link(files_dir.join(first), &dest) {
                Ok(()) => continue,
                Err(_) => {
                    let _ = std::fs::copy(files_dir.join(first), &dest);
                    continue;
                }
            }
        }
        render::blob_download(&s.blobs, &blob_key(dir, &m.path), &dest)
            .await
            .map_err(|e| format!("{}: {e}", m.path))?;
        done.insert(m.path, m.name);
    }
    Ok(())
}

async fn craft_run(
    s: &Arc<AppState>,
    project_name: &str,
    dir: &std::path::Path,
    have_doc: bool,
    tool: &str,
    mut cargs: Value,
    relink: bool,
) -> Result<Value, String> {
    let fcproj = dir.join(files::PROJECT_FILE);
    let mut mcp = if have_doc {
        render::Mcp::spawn(&s.cfg.filmcraft_cli, &fcproj).await?
    } else {
        render::Mcp::spawn_blank(&s.cfg.filmcraft_cli).await?
    };
    if !have_doc {
        mcp.request(
            "tools/call",
            json!({"name": "command_run",
                   "arguments": {"id": "file.newProject",
                                 "params": {"name": project_name}}}),
        )
        .await?;
    }
    if relink {
        let _ = mcp
            .request(
                "tools/call",
                json!({"name": "command_run",
                       "arguments": {"id": "media.autoRelink",
                                     "params": {"from": "/files",
                                                "to": dir.join("files")}}}),
            )
            .await;
    }
    staged(&mut cargs, &dir.join("files"));
    let result = mcp
        .request("tools/call", json!({"name": tool, "arguments": cargs}))
        .await?;
    let save = if have_doc {
        json!({"id": "file.save", "params": {}})
    } else {
        json!({"id": "file.saveAs", "params": {"path": fcproj}})
    };
    let _ = mcp
        .request(
            "tools/call",
            json!({"name": "command_run", "arguments": save}),
        )
        .await;
    Ok(result)
}

/// Write the saved doc back through the real upload endpoint (sniffing, lock
/// check, base-rev check, audit). Media paths pointing at the scratch dir are
/// rewritten to `/files` refs first so the doc stays portable.
async fn put_fcproj(
    s: &Arc<AppState>,
    auth: &HeaderMap,
    pid: &str,
    dir: &std::path::Path,
    bytes: &[u8],
    client_id: &str,
    base: &str,
) -> Result<(), String> {
    let prefix = format!("{}/", dir.join("files").display());
    let body = match serde_json::from_slice::<Value>(bytes) {
        Ok(mut v) => {
            let mut changed = false;
            unstaged(&mut v, &prefix, &mut changed);
            if changed {
                serde_json::to_vec(&v).map_err(|e| e.to_string())?
            } else {
                bytes.to_vec()
            }
        }
        Err(_) => bytes.to_vec(),
    };
    let uri = format!(
        "/api/projects/{pid}/files?{}",
        qs(&[
            ("path", files::PROJECT_FILE.into()),
            ("clientId", client_id.into()),
            ("base", base.into()),
        ])
    );
    let (st, _, b) = call_api(
        s,
        auth,
        Method::PUT,
        &uri,
        Body::from(body),
        "application/octet-stream",
    )
    .await?;
    if st.is_success() {
        Ok(())
    } else {
        Err(format!(
            "save failed (status {st}): {}",
            String::from_utf8_lossy(&b)
        ))
    }
}

/// Rewrite `/files/x` refs in craft tool arguments to the staged copy under
/// the scratch dir, so imports and inserts hit real files. `unstaged` puts
/// them back on save.
fn staged(v: &mut Value, dir: &std::path::Path) {
    match v {
        Value::String(s) if s.starts_with("/files/") => {
            *s = format!("{}", dir.join(&s[7..]).display());
        }
        Value::Array(a) => a.iter_mut().for_each(|x| staged(x, dir)),
        Value::Object(o) => o.values_mut().for_each(|x| staged(x, dir)),
        _ => {}
    }
}

fn unstaged(v: &mut Value, prefix: &str, changed: &mut bool) {
    match v {
        Value::String(s) if s.starts_with(prefix) => {
            *s = format!("/files/{}", &s[prefix.len()..]);
            *changed = true;
        }
        Value::Array(a) => a.iter_mut().for_each(|x| unstaged(x, prefix, changed)),
        Value::Object(o) => o.values_mut().for_each(|x| unstaged(x, prefix, changed)),
        _ => {}
    }
}

async fn resp_text(r: Response) -> (StatusCode, String) {
    let st = r.status();
    let b = axum::body::to_bytes(r.into_body(), 64 * 1024)
        .await
        .unwrap_or_default();
    let v: Value = serde_json::from_slice(&b).unwrap_or(json!({}));
    (
        st,
        v["error"]
            .as_str()
            .map(str::to_string)
            .unwrap_or_else(|| String::from_utf8_lossy(&b).into_owned()),
    )
}

// ---------- token management ----------

fn token_name(ua: &str) -> String {
    ua.strip_prefix(TOKEN_MARK)
        .and_then(|s| s.strip_prefix('/'))
        .unwrap_or("")
        .to_string()
}

pub async fn list_tokens(State(s): State<Arc<AppState>>, session: Session) -> Response {
    match s.db.list_sessions(&session.user.id).await {
        Ok(rows) => Json(json!(rows
            .into_iter()
            .filter(|r| r.ua.starts_with(TOKEN_MARK))
            .map(|r| json!({
                "id": r.id,
                "name": token_name(&r.ua),
                "createdAt": r.created_at,
                "expiresAt": r.expires_at,
                "lastSeen": r.last_seen,
            }))
            .collect::<Vec<_>>()))
        .into_response(),
        Err(e) => db_resp(e),
    }
}

#[derive(Deserialize)]
pub struct TokenReq {
    #[serde(default)]
    name: String,
}

/// Mint a long-lived session tagged as an MCP token. It is a normal session
/// underneath — same permissions as the user, revocable from either the
/// Sessions page or the MCP section.
pub async fn create_token(
    State(s): State<Arc<AppState>>,
    session: Session,
    Json(req): Json<TokenReq>,
) -> Response {
    let name: String = req
        .name
        .trim()
        .chars()
        .filter(|c| !c.is_control() && *c != '/')
        .take(64)
        .collect();
    let ua = if name.is_empty() {
        TOKEN_MARK.to_string()
    } else {
        format!("{TOKEN_MARK}/{name}")
    };
    let token = model::new_token();
    let th = model::token_hash(&token);
    let expires = AppState::now() + TOKEN_TTL;
    if let Err(e) =
        s.db.create_session(&th, &session.user.id, "", expires, "", &ua)
            .await
    {
        return db_resp(e);
    }
    s.audit("account", &session.user, "mcp_token_create", &name, "", "")
        .await;
    Json(json!({
        "id": th,
        "name": name,
        "token": token,
        "expiresAt": expires,
        "url": "/api/mcp",
    }))
    .into_response()
}

pub async fn delete_token(
    State(s): State<Arc<AppState>>,
    session: Session,
    Path(id): Path<String>,
) -> Response {
    match s.db.list_sessions(&session.user.id).await {
        Ok(rows) => {
            if !rows
                .iter()
                .any(|r| r.id == id && r.ua.starts_with(TOKEN_MARK))
            {
                return err(StatusCode::NOT_FOUND, "no such token");
            }
        }
        Err(e) => return db_resp(e),
    }
    if let Err(e) = s.db.delete_user_session(&session.user.id, &id).await {
        return db_resp(e);
    }
    s.audit("account", &session.user, "mcp_token_revoke", &id, "", "")
        .await;
    Json(json!({"ok": true})).into_response()
}

// ---------- tool schemas ----------

fn tools() -> Value {
    json!([
        {"name": "projects", "description": "List projects you can see.",
         "inputSchema": {"type": "object", "properties": {}},
         "annotations": {"readOnlyHint": true}},
        {"name": "project", "description": "One project's details.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "project_create", "description": "Create a project.",
         "inputSchema": {"type": "object", "properties": {
            "name": {"type": "string", "description": "letters, digits, space, _ . - (max 64)"},
            "displayName": {"type": "string"},
            "folderId": {"type": "string", "description": "optional folder to file it under"}},
         "required": ["name"]}},
        {"name": "project_update", "description": "Rename, re-file or pin a project.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "displayName": {"type": "string"},
            "folderId": {"type": "string"},
            "pinned": {"type": "boolean"},
            "template": {"type": "boolean"}}, "required": ["projectId"]}},
        {"name": "project_delete", "description": "Delete a project and its files.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]},
         "annotations": {"destructiveHint": true}},
        {"name": "project_duplicate", "description": "Copy a project with all its files.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]}},
        {"name": "project_submit", "description": "Submit a project for review, or withdraw it.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]}},
        {"name": "project_review", "description": "Staff: mark a submitted project reviewed or return it to draft.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "status": {"type": "string", "enum": ["reviewed", "draft"]}},
         "required": ["projectId", "status"]}},
        {"name": "folders", "description": "List your project folders.",
         "inputSchema": {"type": "object", "properties": {}},
         "annotations": {"readOnlyHint": true}},
        {"name": "folder_create", "description": "Create a project folder.",
         "inputSchema": {"type": "object", "properties": {
            "name": {"type": "string"}}, "required": ["name"]}},
        {"name": "folder_rename", "description": "Rename a folder.",
         "inputSchema": {"type": "object", "properties": {
            "folderId": {"type": "string"}, "name": {"type": "string"}},
         "required": ["folderId", "name"]}},
        {"name": "folder_delete", "description": "Delete a folder (projects inside are kept, unfiled).",
         "inputSchema": {"type": "object", "properties": {
            "folderId": {"type": "string"}}, "required": ["folderId"]},
         "annotations": {"destructiveHint": true}},
        {"name": "files", "description": "List one folder inside a project. Empty path lists the top-level folders.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "path": {"type": "string", "description": "e.g. Raw, Audio/Music, Script"}},
         "required": ["projectId"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "file_tree", "description": "Every file in the project, recursive, with revs for the base check in file_write.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "file_read", "description": "Read a project file. Text comes back as utf8, binary as base64. Use offset/limit (bytes) for ranges.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "path": {"type": "string"},
            "offset": {"type": "integer"},
            "limit": {"type": "integer", "description": "max 8388608"}},
         "required": ["projectId", "path"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "file_write", "description": "Write a project file (text or base64). `base` may hold the rev from file_tree to refuse overwriting a newer file; use \"none\" to require the file does not exist yet.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "path": {"type": "string", "description": "e.g. Raw/clip.mp4, Script/notes.md, project.fcproj"},
            "text": {"type": "string"},
            "base64": {"type": "string"},
            "base": {"type": "string"},
            "clientId": {"type": "string", "description": "lock holder id; defaults to this MCP token"}},
         "required": ["projectId", "path"]}},
        {"name": "file_delete", "description": "Delete a file inside a project.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}, "path": {"type": "string"}},
         "required": ["projectId", "path"]},
         "annotations": {"destructiveHint": true}},
        {"name": "file_move", "description": "Move or rename a file (extension may not change).",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "from": {"type": "string"}, "to": {"type": "string"}},
         "required": ["projectId", "from", "to"]}},
        {"name": "dir_create", "description": "Create a folder inside a project.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}, "path": {"type": "string"}},
         "required": ["projectId", "path"]}},
        {"name": "upload_start", "description": "Begin a chunked upload for a large file. Returns an uploadId for upload_chunk/upload_finish.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}, "path": {"type": "string"}},
         "required": ["projectId", "path"]}},
        {"name": "upload_chunk", "description": "Append one base64 chunk at byte offset (must equal bytes sent so far).",
         "inputSchema": {"type": "object", "properties": {
            "uploadId": {"type": "string"},
            "offset": {"type": "integer"},
            "base64": {"type": "string"}},
         "required": ["uploadId", "offset", "base64"]}},
        {"name": "upload_finish", "description": "Complete a chunked upload and store the file.",
         "inputSchema": {"type": "object", "properties": {
            "uploadId": {"type": "string"}}, "required": ["uploadId"]}},
        {"name": "upload_abort", "description": "Abort a chunked upload.",
         "inputSchema": {"type": "object", "properties": {
            "uploadId": {"type": "string"}}, "required": ["uploadId"]},
         "annotations": {"destructiveHint": true}},
        {"name": "comments", "description": "Comments on a project.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "comment_add", "description": "Add a comment to a project.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}, "body": {"type": "string"}},
         "required": ["projectId", "body"]}},
        {"name": "render_info", "description": "Sequences in a project plus whether server rendering is available.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "renders", "description": "Render jobs of a project, newest first.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"}}, "required": ["projectId"]},
         "annotations": {"readOnlyHint": true}},
        {"name": "render_start", "description": "Queue a render of the project's saved FilmCraft edit. Output lands in Exports/.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "output": {"type": "string", "description": "output name, default 'export'"},
            "sequence": {"type": "integer", "description": "sequence id from render_info"},
            "params": {"type": "object", "description": "file.exportMedia params (format, settings, range)"},
            "mode": {"type": "string", "enum": ["server"], "default": "server"}},
         "required": ["projectId"]}},
        {"name": "render_cancel", "description": "Cancel a queued or running render.",
         "inputSchema": {"type": "object", "properties": {
            "renderId": {"type": "string"}}, "required": ["renderId"]}},
        {"name": "render_retry", "description": "Retry a failed render.",
         "inputSchema": {"type": "object", "properties": {
            "renderId": {"type": "string"}}, "required": ["renderId"]}},
        {"name": "render_delete", "description": "Remove a render job from the list.",
         "inputSchema": {"type": "object", "properties": {
            "renderId": {"type": "string"}}, "required": ["renderId"]},
         "annotations": {"destructiveHint": true}},
        {"name": "project_commands", "description": "List the FilmCraft engine commands usable through project_command (id, label, params).",
         "inputSchema": {"type": "object", "properties": {
            "filter": {"type": "string", "description": "substring match on id or label"}}},
         "annotations": {"readOnlyHint": true}},
        {"name": "project_command", "description": "Run a FilmCraft engine tool on the project's edit (e.g. tool=command_run {id,params}, command_batch, media_import, doc_inspect, sequence_inspect, render_frame). `files` lists project paths to stage for the session; refer to them as /files/<name> in arguments (e.g. media_import {paths:[\"/files/clip.mp4\"]}) and the same refs end up in the saved doc. The edit is saved back to the project afterwards. Fails while a human holds the edit lock.",
         "inputSchema": {"type": "object", "properties": {
            "projectId": {"type": "string"},
            "tool": {"type": "string", "description": "craft tool name, e.g. command_run"},
            "arguments": {"type": "object", "description": "the craft tool's arguments"},
            "files": {"type": "array", "items": {"type": "string"},
                      "description": "project paths to stage for the session"},
            "timeoutSec": {"type": "integer", "description": "default 120, max 600"}},
         "required": ["projectId", "tool"]}},
        {"name": "api", "description": "Call any /api endpoint with your permissions. method (default GET), path like /projects, query object, body (JSON) or bodyBase64.",
         "inputSchema": {"type": "object", "properties": {
            "method": {"type": "string"},
            "path": {"type": "string"},
            "query": {"type": "object"},
            "body": {},
            "bodyBase64": {"type": "string"}},
         "required": ["path"]}},
    ])
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Role, User};
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
                enforce_https: None,
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
            enforce_https: std::sync::atomic::AtomicBool::new(false),
        })
    }

    async fn owner(s: &Arc<AppState>) -> (User, String) {
        let u = User {
            id: model::new_id(),
            username: "owner".into(),
            display_name: "Owner".into(),
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
        s.db.create_owner(&u, "x").await.unwrap();
        let token = model::new_token();
        s.db.create_session(
            &model::token_hash(&token),
            &u.id,
            "csrf",
            AppState::now() + 3600,
            "",
            "",
        )
        .await
        .unwrap();
        (u, token)
    }

    fn req(token: &str, method: Method, uri: &str, body: Value) -> Request<Body> {
        let mut b = Request::builder()
            .method(method)
            .uri(uri)
            .header(header::CONTENT_TYPE, "application/json");
        if !token.is_empty() {
            b = b.header(header::AUTHORIZATION, format!("Bearer {token}"));
        }
        b.body(Body::from(serde_json::to_vec(&body).unwrap()))
            .unwrap()
    }

    async fn post(s: &Arc<AppState>, token: &str, uri: &str, body: Value) -> (StatusCode, Value) {
        let r = super::super::router(s.clone())
            .oneshot(req(token, Method::POST, uri, body))
            .await
            .unwrap();
        let st = r.status();
        let b = axum::body::to_bytes(r.into_body(), MAX_REPLY)
            .await
            .unwrap();
        (st, serde_json::from_slice(&b).unwrap_or(json!({})))
    }

    async fn call(s: &Arc<AppState>, token: &str, name: &str, args: Value) -> Value {
        let (_, v) = post(
            s,
            token,
            "/api/mcp",
            json!({"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                   "params": {"name": name, "arguments": args}}),
        )
        .await;
        v
    }

    fn tool_json(v: &Value) -> Value {
        let c = &v["result"]["content"][0];
        serde_json::from_str(c["text"].as_str().unwrap()).unwrap_or(json!({}))
    }

    fn tmp() -> std::path::PathBuf {
        let d = std::env::temp_dir().join(format!("wfm-mcp-{}", model::new_id()));
        std::fs::create_dir_all(&d).unwrap();
        d
    }

    #[tokio::test]
    async fn protocol_basics() {
        let s = state(&tmp());
        let (_, token) = owner(&s).await;

        let r = super::super::router(s.clone())
            .oneshot(req(&token, Method::POST, "/api/mcp", json!("not json")))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::OK);
        let b = axum::body::to_bytes(r.into_body(), MAX_REPLY)
            .await
            .unwrap();
        let v: Value = serde_json::from_slice(&b).unwrap();
        assert_eq!(v["error"]["code"], -32600);

        let (st, _) = post(&s, &token, "/api/mcp", json!({"bogus": 1})).await;
        assert_eq!(st, StatusCode::ACCEPTED); // no id: treated as a notification
        let (_, v) = post(&s, &token, "/api/mcp", json!({"bogus": 1, "id": 2})).await;
        assert_eq!(v["error"]["code"], -32601);

        let (_, v) = post(
            &s,
            &token,
            "/api/mcp",
            json!({"jsonrpc": "2.0", "id": 7, "method": "initialize", "params": {}}),
        )
        .await;
        assert_eq!(v["id"], 7);
        assert_eq!(v["result"]["serverInfo"]["name"], "wfm");

        let (st, v) = post(
            &s,
            &token,
            "/api/mcp",
            json!({"jsonrpc": "2.0", "id": 1, "method": "nope/nope"}),
        )
        .await;
        assert_eq!(st, StatusCode::OK);
        assert_eq!(v["error"]["code"], -32601);

        let (_, v) = post(
            &s,
            &token,
            "/api/mcp",
            json!({"jsonrpc": "2.0", "id": 1, "method": "tools/list"}),
        )
        .await;
        let names: Vec<&str> = v["result"]["tools"]
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|t| t["name"].as_str())
            .collect();
        for t in [
            "project_create",
            "file_write",
            "project_command",
            "render_start",
            "api",
        ] {
            assert!(names.contains(&t), "missing tool {t}");
        }

        let v = call(&s, &token, "no_such_tool", json!({})).await;
        assert_eq!(v["error"]["code"], -32602);
    }

    #[tokio::test]
    async fn unauthenticated_rejected() {
        let s = state(&tmp());
        let r = super::super::router(s.clone())
            .oneshot(req(
                "",
                Method::POST,
                "/api/mcp",
                json!({"jsonrpc":"2.0","id":1,"method":"tools/list"}),
            ))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn project_and_file_flow() {
        let s = state(&tmp());
        let (_, token) = owner(&s).await;

        let v = call(&s, &token, "project_create", json!({"name": "film"})).await;
        let p = tool_json(&v);
        let pid = p["id"].as_str().unwrap().to_string();

        let v = call(&s, &token, "projects", json!({})).await;
        let list = tool_json(&v);
        assert!(list.as_array().unwrap().iter().any(|x| x["id"] == pid));

        let v = call(
            &s,
            &token,
            "file_write",
            json!({"projectId": pid, "path": "Script/notes.txt",
                   "base64": base64::engine::general_purpose::STANDARD.encode("line one\nline two")}),
        )
        .await;
        assert_ne!(v["result"]["isError"], true, "{v}");

        let v = call(
            &s,
            &token,
            "files",
            json!({"projectId": pid, "path": "Script"}),
        )
        .await;
        let list = tool_json(&v);
        assert!(list
            .as_array()
            .unwrap()
            .iter()
            .any(|x| x["path"] == "Script/notes.txt"));

        let v = call(
            &s,
            &token,
            "file_read",
            json!({"projectId": pid, "path": "Script/notes.txt"}),
        )
        .await;
        let doc = tool_json(&v);
        assert_eq!(doc["content"], "line one\nline two");
        assert_eq!(doc["encoding"], "utf8");

        let v = call(&s, &token, "api", json!({"path": "/projects"})).await;
        let doc = tool_json(&v);
        assert_eq!(doc["status"], 200);

        let v = call(
            &s,
            &token,
            "file_delete",
            json!({"projectId": pid, "path": "Script/notes.txt"}),
        )
        .await;
        assert_ne!(v["result"]["isError"], true, "{v}");
    }

    #[tokio::test]
    async fn token_lifecycle() {
        let s = state(&tmp());
        let (_, token) = owner(&s).await;

        let (st, v) = post(&s, &token, "/api/mcp/tokens", json!({"name": "agent"})).await;
        assert_eq!(st, StatusCode::OK);
        let id = v["id"].as_str().unwrap().to_string();
        let agent = v["token"].as_str().unwrap().to_string();

        let r = super::super::router(s.clone())
            .oneshot(req(&token, Method::GET, "/api/mcp/tokens", json!(null)))
            .await
            .unwrap();
        let b = axum::body::to_bytes(r.into_body(), MAX_REPLY)
            .await
            .unwrap();
        let list: Value = serde_json::from_slice(&b).unwrap();
        assert_eq!(list[0]["name"], "agent");

        let v = call(&s, &agent, "projects", json!({})).await;
        assert!(v["result"].is_object(), "{v}");

        let r = super::super::router(s.clone())
            .oneshot(req(
                &token,
                Method::DELETE,
                &format!("/api/mcp/tokens/{id}"),
                json!(null),
            ))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::OK);

        let r = super::super::router(s.clone())
            .oneshot(req(
                &agent,
                Method::POST,
                "/api/mcp",
                json!({"jsonrpc":"2.0","id":1,"method":"tools/list"}),
            ))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::UNAUTHORIZED);

        let r = super::super::router(s.clone())
            .oneshot(req(
                &token,
                Method::DELETE,
                &format!("/api/mcp/tokens/{id}"),
                json!(null),
            ))
            .await
            .unwrap();
        assert_eq!(r.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn craft_command_respects_edit_lock() {
        let s = state(&tmp());
        let (u, token) = owner(&s).await;

        let v = call(&s, &token, "project_create", json!({"name": "locked"})).await;
        let pid = tool_json(&v)["id"].as_str().unwrap().to_string();

        s.db.lock_acquire(
            &pid,
            "edit",
            "human",
            "alice",
            AppState::now() + 60,
            AppState::now(),
            false,
        )
        .await
        .unwrap();

        let v = call(
            &s,
            &token,
            "project_command",
            json!({"projectId": pid, "tool": "doc_inspect", "arguments": {}}),
        )
        .await;
        assert_eq!(v["result"]["isError"], true);
        assert!(v["result"]["content"][0]["text"]
            .as_str()
            .unwrap()
            .contains("alice"));
        let _ = u;
    }
}
