use std::path::PathBuf;
use std::pin::Pin;
use std::sync::Arc;

use async_trait::async_trait;
use futures::{Stream, StreamExt};
use tokio::io::AsyncRead;

use crate::files::{self};

pub type ByteStream = Pin<Box<dyn Stream<Item = Result<axum::body::Bytes, std::io::Error>> + Send>>;

#[derive(Debug)]
pub struct BlobObject {
    pub key: String,
    pub size: u64,
    pub modified: i64,
}

/// Media/object storage contract. Default deployment speaks S3 to RustFS;
/// any S3-compatible service works, and a local filesystem backend exists
/// for development and tiny installs.
#[async_trait]
pub trait Blobs: Send + Sync {
    async fn put(
        &self,
        key: &str,
        len: u64,
        reader: &mut (dyn AsyncRead + Send + Unpin),
    ) -> Result<(), String>;
    async fn get(&self, key: &str) -> Result<(u64, ByteStream), String>;
    async fn get_range(
        &self,
        key: &str,
        start: u64,
        end: u64,
    ) -> Result<(u64, u64, ByteStream), String>;
    async fn head(&self, key: &str) -> Result<u64, String>;
    async fn list(&self, prefix: &str) -> Result<(Vec<String>, Vec<BlobObject>), String>;
    async fn delete(&self, key: &str) -> Result<(), String>;
    async fn delete_prefix(&self, prefix: &str) -> Result<(), String>;
    async fn rename(&self, from: &str, to: &str) -> Result<(), String>;
    async fn mkdir(&self, key_prefix: &str) -> Result<(), String>;
}

// ---------------- local filesystem backend ----------------

pub struct LocalBlobs {
    root: PathBuf,
}

impl LocalBlobs {
    pub fn new(root: PathBuf) -> Self {
        LocalBlobs { root }
    }

    fn path(&self, key: &str) -> Result<PathBuf, String> {
        let rel = files::clean_rel(key).map_err(|e| format!("{e:?}"))?;
        Ok(self.root.join(rel))
    }
}

async fn file_stream(mut f: tokio::fs::File, start: u64, len: u64) -> Result<ByteStream, String> {
    use tokio::io::{AsyncReadExt, AsyncSeekExt};
    if start > 0 {
        f.seek(std::io::SeekFrom::Start(start))
            .await
            .map_err(|e| e.to_string())?;
    }
    let limited = f.take(len);
    let stream = tokio_util::io::ReaderStream::new(limited);
    Ok(Box::pin(stream))
}

#[async_trait]
impl Blobs for LocalBlobs {
    async fn put(
        &self,
        key: &str,
        _len: u64,
        reader: &mut (dyn AsyncRead + Send + Unpin),
    ) -> Result<(), String> {
        let p = self.path(key)?;
        if let Some(parent) = p.parent() {
            tokio::fs::create_dir_all(parent)
                .await
                .map_err(|e| e.to_string())?;
        }
        let tmp = p.with_extension(format!("wfm-up-{}", &crate::model::new_id()[..8]));
        let mut f = tokio::fs::File::create(&tmp)
            .await
            .map_err(|e| e.to_string())?;
        let res = tokio::io::copy(reader, &mut f).await;
        drop(f);
        if let Err(e) = res {
            let _ = tokio::fs::remove_file(&tmp).await;
            return Err(e.to_string());
        }
        tokio::fs::rename(&tmp, &p).await.map_err(|e| e.to_string())
    }

    async fn get(&self, key: &str) -> Result<(u64, ByteStream), String> {
        let p = self.path(key)?;
        let meta = tokio::fs::metadata(&p)
            .await
            .map_err(|_| "not found".to_string())?;
        let f = tokio::fs::File::open(&p).await.map_err(|e| e.to_string())?;
        let len = meta.len();
        Ok((len, file_stream(f, 0, len).await?))
    }

    async fn get_range(
        &self,
        key: &str,
        start: u64,
        end: u64,
    ) -> Result<(u64, u64, ByteStream), String> {
        let p = self.path(key)?;
        let meta = tokio::fs::metadata(&p)
            .await
            .map_err(|_| "not found".to_string())?;
        let size = meta.len();
        let end = end.min(size.saturating_sub(1));
        if start > end || size == 0 {
            return Err("range".into());
        }
        let f = tokio::fs::File::open(&p).await.map_err(|e| e.to_string())?;
        Ok((size, end, file_stream(f, start, end - start + 1).await?))
    }

    async fn head(&self, key: &str) -> Result<u64, String> {
        let p = self.path(key)?;
        tokio::fs::metadata(&p)
            .await
            .map(|m| m.len())
            .map_err(|_| "not found".to_string())
    }

