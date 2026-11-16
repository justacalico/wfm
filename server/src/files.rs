use std::path::{Component, Path, PathBuf};

use serde::Serialize;

use crate::model::valid_project_name;

/// Top-level folders every project gets. Nested layout:
///   Raw/{A-Roll,B-Roll,Unused,Other}  Audio/{VA,Music,Titles}  Exports  Images
pub const PROJECT_FOLDERS: &[&str] = &[
    "Raw",
    "Raw/A-Roll",
    "Raw/B-Roll",
    "Raw/Unused",
    "Raw/Other",
    "Audio",
    "Audio/VA",
    "Audio/Music",
    "Audio/Titles",
    "Exports",
    "Images",
];

pub const ROOT_FOLDERS: &[&str] = &["Raw", "Audio", "Exports", "Images"];

/// Editor documents stored at the project root.
pub const STATE_FILE: &str = "project.wfm.json";
pub const PROJECT_FILE: &str = "project.fcproj";

#[derive(Debug)]
pub enum FsError {
    BadPath,
    NotFound,
    Exists,
    Forbidden,
    Io(std::io::Error),
}

impl From<std::io::Error> for FsError {
    fn from(e: std::io::Error) -> Self {
        match e.kind() {
            std::io::ErrorKind::NotFound => FsError::NotFound,
            std::io::ErrorKind::AlreadyExists => FsError::Exists,
            std::io::ErrorKind::PermissionDenied => FsError::Forbidden,
            _ => FsError::Io(e),
        }
    }
}

/// Project directory: <projects>/<username>/<userID>/<name>/<uuid>/
pub fn project_dir(root: &Path, username: &str, user_id: &str, name: &str, id: &str) -> PathBuf {
    root.join(username).join(user_id).join(name).join(id)
}

pub fn rel_project_dir(username: &str, user_id: &str, name: &str, id: &str) -> String {
    format!("{username}/{user_id}/{name}/{id}")
}

pub fn create_project_dirs(root: &Path, username: &str, user_id: &str, name: &str, id: &str) -> Result<PathBuf, FsError> {
    let dir = project_dir(root, username, user_id, name, id);
    for f in PROJECT_FOLDERS {
        std::fs::create_dir_all(dir.join(f))?;
    }
    Ok(dir)
}

/// Clean a user-supplied relative path and reject escapes. Result is a safe
/// relative path inside the project or an error.
pub fn clean_rel(rel: &str) -> Result<PathBuf, FsError> {
    let rel = rel.replace('\\', "/");
    let p = Path::new(rel.trim_start_matches('/'));
    let mut out = PathBuf::new();
    for c in p.components() {
        match c {
            Component::Normal(s) => {
                let s = s.to_string_lossy();
                if s.starts_with('.') && s != ".well-known" {
                    return Err(FsError::BadPath);
                }
                out.push(s.as_ref());
            }
            Component::CurDir => {}
            _ => return Err(FsError::BadPath),
        }
    }
    if out.as_os_str().is_empty() {
        return Err(FsError::BadPath);
    }
    Ok(out)
}

/// Validate a project-relative path for use as an object key suffix.
/// Same rules as `resolve` but without touching the filesystem.
pub fn clean_rel_key(rel: &str) -> Result<String, FsError> {
    let rel = clean_rel(rel)?;
    let first = rel
        .components()
        .next()
        .and_then(|c| match c {
            Component::Normal(s) => Some(s.to_string_lossy().to_string()),
            _ => None,
        })
        .ok_or(FsError::BadPath)?;
    let is_state_file = rel == Path::new(STATE_FILE) || rel == Path::new(PROJECT_FILE);
    if !is_state_file && !ROOT_FOLDERS.contains(&first.as_str()) {
        return Err(FsError::BadPath);
    }
    Ok(rel.to_string_lossy().replace('\\', "/"))
}

