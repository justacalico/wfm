use rand::RngCore;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
pub enum Role {
    Student = 1,
    Mod = 2,
    Teacher = 3,
    Admin = 4,
    Owner = 5,
}

impl Role {
    pub fn as_str(&self) -> &'static str {
        match self {
            Role::Student => "student",
            Role::Mod => "mod",
            Role::Teacher => "teacher",
            Role::Admin => "admin",
            Role::Owner => "owner",
        }
    }

    pub fn from_i64(v: i64) -> Role {
        match v {
            2 => Role::Mod,
            3 => Role::Teacher,
            4 => Role::Admin,
            5 => Role::Owner,
            _ => Role::Student,
        }
    }

    pub fn parse(s: &str) -> Option<Role> {
        match s.to_ascii_lowercase().as_str() {
            "student" => Some(Role::Student),
            "mod" => Some(Role::Mod),
            "teacher" => Some(Role::Teacher),
            "admin" => Some(Role::Admin),
            "owner" => Some(Role::Owner),
            _ => None,
        }
    }

    pub fn can_create(&self) -> bool {
        *self >= Role::Teacher
    }

    pub fn can_see_audit(&self) -> bool {
        *self >= Role::Mod
    }
}

impl From<Role> for String {
    fn from(r: Role) -> String {
        r.as_str().to_string()
    }
}

#[derive(Clone, Serialize)]
pub struct User {
    pub id: String,
    pub username: String,
    #[serde(rename = "displayName")]
    pub display_name: String,
    #[serde(skip)]
    pub role: Role,
    #[serde(rename = "role")]
    pub role_name: String,
    #[serde(rename = "studentId")]
    pub student_id: String,
    pub note: String,
    pub disabled: bool,
    pub avatar: String,
    #[serde(rename = "quotaBytes")]
    pub quota_bytes: i64,
    #[serde(rename = "createdBy")]
    pub created_by: String,
    #[serde(skip)]
    pub lineage: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "lastLogin")]
    pub last_login: i64,
}

#[derive(Clone, Serialize)]
pub struct Project {
    pub id: String,
    #[serde(rename = "ownerId")]
    pub owner_id: String,
    pub name: String,
    #[serde(rename = "displayName")]
    pub display_name: String,
    #[serde(skip)]
    pub dir: String,
    #[serde(rename = "groupId")]
    pub group_id: String,
    pub tags: Vec<String>,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "lastActivity")]
    pub last_activity: i64,
    pub pinned: bool,
}

#[derive(Clone, Serialize)]
pub struct ProjectGroup {
    pub id: String,
    #[serde(skip)]
    pub owner_id: String,
    pub name: String,
    #[serde(skip)]
    pub created_at: i64,
}

/// Normalize tag input: trim, lowercase, dedupe, cap length and count.
pub fn norm_tags(tags: &[String]) -> Vec<String> {
    let mut out: Vec<String> = Vec::new();
    for t in tags {
        // Commas would silently split one tag into two via tags_csv.
        let t: String = t
            .trim()
            .to_lowercase()
            .replace(',', "")
            .chars()
            .take(32)
            .collect();
        if !t.is_empty() && !out.contains(&t) {
            out.push(t);
        }
        if out.len() >= 12 {
            break;
        }
    }
    out
}

pub fn tags_csv(tags: &[String]) -> String {
    tags.join(",")
}

pub fn tags_split(csv: &str) -> Vec<String> {
    csv.split(',')
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
        .collect()
}

#[derive(Clone, Serialize)]
pub struct SessionInfo {
    pub id: String,
    pub ip: String,
    pub ua: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "expiresAt")]
    pub expires_at: i64,
    #[serde(rename = "lastSeen")]
    pub last_seen: i64,
}

#[derive(Clone, Serialize)]
pub struct LockInfo {
    pub holder: String,
    pub label: String,
    #[serde(rename = "expiresAt")]
    pub expires_at: i64,
}

