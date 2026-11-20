use std::path::{Component, Path, PathBuf};

use serde::Serialize;

use crate::model::valid_project_name;

/// Top-level folders every project gets. Nested layout:
///   Raw/{A-Roll,B-Roll,Unused,Other}  Audio/{VA,Music,Titles}  Exports  Images
///   Script  Boards
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
    "Script",
    "Boards",
];

pub const ROOT_FOLDERS: &[&str] = &["Raw", "Audio", "Exports", "Images", "Script", "Boards"];

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

const THUMB_EXTS: &[&str] = &[
    "png", "jpg", "jpeg", "gif", "webp", "bmp", "tif", "tiff", "mp4", "mov", "mkv", "webm", "avi",
    "m4v", "mts", "m2ts", "mxf",
];

/// True when [crate::api] can offer a jpeg thumbnail for `path`.
pub fn thumbable(path: &str) -> bool {
    Path::new(path)
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| THUMB_EXTS.contains(&e.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

/// Extensions accepted through the project upload endpoints, grouped by kind:
/// video, audio, image, subtitle/interchange, managed docs (including what
/// the embedded editors export) and fonts. Everything else, notably anything
/// a browser would execute inline like html, svg or scripts, is refused
/// before a byte is spooled.
const UPLOAD_EXTS: &[&str] = &[
    "mp4",
    "mov",
    "mkv",
    "webm",
    "avi",
    "m4v",
    "mts",
    "m2ts",
    "mxf",
    "mpg",
    "mpeg",
    "ts",
    "vob",
    "wmv",
    "3gp",
    "wav",
    "mp3",
    "m4a",
    "aac",
    "flac",
    "ogg",
    "oga",
    "opus",
    "aif",
    "aiff",
    "wma",
    "png",
    "jpg",
    "jpeg",
    "gif",
    "webp",
    "bmp",
    "tif",
    "tiff",
    "dng",
    "exr",
    "hdr",
    "srt",
    "vtt",
    "ass",
    "edl",
    "ale",
    "otio",
    "xml",
    "fcpxml",
    "fcproj",
    "fountain",
    "fdx",
    "deckcraft",
    "json",
    "txt",
    "md",
    "pdf",
    "pptx",
    "potx",
    "ppsx",
    "mogrt",
    "ttf",
    "otf",
    "woff",
    "woff2",
];

pub fn upload_allowed(path: &str) -> bool {
    Path::new(path)
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| UPLOAD_EXTS.contains(&e.to_ascii_lowercase().as_str()))
        .unwrap_or(false)
}

/// Signatures that are never safe to store regardless of the claimed type:
/// Windows/ELF/Mach-O executables, OLE2 and zip containers, and `#!` scripts.
fn dangerous_head(head: &[u8]) -> bool {
    head.starts_with(b"MZ")
        || head.starts_with(b"\x7fELF")
        || head.starts_with(b"PK\x03\x04")
        || head.starts_with(b"PK\x05\x06")
        || head.starts_with(&[0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])
        || head.starts_with(b"#!")
        || head.starts_with(&[0xfe, 0xed, 0xfa, 0xce])
        || head.starts_with(&[0xce, 0xfa, 0xed, 0xfe])
        || head.starts_with(&[0xfe, 0xed, 0xfa, 0xcf])
        || head.starts_with(&[0xcf, 0xfa, 0xed, 0xfe])
        || head.starts_with(&[0xca, 0xfe, 0xba, 0xbe])
        || head.starts_with(&[0xbe, 0xba, 0xfe, 0xca])
}

fn riff(head: &[u8], tag: &[u8; 4]) -> bool {
    head.len() >= 12 && &head[..4] == b"RIFF" && &head[8..12] == tag
}

fn frame_sync(head: &[u8]) -> bool {
    head.len() >= 2 && head[0] == 0xff && head[1] & 0xe0 == 0xe0
}

/// A document that is plausibly text: a UTF-16 BOM, or UTF-8 with no NULs
/// (a truncated multibyte char right at the read boundary still counts).
fn text_head(head: &[u8]) -> bool {
    if head.starts_with(&[0xff, 0xfe]) || head.starts_with(&[0xfe, 0xff]) {
        return true;
    }
    if head.contains(&0) {
        return false;
    }
    match std::str::from_utf8(head) {
        Ok(_) => true,
        Err(e) => e.error_len().is_none() && e.valid_up_to() + 4 >= head.len(),
    }
}

/// Verify an upload's first bytes against the type its extension claims. The
/// caller already ran [upload_allowed]; `head` is the file's first ~512 bytes.
pub fn sniff_ok(path: &str, head: &[u8]) -> bool {
    let ext = Path::new(path)
        .extension()
        .and_then(|e| e.to_str())
        .map(|e| e.to_ascii_lowercase())
        .unwrap_or_default();
    if !UPLOAD_EXTS.contains(&ext.as_str()) {
        return false;
    }
    // Zip-based document formats the editors write carry the one PK signature
    // nothing else may.
    if matches!(
        ext.as_str(),
        "deckcraft" | "pptx" | "potx" | "ppsx" | "mogrt"
    ) {
        return head.starts_with(b"PK\x03\x04");
    }
    if dangerous_head(head) {
        return false;
    }
    match ext.as_str() {
        "mp4" | "mov" | "m4v" | "3gp" | "m4a" => head.get(4..8) == Some(b"ftyp".as_slice()),
        "mkv" | "webm" => head.starts_with(&[0x1a, 0x45, 0xdf, 0xa3]),
        "avi" => riff(head, b"AVI "),
        "wmv" | "wma" => head.starts_with(&[0x30, 0x26, 0xb2, 0x75, 0x8e, 0x66, 0xcf, 0x11]),
        "mxf" => head.starts_with(&[
            0x06, 0x0e, 0x2b, 0x34, 0x02, 0x05, 0x01, 0x01, 0x0d, 0x01, 0x02, 0x01,
        ]),
        "ts" | "mts" | "m2ts" => head.first() == Some(&0x47) || head.get(4) == Some(&0x47),
        "mpg" | "mpeg" | "vob" => head.starts_with(&[0x00, 0x00, 0x01]),
        "wav" => riff(head, b"WAVE"),
        "aif" | "aiff" => {
            head.len() >= 12
                && &head[..4] == b"FORM"
                && (&head[8..12] == b"AIFF" || &head[8..12] == b"AIFC")
        }
        "flac" => head.starts_with(b"fLaC"),
        "ogg" | "oga" | "opus" => head.starts_with(b"OggS"),
        "mp3" | "aac" => head.starts_with(b"ID3") || frame_sync(head),
        "png" => head.starts_with(b"\x89PNG"),
        "jpg" | "jpeg" => head.starts_with(b"\xff\xd8\xff"),
        "gif" => head.starts_with(b"GIF8"),
        "webp" => riff(head, b"WEBP"),
        "bmp" => head.starts_with(b"BM"),
        "tif" | "tiff" | "dng" => head.starts_with(b"II*\x00") || head.starts_with(b"MM\x00*"),
        "exr" => head.starts_with(&[0x76, 0x2f, 0x31, 0x01]),
        "hdr" => head.starts_with(b"#?"),
        "pdf" => head.starts_with(b"%PDF-"),
        "ttf" => head.starts_with(&[0x00, 0x01, 0x00, 0x00]),
        "otf" => head.starts_with(b"OTTO"),
        "woff" => head.starts_with(b"wOFF"),
        "woff2" => head.starts_with(b"wOF2"),
        _ => text_head(head),
    }
}

/// Object key for a finished render upload. Confines `name` under Exports/ so
/// a node-supplied path cannot escape the prefix on any blob backend.
pub fn export_key(name: &str) -> Result<String, FsError> {
    let key = clean_rel_key(&format!("Exports/{name}"))?;
    if !key.starts_with("Exports/") {
        return Err(FsError::BadPath);
    }
    Ok(key)
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
        assert!(clean_rel_key("Script/script.fountain").is_ok());
        assert!(clean_rel_key("Boards/boards.deckcraft").is_ok());
        assert!(clean_rel_key(STATE_FILE).is_ok());
        assert!(clean_rel_key(PROJECT_FILE).is_ok());
        assert!(clean_rel_key("stray.txt").is_err());
    }

    #[test]
    fn upload_allowlist() {
        for k in [
            "Raw/clip.mp4",
            "Raw/KDR_9751.MOV",
            "Audio/VA/take.wav",
            "Images/bg.PNG",
            "Script/script.fountain",
            "Boards/boards.deckcraft",
            STATE_FILE,
            PROJECT_FILE,
            "Raw/caps.srt",
            "Exports/timeline.fcpxml",
            "Exports/script.pdf",
            "Exports/notes.txt",
            "Exports/deck.pptx",
            "Images/frame.dng",
            "Images/plate.exr",
            "Images/env.hdr",
            "Exports/logo.mogrt",
        ] {
            assert!(upload_allowed(k), "{k}");
        }
        for k in [
            "Raw/run.exe",
            "Raw/setup.msi",
            "Raw/go.bat",
            "Raw/s.py",
            "Raw/x.js",
            "Raw/page.html",
            "Raw/icon.svg",
            "Raw/a.zip",
            "Raw/doc.docx",
            "Raw/noext",
            ".hidden",
        ] {
            assert!(!upload_allowed(k), "{k}");
        }
    }

    #[test]
    fn sniff_matches_claimed_types() {
        let ftyp = |b: &[u8]| {
            let mut v = b"\x00\x00\x00\x18ftyp".to_vec();
            v.extend_from_slice(b);
            v
        };
        assert!(sniff_ok("a.mp4", &ftyp(b"isom")));
        assert!(sniff_ok("a.mov", &ftyp(b"qt  ")));
        assert!(!sniff_ok("a.mp4", b"not a real video"));
        assert!(!sniff_ok("a.mp4", &ftyp(b"isom")[..4]));
        assert!(sniff_ok("a.mkv", &[0x1a, 0x45, 0xdf, 0xa3, 0x93]));
        assert!(sniff_ok("a.webm", &[0x1a, 0x45, 0xdf, 0xa3]));
        assert!(sniff_ok("a.png", b"\x89PNG\r\n\x1a\nrest"));
        assert!(sniff_ok("a.jpg", b"\xff\xd8\xff\xe0rest"));
        assert!(sniff_ok("a.gif", b"GIF89arest"));
        assert!(sniff_ok("a.webp", b"RIFF\x10\x00\x00\x00WEBPrest"));
        assert!(sniff_ok("a.wav", b"RIFF\x10\x00\x00\x00WAVErest"));
        assert!(sniff_ok("a.mts", &[0x47, 0x40, 0x11, 0x10]));
        assert!(sniff_ok("a.m2ts", &[0x00, 0x00, 0x00, 0x00, 0x47]));
        assert!(sniff_ok("a.mp3", b"ID3\x04\x00rest"));
        assert!(sniff_ok("a.mp3", &[0xff, 0xfb, 0x90, 0x00]));
        assert!(sniff_ok("a.dng", b"II*\x00rest"));
        assert!(sniff_ok("a.exr", &[0x76, 0x2f, 0x31, 0x01, 0x02]));
        assert!(sniff_ok("a.hdr", b"#?RADIANCE\nrest"));
        assert!(sniff_ok("a.pdf", b"%PDF-1.7 rest"));
        assert!(!sniff_ok("a.png", b"BMrest"));
        assert!(!sniff_ok("a.wav", b"RIFF\x10\x00\x00\x00WEBPrest"));
        assert!(!sniff_ok("a.exe", b"just text"));
    }

    #[test]
    fn sniff_docs_and_text() {
        assert!(sniff_ok("boards/a.deckcraft", b"PK\x03\x04zipbody"));
        assert!(sniff_ok("exports/a.pptx", b"PK\x03\x04zipbody"));
        assert!(sniff_ok("exports/a.mogrt", b"PK\x03\x04zipbody"));
        assert!(!sniff_ok("boards/a.deckcraft", b"not a zip"));
        assert!(!sniff_ok("exports/a.pptx", b"not a zip"));
        assert!(sniff_ok(
            "project.fcproj",
            b"{\"format\":\"filmcraft.project\"}"
        ));
        assert!(sniff_ok(
            "Script/a.fountain",
            "Title: Test\n\nINT. ROOM".as_bytes()
        ));
        assert!(sniff_ok(
            "x.srt",
            "1\n00:00:01,000 --> 00:00:02,000\nHi".as_bytes()
        ));
        assert!(sniff_ok("x.vtt", b"WEBVTT\n\n00:00.000 --> 00:01.000\nHi"));
        assert!(sniff_ok("x.srt", &[0xff, 0xfe, b'1', 0x00]));
        assert!(sniff_ok("x.srt", b""));
        assert!(!sniff_ok("x.srt", b"\x89PNG\r\n\x1a\n"));
        assert!(!sniff_ok("x.json", &[0xff, 0x30, 0x00, 0x00]));
    }

    #[test]
    fn sniff_rejects_renamed_executables() {
        for bad in [
            &b"MZ\x90\x00exe"[..],
            &b"\x7fELF\x02elf"[..],
            &b"#!/bin/sh\nrm -rf /"[..],
            &[0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1][..],
            &[0xfe, 0xed, 0xfa, 0xcf, 0x00][..],
            &[0xca, 0xfe, 0xba, 0xbe, 0x00][..],
        ] {
            assert!(!sniff_ok("a.mp4", bad), "{bad:?}");
            assert!(!sniff_ok("a.srt", bad), "{bad:?}");
            assert!(!sniff_ok("a.png", bad), "{bad:?}");
        }
        assert!(!sniff_ok("a.mp4", b"PK\x03\x04docx"));
        assert!(sniff_ok("a.mp4", b"\x00\x00\x00\x18ftypisom"));
    }

    #[test]
    fn export_key_confines_to_exports() {
        assert_eq!(export_key("cut.mp4").unwrap(), "Exports/cut.mp4");
        assert_eq!(export_key("part 01.mp4").unwrap(), "Exports/part 01.mp4");
        assert!(export_key("../x").is_err());
        assert!(export_key("../../state").is_err());
        assert!(export_key("..\\..\\x").is_err());
        assert!(export_key(".hidden.mp4").is_err());
        assert!(export_key("").is_err());
        // Leading slashes normalize under Exports/, never above it.
        assert_eq!(export_key("/etc/passwd").unwrap(), "Exports/etc/passwd");
    }
}
