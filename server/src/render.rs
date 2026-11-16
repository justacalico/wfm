use std::path::{Path, PathBuf};
use std::sync::Arc;
use std::time::Duration;

use futures::StreamExt;
use tokio::io::AsyncBufReadExt;
use tokio::io::AsyncWriteExt;
use tokio::process::Command;

use crate::auth::AppState;
use crate::files;
use crate::model::{RenderJob, RenderSpec};

const JOB_LEASE: i64 = 90;

/// Build the ffmpeg argument list for a render spec. `resolve` maps a
/// project-relative path to a real filesystem path.
pub fn ffmpeg_args(
    spec: &RenderSpec,
    resolve: &dyn Fn(&str) -> Result<PathBuf, files::FsError>,
    output: &Path,
    ffprobe: &str,
) -> Result<Vec<String>, String> {
    if spec.clips.is_empty() {
        return Err("no clips".into());
    }
    if spec.clips.len() > 200 {
        return Err("too many clips".into());
    }
    let mut args: Vec<String> = vec!["-y".into(), "-hide_banner".into()];
    let mut total = 0.0f64;
    for c in &spec.clips {
        let p = resolve(&c.path).map_err(|_| format!("bad path {}", c.path))?;
        let dur = if c.out > c.in_point {
            c.out - c.in_point
        } else if c.duration > 0.0 {
            c.duration
        } else {
            probe_duration(ffprobe, &p).unwrap_or(0.0)
        };
        if dur <= 0.0 {
            return Err(format!("clip {} has no length", c.path));
        }
        total += dur;
        if c.in_point > 0.0 {
            args.push("-ss".into());
            args.push(fmt_ts(c.in_point));
        }
        args.push("-t".into());
        args.push(fmt_ts(dur));
        args.push("-i".into());
        args.push(p.to_string_lossy().to_string());
    }
    if total > 6.0 * 3600.0 {
        return Err("render too long".into());
    }
    let audio_idx = spec.clips.len();
    if let Some(a) = &spec.audio {
        let p = resolve(&a.path).map_err(|_| format!("bad path {}", a.path))?;
        args.push("-i".into());
        args.push(p.to_string_lossy().to_string());
    }

    let mut fc = String::new();
    for (i, c) in spec.clips.iter().enumerate() {
        fc.push_str(&format!(
            "[{i}:v]scale={w}:{h}:force_original_aspect_ratio=decrease,pad={w}:{h}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps={fps},setpts=PTS-STARTPTS[v{i}];",
            w = spec.width, h = spec.height, fps = spec.fps
        ));
        fc.push_str(&format!(
            "[{i}:a]aresample=44100,aformat=channel_layouts=stereo,asetpts=PTS-STARTPTS[a{i}];"
        ));
        let _ = c;
    }
    let vins: String = (0..spec.clips.len())
        .map(|i| format!("[v{i}][a{i}]"))
        .collect();
    fc.push_str(&format!(
        "{vins}concat=n={}:v=1:a=1[vcat][acat];",
        spec.clips.len()
    ));
    let mut last_v = "vcat".to_string();
    let mut last_a = "acat".to_string();

    for (i, t) in spec.titles.iter().enumerate() {
        let escaped = t
            .text
            .replace('\\', "\\\\")
            .replace(':', "\\:")
            .replace('\'', "\\'")
            .replace('%', "\\%");
        let out = format!("vt{i}");
        fc.push_str(&format!(
            "[{last_v}]drawtext=text='{escaped}':fontsize={fs}:fontcolor=white:borderw=2:bordercolor=black:x=(w-text_w)/2:y=h-text_h-{m}:enable='between(t,{s},{e})'[{out}];",
            fs = (spec.height / 18).max(24),
            m = (spec.height / 12),
            s = t.start,
            e = t.end.max(t.start + 0.1)
        ));
        last_v = out;
    }

    if spec.audio.is_some() {
        fc.push_str(&format!(
            "[{audio_idx}:a]volume={vol},aresample=44100,aformat=channel_layouts=stereo,atrim=0:{total},asetpts=PTS-STARTPTS[bg];",
            vol = spec.audio.as_ref().unwrap().volume.clamp(0.0, 4.0)
        ));
        fc.push_str(&format!(
            "[acat][bg]amix=inputs=2:duration=first:dropout_transition=0[aout];"
        ));
        last_a = "aout".into();
    }
    let fc = fc.trim_end_matches(';').to_string();

    args.push("-filter_complex".into());
    args.push(fc);
    args.push("-map".into());
    args.push(format!("[{last_v}]"));
    args.push("-map".into());
    args.push(format!("[{last_a}]"));
    args.extend([
        "-c:v".into(),
        "libx264".into(),
        "-preset".into(),
        "veryfast".into(),
        "-crf".into(),
        "21".into(),
        "-pix_fmt".into(),
        "yuv420p".into(),
        "-c:a".into(),
        "aac".into(),
        "-b:a".into(),
        "160k".into(),
        "-movflags".into(),
        "+faststart".into(),
        "-progress".into(),
        "pipe:1".into(),
        "-nostats".into(),
        output.to_string_lossy().to_string(),
    ]);
    Ok(args)
}

