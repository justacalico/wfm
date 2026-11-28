import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'uploads.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  final String? rev;
  final Map<String, dynamic>? body;
  ApiException(this.status, this.message, [this.rev, this.body]);
  @override
  String toString() => message;
}

class User {
  final String id, username, name, role, studentId, note, avatar;
  final bool disabled;
  final int createdAt, lastLogin, quotaBytes;
  final String createdBy, classId;
  User.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        username = j['username'] ?? '',
        name = j['displayName'] ?? '',
        role = j['role'] ?? 'student',
        disabled = j['disabled'] ?? false,
        studentId = j['studentId'] ?? '',
        note = j['note'] ?? '',
        avatar = j['avatar'] ?? '',
        createdBy = j['createdBy'] ?? '',
        classId = j['classId'] ?? '',
        createdAt = j['createdAt'] ?? 0,
        lastLogin = j['lastLogin'] ?? 0,
        quotaBytes = j['quotaBytes'] ?? 0;
  bool get hasAvatar => avatar.isNotEmpty;

  static const ranks = {
    'student': 0,
    'mod': 1,
    'teacher': 2,
    'admin': 3,
    'owner': 4,
  };
  int get rank => ranks[role] ?? 0;
  bool get isAdmin => rank >= ranks['admin']!;
  bool get isStaff => rank >= ranks['teacher']!;
  bool get isOwner => role == 'owner';
}

class Caps {
  final List<String> creatable;
  final bool manage, audit;
  Caps.fromJson(Map<String, dynamic> j)
      : creatable = [for (final r in (j['creatable'] as List? ?? [])) '$r'],
        manage = j['canManage'] == true,
        audit = j['canAudit'] == true;
  static const none = Caps._();
  const Caps._()
      : creatable = const [],
        manage = false,
        audit = false;
}

class Project {
  final String id, name, displayName, folderId, ownerId, ownerName, access;
  final int createdAt, lastActivity;
  final bool pinned, template, canTakeOver, submitAllowed;
  final String status, reviewedBy;
  final int submittedAt;
  Project.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        displayName = j['displayName'] ?? j['name'] ?? '',
        folderId = j['folderId'] ?? '',
        ownerId = j['ownerId'] ?? '',
        ownerName = j['ownerName'] ?? '',
        access = j['access'] ?? '',
        createdAt = j['createdAt'] ?? 0,
        lastActivity = j['lastActivity'] ?? j['createdAt'] ?? 0,
        pinned = j['pinned'] ?? false,
        template = j['template'] ?? false,
        canTakeOver = j['takeOver'] == true,
        status = j['status'] ?? 'draft',
        submittedAt = j['submittedAt'] ?? 0,
        reviewedBy = j['reviewedBy'] ?? '',
        submitAllowed = j['submitAllowed'] == true;
  bool get mine => access.isEmpty
      ? (ownerId.isEmpty || ownerId == Api.i.user?.id)
      : access == 'owner';
  bool get locked => status == 'submitted';
  bool get editable => !locked && (mine || access == 'edit');
  Project copyWith(
          {String? displayName,
          bool? template,
          String? status,
          bool? submitAllowed}) =>
      Project.fromJson({
        'id': id,
        'name': name,
        'displayName': displayName ?? this.displayName,
        'folderId': folderId,
        'ownerId': ownerId,
        'ownerName': ownerName,
        'access': access,
        'createdAt': createdAt,
        'lastActivity': lastActivity,
        'pinned': pinned,
        'template': template ?? this.template,
        'takeOver': canTakeOver,
        'status': status ?? this.status,
        'submittedAt': submittedAt,
        'reviewedBy': reviewedBy,
        'submitAllowed': submitAllowed ?? this.submitAllowed,
      });
}

class Folder {
  final String id, name;
  Folder.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '';
}

class SchoolClass {
  final String id, name, ownerId;
  final bool unmanaged;
  final int members, teachers, createdAt;
  SchoolClass.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        ownerId = j['ownerId'] ?? '',
        unmanaged = j['unmanaged'] ?? false,
        members = j['members'] ?? 0,
        teachers = j['teachers'] ?? 0,
        createdAt = j['createdAt'] ?? 0;
}

class FileEntry {
  final String name, path, type, rev;
  final int size, modified;
  FileEntry.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        path = j['path'] ?? '',
        type = j['type'] ?? 'file',
        size = j['size'] ?? 0,
        modified = j['modified'] ?? 0,
        rev = j['rev'] ?? '';
  bool get isDir => type == 'dir';
}

class BackupList {
  final List<String> names;
  final int limit;
  BackupList.fromJson(Map<String, dynamic> j)
      : names = [for (final e in j['backups'] as List? ?? []) '$e'],
        limit = j['limit'] as int? ?? 5;
}

class SessionInfo {
  final String id, ip, ua;
  final int createdAt, expiresAt, lastSeen;
  final bool current;
  SessionInfo.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        ip = j['ip'] ?? '',
        ua = j['ua'] ?? '',
        createdAt = j['createdAt'] ?? 0,
        expiresAt = j['expiresAt'] ?? 0,
        lastSeen = j['lastSeen'] ?? 0,
        current = j['current'] == true;
}