    async fn list(&self, prefix: &str) -> Result<(Vec<String>, Vec<BlobObject>), String> {
        let dir = if prefix.is_empty() || prefix == "/" {
            self.root.clone()
        } else {
            self.path(prefix)?
        };
        let mut folders = Vec::new();
        let mut objects = Vec::new();
        if tokio::fs::metadata(&dir)
            .await
            .map(|m| m.is_dir())
            .unwrap_or(false)
        {
            let mut entries = tokio::fs::read_dir(&dir).await.map_err(|e| e.to_string())?;
            while let Some(e) = entries.next_entry().await.map_err(|e| e.to_string())? {
                let name = e.file_name().to_string_lossy().to_string();
                if name.starts_with('.') {
                    continue;
                }
                let meta = e.metadata().await.map_err(|e| e.to_string())?;
                if meta.is_symlink() {
                    continue;
                }
                let rel = format!("{}/{}", prefix.trim_matches('/'), name)
                    .trim_start_matches('/')
                    .to_string();
                if meta.is_dir() {
                    folders.push(rel);
                } else {
                    objects.push(BlobObject {
                        key: rel,
                        size: meta.len(),
                        modified: meta
                            .modified()
                            .ok()
                            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                            .map(|d| d.as_secs() as i64)
                            .unwrap_or(0),
                    });
                }
            }
        }
        Ok((folders, objects))
    }

    async fn delete(&self, key: &str) -> Result<(), String> {
        let p = self.path(key)?;
        match tokio::fs::metadata(&p).await {
            Ok(m) if m.is_dir() => tokio::fs::remove_dir_all(&p)
                .await
                .map_err(|e| e.to_string()),
            Ok(_) => tokio::fs::remove_file(&p).await.map_err(|e| e.to_string()),
            Err(_) => Err("not found".into()),
        }
    }

    async fn delete_prefix(&self, prefix: &str) -> Result<(), String> {
        let p = self.path(prefix)?;
        if tokio::fs::metadata(&p)
            .await
            .map(|m| m.is_dir())
            .unwrap_or(false)
        {
            tokio::fs::remove_dir_all(&p)
                .await
                .map_err(|e| e.to_string())?;
        }
        Ok(())
    }

    async fn rename(&self, from: &str, to: &str) -> Result<(), String> {
        let src = self.path(from)?;
        let dst = self.path(to)?;
        if tokio::fs::metadata(&src).await.is_err() {
            return Err("not found".into());
        }
        if tokio::fs::metadata(&dst).await.is_ok() {
            return Err("exists".into());
        }
        if let Some(p) = dst.parent() {
            tokio::fs::create_dir_all(p)
                .await
                .map_err(|e| e.to_string())?;
        }
        tokio::fs::rename(&src, &dst)
            .await
            .map_err(|e| e.to_string())
    }

    async fn mkdir(&self, key_prefix: &str) -> Result<(), String> {
        let p = self.path(key_prefix)?;
        tokio::fs::create_dir_all(p)
            .await
            .map_err(|e| e.to_string())
    }
}

// ---------------- S3 backend ----------------

pub struct S3Blobs {
    bucket: s3::Bucket,
    prefix: String,
}

impl S3Blobs {
    pub async fn connect(
        endpoint: &str,
        region: &str,
        bucket_name: &str,
        access: &str,
        secret: &str,
        prefix: &str,
    ) -> Result<Self, String> {
        let region = s3::Region::Custom {
            region: region.to_string(),
            endpoint: endpoint.to_string(),
        };
        let creds = s3::creds::Credentials::new(Some(access), Some(secret), None, None, None)
            .map_err(|e| format!("s3 credentials: {e}"))?;
        let bucket = s3::Bucket::new(bucket_name, region, creds)
            .map_err(|e| format!("s3 bucket: {e}"))?
            .with_path_style();
        let b = S3Blobs {
            bucket: *bucket,
            prefix: prefix.trim_matches('/').to_string(),
        };
        b.ensure_bucket().await?;
        Ok(b)
    }

    async fn ensure_bucket(&self) -> Result<(), String> {
        match self.bucket.exists().await {
            Ok(true) => Ok(()),
            _ => {
                let creds = self.bucket.credentials().await.map_err(s3_err)?;
                s3::Bucket::create_with_path_style(
                    &self.bucket.name,
                    self.bucket.region.clone(),
                    creds,
                    s3::BucketConfiguration::default(),
                )
                .await
                .map(|_| ())
                .or_else(|e| {
                    if e.to_string().contains("already") {
                        Ok(())
                    } else {
                        Err(format!("s3 bucket: {e}"))
                    }
                })
            }
        }
    }

