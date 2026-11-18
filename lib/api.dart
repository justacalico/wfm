import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class User {
  final String id, username, name, role, studentId, note;
  final bool disabled;
  final int createdAt, lastLogin;
  User.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        username = j['username'] ?? '',
        name = j['displayName'] ?? '',
        role = j['role'] ?? 'student',
        disabled = j['disabled'] ?? false,
        studentId = j['studentId'] ?? '',
        note = j['note'] ?? '',
        createdAt = j['createdAt'] ?? 0,
        lastLogin = j['lastLogin'] ?? 0;

  static const ranks = {
    'student': 0,
    'mod': 1,
    'teacher': 2,
    'admin': 3,
    'owner': 4,
  };
  int get rank => ranks[role] ?? 0;
  bool get isAdmin => rank >= ranks['admin']!;
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
  final String id, name, displayName, groupId;
  final List<String> tags;
  final int createdAt, lastActivity;
  final bool pinned;
  Project.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        displayName = j['displayName'] ?? j['name'] ?? '',
        groupId = j['groupId'] ?? '',
        tags = [for (final t in (j['tags'] ?? []) as List) '$t'],
        createdAt = j['createdAt'] ?? 0,
        lastActivity = j['lastActivity'] ?? j['createdAt'] ?? 0,
        pinned = j['pinned'] ?? false;
}

class ProjectGroup {
  final String id, name;
  ProjectGroup.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '';
}

class FileEntry {
  final String name, path, type;
  final int size, modified;
  FileEntry.fromJson(Map<String, dynamic> j)
      : name = j['name'] ?? '',
        path = j['path'] ?? '',
        type = j['type'] ?? 'file',
        size = j['size'] ?? 0,
        modified = j['modified'] ?? 0;
  bool get isDir => type == 'dir';
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

class Api {
  static Api i = Api();
  final http.Client _c;
  String csrf = '';
  User? user;
  Caps caps = Caps.none;

  /// Called once per request that gets a 401, after [user] is cleared.
  /// The app wires this to drop back to the gate/login screen.
  void Function()? onSignedOut;

  Api([http.Client? client]) : _c = client ?? http.Client();

  static const _base = String.fromEnvironment('WFM_API');

  Uri _u(String p, [Map<String, String>? q]) => Uri.parse('$_base/api$p')
      .replace(queryParameters: (q == null || q.isEmpty) ? null : q);

  Map<String, String> get _h => {
        'content-type': 'application/json',
        if (csrf.isNotEmpty) 'x-csrf-token': csrf,
      };