#[derive(Clone, Serialize, Deserialize)]
pub struct RenderJob {
    pub id: String,
    #[serde(rename = "projectId")]
    pub project_id: String,
    #[serde(rename = "userId")]
    pub user_id: String,
    pub status: String,
    pub mode: String,
    pub spec: String,
    #[serde(rename = "outputName")]
    pub output_name: String,
    pub progress: f64,
    pub error: String,
    pub worker: String,
    pub attempts: i64,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "finishedAt")]
    pub finished_at: i64,
}

#[derive(Clone, Serialize)]
pub struct RenderNode {
    pub id: String,
    pub name: String,
    pub disabled: bool,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "lastSeen")]
    pub last_seen: i64,
}

#[derive(Clone, Serialize)]
pub struct InviteCode {
    pub id: String,
    #[serde(skip)]
    pub code_hash: String,
    #[serde(rename = "createdBy")]
    pub created_by: String,
    pub role: String,
    #[serde(rename = "presetUsername")]
    pub preset_username: String,
    #[serde(rename = "presetName")]
    pub preset_name: String,
    #[serde(rename = "usedBy")]
    pub used_by: String,
    #[serde(rename = "usedAt")]
    pub used_at: i64,
    #[serde(rename = "expiresAt")]
    pub expires_at: i64,
    pub revoked: bool,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
}

#[derive(Clone, Serialize)]
pub struct ProjectShare {
    pub id: String,
    #[serde(rename = "projectId")]
    pub project_id: String,
    #[serde(rename = "inviterId")]
    pub inviter_id: String,
    #[serde(rename = "inviteeId")]
    pub invitee_id: String,
    pub level: String,
    pub status: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "respondedAt")]
    pub responded_at: i64,
}

#[derive(Debug, Clone, Serialize)]
pub struct AutoShare {
    pub id: String,
    #[serde(rename = "ownerId")]
    pub owner_id: String,
    #[serde(rename = "inviteeId")]
    pub invitee_id: String,
    pub level: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
}

#[derive(Debug, Clone, Serialize)]
pub struct AutoShareView {
    pub id: String,
    #[serde(rename = "inviteeId")]
    pub invitee_id: String,
    #[serde(rename = "inviteeUsername")]
    pub invitee_username: String,
    #[serde(rename = "inviteeName")]
    pub invitee_name: String,
    pub level: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
}

#[derive(Clone, Serialize)]
pub struct ShareView {
    pub id: String,
    #[serde(rename = "projectId")]
    pub project_id: String,
    #[serde(rename = "projectName")]
    pub project_name: String,
    #[serde(rename = "inviterId")]
    pub inviter_id: String,
    #[serde(rename = "inviterUsername")]
    pub inviter_username: String,
    #[serde(rename = "inviteeId")]
    pub invitee_id: String,
    #[serde(rename = "inviteeUsername")]
    pub invitee_username: String,
    #[serde(rename = "inviteeName")]
    pub invitee_name: String,
    pub level: String,
    pub status: String,
    #[serde(rename = "createdAt")]
    pub created_at: i64,
    #[serde(rename = "respondedAt")]
    pub responded_at: i64,
}

#[derive(Clone, Serialize)]
pub struct AuditEntry {
    pub id: i64,
    pub ts: i64,
    pub scope: String,
    #[serde(rename = "actorId")]
    pub actor_id: String,
    #[serde(rename = "actorName")]
    pub actor_name: String,
    pub action: String,
    pub target: String,
    pub detail: String,
}

/// One project media file staged for a render: `name` is the `/files/<name>`
/// the project references inside FilmCraft, `path` the project-relative key.
#[derive(Serialize, Deserialize)]
pub struct RenderStageFile {
    pub name: String,
    pub path: String,
}

/// What a render job is: a FilmCraft `file.exportMedia` call. `params` is the
/// command's parameter object minus path/wait/sequence (the worker forces
/// those); `media` lists the project files to stage under `/files`.
#[derive(Serialize, Deserialize)]
pub struct RenderSpec {
    #[serde(default)]
    pub sequence: u64,
    #[serde(default)]
    pub output: String,
    #[serde(default)]
    pub params: serde_json::Value,
    #[serde(default)]
    pub media: Vec<RenderStageFile>,
}