class McpToken {
  final String id, name, token;
  final int createdAt, expiresAt, lastSeen;
  McpToken.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        token = j['token'] ?? '',
        createdAt = j['createdAt'] ?? 0,
        expiresAt = j['expiresAt'] ?? 0,
        lastSeen = j['lastSeen'] ?? 0;
}

class RenderJob {
  final String id, status, outputName, error, worker, mode;
  final double progress;
  final int createdAt, finishedAt;
  RenderJob.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        status = j['status'] ?? '',
        outputName = j['outputName'] ?? 'export',
        error = j['error'] ?? '',
        worker = j['worker'] ?? '',
        mode = j['mode'] ?? 'server',
        progress = (j['progress'] ?? 0).toDouble(),
        createdAt = j['createdAt'] ?? 0,
        finishedAt = j['finishedAt'] ?? 0;
  bool get active => status == 'queued' || status == 'running';
}

class RenderSeq {
  final int id;
  final String name;
  RenderSeq.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? 0,
        name = j['name'] ?? '';
}

class RenderInfo {
  final List<RenderSeq> sequences;
  final int? activeSequence;
  final bool serverRender, project;
  RenderInfo.fromJson(Map<String, dynamic> j)
      : sequences = [
          for (final s in (j['sequences'] as List? ?? [])) RenderSeq.fromJson(s)
        ],
        activeSequence = j['activeSequence'],
        serverRender = j['serverRender'] ?? false,
        project = j['project'] ?? false;
}

class RenderNode {
  final String id, name;
  final bool disabled;
  final int createdAt, lastSeen;
  RenderNode.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        disabled = j['disabled'] ?? false,
        createdAt = j['createdAt'] ?? 0,
        lastSeen = j['lastSeen'] ?? 0;
}

class ProjectComment {
  final String id,
      projectId,
      userId,
      username,
      displayName,
      avatar,
      body,
      parentId;
  final int createdAt, editedAt;
  ProjectComment.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        projectId = j['projectId'] ?? '',
        userId = j['userId'] ?? '',
        username = j['username'] ?? '',
        displayName = j['displayName'] ?? j['username'] ?? '',
        avatar = j['avatar'] ?? '',
        body = j['body'] ?? '',
        parentId = j['parentId'] ?? '',
        createdAt = j['createdAt'] ?? 0,
        editedAt = j['editedAt'] ?? 0;
  String get author => displayName.isEmpty ? username : displayName;
}

class Share {
  final String id,
      projectId,
      projectName,
      inviterUsername,
      inviteeId,
      inviteeUsername,
      inviteeName,
      level,
      status;
  final bool template;
  final int createdAt;
  Share.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        projectId = j['projectId'] ?? '',
        projectName = j['projectName'] ?? '',
        inviterUsername = j['inviterUsername'] ?? '',
        inviteeId = j['inviteeId'] ?? '',
        inviteeUsername = j['inviteeUsername'] ?? '',
        inviteeName = j['inviteeName'] ?? '',
        level = j['level'] ?? 'view',
        status = j['status'] ?? '',
        template = j['template'] ?? false,
        createdAt = j['createdAt'] ?? 0;
}

class AutoShare {
  final String id,
      inviteeId,
      inviteeUsername,
      inviteeName,
      ownerUsername,
      ownerName,
      level,
      status;
  final int createdAt;
  AutoShare.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        inviteeId = j['inviteeId'] ?? '',
        inviteeUsername = j['inviteeUsername'] ?? '',
        inviteeName = j['inviteeName'] ?? '',
        ownerUsername = j['ownerUsername'] ?? '',
        ownerName = j['ownerName'] ?? '',
        level = j['level'] ?? 'view',
        status = j['status'] ?? '',
        createdAt = j['createdAt'] ?? 0;
}

class Assignment {
  final String id, projectId, teacherId;
  final bool allowWithdraw, hidden, locked;
  final int maxSubmissions, dueAt, createdAt;
  Assignment.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        projectId = j['projectId'] ?? '',
        teacherId = j['teacherId'] ?? '',
        allowWithdraw = j['allowWithdraw'] ?? true,
        maxSubmissions = j['maxSubmissions'] ?? 0,
        dueAt = j['dueAt'] ?? 0,
        hidden = j['hidden'] ?? false,
        locked = j['locked'] ?? false,
        createdAt = j['createdAt'] ?? 0;
}

class AssignmentCopy {
  final String projectId, assignmentId, studentId;
  final int submissions;
  AssignmentCopy.fromJson(Map<String, dynamic> j)
      : projectId = j['projectId'] ?? '',
        assignmentId = j['assignmentId'] ?? '',
        studentId = j['studentId'] ?? '',
        submissions = j['submissions'] ?? 0;
}