/// Resolve a relative path inside a project dir. Operations are restricted to
/// the managed folder roots; nothing may escape or sit at project root level.
pub fn resolve(project_root: &Path, rel: &str) -> Result<PathBuf, FsError> {
    let rel = clean_rel(rel)?;
    let first = rel
        .components()
        .next()
        .and_then(|c| match c {
            Component::Normal(s) => Some(s.to_string_lossy().to_string()),
            _ => None,
        })
        .ok_or(FsError::BadPath)?;
    // The editor state file is the one file allowed at project root level.
    let is_state_file = rel == Path::new(STATE_FILE) || rel == Path::new(PROJECT_FILE);
    if !is_state_file && !ROOT_FOLDERS.contains(&first.as_str()) {
        return Err(FsError::BadPath);
    }
    let full = project_root.join(&rel);
    // Containment check: resolved path must stay under project_root. Existing
    // symlinks in the parent chain are honoured by canonicalize.
    let parent = full.parent().unwrap_or(project_root);
    if parent.exists() {
        let canon = parent.canonicalize()?;
        let root_canon = project_root.canonicalize()?;
        if !canon.starts_with(&root_canon) {
            return Err(FsError::Forbidden);
        }
    }
    if full.is_symlink() {
        return Err(FsError::Forbidden);
    }
    Ok(full)
}

pub fn resolve_root(project_root: &Path, rel: &str) -> Result<PathBuf, FsError> {
    if rel.is_empty() || rel == "/" {
        return Ok(project_root.to_path_buf());
    }
    resolve(project_root, rel)
}

#[derive(Serialize)]
pub struct FileEntry {
    pub name: String,
    pub path: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub size: u64,
    pub modified: i64,
}

pub fn list(project_root: &Path, rel: &str) -> Result<Vec<FileEntry>, FsError> {
    let dir = resolve_root(project_root, rel)?;
    if dir == project_root {
        // virtual root listing: the managed top-level folders
        let mut out = Vec::new();
        for f in ROOT_FOLDERS {
            out.push(FileEntry {
                name: f.to_string(),
                path: f.to_string(),
                kind: "dir".into(),
                size: 0,
                modified: 0,
            });
        }
        return Ok(out);
    }
    let mut out = Vec::new();
    for e in std::fs::read_dir(&dir)? {
        let e = e?;
        let name = e.file_name().to_string_lossy().to_string();
        if name.starts_with('.') {
            continue;
        }
        let meta = e.metadata()?;
        if meta.is_symlink() {
            continue;
        }
        let kind = if meta.is_dir() { "dir" } else { "file" };
        out.push(FileEntry {
            path: format!("{}/{}", rel.trim_matches('/'), name)
                .trim_start_matches('/')
                .to_string(),
            name,
            kind: kind.into(),
            size: meta.len(),
            modified: meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0),
        });
    }
    out.sort_by(|a, b| (b.kind == "dir").cmp(&(a.kind == "dir")).then(a.name.cmp(&b.name)));
    Ok(out)
}

pub fn mkdir(project_root: &Path, rel: &str) -> Result<(), FsError> {
    let p = resolve(project_root, rel)?;
    if p.exists() {
        return Err(FsError::Exists);
    }
    std::fs::create_dir_all(p)?;
    Ok(())
}

pub fn remove(project_root: &Path, rel: &str) -> Result<(), FsError> {
    let p = resolve(project_root, rel)?;
    let rel_clean = clean_rel(rel)?;
    // The managed root folders themselves may not be deleted.
    if rel_clean.components().count() == 1 {
        return Err(FsError::Forbidden);
    }
    if !p.exists() {
        return Err(FsError::NotFound);
    }
    if p.is_dir() {
        std::fs::remove_dir_all(p)?;
    } else {
        std::fs::remove_file(p)?;
    }
    Ok(())
}

pub fn rename(project_root: &Path, from: &str, to: &str) -> Result<(), FsError> {
    let src = resolve(project_root, from)?;
    let dst = resolve(project_root, to)?;
    if !src.exists() {
        return Err(FsError::NotFound);
    }
    if dst.exists() {
        return Err(FsError::Exists);
    }
    if let Some(parent) = dst.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::rename(src, dst)?;
    Ok(())
}

/// Path a streamed upload lands on; returns the temp path and final path.
pub fn upload_paths(project_root: &Path, rel: &str) -> Result<(PathBuf, PathBuf), FsError> {
    let dst = resolve(project_root, rel)?;
    if dst.is_dir() {
        return Err(FsError::BadPath);
    }
    if let Some(parent) = dst.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let tmp = dst.with_extension(format!(
        "wfm-up-{}",
        &crate::model::new_id()[..8]
    ));
    Ok((tmp, dst))
}

pub fn finish_upload(tmp: &Path, dst: &Path) -> Result<(), FsError> {
    std::fs::rename(tmp, dst)?;
    Ok(())
}

pub fn valid_project_name_or_err(name: &str) -> Result<String, FsError> {
    let n = name.trim();
    if valid_project_name(n) {
        Ok(n.to_string())
    } else {
        Err(FsError::BadPath)
    }
}
