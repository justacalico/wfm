use std::path::PathBuf;

#[derive(Clone)]
pub struct Config {
    pub addr: String,
    pub data_dir: PathBuf,
    pub web_dir: Option<PathBuf>,
    pub filmcraft_dir: Option<PathBuf>,
    pub max_upload: u64,
    pub secure_cookies: bool,
    pub cors_origins: Vec<String>,
    pub render_workers: usize,
    pub filmcraft_cli: String,
    pub ffmpeg: String,
    pub local_renders: bool,
    pub db_url: Option<String>,
    pub session_ttl: i64,
    pub audit_days: i64,
    pub lock_ttl: i64,
    pub worker: Option<WorkerCfg>,
    pub media_kind: String,
    pub media_path: Option<PathBuf>,
    pub s3_endpoint: String,
    pub s3_region: String,
    pub s3_bucket: String,
    pub s3_access: String,
    pub s3_secret: String,
    pub s3_prefix: String,
    pub trusted_proxies: Vec<ipnet::IpNet>,
}

#[derive(Clone)]
pub struct WorkerCfg {
    pub server: String,
    pub token: String,
    pub name: String,
    pub filmcraft_cli: String,
    pub work_dir: PathBuf,
}

fn env(name: &str, def: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| def.to_string())
}

fn env_int(name: &str, def: i64) -> i64 {
    std::env::var(name)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(def)
}

fn env_bool(name: &str, def: bool) -> bool {
    std::env::var(name)
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(def)
}

impl Config {
    pub fn projects_dir(&self) -> PathBuf {
        self.data_dir.join("projects")
    }

    pub fn db_path(&self) -> PathBuf {
        self.data_dir.join("wfm.db")
    }

    pub fn effective_db_url(&self) -> String {
        self.db_url
            .clone()
            .unwrap_or_else(|| format!("sqlite:{}", self.db_path().display()))
    }