class Submission {
  final String projectId, projectName, studentId, studentUsername, studentName;
  final String status;
  final int submittedAt, submissions;
  final bool late;
  Submission.fromJson(Map<String, dynamic> j)
      : projectId = j['projectId'] ?? '',
        projectName = j['projectName'] ?? '',
        studentId = j['studentId'] ?? '',
        studentUsername = j['studentUsername'] ?? '',
        studentName = j['studentName'] ?? '',
        status = j['status'] ?? 'draft',
        submittedAt = j['submittedAt'] ?? 0,
        submissions = j['submissions'] ?? 0,
        late = j['late'] ?? false;
}

class AssignmentInfo {
  final Assignment assignment;
  final AssignmentCopy? copy;
  final List<Submission> submissions;
  AssignmentInfo.fromJson(Map<String, dynamic> j)
      : assignment = Assignment.fromJson(j['assignment'] ?? {}),
        copy = j['copy'] == null ? null : AssignmentCopy.fromJson(j['copy']),
        submissions = [
          for (final e in (j['submissions'] ?? []) as List)
            Submission.fromJson(e)
        ];
}

class MyAssignment {
  final Assignment assignment;
  final AssignmentCopy copy;
  final String projectName, teacherName, status;
  MyAssignment.fromJson(Map<String, dynamic> j)
      : assignment = Assignment.fromJson(j),
        copy = AssignmentCopy.fromJson(j['copy'] ?? {}),
        projectName = j['projectName'] ?? '',
        teacherName = j['teacherName'] ?? '',
        status = j['status'] ?? 'draft';
}

class ShareLink {
  final String id, projectId, scope;
  final int createdAt, expiresAt;
  final bool revoked;
  ShareLink.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        projectId = j['projectId'] ?? '',
        scope = j['scope'] ?? 'project',
        createdAt = j['createdAt'] ?? 0,
        expiresAt = j['expiresAt'] ?? 0,
        revoked = j['revoked'] ?? false;
}

class AppNotification {
  final String id, kind;
  final Map<String, dynamic> payload;
  int readAt;
  final int createdAt;
  AppNotification.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        kind = j['kind'] ?? '',
        payload = (j['payload'] as Map?)?.cast<String, dynamic>() ?? {},
        readAt = j['readAt'] ?? 0,
        createdAt = j['createdAt'] ?? 0;
}

class Invite {
  final String id, role, presetUsername, presetName, usedBy;
  final String usedByUsername, usedByName;
  final int usedAt, expiresAt, createdAt;
  final bool revoked;
  Invite.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        role = j['role'] ?? '',
        presetUsername = j['presetUsername'] ?? '',
        presetName = j['presetName'] ?? '',
        usedBy = j['usedBy'] ?? '',
        usedByUsername = j['usedByUsername'] ?? '',
        usedByName = j['usedByName'] ?? j['usedByUsername'] ?? '',
        usedAt = j['usedAt'] ?? 0,
        expiresAt = j['expiresAt'] ?? 0,
        createdAt = j['createdAt'] ?? 0,
        revoked = j['revoked'] == true;
  bool expired(int now) => usedBy.isEmpty && !revoked && expiresAt <= now;
  bool pending(int now) => usedBy.isEmpty && !revoked && expiresAt > now;
}

class ServerSettings {
  final String trustedProxies;
  final int backupCount;
  bool enforceHttps;
  final bool enforceHttpsLocked;
  ServerSettings.fromJson(Map<String, dynamic> j)
      : trustedProxies = j['trustedProxies'] ?? '',
        backupCount = j['backupCount'] as int? ?? 5,
        enforceHttps = j['enforceHttps'] == true,
        enforceHttpsLocked = j['enforceHttpsLocked'] == true;
}

class StoragePool {
  final String id;
  final int used, total;
  StoragePool.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        used = j['used'] ?? 0,
        total = j['total'] ?? 0;
}

class StorageUser {
  final String id, username, name;
  final int bytes;
  StorageUser.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        username = j['username'] ?? '',
        name = j['name'] ?? '',
        bytes = j['bytes'] ?? 0;
}

class StorageStats {
  final List<StoragePool> pools;
  final List<StorageUser> users;
  StorageStats.fromJson(Map<String, dynamic> j)
      : pools = [for (final e in j['pools'] ?? []) StoragePool.fromJson(e)],
        users = [for (final e in j['users'] ?? []) StorageUser.fromJson(e)];
}

class AuditEntry {
  final int ts;
  final String actor, action, target, detail;
  AuditEntry.fromJson(Map<String, dynamic> j)
      : ts = j['ts'] ?? 0,
        actor = j['actorName'] ?? '',
        action = j['action'] ?? '',
        target = j['target'] ?? '',
        detail = j['detail'] ?? '';
}

class ShortcutAction {
  final String id, label, category;
  final List<String> menu;
  final List<ShortcutBinding> bindings;
  ShortcutAction.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        label = j['label'] ?? '',
        category = j['category'] ?? '',
        menu = [for (final m in (j['menu'] as List? ?? [])) '$m'],
        bindings = [
          for (final b in (j['shortcuts'] as List? ?? []))
            ShortcutBinding.fromJson(b)
        ];

