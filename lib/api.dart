import 'dart:convert';
import 'package:fetch_client/fetch_client.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class User {
  final String id, username, name, role;
  final bool disabled;
  final String studentId, note;
  User.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        username = j['username'] ?? '',
        name = j['name'] ?? j['displayName'] ?? '',
        role = j['role'] ?? 'student',
        disabled = j['disabled'] ?? false,
        studentId = j['studentId'] ?? '',
        note = j['note'] ?? '';

  static const ranks = {
    'student': 0,
    'mod': 1,
    'teacher': 2,
    'admin': 3,
    'owner': 4,
  };
  int get rank => ranks[role] ?? 0;
  bool get canManage => rank >= ranks['teacher']!;
}

class Project {
  final String id, name, displayName;
  Project.fromJson(Map<String, dynamic> j)
      : id = j['id'] ?? '',
        name = j['name'] ?? '',
        displayName = j['displayName'] ?? j['display_name'] ?? j['name'] ?? '';
}

class Api {
  static final Api i = Api._();
  late final http.Client _c;
  String csrf = '';
  User? user;

  Api._() {
    _c = FetchClient(mode: RequestMode.cors, credentials: RequestCredentials.sameOrigin);
  }

  Uri _u(String p, [Map<String, String>? q]) =>
      Uri(path: '/api$p', queryParameters: (q == null || q.isEmpty) ? null : q);

  Map<String, String> get _h => {
        'content-type': 'application/json',
        if (csrf.isNotEmpty) 'x-csrf-token': csrf,
      };

  Future<dynamic> _go(Future<http.Response> Function() send) async {
    final r = await send();
    final body = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode == 401) {
      user = null;
      throw ApiException(401, 'auth');
    }
    if (r.statusCode >= 400) {
      throw ApiException(r.statusCode, body is Map ? '${body['error']}' : 'error ${r.statusCode}');
    }
    return body;
  }

  Future<dynamic> get(String p, [Map<String, String>? q]) => _go(() => _c.get(_u(p, q)));
  Future<dynamic> post(String p, Object? body, [Map<String, String>? q]) =>
      _go(() => _c.post(_u(p, q), headers: _h, body: jsonEncode(body)));
  Future<dynamic> patch(String p, Object? body) =>
      _go(() => _c.patch(_u(p), headers: _h, body: jsonEncode(body)));
  Future<dynamic> delete(String p, [Map<String, String>? q]) => _go(() => _c.delete(_u(p, q)));
  Future<dynamic> putFile(String p, List<int> bytes, Map<String, String> q) =>
      _go(() => _c.put(_u(p, q), body: bytes));

  Future<bool> needsSetup() async => (await get('/setup'))['needsSetup'] == true;

  Future<User> setupOwner(String username, String password, String name) async {
    final j = await post('/setup', {'username': username, 'password': password, 'name': name});
    csrf = j['csrf'] ?? '';
    return user = User.fromJson(j['user']);
  }

  Future<User> login(String username, String password) async {
    final j = await post('/login', {'username': username, 'password': password});
    csrf = j['csrf'] ?? '';
    return user = User.fromJson(j['user']);
  }

  Future<User?> me() async {
    try {
      final j = await get('/me');
      csrf = j['csrf'] ?? csrf;
      return user = User.fromJson(j);
    } on ApiException {
      return user = null;
    }
  }

  Future<void> logout() async {
    try {
      await post('/logout', {});
    } finally {
      user = null;
      csrf = '';
    }
  }

  Future<List<Project>> projects() async =>
      ((await get('/projects')) as List).map((e) => Project.fromJson(e)).toList();

  Future<Project> createProject(String name, [String? display]) async =>
      Project.fromJson(await post('/projects', {'name': name, 'displayName': display ?? name}));

  Future<List<dynamic>> files(String pid, String path) async =>
      (await get('/projects/$pid/files', {'path': path})) as List;

  String projectUrl(String pid) => '/filmcraft/wfm.html?project=$pid';
  String downloadUrl(String pid, String path) =>
      '/api/projects/$pid/download?path=${Uri.encodeComponent(path)}';

  Future<List<User>> accounts() async =>
      ((await get('/accounts')) as List).map((e) => User.fromJson(e)).toList();

  Future<List<String>> roles() async =>
      ((await get('/roles')) as List).map((e) => e.toString()).toList();

  Future<User> createAccount(Map<String, dynamic> body) async =>
      User.fromJson(await post('/accounts', body));

  Future<void> resetPassword(String id, String password) async =>
      post('/accounts/$id/password', {'password': password});

  Future<void> setDisabled(String id, bool disabled) async =>
      post('/accounts/$id/status', {'disabled': disabled});
}