    fn key(&self, key: &str) -> String {
        if self.prefix.is_empty() {
            key.to_string()
        } else {
            format!("{}/{key}", self.prefix)
        }
    }
}

fn s3_err(e: impl std::fmt::Display) -> String {
    e.to_string()
}

#[async_trait]
impl Blobs for S3Blobs {
    async fn put(
        &self,
        key: &str,
        len: u64,
        reader: &mut (dyn AsyncRead + Send + Unpin),
    ) -> Result<(), String> {
        self.bucket
            .put_object_stream(reader, self.key(key))
            .await
            .map_err(s3_err)?;
        let _ = len;
        Ok(())
    }

    async fn get(&self, key: &str) -> Result<(u64, ByteStream), String> {
        let resp = self
            .bucket
            .get_object_stream(self.key(key))
            .await
            .map_err(s3_err)?;
        // ResponseDataStream carries no headers; a HEAD is the only way to
        // learn the object's size.
        let len = self.head(key).await.unwrap_or(0);
        let stream = resp
            .bytes
            .map(|r| r.map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string())));
        Ok((len, Box::pin(stream)))
    }

    async fn get_range(
        &self,
        key: &str,
        start: u64,
        end: u64,
    ) -> Result<(u64, u64, ByteStream), String> {
        let total = self.head(key).await?;
        // Bridge get_object_range_to_writer into a byte stream so large
        // ranges are not buffered in memory.
        let (mut w, r) = tokio::io::duplex(256 * 1024);
        let (bucket, key) = (self.bucket.clone(), self.key(key));
        tokio::spawn(async move {
            if let Err(e) = bucket
                .get_object_range_to_writer(&key, start, Some(end), &mut w)
                .await
            {
                tracing::warn!("s3 range stream {key}: {e}");
            }
        });
        let stream = tokio_util::io::ReaderStream::new(r);
        Ok((total, end, Box::pin(stream)))
    }

    async fn head(&self, key: &str) -> Result<u64, String> {
        let (obj, _code) = self
            .bucket
            .head_object(self.key(key))
            .await
            .map_err(s3_err)?;
        Ok(obj.content_length.unwrap_or(0) as u64)
    }

    async fn list(&self, prefix: &str) -> Result<(Vec<String>, Vec<BlobObject>), String> {
        let p = if prefix.is_empty() || prefix == "/" {
            self.key("")
        } else {
            self.key(&format!("{}/", prefix.trim_matches('/')))
        };
        let results = self
            .bucket
            .list(p, Some("/".to_string()))
            .await
            .map_err(s3_err)?;
        let mut folders = Vec::new();
        let mut objects = Vec::new();
        for page in results {
            for cp in page.common_prefixes.unwrap_or_default() {
                let p = cp.prefix.trim_matches('/').to_string();
                let rel = p
                    .strip_prefix(&self.prefix)
                    .unwrap_or(&p)
                    .trim_start_matches('/')
                    .to_string();
                folders.push(rel);
            }
            for o in page.contents {
                let rel = o
                    .key
                    .strip_prefix(&format!("{}/", self.prefix))
                    .unwrap_or(&o.key)
                    .to_string();
                if o.key.ends_with('/') || o.key.ends_with(".keep") {
                    continue;
                }
                objects.push(BlobObject {
                    key: rel,
                    size: o.size as u64,
                    modified: chrono_ts(&o.last_modified),
                });
            }
        }
        Ok((folders, objects))
    }

    async fn delete(&self, key: &str) -> Result<(), String> {
        if self.bucket.head_object(self.key(key)).await.is_ok() {
            self.bucket
                .delete_object(self.key(key))
                .await
                .map_err(s3_err)?;
            return Ok(());
        }
        self.delete_prefix(key).await
    }

    async fn delete_prefix(&self, prefix: &str) -> Result<(), String> {
        let p = format!("{}/", self.key(prefix.trim_matches('/')));
        let results = self.bucket.list(p, None).await.map_err(s3_err)?;
        for page in results {
            for o in page.contents {
                let _ = self.bucket.delete_object(o.key).await;
            }
        }
        Ok(())
    }

    async fn rename(&self, from: &str, to: &str) -> Result<(), String> {
        if self.bucket.head_object(self.key(from)).await.is_ok() {
            if self.bucket.head_object(self.key(to)).await.is_ok() {
                return Err("exists".into());
            }
            self.bucket
                .copy_object_internal(&self.key(from), &self.key(to))
                .await
                .map_err(s3_err)?;
            self.bucket
                .delete_object(self.key(from))
                .await
                .map_err(s3_err)?;
            return Ok(());
        }
        let results = self
            .bucket
            .list(format!("{}/", self.key(from.trim_matches('/'))), None)
            .await
            .map_err(s3_err)?;
        let mut moved = false;
        for page in results {
            for o in page.contents {
                let rel = o
                    .key
                    .strip_prefix(&format!("{}/", self.key(from.trim_matches('/'))))
                    .unwrap_or("");
                let dst = format!("{}/{}", self.key(to.trim_matches('/')), rel);
                self.bucket
                    .copy_object_internal(&o.key, &dst)
                    .await
                    .map_err(s3_err)?;
                let _ = self.bucket.delete_object(o.key).await;
                moved = true;
            }
        }
        if moved {
            Ok(())
        } else {
            Err("not found".into())
        }
    }

    async fn mkdir(&self, key_prefix: &str) -> Result<(), String> {
        // S3 has no real folders; drop a marker so empty folders list.
        let key = format!("{}/.keep", self.key(key_prefix.trim_matches('/')));
        let mut empty: &[u8] = &[];
        self.bucket
            .put_object_stream(&mut empty, key)
            .await
            .map_err(s3_err)?;
        Ok(())
    }
}