  List<String?> get contexts =>
      {null, for (final b in bindings) b.panel}.toList();

  String defaultKeys(String? panel) =>
      bindings.where((b) => b.panel == panel).map((b) => b.keys).firstOrNull ??
      '';
}

class ShortcutBinding {
  final String keys;
  final String? panel;
  ShortcutBinding.fromJson(Map<String, dynamic> j)
      : keys = j['keys'] ?? '',
        panel = j['panel'] is String ? j['panel'] as String : null;
}

class Api {
  final uploads = UploadQueue();
  int chunkSize = 80 * 1048576;
  static Api i = Api();
  final http.Client _c;
  String csrf = '';
  User? user;
  Caps caps = Caps.none;

  /// Called once per request that gets a 401, after [user] is cleared.
  /// The app wires this to drop back to the gate/login screen.
  void Function()? onSignedOut;

  /// Called when the session token changes so native builds can persist it;
  /// '' means signed out.
  void Function(String token)? sessionChanged;

  Api([http.Client? client]) : _c = client ?? http.Client();

  String baseUrl = const String.fromEnvironment('WFM_API');
  String sessionToken = '';

  Uri _u(String p, [Map<String, String>? q]) => Uri.parse('$baseUrl/api$p')
      .replace(queryParameters: (q == null || q.isEmpty) ? null : q);

  Map<String, String> get _h => {
        'content-type': 'application/json',
        if (csrf.isNotEmpty) 'x-csrf-token': csrf,
        if (sessionToken.isNotEmpty) 'authorization': 'Bearer $sessionToken',
      };

  /// Headers for Image.network/NetworkImage so native builds send the bearer
  /// token on file and avatar URLs (web ignores them and uses cookies).
  Map<String, String> get imageHeaders => sessionToken.isEmpty
      ? const {}
      : {'authorization': 'Bearer $sessionToken'};

  Future<dynamic> _go(Future<http.Response> Function() send) async {
    final r = await send();
    dynamic body;
    try {
      body = r.body.isEmpty ? null : jsonDecode(r.body);
    } on FormatException {
      throw ApiException(r.statusCode, 'error ${r.statusCode}');
    }
    if (r.statusCode == 401) {
      if (user != null) {
        user = null;
        csrf = '';
        sessionToken = '';
        sessionChanged?.call('');
        onSignedOut?.call();
      }
      throw ApiException(401, 'auth');
    }
    if (r.statusCode >= 400) {
      throw ApiException(
          r.statusCode,
          body is Map ? '${body['error']}' : 'error ${r.statusCode}',
          body is Map && body['rev'] is String ? body['rev'] : null,
          body is Map ? Map<String, dynamic>.from(body) : null);
    }
    return body;
  }

