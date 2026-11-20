use std::collections::HashSet;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::{Duration, SystemTime};

use futures::StreamExt;
use serde_json::{json, Value};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader, Lines};
use tokio::process::{Child, ChildStdin, ChildStdout, Command};

use crate::auth::AppState;
use crate::files;
use crate::model::{RenderJob, RenderSpec, RenderStageFile};

const JOB_LEASE: i64 = 90;
/// Give up on a command_run that produces no output for two lease periods;
/// without progress the lease lapses and the job is requeued anyway, so a
/// hung filmcraft-cli would only hold the worker slot forever.
const STALL: Duration = Duration::from_secs(2 * JOB_LEASE as u64);
const MCP_PROTOCOL: &str = "2024-11-05";

/// Extensions wfm.html feeds to FilmCraft as project media; everything else
/// (project files, renders) is not staged for a render.
const MEDIA_EXTS: &[&str] = &[
    "mp4", "mov", "mkv", "webm", "avi", "mts", "m2ts", "mxf", "mp3", "wav", "aac", "flac", "ogg",
    "oga", "m4a", "opus", "png", "jpeg", "jpg", "webp", "gif", "tiff", "tif", "bmp", "srt", "vtt",
    "dng", "exr", "hdr",
];

fn is_media(name: &str) -> bool {
    name.rsplit('.')
        .next()
        .map(|e| MEDIA_EXTS.contains(&e.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

/// Every file in the project (project-relative paths, recursive).
pub async fn project_files(s: &Arc<AppState>, dir: &str) -> Result<Vec<String>, String> {
    let mut out = Vec::new();
    let mut stack = vec![String::new()];
    while let Some(prefix) = stack.pop() {
        let key = if prefix.is_empty() {
            dir.to_string()
        } else {
            format!("{dir}/{prefix}")
        };
        let (folders, objects) = s.blobs.list(&key).await?;
        for f in folders {
            stack.push(f.trim_start_matches(&format!("{dir}/")).to_string());
        }
        for o in objects {
            out.push(o.key.trim_start_matches(&format!("{dir}/")).to_string());
        }
    }
    out.sort();
    Ok(out)
}

/// The `/files/<name>` the web app registers a blob under, reproduced for a
/// staged copy: '/' and '\' become '_', and on collision the name gets
/// ` (n)` before the extension, in the order paths were registered.
pub fn stage_name(taken: &mut HashSet<String>, name: &str) -> String {
    let clean: String = name
        .chars()
        .map(|c| if c == '/' || c == '\\' { '_' } else { c })
        .collect();
    let (stem, ext) = match clean.rfind('.') {
        Some(i) if i > 0 => (clean[..i].to_string(), clean[i..].to_string()),
        _ => (clean.clone(), String::new()),
    };
    let mut n = 1;
    loop {
        let p = if n == 1 {
            clean.clone()
        } else {
            format!("{stem} ({n}){ext}")
        };
        if taken.insert(p.clone()) {
            return p;
        }
        n += 1;
    }
}

/// spec.media entries: media paths sorted (the order wfm.html registers them)
/// mapped to their `/files` staging names.
pub fn stage_media(paths: &[String]) -> Vec<RenderStageFile> {
    let mut taken = HashSet::new();
    let mut media: Vec<&String> = paths
        .iter()
        .filter(|p| is_media(p) && !p.starts_with("Exports/") && !p.ends_with(".fcproj"))
        .collect();
    media.sort();
    media
        .into_iter()
        .flat_map(|p| {
            // The client registers the whole cleaned path first, then the basename when it
            // differs (`host.rs` media-ref/media). Both consume a ` (n)` slot in registration
            // order, so reproduce both registrations or later numbers diverge.
            let clean: String = p.chars().map(|c| if c == '/' || c == '\\' { '_' } else { c }).collect();
            let mut files = vec![RenderStageFile { name: stage_name(&mut taken, p), path: p.clone() }];
            if let Some(base) = p.rsplit('/').next().filter(|b| *b != &clean) {
                files.push(RenderStageFile { name: stage_name(&mut taken, base), path: p.clone() });
            }
            files
        })
        .collect()
}

/// Newline-delimited JSON-RPC client for `filmcraft-cli mcp` on stdio. The
/// child is killed when the client drops.
pub struct Mcp {
    _child: Child,
    stdin: ChildStdin,
    stdout: Lines<BufReader<ChildStdout>>,
    next_id: u64,
}

impl Mcp {
    /// Spawn `filmcraft-cli --project <fcproj> mcp` and do the MCP handshake.
    pub async fn spawn(cli: &str, project: &Path) -> Result<Mcp, String> {
        let mut child = Command::new(cli)
            .arg("--project")
            .arg(project)
            .arg("mcp")
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .map_err(|e| format!("spawn filmcraft-cli: {e}"))?;
        let stdin = child.stdin.take().ok_or("no stdin")?;
        let stdout = child.stdout.take().ok_or("no stdout")?;
        let mut mcp = Mcp {
            _child: child,
            stdin,
            stdout: BufReader::new(stdout).lines(),
            next_id: 0,
        };
        mcp.request(
            "initialize",
            json!({
                "protocolVersion": MCP_PROTOCOL,
                "capabilities": {},
                "clientInfo": {"name": "wfm", "version": env!("CARGO_PKG_VERSION")},
            }),
        )
        .await?;
        mcp.send(&json!({"jsonrpc": "2.0", "method": "notifications/initialized"}))
            .await?;
        Ok(mcp)
    }

    async fn send(&mut self, v: &Value) -> Result<(), String> {
        let mut line = serde_json::to_string(v).map_err(|e| e.to_string())?;
        line.push('\n');
        self.stdin
            .write_all(line.as_bytes())
            .await
            .map_err(|e| format!("mcp write: {e}"))?;
        self.stdin
            .flush()
            .await
            .map_err(|e| format!("mcp write: {e}"))
    }

    async fn read_line(&mut self) -> Result<Value, String> {
        match self.stdout.next_line().await {
            Ok(Some(l)) => serde_json::from_str(&l).map_err(|e| format!("mcp read: {e}")),
            Ok(None) => Err("filmcraft-cli exited".into()),
            Err(e) => Err(format!("mcp read: {e}")),
        }
    }

    /// A request; notifications received while waiting are ignored.
    pub async fn request(&mut self, method: &str, params: Value) -> Result<Value, String> {
        self.next_id += 1;
        let id = self.next_id;
        self.send(&json!({"jsonrpc": "2.0", "id": id, "method": method, "params": params}))
            .await?;
        loop {
            let msg = self.read_line().await?;
            if msg.get("id").and_then(Value::as_u64) != Some(id) {
                continue;
            }
            if let Some(e) = msg.get("error") {
                return Err(e
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("mcp error")
                    .to_string());
            }
            return Ok(msg.get("result").cloned().unwrap_or(Value::Null));
        }
    }

    /// `tools/call command_run` with a progress token; `on_progress` gets the
    /// fraction and status text. `stop` asks for cancellation (and the request
    /// is then aborted).
    pub async fn command_run(
        &mut self,
        command: &str,
        params: Value,
        mut on_progress: impl FnMut(f64, &str),
        stop: impl Fn() -> bool,
    ) -> Result<Value, String> {
        self.next_id += 1;
        let id = self.next_id;
        let token = format!("wfm-{id}");
        self.send(&json!({
            "jsonrpc": "2.0", "id": id, "method": "tools/call",
            "params": {"name": "command_run", "arguments": {"id": command, "params": params},
                       "_meta": {"progressToken": token}},
        }))
        .await?;
        let mut canceled = false;
        loop {
            if !canceled && stop() {
                canceled = true;
                let _ = self
                    .send(&json!({
                        "jsonrpc": "2.0", "method": "notifications/cancelled",
                        "params": {"requestId": id, "reason": "canceled"},
                    }))
                    .await;
            }
            let msg = match tokio::time::timeout(STALL, self.read_line()).await {
                Ok(m) => m?,
                Err(_) => return Err("render stalled".into()),
            };
            if msg.get("method").and_then(Value::as_str) == Some("notifications/progress") {
                let p = &msg["params"];
                if p.get("progressToken").and_then(Value::as_str) == Some(token.as_str()) {
                    let (done, total) = (
                        p["progress"].as_f64().unwrap_or(0.0),
                        p["total"].as_f64().unwrap_or(0.0),
                    );
                    let frac = if total > 0.0 {
                        (done / total).clamp(0.0, 0.999)
                    } else {
                        0.0
                    };
                    on_progress(frac, p["message"].as_str().unwrap_or(""));
                }
                continue;
            }
            if msg.get("id").and_then(Value::as_u64) != Some(id) {
                continue;
            }
            if canceled {
                return Err("canceled".into());
            }
            if let Some(e) = msg.get("error") {
                return Err(e
                    .get("message")
                    .and_then(Value::as_str)
                    .unwrap_or("mcp error")
                    .to_string());
            }
            let result = msg.get("result").cloned().unwrap_or(Value::Null);
            if result["isError"].as_bool() == Some(true) {
                let text = result["content"]
                    .as_array()
                    .and_then(|c| c.first())
                    .and_then(|c| c["text"].as_str())
                    .unwrap_or("command failed");
                return Err(text.to_string());
            }
            let text = result["content"]
                .as_array()
                .and_then(|c| c.first())
                .and_then(|c| c["text"].as_str())
                .unwrap_or("{}");
            return Ok(serde_json::from_str(text).unwrap_or(Value::Null));
        }
    }
}

/// Periodic maintenance: drop expired locks/sessions, requeue stale renders.
pub fn spawn_janitor(state: Arc<AppState>) {
    tokio::spawn(async move {
        let mut tick = tokio::time::interval(Duration::from_secs(20));
        let mut sweep = tokio::time::interval(Duration::from_secs(3600));
        loop {
            tokio::select! {
                _ = tick.tick() => {
                    let now = AppState::now();
                    let _ = state.db.clean_locks(now).await;
                    let _ = state.db.clean_sessions(now).await;
                    if state.cfg.audit_days > 0 {
                        let _ = state
                            .db
                            .audit_purge(now - state.cfg.audit_days * 86400)
                            .await;
                    }
                    let _ = state.db.job_requeue_stale(now).await;
                    let _ = state.db.job_fail_stale(now).await;
                    if let Ok(nodes) = state.db.nodes_newly_offline(now - 120).await {
                        if !nodes.is_empty() {
                            if let Ok(staff) = state.db.staff_ids().await {
                                for n in nodes {
                                    for uid in &staff {
                                        state
                                            .notify(
                                                uid,
                                                "node_offline",
                                                serde_json::json!({
                                                    "node": n.id,
                                                    "name": n.name,
                                                }),
                                            )
                                            .await;
                                    }
                                }
                            }
                        }
                    }
                    crate::auth::login_prune(&state.logins);
                    crate::auth::login_prune(&state.link_hits);
                    // Cancel flags only matter while a job runs; purge ids
                    // whose job reached a terminal state (or vanished) so the
                    // set cannot grow forever.
                    let ids: Vec<String> =
                        state.cancels.lock().unwrap().iter().cloned().collect();
                    for id in ids {
                        match state.db.job_by_id(&id).await {
                            Ok(j) if j.status == "running" => {}
                            _ => {
                                state.cancels.lock().unwrap().remove(&id);
                            }
                        }
                    }
                }
                _ = sweep.tick() => {
                    sweep_stale_dirs(&state.cfg.data_dir).await;
                    let now = AppState::now();
                    let stale: Vec<crate::auth::ChunkUpload> = {
                        let mut m = state.chunk_uploads.lock().unwrap();
                        let ids: Vec<String> = m
                            .iter()
                            .filter(|(_, u)| u.touched < now - 24 * 3600)
                            .map(|(k, _)| k.clone())
                            .collect();
                        ids.iter().filter_map(|i| m.remove(i)).collect()
                    };
                    for u in stale {
                        let _ = tokio::fs::remove_file(&u.tmp).await;
                    }
                    state
                        .handoffs
                        .lock()
                        .unwrap()
                        .retain(|_, (_, exp)| *exp > now);
                }
            }
        }
    });
}

/// Delete upload spool files and render/inspect/worker staging dirs that have
/// been untouched for a day; a kill mid-upload or mid-render leaves them
/// behind forever otherwise.
async fn sweep_stale_dirs(root: &Path) {
    let cutoff = SystemTime::now() - Duration::from_secs(24 * 3600);
    for d in ["tmp", "render", "inspect", "worker"] {
        let mut rd = match tokio::fs::read_dir(root.join(d)).await {
            Ok(r) => r,
            Err(_) => continue,
        };
        while let Ok(Some(e)) = rd.next_entry().await {
            if let Some(t) = newest_mtime(&e.path()).await {
                if t < cutoff {
                    let _ = if e.file_type().await.map(|t| t.is_dir()).unwrap_or(false) {
                        tokio::fs::remove_dir_all(e.path()).await
                    } else {
                        tokio::fs::remove_file(e.path()).await
                    };
                }
            }
        }
    }
}

/// Most recent mtime anywhere under `p`, so a staging dir whose output file
/// is still being written counts as in-flight rather than stale.
async fn newest_mtime(p: &Path) -> Option<SystemTime> {
    let mut newest = tokio::fs::metadata(p).await.ok()?.modified().ok()?;
    let mut stack = vec![p.to_path_buf()];
    while let Some(d) = stack.pop() {
        if let Ok(mut rd) = tokio::fs::read_dir(&d).await {
            while let Ok(Some(e)) = rd.next_entry().await {
                if let Ok(md) = e.metadata().await {
                    if let Ok(t) = md.modified() {
                        if t > newest {
                            newest = t;
                        }
                    }
                    if md.is_dir() {
                        stack.push(e.path());
                    }
                }
            }
        }
    }
    Some(newest)
}

/// Local render workers draining the queue on this machine.
pub fn spawn_workers(state: Arc<AppState>) {
    for i in 0..state.cfg.render_workers {
        let st = state.clone();
        tokio::spawn(async move { worker_loop(st, i).await });
    }
}

async fn worker_loop(state: Arc<AppState>, idx: usize) {
    let worker_name = format!("local-{idx}");
    loop {
        let job = match state.db.job_next_queued().await {
            Ok(Some(j)) => j,
            _ => {
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
        };
        let lease = AppState::now() + JOB_LEASE;
        match state.db.job_claim(&job.id, &worker_name, lease).await {
            Ok(true) => {}
            _ => continue,
        }
        run_job(&state, &job, &worker_name).await;
    }
}

/// Download one project blob to `dest`.
pub async fn blob_download(
    b: &Arc<dyn crate::blobs::Blobs>,
    key: &str,
    dest: &Path,
) -> Result<(), String> {
    let (_len, mut stream) = b.get(key).await?;
    let mut f = tokio::fs::File::create(dest)
        .await
        .map_err(|e| e.to_string())?;
    while let Some(chunk) = stream.next().await {
        let chunk = chunk.map_err(|e| e.to_string())?;
        f.write_all(&chunk).await.map_err(|e| e.to_string())?;
    }
    Ok(())
}

/// Stage the project under `dir`: project.fcproj plus every media file under
/// `dir/files/<staged name>` so `media.autoRelink` can fix the `/files/` paths.
pub async fn stage_project(
    s: &Arc<AppState>,
    project_dir: &str,
    spec: &RenderSpec,
    dir: &Path,
) -> Result<(), String> {
    let fcproj = dir.join(files::PROJECT_FILE);
    blob_download(
        &s.blobs,
        &format!("{project_dir}/{}", files::PROJECT_FILE),
        &fcproj,
    )
    .await
    .map_err(|_| "no saved FilmCraft project: open it in the editor once".to_string())?;
    let files_dir = dir.join("files");
    for m in &spec.media {
        let dest = files_dir.join(&m.name);
        if let Some(p) = dest.parent() {
            let _ = std::fs::create_dir_all(p);
        }
        blob_download(&s.blobs, &format!("{project_dir}/{}", m.path), &dest).await?;
    }
    Ok(())
}

/// The params for `file.exportMedia`: the job's params with the output path,
/// sequence and wait forced by the worker.
pub fn export_params(spec: &RenderSpec, out_path: &str) -> Value {
    let mut p = spec.params.clone();
    if !p.is_object() {
        p = json!({});
    }
    let o = p.as_object_mut().unwrap();
    o.insert("path".into(), json!(out_path));
    o.insert("wait".into(), json!(true));
    if spec.sequence > 0 {
        o.insert("sequence".into(), json!(spec.sequence));
    }
    p
}

/// Render a staged project with filmcraft-cli: relink staged media, export,
/// report progress, honour `stop`. Returns paths of produced output files.
pub async fn render_with_cli(
    cli: &str,
    dir: &Path,
    spec: &RenderSpec,
    on_progress: impl FnMut(f64, &str),
    stop: impl Fn() -> bool,
) -> Result<Vec<PathBuf>, String> {
    let files_dir = dir.join("files");
    let mut mcp = Mcp::spawn(cli, &dir.join(files::PROJECT_FILE)).await?;
    mcp.request(
        "tools/call",
        json!({"name": "command_run", "arguments": {"id": "media.autoRelink",
              "params": {"from": "/files", "to": files_dir.to_string_lossy()}}}),
    )
    .await?;
    let out_dir = dir.join("out");
    let _ = std::fs::create_dir_all(&out_dir);
    let before: HashSet<PathBuf> = std::fs::read_dir(&out_dir)
        .map(|d| d.flatten().map(|e| e.path()).collect())
        .unwrap_or_default();
    let params = export_params(spec, &out_dir.join("export.mp4").to_string_lossy());
    mcp.command_run("file.exportMedia", params, on_progress, stop)
        .await?;
    let mut produced: Vec<PathBuf> = std::fs::read_dir(&out_dir)
        .map_err(|e| e.to_string())?
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_file() && !before.contains(p))
        .collect();
    produced.sort();
    if produced.is_empty() {
        return Err("export produced no output".into());
    }
    Ok(produced)
}

async fn run_job(state: &Arc<AppState>, job: &RenderJob, worker: &str) {
    let fail = |state: &Arc<AppState>, job: &RenderJob, e: String| {
        let (state, job, w) = (state.clone(), job.clone(), worker.to_string());
        async move {
            let _ = state
                .db
                .job_finish(&job.id, &w, "failed", &e, AppState::now())
                .await;
            let _ = state
                .db
                .lock_release(&job.project_id, "render", &job.id)
                .await;
            state.cancels.lock().unwrap().remove(&job.id);
            let pname = state
                .db
                .project_by_id(&job.project_id)
                .await
                .map(|p| p.display_name)
                .unwrap_or_default();
            state
                .notify(
                    &job.user_id,
                    "render_failed",
                    serde_json::json!({
                        "project": job.project_id,
                        "projectName": pname,
                        "name": job.output_name,
                        "error": e,
                    }),
                )
                .await;
        }
    };

    let project = match state.db.project_by_id(&job.project_id).await {
        Ok(p) => p,
        Err(_) => {
            fail(state, job, "project gone".into()).await;
            return;
        }
    };
    let spec: RenderSpec = match serde_json::from_str(&job.spec) {
        Ok(s) => s,
        Err(e) => {
            fail(state, job, format!("bad spec: {e}")).await;
            return;
        }
    };
    let stage = state.cfg.data_dir.join("render").join(&job.id);
    let _ = std::fs::remove_dir_all(&stage);
    if let Err(e) = std::fs::create_dir_all(&stage) {
        fail(state, job, e.to_string()).await;
        return;
    }
    if let Err(e) = stage_project(state, &project.dir, &spec, &stage).await {
        let _ = std::fs::remove_dir_all(&stage);
        fail(state, job, e).await;
        return;
    }

    let out_name =
        files::valid_project_name_or_err(&spec.output).unwrap_or_else(|_| "export".into());
    let alive = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(true));
    let (state2, jid, w2, alive2) = (
        state.clone(),
        job.id.clone(),
        worker.to_string(),
        alive.clone(),
    );
    let mut last_report = std::time::Instant::now();
    let (state3, jid2) = (state.clone(), job.id.clone());
    let result = render_with_cli(
        &state.cfg.filmcraft_cli,
        &stage,
        &spec,
        move |p, _status| {
            if last_report.elapsed().as_secs() >= 2 {
                last_report = std::time::Instant::now();
                let (st, id, w, a) = (state2.clone(), jid.clone(), w2.clone(), alive2.clone());
                tokio::spawn(async move {
                    // The update no-ops once the job is requeued or finished
                    // under someone else, telling us to stop rendering.
                    if let Ok(mine) = st
                        .db
                        .job_progress(&id, &w, p, AppState::now() + JOB_LEASE)
                        .await
                    {
                        a.store(mine, std::sync::atomic::Ordering::Relaxed);
                    }
                });
            }
        },
        move || {
            !alive.load(std::sync::atomic::Ordering::Relaxed)
                || state3.cancels.lock().unwrap().contains(&jid2)
        },
    )
    .await;

    match result {
        Ok(produced) => {
            // The claim may have been requeued while rendering; a stale
            // worker must not publish over the new run's output.
            match state.db.job_by_id(&job.id).await {
                Ok(j) if j.status == "running" && j.worker == worker => {}
                _ => {
                    let _ = std::fs::remove_dir_all(&stage);
                    state.cancels.lock().unwrap().remove(&job.id);
                    return;
                }
            }
            let mut uploaded = Vec::new();
            let multi = produced.len() > 1;
            let mut put_err = None;
            for f in produced {
                let ext = f
                    .extension()
                    .map(|e| format!(".{}", e.to_string_lossy()))
                    .unwrap_or_default();
                let base = f
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_default();
                let name = if multi {
                    base
                } else {
                    format!("{out_name}{ext}")
                };
                let put = async {
                    let mut f = tokio::fs::File::open(&f).await.map_err(|e| e.to_string())?;
                    let len = f.metadata().await.map_err(|e| e.to_string())?.len();
                    state
                        .blobs
                        .put(&format!("{}/Exports/{name}", project.dir), len, &mut f)
                        .await
                }
                .await;
                if let Err(e) = put {
                    put_err = Some(e);
                    break;
                }
                uploaded.push(name);
            }
            let _ = std::fs::remove_dir_all(&stage);
            if let Some(e) = put_err {
                fail(state, job, format!("publish: {e}")).await;
                return;
            }
            let _ = state
                .db
                .job_finish(&job.id, worker, "done", "", AppState::now())
                .await;
            let _ = state
                .db
                .lock_release(&job.project_id, "render", &job.id)
                .await;
            state.cancels.lock().unwrap().remove(&job.id);
            if let Ok(u) = state.db.user_by_id(&job.user_id).await {
                state
                    .audit(
                        "project",
                        &u,
                        "render_done",
                        &project.display_name,
                        &uploaded.join(", "),
                        "",
                    )
                    .await;
            }
            state
                .notify(
                    &job.user_id,
                    "render_done",
                    serde_json::json!({
                        "project": project.id,
                        "projectName": project.display_name,
                        "name": uploaded.join(", "),
                    }),
                )
                .await;
        }
        Err(e) => {
            let _ = std::fs::remove_dir_all(&stage);
            fail(state, job, e).await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn sweep_removes_stale_and_keeps_fresh() {
        let root = std::env::temp_dir().join(format!("wfm-sweep-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&root);
        let stale = root.join("tmp/up-old");
        std::fs::create_dir_all(stale.parent().unwrap()).unwrap();
        std::fs::write(&stale, b"x").unwrap();
        let fresh = root.join("render/j1/out");
        std::fs::create_dir_all(&fresh).unwrap();
        std::fs::File::options()
            .write(true)
            .open(&stale)
            .unwrap()
            .set_modified(SystemTime::now() - Duration::from_secs(48 * 3600))
            .unwrap();
        sweep_stale_dirs(&root).await;
        assert!(!stale.exists());
        assert!(fresh.exists());
        let _ = std::fs::remove_dir_all(&root);
    }

    #[test]
    fn stage_names_match_the_app() {
        let mut taken = HashSet::new();
        assert_eq!(stage_name(&mut taken, "a.mp4"), "a.mp4");
        assert_eq!(stage_name(&mut taken, "b/clip.wav"), "b_clip.wav");
        assert_eq!(stage_name(&mut taken, "a.mp4"), "a (2).mp4");
        assert_eq!(stage_name(&mut taken, "noext"), "noext");
        assert_eq!(stage_name(&mut taken, "a.mp4"), "a (3).mp4");
    }

    #[test]
    fn media_list_filters_and_orders() {
        let paths: Vec<String> = vec![
            "Raw/b.mp4".into(),
            "Exports/old.mp4".into(),
            "project.fcproj".into(),
            "Audio/song.mp3".into(),
            "Raw/a.mp4".into(),
            "Raw/notes.txt".into(),
        ];
        let m = stage_media(&paths);
        let got: Vec<(&str, &str)> = m
            .iter()
            .map(|f| (f.name.as_str(), f.path.as_str()))
            .collect();
        assert_eq!(
            got,
            [
                ("Audio_song.mp3", "Audio/song.mp3"),
                ("song.mp3", "Audio/song.mp3"),
                ("Raw_a.mp4", "Raw/a.mp4"),
                ("a.mp4", "Raw/a.mp4"),
                ("Raw_b.mp4", "Raw/b.mp4"),
                ("b.mp4", "Raw/b.mp4")
            ]
        );
    }

    #[test]
    fn media_stage_names_match_client_registration_order() {
        // Nested paths stage under the cleaned whole path the client registered, not the
        // basename, and same-named files get the same ` (n)` the client's free_path minted:
        // each nested file registers its basename alias too, so `x.mp4` at the root collides
        // with `Raw/x.mp4`'s alias, not just with a root file of the same name.
        let paths: Vec<String> = vec!["x.mp4".into(), "Raw/A-Roll/x.mp4".into(), "Audio/x.mp4".into()];
        let m = stage_media(&paths);
        let got: Vec<(&str, &str)> = m
            .iter()
            .map(|f| (f.name.as_str(), f.path.as_str()))
            .collect();
        assert_eq!(
            got,
            [
                ("Audio_x.mp4", "Audio/x.mp4"),
                ("x.mp4", "Audio/x.mp4"),
                ("Raw_A-Roll_x.mp4", "Raw/A-Roll/x.mp4"),
                ("x (2).mp4", "Raw/A-Roll/x.mp4"),
                ("x (3).mp4", "x.mp4")
            ]
        );
    }

    #[test]
    fn export_params_forces_path_wait_and_sequence() {
        let spec = RenderSpec {
            sequence: 7,
            output: "o".into(),
            params: json!({"path": "/evil", "wait": false, "format": "h264"}),
            media: vec![],
        };
        let p = export_params(&spec, "/stage/out.mp4");
        assert_eq!(p["path"], "/stage/out.mp4");
        assert_eq!(p["wait"], true);
        assert_eq!(p["sequence"], 7);
        assert_eq!(p["format"], "h264");
    }
}