/// S3 `last_modified` is ISO8601 UTC (`2026-01-02T03:04:05.678Z`); pull the
/// six leading numeric fields and convert with days-from-civil. Fractional
/// seconds and offsets are ignored — S3 reports UTC.
fn chrono_ts(s: &str) -> i64 {
    let mut n = [0i64; 6];
    let mut i = 0;
    for part in s.split(|c: char| !c.is_ascii_digit()) {
        if i >= n.len() {
            break;
        }
        if part.is_empty() {
            continue;
        }
        match part.parse::<i64>() {
            Ok(v) => {
                n[i] = v;
                i += 1;
            }
            Err(_) => return 0,
        }
    }
    if i < n.len() {
        return 0;
    }
    let (mut y, m, d) = (n[0], n[1], n[2]);
    y -= if m <= 2 { 1 } else { 0 };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = (m + 9) % 12;
    let doy = (153 * mp + 2) / 5 + d - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    (era * 146097 + doe - 719468) * 86400 + n[3] * 3600 + n[4] * 60 + n[5]
}

#[cfg(test)]
mod tests {
    use super::{chrono_ts, Blobs, LocalBlobs};

    #[tokio::test]
    async fn local_rename_fails_when_destination_exists() {
        let dir = std::env::temp_dir().join(format!("wfm-blobs-rename-{}", std::process::id()));
        let blobs = LocalBlobs::new(dir.clone());
        blobs
            .put("a.txt", 0, &mut tokio::io::empty())
            .await
            .unwrap();
        blobs
            .put("b.txt", 0, &mut tokio::io::empty())
            .await
            .unwrap();
        assert_eq!(blobs.rename("a.txt", "b.txt").await, Err("exists".into()));
        assert_eq!(blobs.rename("a.txt", "c.txt").await, Ok(()));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn s3_timestamps_parse() {
        assert_eq!(chrono_ts("1970-01-01T00:00:00.000Z"), 0);
        assert_eq!(chrono_ts("2000-01-01T00:00:00Z"), 946684800);
        assert_eq!(chrono_ts("2024-01-01T00:00:00.000Z"), 1704067200);
        assert_eq!(chrono_ts("2026-11-18T01:02:03.456Z"), 1794963723);
        assert_eq!(chrono_ts("2026-11-18T01:02:03+00:00"), 1794963723);
        assert_eq!(chrono_ts("garbage"), 0);
        assert_eq!(chrono_ts(""), 0);
    }
}

pub async fn connect(cfg: &crate::config::Config) -> Result<Arc<dyn Blobs>, String> {
    match cfg.media_kind.as_str() {
        "s3" => Ok(Arc::new(
            S3Blobs::connect(
                &cfg.s3_endpoint,
                &cfg.s3_region,
                &cfg.s3_bucket,
                &cfg.s3_access,
                &cfg.s3_secret,
                &cfg.s3_prefix,
            )
            .await?,
        )),
        _ => {
            let root = cfg
                .media_path
                .clone()
                .unwrap_or_else(|| cfg.data_dir.join("media"));
            std::fs::create_dir_all(&root).map_err(|e| e.to_string())?;
            Ok(Arc::new(LocalBlobs::new(root)))
        }
    }
}