  Future<dynamic> get(String p, [Map<String, String>? q]) =>
      _go(() => _c.get(_u(p, q), headers: _h));
  Future<dynamic> post(String p, Object? body, [Map<String, String>? q]) =>
      _go(() => _c.post(_u(p, q), headers: _h, body: jsonEncode(body ?? {})));
  Future<dynamic> patch(String p, Object? body) =>
      _go(() => _c.patch(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> put(String p, Object? body) =>
      _go(() => _c.put(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> del(String p, [Map<String, String>? q]) =>
      _go(() => _c.delete(_u(p, q), headers: _h));
  Future<dynamic> putFile(String p, Uint8List bytes, Map<String, String> q) =>
      _go(() => _c.put(_u(p, q), headers: _h, body: bytes));

  void _session(Map<String, dynamic> j) {
    csrf = j['csrf'] ?? csrf;
    sessionToken = j['token'] ?? sessionToken;
    if (j['token'] is String) sessionChanged?.call(sessionToken);
    user = User.fromJson(j['user'] ?? j);
  }

  Future<bool> needsSetup() async =>
      (await get('/setup'))['needsSetup'] == true;

  Future<User> setupOwner(String username, String password, String name,
      {String trustedProxies = ''}) async {
    _session(await post('/setup', {
      'username': username,
      'password': password,
      'name': name,
      if (trustedProxies.trim().isNotEmpty)
        'trustedProxies': trustedProxies.trim(),
    }));
    return user!;
  }

  Future<User> login(String username, String password) async {
    _session(
        await post('/login', {'username': username, 'password': password}));
    return user!;
  }

  Future<User?> me() async {
    try {
      _session(await get('/me'));
      return user;
    } on ApiException catch (e) {
      if (e.status == 401) return user = null;
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await post('/logout', {});
    } catch (_) {
    } finally {
      user = null;
      csrf = '';
      sessionToken = '';
      caps = Caps.none;
      sessionChanged?.call('');
    }
  }

  Future<Caps> roles() async => caps = Caps.fromJson(await get('/roles'));

  Future<List<SessionInfo>> sessions() async => [
        for (final s in (await get('/sessions')) as List)
          SessionInfo.fromJson(s)
      ];

  Future<void> revokeSession(String id) => del('/sessions/$id');

  String get mcpUrl {
    var origin = baseUrl;
    // coverage:ignore-start
    if (origin.isEmpty && Uri.base.scheme.startsWith('http')) {
      origin = Uri.base.origin;
    }
    // coverage:ignore-end
    return '$origin/api/mcp';
  }

  Future<List<McpToken>> mcpTokens() async => [
        for (final t in (await get('/mcp/tokens')) as List) McpToken.fromJson(t)
      ];

  Future<McpToken> mcpTokenCreate(String name) async =>
      McpToken.fromJson(await post('/mcp/tokens', {'name': name}));

  Future<void> mcpTokenDelete(String id) => del('/mcp/tokens/$id');

  Future<String> serverVersion() async =>
      '${(await get('/version'))['version'] ?? ''}';

  Future<ServerSettings> serverSettings() async =>
      ServerSettings.fromJson(await get('/settings'));

  Future<void> saveSettings(String trustedProxies) =>
      put('/settings', {'trustedProxies': trustedProxies});

  Future<void> saveEnforceHttps(bool enforce) async {
    final s = await serverSettings();
    await put('/settings', {
      'trustedProxies': s.trustedProxies,
      'enforceHttps': enforce,
    });
  }

  Future<void> saveBackupCount(int count) async {
    final s = await serverSettings();
    await put('/settings', {
      'trustedProxies': s.trustedProxies,
      'backupCount': count,
    });
  }

  Future<List<Project>> projects() async =>
      [for (final e in (await get('/projects')) as List) Project.fromJson(e)];

  Future<Project> project(String id) async =>
      Project.fromJson(await get('/projects/$id'));

  Future<Project> createProject(String name, {String folderId = ''}) async =>
      Project.fromJson(await post('/projects', {
        'name': name,
        'displayName': name,
        if (folderId.isNotEmpty) 'folderId': folderId,
      }));

  Future<void> updateProject(String id,
          {String? displayName,
          String? folderId,
          bool? pinned,
          bool? template}) =>
      patch('/projects/$id', {
        if (displayName != null) 'displayName': displayName,
        if (folderId != null) 'folderId': folderId,
        if (pinned != null) 'pinned': pinned,
        if (template != null) 'template': template,
      });

  Future<Project> duplicateProject(String id) async =>
      Project.fromJson(await post('/projects/$id/duplicate', {}));

  Future<List<ProjectComment>> comments(String pid) async => [
        for (final e in (await get('/projects/$pid/comments')) as List)
          ProjectComment.fromJson(e)
      ];

  Future<void> addComment(String pid, String body, {String parentId = ''}) =>
      post('/projects/$pid/comments',
          {'body': body, if (parentId.isNotEmpty) 'parentId': parentId});

  Future<void> editComment(String pid, String cid, String body) =>
      patch('/projects/$pid/comments/$cid', {'body': body});

  Future<void> deleteComment(String pid, String cid) =>
      del('/projects/$pid/comments/$cid');

  Future<String> submitProject(String id) async =>
      '${(await post('/projects/$id/submit', {}))['status'] ?? 'submitted'}';

  Future<void> setSubmitAllowed(String id, bool allowed) =>
      post('/projects/$id/submit-allowed', {'allowed': allowed});

  Future<void> wipeAudit(String scope) => del('/audit?scope=$scope');

  Future<StorageStats> storageStats() async =>
      StorageStats.fromJson(await get('/storage'));

  Future<String> reviewProject(String id, String status) async =>
      '${(await post('/projects/$id/review', {
                'status': status
              }))['status'] ?? status}';

  Future<Map<String, dynamic>> assignProject(
          String id, Map<String, dynamic> body) async =>
      (await post('/projects/$id/assign', body)) as Map<String, dynamic>;

  Future<AssignmentInfo?> projectAssignment(String id) async {
    try {
      return AssignmentInfo.fromJson(
          (await get('/projects/$id/assignment')) as Map<String, dynamic>);
    } on ApiException {
      return null;
    }
  }

  Future<Assignment> updateAssignment(
          String id, Map<String, dynamic> body) async =>
      Assignment.fromJson(
          (await patch('/assignments/$id', body)) as Map<String, dynamic>);

  Future<void> deleteAssignment(String id) => del('/assignments/$id');

  Future<List<MyAssignment>> myAssignments() async => [
        for (final e in (await get('/assignments')) as List)
          MyAssignment.fromJson(e)
      ];

  Future<List<ShortcutAction>> shortcutCatalog(
          [String app = 'filmcraft']) async =>
      [
        for (final e in (await get('/shortcuts/catalog?app=$app')) as List)
          ShortcutAction.fromJson(e)
      ];

  Future<Map<String, String>> shortcuts() async =>
      Map<String, String>.from((await get('/shortcuts'))['bindings'] ?? {});