    pub fn load() -> Result<Config, String> {
        let args: Vec<String> = std::env::args().collect();
        let mut c = Config {
            addr: env("WFM_ADDR", ":8080"),
            data_dir: PathBuf::from(env("WFM_DATA", "wfm-data")),
            web_dir: std::env::var("WFM_WEB_DIR").ok().map(PathBuf::from),
            filmcraft_dir: std::env::var("WFM_FILMCRAFT_DIR")
                .ok()
                .map(PathBuf::from)
                .or_else(|| {
                    let d = PathBuf::from("filmcraft");
                    d.is_dir().then_some(d)
                }),
            max_upload: env_int("WFM_MAX_UPLOAD_MB", 4096) as u64 * 1024 * 1024,
            secure_cookies: env_bool("WFM_SECURE_COOKIES", false),
            cors_origins: env("WFM_CORS_ORIGINS", "")
                .split(',')
                .map(|s| s.trim().to_string())
                .filter(|s| !s.is_empty())
                .collect(),
            render_workers: env_int("WFM_RENDER_WORKERS", 1).max(0) as usize,
            filmcraft_cli: env("WFM_FILMCRAFT_CLI", "filmcraft-cli"),
            ffmpeg: env("WFM_FFMPEG", "ffmpeg"),
            local_renders: env_bool("WFM_LOCAL_RENDERS", true),
            db_url: std::env::var("WFM_DB").ok().filter(|s| !s.is_empty()),
            session_ttl: env_int("WFM_SESSION_DAYS", 7) * 86400,
            audit_days: env_int("WFM_AUDIT_DAYS", 0),
            lock_ttl: env_int("WFM_LOCK_TTL", 45),
            media_kind: env("WFM_MEDIA", "local"),
            media_path: std::env::var("WFM_MEDIA_PATH").ok().map(PathBuf::from),
            s3_endpoint: env("WFM_S3_ENDPOINT", "http://localhost:9000"),
            s3_region: env("WFM_S3_REGION", "us-east-1"),
            s3_bucket: env("WFM_S3_BUCKET", "wfm"),
            s3_access: env("WFM_S3_ACCESS_KEY", "rustfsadmin"),
            s3_secret: env("WFM_S3_SECRET_KEY", "rustfsadminsecret"),
            s3_prefix: env("WFM_S3_PREFIX", ""),
            trusted_proxies: crate::auth::parse_nets(&env("WFM_TRUSTED_PROXIES", ""))
                .unwrap_or_default(),
            worker: None,
        };

        let mut i = 1;
        while i < args.len() {
            let next = |i: &mut usize| -> Result<String, String> {
                *i += 1;
                args.get(*i)
                    .cloned()
                    .ok_or_else(|| format!("missing value for {}", args[*i - 1]))
            };
            match args[i].as_str() {
                "--addr" => c.addr = next(&mut i)?,
                "--data" => c.data_dir = PathBuf::from(next(&mut i)?),
                "--web-dir" => c.web_dir = Some(PathBuf::from(next(&mut i)?)),
                "--filmcraft-dir" => c.filmcraft_dir = Some(PathBuf::from(next(&mut i)?)),
                "--max-upload-mb" => {
                    c.max_upload = next(&mut i)?.parse::<u64>().map_err(|e| e.to_string())? * 1024 * 1024
                }
                "--secure-cookies" => c.secure_cookies = true,
                "--cors-origins" => {
                    c.cors_origins = next(&mut i)?
                        .split(',')
                        .map(|s| s.trim().to_string())
                        .filter(|s| !s.is_empty())
                        .collect()
                }
                "--render-workers" => {
                    c.render_workers = next(&mut i)?.parse::<usize>().map_err(|e| e.to_string())?
                }
                "--filmcraft-cli" => c.filmcraft_cli = next(&mut i)?,
                "--ffmpeg" => c.ffmpeg = next(&mut i)?,
                "--no-local-renders" => c.local_renders = false,
                "--db" => c.db_url = Some(next(&mut i)?),
                "--media" => c.media_kind = next(&mut i)?,
                "--media-path" => c.media_path = Some(PathBuf::from(next(&mut i)?)),
                "--s3-endpoint" => c.s3_endpoint = next(&mut i)?,
                "--s3-region" => c.s3_region = next(&mut i)?,
                "--s3-bucket" => c.s3_bucket = next(&mut i)?,
                "--s3-access-key" => c.s3_access = next(&mut i)?,
                "--s3-secret-key" => c.s3_secret = next(&mut i)?,
                "--s3-prefix" => c.s3_prefix = next(&mut i)?,
                "--session-days" => {
                    c.session_ttl = next(&mut i)?.parse::<i64>().map_err(|e| e.to_string())? * 86400
                }
                "--audit-days" => {
                    c.audit_days = next(&mut i)?.parse::<i64>().map_err(|e| e.to_string())?
                }
                "--lock-ttl" => c.lock_ttl = next(&mut i)?.parse::<i64>().map_err(|e| e.to_string())?,
                "--trusted-proxies" => {
                    c.trusted_proxies = crate::auth::parse_nets(&next(&mut i)?)?
                }
                "--worker" => {
                    let server = next(&mut i)?;
                    // Trailing positionals stop at the next flag: with
                    // WFM_WORKER_TOKEN set they are [NAME], otherwise
                    // [TOKEN] [NAME].
                    let mut extra: Vec<String> = Vec::new();
                    while let Some(a) = args.get(i + 1) {
                        if a.starts_with("--") {
                            break;
                        }
                        i += 1;
                        extra.push(a.clone());
                    }
                    let env_token = std::env::var("WFM_WORKER_TOKEN")
                        .ok()
                        .filter(|t| !t.is_empty());
                    let (token, name) = match (env_token, extra.as_slice()) {
                        (Some(t), []) => (t, "node".into()),
                        (Some(t), [n]) => (t, n.clone()),
                        (Some(_), _) => {
                            return Err("--worker: too many arguments".into());
                        }
                        (None, []) => {
                            return Err(
                                "--worker: missing token (arg or WFM_WORKER_TOKEN)".into()
                            );
                        }
                        (None, [t]) | (None, [t, _]) => {
                            eprintln!(
                                "wfm: warning: worker token on argv is visible in ps; \
                                 prefer WFM_WORKER_TOKEN"
                            );
                            (
                                t.clone(),
                                extra.get(1).cloned().unwrap_or_else(|| "node".into()),
                            )
                        }
                        (None, _) => {
                            return Err("--worker: too many arguments".into());
                        }
                    };
                    c.worker = Some(WorkerCfg {
                        server,
                        token,
                        name,
                        filmcraft_cli: c.filmcraft_cli.clone(),
                        work_dir: c.data_dir.join("worker"),
                    });
                }
                "--help" | "-h" => {
                    println!(
                        "wfm - Web Film Manager\n\
                         Usage: wfm [options]\n\
                         --addr ADDR            listen address (default :8080)\n\
                         --data DIR             data directory (default wfm-data)\n\
                         --web-dir DIR          serve app from DIR instead of embedded\n\
                         --filmcraft-dir DIR    serve filmcraft from DIR instead of embedded\n\
                         --max-upload-mb N      max upload size in MiB (default 4096)\n\
                         --secure-cookies       mark cookies Secure (use behind HTTPS)\n\
                         --cors-origins LIST    extra allowed CORS origins\n\
                         --render-workers N     local render workers (default 1)\n\
                         --filmcraft-cli PATH   filmcraft-cli binary path\n\
                         --no-local-renders     disable local render processing\n\
                         --db URL               database url: sqlite (default) or postgres://\n\
                         --trusted-proxies LIST honor X-Forwarded-For from these proxies\n\
                         --worker URL [TOKEN] [NAME]  run as a remote render node\n\
                                                    (token via WFM_WORKER_TOKEN preferred)\n\
                         Env: WFM_ADDR WFM_DATA WFM_DB WFM_WEB_DIR WFM_FILMCRAFT_DIR \
                         WFM_MAX_UPLOAD_MB WFM_SECURE_COOKIES WFM_CORS_ORIGINS \
                         WFM_RENDER_WORKERS WFM_FILMCRAFT_CLI WFM_LOCAL_RENDERS \
                         WFM_SESSION_DAYS WFM_LOCK_TTL WFM_WORKER_TOKEN \
                         WFM_TRUSTED_PROXIES"
                    );
                    std::process::exit(0);
                }
                other => return Err(format!("unknown flag {other}")),
            }
            i += 1;
        }

        c.data_dir = c
            .data_dir
            .canonicalize()
            .unwrap_or_else(|_| c.data_dir.clone());
        std::fs::create_dir_all(c.projects_dir()).map_err(|e| e.to_string())?;
        Ok(c)
    }
}