  Future<dynamic> _go(Future<http.Response> Function() send) async {
    final r = await send();
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode == 401) {
      if (user != null) {
        user = null;
        onSignedOut?.call();
      }
      throw ApiException(401, 'auth');
    }
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode,
          body is Map ? '${body['error']}' : 'error ${r.statusCode}');
    }
    return body;
  }

  Future<dynamic> get(String p, [Map<String, String>? q]) =>
      _go(() => _c.get(_u(p, q)));
  Future<dynamic> post(String p, Object? body, [Map<String, String>? q]) =>
      _go(() => _c.post(_u(p, q), headers: _h, body: jsonEncode(body ?? {})));
  Future<dynamic> patch(String p, Object? body) =>
      _go(() => _c.patch(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> put(String p, Object? body) =>
      _go(() => _c.put(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> del(String p, [Map<String, String>? q]) =>
      _go(() => _c.delete(_u(p, q), headers: _h));
  Future<dynamic> putFile(String p, Uint8List bytes, Map<String, String> q) =>
      _go(() => _c.put(_u(p, q),
          headers: {if (csrf.isNotEmpty) 'x-csrf-token': csrf}, body: bytes));

  void _session(Map<String, dynamic> j) {
    csrf = j['csrf'] ?? csrf;
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
      caps = Caps.none;
    }
  }

  Future<Caps> roles() async => caps = Caps.fromJson(await get('/roles'));

  Future<String> serverVersion() async =>
      '${(await get('/version'))['version'] ?? ''}';

  Future<String> serverSettings() async =>
      '${(await get('/settings'))['trustedProxies'] ?? ''}';

  Future<void> saveSettings(String trustedProxies) =>
      put('/settings', {'trustedProxies': trustedProxies});

  Future<List<Project>> projects() async =>
      [for (final e in (await get('/projects')) as List) Project.fromJson(e)];

  Future<Project> createProject(String name, {String groupId = ''}) async =>
      Project.fromJson(await post('/projects', {
        'name': name,
        'displayName': name,
        if (groupId.isNotEmpty) 'groupId': groupId,
      }));

  Future<void> updateProject(String id,
          {String? displayName,
          String? groupId,
          List<String>? tags,
          bool? pinned}) =>
      patch('/projects/$id', {
        if (displayName != null) 'displayName': displayName,
        if (groupId != null) 'groupId': groupId,
        if (tags != null) 'tags': tags,
        if (pinned != null) 'pinned': pinned,
      });

  Future<List<ProjectGroup>> groups() async => [
        for (final e in (await get('/groups')) as List) ProjectGroup.fromJson(e)
      ];

  Future<ProjectGroup> createGroup(String name) async =>
      ProjectGroup.fromJson(await post('/groups', {'name': name}));

  Future<void> renameGroup(String id, String name) =>
      patch('/groups/$id', {'name': name});

  Future<void> deleteAccount(String id) => del('/accounts/$id');

  Future<void> deleteGroup(String id) => del('/groups/$id');

  Future<void> deleteProject(String id) => del('/projects/$id');

  Future<List<FileEntry>> files(String pid, String path) async => [
        for (final e
            in (await get('/projects/$pid/files', {'path': path})) as List)
          FileEntry.fromJson(e)
      ];

  Future<void> upload(String pid, String path, Uint8List bytes) =>
      putFile('/projects/$pid/files', bytes, {'path': path});

  Future<void> mkdir(String pid, String path) =>
      post('/projects/$pid/files/mkdir', {'path': path});

  Future<void> move(String pid, String from, String to) =>
      post('/projects/$pid/files/move', {'from': from, 'to': to});

  Future<void> deleteFile(String pid, String path) =>
      del('/projects/$pid/files', {'path': path});

  String projectUrl(String pid, {String? theme}) =>
      '/filmcraft/wfm.html?project=$pid${theme == null ? '' : '&theme=$theme'}';

  String renderUrl(String pid, String rid, {String? theme}) =>
      '/filmcraft/wfm.html?project=$pid&render=$rid${theme == null ? '' : '&theme=$theme'}';

  Future<RenderInfo> renderInfo(String pid) async =>
      RenderInfo.fromJson(await get('/projects/$pid/render-info'));
  String downloadUrl(String pid, String path, {bool dl = false}) =>
      '$_base/api/projects/$pid/download?path=${Uri.encodeComponent(path)}${dl ? '&dl=true' : ''}';

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

  Future<RenderJob> retryRender(String id) async =>
      RenderJob.fromJson(await post('/renders/$id/retry', {}));

  Future<void> deleteRender(String id) => del('/renders/$id');

  Future<List<User>> accounts() async =>
      [for (final e in (await get('/accounts')) as List) User.fromJson(e)];

  Future<User> createAccount(Map<String, dynamic> body) async =>
      User.fromJson(await post('/accounts', body));

  Future<User> updateAccount(String id, Map<String, dynamic> body) async =>
      User.fromJson(await patch('/accounts/$id', body));

  Future<void> resetPassword(String id, String password) =>
      post('/accounts/$id/password', {'password': password});

  Future<void> setDisabled(String id, bool disabled) =>
      post('/accounts/$id/status', {'disabled': disabled});

  Future<void> changePassword(String current, String next) =>
      post('/me/password', {'current': current, 'next': next});

  Future<List<AuditEntry>> audit(
          {String scope = 'account', int limit = 200}) async =>
      [
        for (final e
            in (await get('/audit', {'scope': scope, 'limit': '$limit'}))
                as List)
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
