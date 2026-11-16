use std::path::PathBuf;
use std::time::Duration;

use serde::Deserialize;

use crate::config::WorkerCfg;
use crate::model::RenderSpec;
use crate::render::{ffmpeg_args, run_ffmpeg};

/// `wfm --worker URL TOKEN NAME` turns this binary into a render node that
/// polls the main server for jobs, downloads the referenced media, renders
/// with local ffmpeg, and uploads the result to Exports/.
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

async fn run_job(client: &reqwest::Client, cfg: &WorkerCfg, job: &Job) -> Result<(), String> {
    let spec: RenderSpec = serde_json::from_str(&job.spec).map_err(|e| e.to_string())?;
    let dir = cfg.work_dir.join(&job.id);
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let cleanup = |d: &PathBuf| {
        let _ = std::fs::remove_dir_all(d);
    };

    let mut paths: Vec<String> = spec.clips.iter().map(|c| c.path.clone()).collect();
    if let Some(a) = &spec.audio {
        paths.push(a.path.clone());
    }
    for rel in &paths {
        let dest = dir.join(rel);
        if let Some(p) = dest.parent() {
            std::fs::create_dir_all(p).map_err(|e| e.to_string())?;
        }
        let resp = client
            .get(format!(
                "{}/api/worker/jobs/{}/file",
                cfg.server, job.id
            ))
            .bearer_auth(&cfg.token)
            .query(&[("path", rel)])
            .send()
            .await
            .map_err(|e| e.to_string())?;
        if !resp.status().is_success() {
            cleanup(&dir);
            return Err(format!("download {rel}: http {}", resp.status()));
        }
        let bytes = resp.bytes().await.map_err(|e| e.to_string())?;
        std::fs::write(&dest, &bytes).map_err(|e| e.to_string())?;
    }

    let out = dir.join("output.mp4");
    let resolve = |rel: &str| -> Result<PathBuf, crate::files::FsError> {
        let p = dir.join(rel);
        if p.is_file() {
            Ok(p)
        } else {
            Err(crate::files::FsError::NotFound)
        }
    };
    let args = ffmpeg_args(&spec, &resolve, &out).map_err(|e| {
        cleanup(&dir);
        e
    })?;

    let total: f64 = spec
        .clips
        .iter()
        .map(|c| {
            if c.out > c.in_point {
                c.out - c.in_point
            } else {
                c.duration.max(0.0)
            }
        })
        .sum();

    let (client2, server, token, jid) = (
        client.clone(),
        cfg.server.clone(),
        cfg.token.clone(),
        job.id.clone(),
    );
    let mut last = std::time::Instant::now();
    let canceled = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false));
    let canceled2 = canceled.clone();
    let result = run_ffmpeg(
        &cfg.ffmpeg,
        &args,
        total,
        move |p| {
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
    result?;

    if !out.is_file() {
        cleanup(&dir);
        return Err("ffmpeg produced no output".into());
    }
    let name = if job.output_name.to_lowercase().ends_with(".mp4") {
        job.output_name.clone()
    } else {
        format!("{}.mp4", job.output_name)
    };
    let bytes = std::fs::read(&out).map_err(|e| e.to_string())?;
    let resp = client
        .post(format!(
            "{}/api/worker/jobs/{}/complete",
            cfg.server, job.id
        ))
        .bearer_auth(&cfg.token)
        .query(&[("path", name)])
        .body(bytes)
        .send()
        .await
        .map_err(|e| e.to_string())?;
    cleanup(&dir);
    if !resp.status().is_success() {
        return Err(format!("upload: http {}", resp.status()));
    }
    tracing::info!(job = %job.id, "render finished");
    Ok(())
}
