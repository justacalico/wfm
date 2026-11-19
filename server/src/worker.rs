use std::time::Duration;

use futures::StreamExt;
use serde::Deserialize;
use tokio::io::AsyncWriteExt;

use crate::config::WorkerCfg;
use crate::files;
use crate::model::RenderSpec;
use crate::render::render_with_cli;

/// `wfm --worker URL TOKEN NAME` turns this binary into a render node that
/// polls the main server for jobs, stages the project's FilmCraft file and
/// media, renders with filmcraft-cli, and uploads the result to Exports/.
pub async fn run(cfg: WorkerCfg) -> Result<(), String> {
    std::fs::create_dir_all(&cfg.work_dir).map_err(|e| e.to_string())?;
    let client = reqwest::Client::builder()
        .timeout(Duration::from_secs(3600))
        .build()
        .map_err(|e| e.to_string())?;
    tracing::info!(server = %cfg.server, name = %cfg.name, "render node started");
    loop {
        match poll_once(&client, &cfg).await {
            Ok(true) => {}
            Ok(false) => tokio::time::sleep(Duration::from_secs(5)).await,
            Err(e) => {
                tracing::warn!("poll failed: {e}");
                tokio::time::sleep(Duration::from_secs(10)).await;
            }
        }
    }
}

#[derive(Deserialize)]
struct Job {
    id: String,
    spec: String,
    #[serde(rename = "outputName")]
    output_name: String,
}

#[derive(Deserialize)]
struct PollResp {
    job: Option<Job>,
}

async fn poll_once(client: &reqwest::Client, cfg: &WorkerCfg) -> Result<bool, String> {
    let resp: PollResp = client
        .post(format!("{}/api/worker/poll", cfg.server))
        .bearer_auth(&cfg.token)
        .send()
        .await
        .map_err(|e| e.to_string())?
        .json()
        .await
        .map_err(|e| e.to_string())?;
    let Some(job) = resp.job else {
        return Ok(false);
    };
    tracing::info!(job = %job.id, "claimed render job");
    if let Err(e) = run_job(client, cfg, &job).await {
        tracing::warn!(job = %job.id, "render failed: {e}");
        let _ = client
            .post(format!("{}/api/worker/jobs/{}/fail", cfg.server, job.id))
            .bearer_auth(&cfg.token)
            .json(&serde_json::json!({"error": e.chars().take(500).collect::<String>()}))
            .send()
            .await;
    }
    Ok(true)
}

async fn pull_file(
    client: &reqwest::Client,
    cfg: &WorkerCfg,
    job: &Job,
    rel: &str,
    dest: &std::path::Path,
) -> Result<(), String> {
    if let Some(p) = dest.parent() {
        std::fs::create_dir_all(p).map_err(|e| e.to_string())?;
    }
    let resp = client
        .get(format!("{}/api/worker/jobs/{}/file", cfg.server, job.id))
        .bearer_auth(&cfg.token)
        .query(&[("path", rel)])
        .send()
        .await
        .map_err(|e| e.to_string())?;
    if !resp.status().is_success() {
        return Err(format!("download {rel}: http {}", resp.status()));
    }
    // Stream to disk: media files can be several GB.
    let mut f = tokio::fs::File::create(dest)
        .await
        .map_err(|e| e.to_string())?;
    let mut body = resp.bytes_stream();
    while let Some(chunk) = body.next().await {
        let chunk = chunk.map_err(|e| e.to_string())?;
        f.write_all(&chunk).await.map_err(|e| e.to_string())?;
    }
    f.flush().await.map_err(|e| e.to_string())
}

async fn run_job(client: &reqwest::Client, cfg: &WorkerCfg, job: &Job) -> Result<(), String> {
    let spec: RenderSpec = serde_json::from_str(&job.spec).map_err(|e| e.to_string())?;
    let dir = cfg.work_dir.join(&job.id);
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(dir.join("files")).map_err(|e| e.to_string())?;
    let cleanup = |d: &std::path::Path| {
        let _ = std::fs::remove_dir_all(d);
    };

    pull_file(
        client,
        cfg,
        job,
        files::PROJECT_FILE,
        &dir.join(files::PROJECT_FILE),
    )
    .await?;
    for m in &spec.media {
        if let Err(e) = pull_file(client, cfg, job, &m.path, &dir.join("files").join(&m.name)).await
        {
            cleanup(&dir);
            return Err(e);
        }
    }

    let (client2, server, token, jid) = (
        client.clone(),
        cfg.server.clone(),
        cfg.token.clone(),
        job.id.clone(),
    );
    let mut last = std::time::Instant::now();
    let canceled = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let canceled2 = canceled.clone();
    let produced = render_with_cli(
        &cfg.filmcraft_cli,
        &dir,
        &spec,
        move |p, _status| {
            if last.elapsed().as_secs() < 2 {
                return;
            }
            last = std::time::Instant::now();
            let (c, s, t, j, flag) = (
                client2.clone(),
                server.clone(),
                token.clone(),
                jid.clone(),
                canceled2.clone(),
            );
            tokio::spawn(async move {
                if let Ok(r) = c
                    .post(format!("{s}/api/worker/jobs/{j}/progress"))
                    .bearer_auth(&t)
                    .json(&serde_json::json!({"progress": p}))
                    .send()
                    .await
                {
                    if let Ok(v) = r.json::<serde_json::Value>().await {
                        if v["canceled"].as_bool().unwrap_or(false) {
                            flag.store(true, std::sync::atomic::Ordering::Relaxed);
                        }
                    }
                }
            });
        },
        move || canceled.load(std::sync::atomic::Ordering::Relaxed),
    )
    .await;
    let produced = match produced {
        Ok(p) => p,
        Err(e) => {
            cleanup(&dir);
            return Err(e);
        }
    };

    let out_name =
        files::valid_project_name_or_err(&job.output_name).unwrap_or_else(|_| "export".into());
    let multi = produced.len() > 1;
    let last_idx = produced.len() - 1;
    for (i, f) in produced.iter().enumerate() {
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
        // Stream the export from disk instead of buffering it in memory.
        let len = tokio::fs::metadata(f)
            .await
            .map_err(|e| e.to_string())?
            .len();
        let file = tokio::fs::File::open(f).await.map_err(|e| e.to_string())?;
        let resp = client
            .post(format!(
                "{}/api/worker/jobs/{}/complete",
                cfg.server, job.id
            ))
            .bearer_auth(&cfg.token)
            .query(&[("path", name), ("done", (i == last_idx).to_string())])
            .header(reqwest::header::CONTENT_LENGTH, len)
            .body(reqwest::Body::from(file))
            .send()
            .await
            .map_err(|e| e.to_string())?;
        if !resp.status().is_success() {
            cleanup(&dir);
            return Err(format!("upload: http {}", resp.status()));
        }
    }
    cleanup(&dir);
    tracing::info!(job = %job.id, "render finished");
    Ok(())
}