fn fmt_ts(t: f64) -> String {
    format!("{:.3}", t.max(0.0))
}

/// Media duration in seconds via ffprobe; None when the file can't be probed.
pub fn probe_duration(ffprobe: &str, path: &Path) -> Option<f64> {
    let out = std::process::Command::new(ffprobe)
        .args([
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
        ])
        .arg(path)
        .output()
        .ok()?;
    if !out.status.success() {
        return None;
    }
    String::from_utf8_lossy(&out.stdout).trim().parse().ok()
}

pub fn spec_duration(
    spec: &RenderSpec,
    resolve: &dyn Fn(&str) -> Result<PathBuf, files::FsError>,
    ffprobe: &str,
) -> f64 {
    spec.clips
        .iter()
        .map(|c| {
            if c.out > c.in_point {
                c.out - c.in_point
            } else if c.duration > 0.0 {
                c.duration
            } else {
                resolve(&c.path)
                    .ok()
                    .and_then(|p| probe_duration(ffprobe, &p))
                    .unwrap_or(0.0)
            }
        })
        .sum()
}

/// Run ffmpeg, reporting progress via `on_progress` (fraction of total) and
/// aborting early when `stop` returns true.
pub async fn run_ffmpeg(
    ffmpeg: &str,
    args: &[String],
    total_secs: f64,
    mut on_progress: impl FnMut(f64),
    stop: impl Fn() -> bool + Send,
) -> Result<(), String> {
    use std::sync::atomic::{AtomicU64, Ordering};
    use std::sync::Arc as SArc;

    let mut child = Command::new(ffmpeg)
        .args(args)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| format!("spawn ffmpeg: {e}"))?;

    let out_us = SArc::new(AtomicU64::new(0));
    let stdout = child.stdout.take().map(|s| {
        let out_us = out_us.clone();
        tokio::spawn(async move {
            let mut lines = tokio::io::BufReader::new(s).lines();
            while let Ok(Some(l)) = lines.next_line().await {
                if let Some(us) = l.strip_prefix("out_time_us=").and_then(|v| v.parse::<u64>().ok()) {
                    out_us.store(us, Ordering::Relaxed);
                }
            }
        })
    });
    let stderr = child.stderr.take().map(|s| {
        tokio::spawn(async move {
            let mut lines = tokio::io::BufReader::new(s).lines();
            let mut tail = String::new();
            while let Ok(Some(l)) = lines.next_line().await {
                tail = l;
            }
            tail
        })
    });

    let status = loop {
        if stop() {
            let _ = child.kill().await;
            return Err("canceled".into());
        }
        match child.try_wait() {
            Ok(Some(st)) => break st,
            Ok(None) => {
                if total_secs > 0.0 {
                    let secs = out_us.load(Ordering::Relaxed) as f64 / 1_000_000.0;
                    on_progress((secs / total_secs).clamp(0.0, 0.999));
                }
                tokio::time::sleep(Duration::from_millis(150)).await;
            }
            Err(e) => return Err(e.to_string()),
        }
    };
    if let Some(h) = stdout {
        let _ = h.await;
    }
    on_progress(1.0);
    let tail = match stderr {
        Some(h) => h.await.unwrap_or_default(),
        None => String::new(),
    };
    if !status.success() {
        return Err(if tail.is_empty() {
            format!("ffmpeg exited {status}")
        } else {
            tail
        });
    }
    Ok(())
}