  Future<void> saveShortcuts(Map<String, String> bindings) =>
      put('/shortcuts', {'bindings': bindings});

  Future<List<Folder>> folders() async =>
      [for (final e in (await get('/folders')) as List) Folder.fromJson(e)];

  Future<Folder> createFolder(String name) async =>
      Folder.fromJson(await post('/folders', {'name': name}));

  Future<void> renameFolder(String id, String name) =>
      patch('/folders/$id', {'name': name});

  Future<void> deleteAccount(String id) => del('/accounts/$id');

  Future<void> deleteFolder(String id) => del('/folders/$id');

  Future<void> deleteProject(String id) => del('/projects/$id');

  /// (acquired, holder): holder names whoever holds the lock when it is not
  /// acquired, for the take-over prompt.
  Future<(bool, String)> lockAcquire(String pid, String kind, String clientId,
      {bool force = false}) async {
    try {
      await post('/projects/$pid/locks',
          {'kind': kind, 'clientId': clientId, 'force': force});
      return (true, '');
    } on ApiException catch (e) {
      if (e.status == 409) {
        final lock = e.body?['lock'];
        final holder = lock is Map ? '${lock['holder'] ?? ''}' : e.message;
        return (false, holder);
      }
      rethrow;
    }
  }

  Future<bool> lockHeartbeat(String pid, String kind, String clientId) async {
    try {
      await post('/projects/$pid/locks/heartbeat',
          {'kind': kind, 'clientId': clientId});
      return true;
    } on ApiException catch (e) {
      if (e.status == 409 || e.status == 404) return false;
      rethrow;
    }
  }

  Future<void> lockRelease(String pid, String kind, String clientId) =>
      del('/projects/$pid/locks', {'kind': kind, 'clientId': clientId});

  Future<List<FileEntry>> files(String pid, String path) async => [
        for (final e
            in (await get('/projects/$pid/files', {'path': path})) as List)
          FileEntry.fromJson(e)
      ];

  Future<List<FileEntry>> manifest(String pid) async => [
        for (final e in (await get('/projects/$pid/manifest')) as List)
          FileEntry.fromJson(e)
      ];

  Future<BackupList> backups(String pid) async =>
      BackupList.fromJson(await get('/projects/$pid/backups'));

  Future<void> createBackup(String pid, String app, String path,
          {bool replaceOldest = false}) =>
      post('/projects/$pid/backups',
          {'app': app, 'path': path, 'replaceOldest': replaceOldest});

  Future<void> upload(String pid, String path, Uint8List bytes,
      {String clientId = '', String base = ''}) async {
    if (bytes.length <= chunkSize) {
      return putFile('/projects/$pid/files', bytes,
          {'path': path, 'clientId': clientId, 'base': base});
    }
    await uploadChunked(pid, path, bytes.length,
        (a, b) async => bytes.sublist(a, b), null, clientId, base);
  }