pub fn new_id() -> String {
    let mut b = [0u8; 16];
    rand::rng().fill_bytes(&mut b);
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    format!(
        "{}-{}-{}-{}-{}",
        hex::encode(&b[0..4]),
        hex::encode(&b[4..6]),
        hex::encode(&b[6..8]),
        hex::encode(&b[8..10]),
        hex::encode(&b[10..16])
    )
}

pub fn new_token() -> String {
    let mut b = [0u8; 32];
    rand::rng().fill_bytes(&mut b);
    hex::encode(b)
}

pub fn token_hash(tok: &str) -> String {
    use sha2::Digest;
    hex::encode(sha2::Sha256::digest(tok.as_bytes()))
}

fn valid_name(s: &str, max: usize, extra: &str) -> bool {
    !s.is_empty()
        && s.len() <= max
        && !s.contains("..")
        && s.chars()
            .all(|c| c.is_ascii_alphanumeric() || extra.contains(c))
}

pub fn valid_username(s: &str) -> bool {
    s.len() >= 2 && valid_name(s, 32, "_.-")
}

pub fn valid_project_name(s: &str) -> bool {
    valid_name(s.trim(), 64, " _.-")
}

pub fn valid_password(s: &str) -> bool {
    s.len() >= 8 && s.len() <= 256
}

/// Whether `actor` may administrate `target`: target must rank lower and sit in
/// the actor's subtree. Mods may only police students in their creator's tree.
pub fn can_manage(actor: &User, target: &User) -> bool {
    if target.id == actor.id || target.role >= actor.role {
        return false;
    }
    if actor.role == Role::Mod {
        return target.role == Role::Student && lineage_has(&target.lineage, &actor.created_by);
    }
    lineage_has(&target.lineage, &actor.id)
}

pub fn lineage_has(lineage: &str, id: &str) -> bool {
    if id.is_empty() {
        return false;
    }
    let hay = format!("/{}/", lineage.trim_matches('/'));
    hay.contains(&format!("/{}/", id))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn role_from_i64_fails_closed() {
        assert_eq!(Role::from_i64(1), Role::Student);
        assert_eq!(Role::from_i64(2), Role::Mod);
        assert_eq!(Role::from_i64(3), Role::Teacher);
        assert_eq!(Role::from_i64(4), Role::Admin);
        assert_eq!(Role::from_i64(5), Role::Owner);
        for v in [0, 6, 99, -1] {
            assert_eq!(Role::from_i64(v), Role::Student);
        }
    }

    fn user(id: &str, role: Role, created_by: &str, lineage: &str) -> User {
        User {
            id: id.into(),
            username: id.into(),
            display_name: id.into(),
            role,
            role_name: role.as_str().into(),
            student_id: String::new(),
            note: String::new(),
            disabled: false,
            avatar: String::new(),
            quota_bytes: 0,
            created_by: created_by.into(),
            lineage: lineage.into(),
            created_at: 0,
            last_login: 0,
        }
    }

    #[test]
    fn manage_requires_subtree_and_lower_rank() {
        let teacher = user("t1", Role::Teacher, "a1", "/a1/");
        let student = user("s1", Role::Student, "t1", "/a1/t1/");
        let outsider = user("s2", Role::Student, "t2", "/a1/t2/");
        assert!(can_manage(&teacher, &student));
        assert!(!can_manage(&teacher, &outsider));
        assert!(!can_manage(&teacher, &teacher.clone()));
    }

    #[test]
    fn mod_only_polices_own_tree_students() {
        let modd = user("m1", Role::Mod, "t1", "/a1/t1/");
        let in_tree = user("s1", Role::Student, "t1", "/a1/t1/m1/");
        let not_in_tree = user("s2", Role::Student, "t2", "/a1/t2/");
        let teacher = user("t9", Role::Teacher, "a1", "/a1/t1/m1/");
        assert!(can_manage(&modd, &in_tree));
        assert!(!can_manage(&modd, &not_in_tree));
        assert!(!can_manage(&modd, &teacher));
    }

    #[test]
    fn lineage_matching_is_segment_exact() {
        assert!(lineage_has("/a/b/c/", "b"));
        assert!(!lineage_has("/ab/c/", "b"));
        assert!(!lineage_has("/", "x"));
    }
}