/// Periodic maintenance: drop expired locks/sessions, requeue stale renders.
pub fn spawn_janitor(state: Arc<AppState>) {
    tokio::spawn(async move {
        let mut tick = tokio::time::interval(Duration::from_secs(20));
        loop {
            tick.tick().await;
            let now = AppState::now();
            let _ = state.db.clean_locks(now).await;
            let _ = state.db.clean_sessions(now).await;
            let _ = state.db.job_requeue_stale(now).await;
            let _ = state.db.job_fail_stale(now).await;
        }
    });
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
        run_job(&state, &job).await;
    }
}

async fn run_job(state: &Arc<AppState>, job: &RenderJob) {
    let fail = |state: &Arc<AppState>, job: &RenderJob, e: String| {
        let state = state.clone();
        let job = job.clone();
        async move {
            let _ = state
                .db
                .job_finish(&job.id, "failed", &e, AppState::now())
                .await;
            let _ = state
                .db
                .lock_release(&job.project_id, "render", &job.id)
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
    let out_name = files::valid_project_name_or_err(&spec.output)
        .unwrap_or_else(|_| "export.mp4".into());
    let out_name = if out_name.to_lowercase().ends_with(".mp4") {
        out_name
    } else {
        format!("{out_name}.mp4")
    };
    let stage = state.cfg.data_dir.join("render").join(&job.id);
    let _ = std::fs::remove_dir_all(&stage);
    let media_root = stage.join("media");
    let mut inputs: Vec<String> = spec.clips.iter().map(|c| c.path.clone()).collect();
    if let Some(a) = &spec.audio {
        inputs.push(a.path.clone());
    }
    let mut staged = true;
    for rel in &inputs {
        let key = match files::clean_rel_key(rel) {
            Ok(k) => k,
            Err(_) => {
                fail(state, job, format!("bad path {rel}")).await;
                return;
            }
        };
        let dest = media_root.join(&key);
        if let Some(par) = dest.parent() {
            let _ = std::fs::create_dir_all(par);
        }
        if let Err(e) = blob_download(&state.blobs, &format!("{}/{key}", project.dir), &dest).await {
            let _ = std::fs::remove_dir_all(&stage);
            fail(state, job, format!("download {rel}: {e}")).await;
            staged = false;
        }
        if !staged {
            return;
        }
    }
    let tmp_out = stage.join("output.mp4");
    let resolve = |rel: &str| files::resolve(&media_root, rel);
    let args = match ffmpeg_args(&spec, &resolve, &tmp_out, &state.cfg.ffprobe) {
        Ok(a) => a,
        Err(e) => {
            let _ = std::fs::remove_dir_all(&stage);
            fail(state, job, e).await;
            return;
        }
    };

    let total = spec_duration(&spec, &resolve, &state.cfg.ffprobe);
    let (state2, jid) = (state.clone(), job.id.clone());
    let mut last_report = std::time::Instant::now();
    let (state3, jid2) = (state.clone(), job.id.clone());
    let result = run_ffmpeg(
        &state.cfg.ffmpeg,
        &args,
        total,
        move |p| {
            if last_report.elapsed().as_secs() >= 2 {
                last_report = std::time::Instant::now();
                let (st, id) = (state2.clone(), jid.clone());
                tokio::spawn(async move {
                    let _ = st
                        .db
                        .job_progress(&id, p, AppState::now() + JOB_LEASE)
                        .await;
                });
            }
        },
        move || state3.cancels.lock().unwrap().contains(&jid2),
    )
    .await;

    match result {
        Ok(()) => {
            let put = async {
                let mut f = tokio::fs::File::open(&tmp_out)
                    .await
                    .map_err(|e| e.to_string())?;
                let len = f.metadata().await.map_err(|e| e.to_string())?.len();
                state
                    .blobs
                    .put(&format!("{}/Exports/{out_name}", project.dir), len, &mut f)
                    .await
            }
            .await;
            let _ = std::fs::remove_dir_all(&stage);
            if let Err(e) = put {
                fail(state, job, format!("publish: {e}")).await;
                return;
            }
            let _ = state
                .db
                .job_finish(&job.id, "done", "", AppState::now())
                .await;
            let _ = state
                .db
                .lock_release(&job.project_id, "render", &job.id)
                .await;
            if let Ok(u) = state.db.user_by_id(&job.user_id).await {
                state
                    .audit(
                        "project",
                        &u,
                        "render_done",
                        &project.display_name,
                        &out_name,
                        "",
                    )
                    .await;
            }
        }
        Err(e) => {
            let _ = std::fs::remove_dir_all(&stage);
            fail(state, job, e).await;
        }
    }
}


async fn blob_download(
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{RenderAudio, RenderClip, RenderSpec};

    fn spec() -> RenderSpec {
        RenderSpec {
            width: 1280,
            height: 720,
            fps: 30,
            clips: vec![
                RenderClip { path: "Raw/a.mp4".into(), in_point: 1.0, out: 4.0, duration: 0.0 },
                RenderClip { path: "Raw/b.mp4".into(), in_point: 0.0, out: 0.0, duration: 2.5 },
            ],
            audio: Some(RenderAudio { path: "Audio/Music/m.mp3".into(), volume: 0.5 }),
            titles: vec![],
            output: "out".into(),
        }
    }

    fn resolve(_: &str) -> Result<PathBuf, files::FsError> {
        Ok(PathBuf::from("/tmp/fake"))
    }

    #[test]
    fn args_have_inputs_and_maps() {
        let args = ffmpeg_args(&spec(), &resolve, Path::new("/tmp/out.mp4"), "ffprobe").unwrap();
        let s = args.join(" ");
        assert!(s.contains("-ss 1.000 -t 3.000 -i /tmp/fake"));
        assert!(s.contains("concat=n=2:v=1:a=1"));
        assert!(s.contains("volume=0.5"));
        assert!(s.contains("-map [vcat]"));
        assert!(s.contains("-map [aout]"));
        assert!(s.contains("libx264"));
    }

    #[test]
    fn rejects_empty_and_zero_clips() {
        let mut s = spec();
        s.clips.clear();
        assert!(ffmpeg_args(&s, &resolve, Path::new("/tmp/o.mp4"), "ffprobe").is_err());
        let mut s = spec();
        s.clips[0].in_point = 0.0;
        s.clips[0].out = 0.0;
        s.clips[0].duration = 0.0;
        s.audio = None;
        let args = ffmpeg_args(&s, &resolve, Path::new("/tmp/o.mp4"), "ffprobe");
        assert!(args.is_err());
    }

    #[test]
    fn title_text_is_escaped() {
        let mut s = spec();
        s.titles.push(crate::model::RenderTitle {
            text: "it's: 100%".into(),
            start: 0.0,
            end: 1.0,
        });
        let args = ffmpeg_args(&s, &resolve, Path::new("/tmp/o.mp4"), "ffprobe").unwrap();
        let fc_i = args.iter().position(|a| a == "-filter_complex").unwrap();
        let fc = &args[fc_i + 1];
        assert!(fc.contains("it\\'s\\: 100\\%"));
    }
}
