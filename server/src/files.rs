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

/// Project directory key: <username>/<userID>/<name>/<uuid>
pub fn rel_project_dir(username: &str, user_id: &str, name: &str, id: &str) -> String {
    format!("{username}/{user_id}/{name}/{id}")
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

#[derive(Serialize)]
pub struct FileEntry {
    pub name: String,
    pub path: String,
    #[serde(rename = "type")]
    pub kind: String,
    pub size: u64,
    pub modified: i64,
}

pub fn valid_project_name_or_err(name: &str) -> Result<String, FsError> {
    let n = name.trim();
    if valid_project_name(n) {
        Ok(n.to_string())
    } else {
        Err(FsError::BadPath)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn clean_rel_blocks_traversal_and_hidden() {
        assert!(clean_rel("../etc/passwd").is_err());
        assert!(clean_rel("Raw/../../x").is_err());
        assert!(clean_rel(".git/config").is_err());
        assert!(clean_rel("").is_err());
        assert!(clean_rel("Raw/A-Roll/clip.mp4").is_ok());
        assert!(clean_rel("Audio/VA/take 01.wav").is_ok());
    }

    #[test]
    fn clean_rel_key_restricts_to_roots() {
        assert!(clean_rel_key("etc/hostname").is_err());
        assert!(clean_rel_key("Raw/clip.mp4").is_ok());
        assert!(clean_rel_key(STATE_FILE).is_ok());
        assert!(clean_rel_key(PROJECT_FILE).is_ok());
        assert!(clean_rel_key("stray.txt").is_err());
    }

}
