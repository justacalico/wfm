import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wfm/api.dart';
import 'helpers.dart';

FakeClient client(Map<String, dynamic> canned) => FakeClient(apiRoutes(canned));

void main() {
  group('models', () {
    test('ApiException', () {
      final e = ApiException(403, 'nope');
      expect(e.status, 403);
      expect('$e', 'nope');
    });

    test('User parses fallbacks and rank', () {
      final u = User.fromJson({});
      expect(u.role, 'student');
      expect(u.rank, 0);
      expect(u.isAdmin, isFalse);
      expect(u.isOwner, isFalse);
      expect(u.name, '');
      final w = User.fromJson({'role': 'weird'});
      expect(w.rank, 0);
      final o = User.fromJson({'id': 'x', 'role': 'owner', 'lastLogin': 5});
      expect(o.isOwner, isTrue);
      expect(o.isAdmin, isTrue);
      final m = User.fromJson({'role': 'mod'});
      expect(m.rank, 1);
      final t = User.fromJson({'role': 'teacher'});
      expect(t.rank, 2);
      final a = User.fromJson(
          {'role': 'admin', 'disabled': true, 'studentId': 'S1', 'note': 'n'});
      expect(a.rank, 3);
      expect(a.disabled, isTrue);
      expect(a.studentId, 'S1');
    });

    test('Caps', () {
      expect(Caps.none.manage, isFalse);
      expect(Caps.none.creatable, isEmpty);
      final c = Caps.fromJson({
        'creatable': ['student'],
        'canManage': true,
        'canAudit': true
      });
      expect(c.creatable, ['student']);
      expect(c.manage, isTrue);
      expect(c.audit, isTrue);
      final d = Caps.fromJson({});
      expect(d.manage, isFalse);
    });

    test('Project/FileEntry/RenderJob/RenderNode/AuditEntry', () {
      expect(Project.fromJson({}).displayName, '');
      expect(Project.fromJson({'name': 'n'}).displayName, 'n');
      final f = FileEntry.fromJson({'name': 'x', 'type': 'dir'});
      expect(f.isDir, isTrue);
      expect(FileEntry.fromJson({}).isDir, isFalse);
      final r = RenderJob.fromJson({'status': 'running', 'progress': 1});
      expect(r.active, isTrue);
      expect(RenderJob.fromJson({'status': 'queued'}).active, isTrue);
      expect(RenderJob.fromJson({}).active, isFalse);
      expect(r.progress, 1.0);
      expect(RenderNode.fromJson({}).name, '');
      final a = AuditEntry.fromJson({
        'ts': 1,
        'actorName': 'x',
        'action': 'y',
        'target': 'z',
        'detail': 'd'
      });
      expect(a.actor, 'x');
      expect(a.detail, 'd');
    });
  });

  group('Api', () {
    test('needsSetup', () async {
      final api = Api(client({
        'GET /api/setup': {'needsSetup': true}
      }));
      expect(await api.needsSetup(), isTrue);
      final api2 = Api(client({
        'GET /api/setup': {'needsSetup': false}
      }));
      expect(await api2.needsSetup(), isFalse);
    });

    test('setupOwner with and without proxies', () async {
      final bodies = <String>[];
      final c = FakeClient({
        'POST /api/setup': (req) {
          bodies.add(req.body);
          return {'csrf': 't', 'user': userJson};
        },
      });
      final api = Api(c);
      final u = await api.setupOwner('ada', 'pw', 'Ada',
          trustedProxies: ' 10.0.0.0/8 ');
      expect(u.username, 'ada');
      expect(api.csrf, 't');
      expect(jsonDecode(bodies.single)['trustedProxies'], '10.0.0.0/8');
      await api.setupOwner('ada', 'pw', 'Ada', trustedProxies: '  ');
      expect(jsonDecode(bodies.last).containsKey('trustedProxies'), isFalse);
      await api.setupOwner('a', 'b', 'c');
      expect(jsonDecode(bodies.last).containsKey('trustedProxies'), isFalse);
    });

    test('login/me/logout', () async {
      final api = Api(client({
        'POST /api/login': {'csrf': 'x', 'user': userJson},
        'GET /api/me': {'csrf': 'x', 'user': userJson},
        'POST /api/logout': {'ok': true},
      }));
      await api.login('ada', 'pw');
      expect(api.user?.username, 'ada');
      expect(api.csrf, 'x');
      expect(await api.me(), isNotNull);
      await api.logout();
      expect(api.user, isNull);
      expect(api.csrf, '');
      expect(api.caps.manage, isFalse);
    });

    test('me returns null on 401 and logout swallows errors', () async {
      final api = Api(client({
        'GET /api/me': 401,
        'POST /api/logout': 500,
      }));
      expect(await api.me(), isNull);
      await api.logout();
      expect(api.user, isNull);
    });

    test('_go error paths', () async {
      final api = Api(client({
        'GET /api/version': {'version': '2.0'},
        'POST /api/login': 403,
      }));
      expect(await api.serverVersion(), '2.0');
      expect(() => api.login('a', 'b'), throwsA(isA<ApiException>()));
      final c2 = FakeClient({
        'GET /api/version': (_) => http.Response('garbage{', 200),
      });
      final api2 = Api(c2);
      expect(() => api2.serverVersion(), throwsA(anything));
      final c3 = FakeClient({
        'GET /api/version': (_) => http.Response('', 400),
      });
      final api3 = Api(c3);
      try {
        await api3.serverVersion();
        fail('expected');
      } on ApiException catch (e) {
        expect(e.message, 'error 400');
      }
    });

    test('roles/serverSettings/saveSettings', () async {
      final api = Api(client({
        'GET /api/roles': {
          'creatable': ['student'],
          'canManage': true,
          'canAudit': false
        },
        'GET /api/settings': {'trustedProxies': '10.0.0.0/8'},
        'PUT /api/settings': {'ok': true},
      }));
      final caps = await api.roles();
      expect(caps.manage, isTrue);
      expect(api.caps.creatable, ['student']);
      expect(await api.serverSettings(), '10.0.0.0/8');
      await api.saveSettings('192.168.0.1');
      expect(jsonDecode(lastRequest!.body)['trustedProxies'], '192.168.0.1');
      expect(lastRequest!.headers['x-csrf-token'], isNull);
      api.csrf = 'k';
      await api.saveSettings('');
      expect(lastRequest!.headers['x-csrf-token'], 'k');
    });

    test('projects/files/upload/mkdir/move/delete', () async {
      final api = Api(client({
        'GET /api/projects': [
          {'id': 'p1', 'name': 'n', 'displayName': 'N', 'createdAt': 1}
        ],
        'POST /api/projects': {'id': 'p2', 'name': 'n2', 'displayName': 'n2'},
        'GET /api/groups': [
          {'id': 'g1', 'name': 'Class A'}
        ],
        'POST /api/groups': {'id': 'g2', 'name': 'g2'},
        'PATCH *': {'ok': true},
        'DELETE *': {'ok': true},
        'GET /api/projects/p1/files': [
          {'name': 'a.txt', 'path': 'a.txt', 'type': 'file'}
        ],
        'POST *': {'ok': true},
        'PUT *': {'ok': true},
      }));
      final ps = await api.projects();
      expect(ps.single.id, 'p1');
      final p2 = await api.createProject('n2');
      expect(p2.id, 'p2');
      await api.updateProject('p1',
          displayName: 'New', groupId: 'g1', tags: ['a', 'b']);
      final patchBody = jsonDecode(lastRequest!.body);
      expect(patchBody['displayName'], 'New');
      expect(patchBody['groupId'], 'g1');
      expect(patchBody['tags'], ['a', 'b']);
      final gs = await api.groups();
      expect(gs.single.id, 'g1');
      final g2 = await api.createGroup('g2');
      expect(g2.id, 'g2');
      await api.renameGroup('g1', 'Renamed');
      expect(jsonDecode(lastRequest!.body)['name'], 'Renamed');
      await api.deleteGroup('g1');
      await api.deleteProject('p1');
      final fs = await api.files('p1', 'Raw');
      expect(fs.single.name, 'a.txt');
      expect(lastRequest!.url.queryParameters['path'], 'Raw');
      await api.upload('p1', 'Raw/x.mp4', Uint8List.fromList([1, 2]));
      expect(lastRequest!.url.path, '/api/projects/p1/files');
      expect(lastRequest!.bodyBytes, [1, 2]);
      expect(lastRequest!.headers['x-csrf-token'], isNull);
      api.csrf = 'tok';
      await api.upload('p1', 'Raw/y.mp4', Uint8List.fromList([3]));
      expect(lastRequest!.headers['x-csrf-token'], 'tok');
      await api.mkdir('p1', 'Raw/New');
      await api.move('p1', 'a', 'b');
      expect(jsonDecode(lastRequest!.body)['from'], 'a');
      await api.deleteFile('p1', 'a.txt');
      expect(lastRequest!.url.queryParameters['path'], 'a.txt');
    });

    test('urls', () {
      final api = Api(client({}));
      expect(api.projectUrl('p1'), '/filmcraft/wfm.html?project=p1');
      expect(api.downloadUrl('p1', 'a b.mp4'),
          '/api/projects/p1/download?path=a%20b.mp4');
      expect(api.downloadUrl('p1', 'a.mp4', dl: true),
          '/api/projects/p1/download?path=a.mp4&dl=true');
    });

    test('renders', () async {
      final api = Api(client({
        'GET /api/projects/p1/renders': [
          {'id': 'r1', 'status': 'done'}
        ],
        'POST /api/projects/p1/renders': {'id': 'r2', 'status': 'queued'},
        'POST /api/renders/r2/cancel': {'ok': true},
      }));
      expect((await api.renders('p1')).single.id, 'r1');
      final r = await api.createRender('p1', {'fps': 30});
      expect(r.status, 'queued');
      await api.cancelRender('r2');
      expect(lastRequest!.url.path, '/api/renders/r2/cancel');
    });

    test('accounts/audit/nodes', () async {
      final api = Api(client({
        'GET /api/accounts': [userJson],
        'POST /api/accounts': userJson,
        'PATCH /api/accounts/u1': userJson,
        'POST /api/accounts/u1/password': {'ok': true},
        'POST /api/accounts/u1/status': {'ok': true},
        'POST /api/me/password': {'ok': true},
        'GET /api/audit': [
          {'ts': 1, 'action': 'login'}
        ],
        'GET /api/nodes': [
          {'id': 'n1', 'name': 'box'}
        ],
        'POST /api/nodes': {'id': 'n2', 'name': 'box2', 'token': 'sekrit'},
        'PATCH *': {'ok': true},
        'DELETE *': {'ok': true},
      }));
      expect((await api.accounts()).single.username, 'ada');
      expect((await api.createAccount({'username': 'x'})).username, 'ada');
      expect((await api.updateAccount('u1', {'name': 'Ada'})).id, 'u1');
      expect(jsonDecode(lastRequest!.body)['name'], 'Ada');
      await api.resetPassword('u1', 'pw');
      expect(jsonDecode(lastRequest!.body)['password'], 'pw');
      await api.setDisabled('u1', true);
      expect(jsonDecode(lastRequest!.body)['disabled'], isTrue);
      await api.changePassword('a', 'b');
      expect(jsonDecode(lastRequest!.body)['next'], 'b');
      final audit = await api.audit(scope: 'project', limit: 50);
      expect(lastRequest!.url.queryParameters['scope'], 'project');
      expect(lastRequest!.url.queryParameters['limit'], '50');
      expect(audit.single.action, 'login');
      expect((await api.nodes()).single.name, 'box');
      final n = await api.createNode('box2');
      expect(n['token'], 'sekrit');
      await api.setNodeDisabled('n1', true);
      expect(jsonDecode(lastRequest!.body)['disabled'], isTrue);
      await api.deleteNode('n1');
      expect(lastRequest!.method, 'DELETE');
    });
  });
}