  Future<String> uploadStart(String pid, String path,
          {String clientId = '', String base = ''}) async =>
      '${(await post('/projects/$pid/files/upload', {
            'path': path,
            'clientId': clientId,
            'base': base
          }))['id']}';

  Future<void> uploadChunk(String uid, int offset, Uint8List bytes) =>
      putFile('/uploads/$uid/chunk', bytes, {'offset': '$offset'});

  Future<int> uploadReceived(String uid) async =>
      (await get('/uploads/$uid'))['received'];

  Future<void> uploadFinish(String uid) => post('/uploads/$uid/complete', {});

  Future<void> uploadAbort(String uid) => del('/uploads/$uid');

  Future<void> uploadChunked(String pid, String path, int total,
      Future<Uint8List> Function(int start, int end) slice,
      [void Function(int sent, int total)? onProgress,
      String clientId = '',
      String base = '']) async {
    final uid = await uploadStart(pid, path, clientId: clientId, base: base);
    var off = 0;
    var size = chunkSize;
    try {
      while (off < total) {
        final end = math.min(off + size, total);
        try {
          await uploadChunk(uid, off, await slice(off, end));
          off = end;
          onProgress?.call(off, total);
        } on ApiException catch (e) {
          if (e.status == 413 && size > 1048576) {
            size ~/= 2;
          } else {
            rethrow;
          }
        }
      }
      await uploadFinish(uid);
    } catch (_) {
      try {
        await uploadAbort(uid);
      } catch (_) {}
      rethrow;
    }
  }

  String avatarUrl(String uid, String key) =>
      '$baseUrl/api/users/$uid/avatar?v=${Uri.encodeComponent(key)}';

  Future<void> uploadAvatar(Uint8List bytes) =>
      putFile('/me/avatar', bytes, {});

  Future<void> mkdir(String pid, String path, {String clientId = ''}) =>
      post('/projects/$pid/files/mkdir', {'path': path, 'clientId': clientId});

  Future<void> move(String pid, String from, String to,
          {String clientId = '', String base = ''}) =>
      post('/projects/$pid/files/move',
          {'from': from, 'to': to, 'clientId': clientId, 'base': base});

  String zipUrl(String pid, List<String> paths) =>
      '$baseUrl/api/projects/$pid/zip?paths=${paths.map(Uri.encodeComponent).join(',')}';

  Future<void> deleteFile(String pid, String path,
          {String clientId = '', String base = ''}) =>
      del('/projects/$pid/files',
          {'path': path, 'clientId': clientId, 'base': base});

  String projectUrl(String pid, {String? theme}) =>
      '$baseUrl/filmcraft/wfm.html?project=$pid${theme == null ? '' : '&theme=$theme'}';

  String scriptUrl(String pid, {String? theme}) =>
      '$baseUrl/scriptcraft/wfm.html?project=$pid${theme == null ? '' : '&theme=$theme'}';

  String deckUrl(String pid, {String? theme}) =>
      '$baseUrl/deckcraft/wfm.html?project=$pid${theme == null ? '' : '&theme=$theme'}';

  String renderUrl(String pid, String rid, {String? theme}) =>
      '$baseUrl/filmcraft/wfm.html?project=$pid&render=$rid${theme == null ? '' : '&theme=$theme'}';

  Future<String> handoffUrl(String to) async =>
      '$baseUrl/api/handoff?t=${(await post('/handoff', {
            'to': to
          }))['t']}&to=${Uri.encodeComponent(to)}';

  Future<RenderInfo> renderInfo(String pid) async =>
      RenderInfo.fromJson(await get('/projects/$pid/render-info'));
  String thumbUrl(String pid, String path) =>
      '$baseUrl/api/projects/$pid/thumb?path=${Uri.encodeComponent(path)}';

  String downloadUrl(String pid, String path, {bool dl = false}) =>
      '$baseUrl/api/projects/$pid/download?path=${Uri.encodeComponent(path)}${dl ? '&dl=true' : ''}';

  /// Streamed download into [sink] so large media never sits in memory.
  Future<void> downloadInto(
      String pid, String path, StreamConsumer<List<int>> sink) async {
    final req =
        http.Request('GET', _u('/projects/$pid/download', {'path': path}))
          ..headers.addAll(_h);
    final r = await _c.send(req);
    if (r.statusCode == 401) {
      if (user != null) {
        user = null;
        csrf = '';
        sessionToken = '';
        sessionChanged?.call('');
        onSignedOut?.call();
      }
      throw ApiException(401, 'auth');
    }
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, 'error ${r.statusCode}');
    }
    await r.stream.pipe(sink);
  }

  Future<List<RenderJob>> renders(String pid,
          {int offset = 0, int limit = 50}) async =>
      [
        for (final e
            in (await get('/projects/$pid/renders?offset=$offset&limit=$limit'))
                as List)
          RenderJob.fromJson(e)
      ];

  Future<RenderJob> createRender(String pid, Map<String, dynamic> spec) async =>
      RenderJob.fromJson(await post('/projects/$pid/renders', spec));

  Future<void> cancelRender(String id) => post('/renders/$id/cancel', {});

  Future<void> takeOverProject(String id) =>
      post('/projects/$id/take-over', {});

  Future<RenderJob> retryRender(String id) async =>
      RenderJob.fromJson(await post('/renders/$id/retry', {}));

  Future<void> deleteRender(String id) => del('/renders/$id');

  Future<List<User>> accounts() async =>
      [for (final e in (await get('/accounts')) as List) User.fromJson(e)];

  Future<List<User>> shareTargets() async =>
      [for (final e in (await get('/share-targets')) as List) User.fromJson(e)];

  Future<List<SchoolClass>> classes() async => [
        for (final e in (await get('/classes')) as List) SchoolClass.fromJson(e)
      ];

  Future<SchoolClass> classCreate(String name) async =>
      SchoolClass.fromJson(await post('/classes', {'name': name}));

  Future<void> classRename(String id, String name) =>
      patch('/classes/$id', {'name': name});

  Future<void> classDelete(String id) => del('/classes/$id');

  Future<List<User>> classTeachers(String id) async => [
        for (final e in (await get('/classes/$id/teachers')) as List)
          User.fromJson(e)
      ];

  Future<User> classTeacherAdd(String id, String username) async =>
      User.fromJson(
          await post('/classes/$id/teachers', {'username': username}));

  Future<void> classTeacherRemove(String id, String uid) =>
      del('/classes/$id/teachers/$uid');

  Future<User> createAccount(Map<String, dynamic> body) async =>
      User.fromJson(await post('/accounts', body));

  Future<int> projectUsage(String id) async =>
      (await get('/projects/$id/usage'))['bytes'] ?? 0;

  Future<int> accountUsage(String id) async =>
      (await get('/accounts/$id/usage'))['bytes'] ?? 0;

  Future<List<Project>> accountProjects(String id) async => [
        for (final e in (await get('/accounts/$id/projects')) as List)
          Project.fromJson(e)
      ];

  Future<User> updateAccount(String id, Map<String, dynamic> body) async =>
      User.fromJson(await patch('/accounts/$id', body));

  Future<void> resetPassword(String id, String password) =>
      post('/accounts/$id/password', {'password': password});

  Future<void> setDisabled(String id, bool disabled) =>
      post('/accounts/$id/status', {'disabled': disabled});

  Future<void> changePassword(String current, String next) =>
      post('/me/password', {'current': current, 'next': next});

  Future<List<Share>> projectShares(String pid) async => [
        for (final e in (await get('/projects/$pid/shares')) as List)
          Share.fromJson(e)
      ];

  Future<void> shareProject(String pid, String username, String level) =>
      post('/projects/$pid/shares', {'username': username, 'level': level});

  Future<void> shareLevel(String pid, String sid, String level) =>
      patch('/projects/$pid/shares/$sid', {'level': level});

  Future<void> shareRevoke(String pid, String sid) =>
      del('/projects/$pid/shares/$sid');

  Future<List<Share>> shares() async =>
      [for (final e in (await get('/shares')) as List) Share.fromJson(e)];

  Future<List<AutoShare>> autoShares() async => [
        for (final e in (await get('/auto-shares')) as List)
          AutoShare.fromJson(e)
      ];

  Future<void> autoShareAdd(String username, String level) =>
      post('/auto-shares', {'username': username, 'level': level});

  Future<void> autoShareDelete(String id) => del('/auto-shares/$id');

  Future<List<AutoShare>> autoSharesIncoming() async => [
        for (final e in (await get('/auto-shares/incoming')) as List)
          AutoShare.fromJson(e)
      ];

  Future<void> autoShareRespond(String id, bool accept) =>
      post('/auto-shares/$id/${accept ? 'accept' : 'decline'}', {});

  Future<void> shareLeave(String sid) => del('/shares/$sid');

  Future<void> shareRespond(String sid, bool accept) =>
      post('/shares/$sid/${accept ? 'accept' : 'decline'}', {});

  Future<(List<AppNotification>, int)> notifications(
      {int before = 0, int limit = 50}) async {
    final j = await get('/notifications?before=$before&limit=$limit')
        as Map<String, dynamic>;
    return (
      [for (final e in (j['list'] as List? ?? [])) AppNotification.fromJson(e)],
      (j['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<Map<String, dynamic>> linkCreate(String pid, String scope,
          {int expiresAt = 0}) async =>
      (await post(
              '/projects/$pid/links', {'scope': scope, 'expiresAt': expiresAt}))
          as Map<String, dynamic>;

  Future<List<ShareLink>> projectLinks(String pid) async => [
        for (final e in (await get('/projects/$pid/links')) as List)
          ShareLink.fromJson(e)
      ];

  Future<void> linkRevoke(String pid, String lid) =>
      del('/projects/$pid/links/$lid');

  Future<Map<String, dynamic>> linkResolve(String token) async =>
      (await get('/link/$token')) as Map<String, dynamic>;

  String linkFileUrl(String token, String path) =>
      '$baseUrl/api/link/$token/file?path=${Uri.encodeComponent(path)}';

  Future<int> notificationsUnread() async {
    final j = await get('/notifications?limit=1') as Map<String, dynamic>;
    return (j['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> notificationRead(String id) =>
      post('/notifications/$id/read', {});

  Future<void> notificationsReadAll() => post('/notifications/read-all', {});

  Future<List<Invite>> invites() async =>
      [for (final e in (await get('/invites')) as List) Invite.fromJson(e)];

  Future<String> inviteCreate(String role,
          {String username = '', String name = ''}) async =>
      '${(await post('/invites', {
            'role': role,
            'username': username,
            'name': name
          }))['code']}';

  Future<void> inviteRevoke(String id) => del('/invites/$id');

  Future<Map<String, dynamic>> inviteGet(String code) async =>
      Map<String, dynamic>.from(await get('/invites/$code'));

  Future<void> inviteRedeem(
          String code, String username, String name, String password) async =>
      _session(Map<String, dynamic>.from(await post('/invites/$code/redeem',
          {'username': username, 'name': name, 'password': password})));

  Future<List<AuditEntry>> audit(
          {String scope = 'account',
          int limit = 200,
          int offset = 0,
          String action = '',
          String actor = '',
          int from = 0,
          int to = 0}) async =>
      [
        for (final e in (await get('/audit', {
          'scope': scope,
          'limit': '$limit',
          'offset': '$offset',
          'action': action,
          'actor': actor,
          'from': '$from',
          'to': '$to',
        })) as List)
          AuditEntry.fromJson(e)
      ];

  Future<List<RenderNode>> nodes() async =>
      [for (final e in (await get('/nodes')) as List) RenderNode.fromJson(e)];

  Future<Map<String, dynamic>> createNode(String name) async =>
      Map<String, dynamic>.from(await post('/nodes', {'name': name}));

  Future<void> setNodeDisabled(String id, bool disabled) =>
      patch('/nodes/$id', {'disabled': disabled});

  Future<void> deleteNode(String id) => del('/nodes/$id');
}
