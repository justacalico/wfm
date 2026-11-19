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

    test('chunked upload flow', () async {
      final chunks = <List<int>>[];
      String? startPath;
      final api = Api(FakeClient({
        'POST /api/projects/p1/files/upload': (req) {
          startPath = jsonDecode(req.body)['path'];
          return {'id': 'u1'};
        },
        'PUT /api/uploads/u1/chunk': (req) {
          chunks.add(req.bodyBytes);
          return {'received': 0};
        },
        'GET /api/uploads/u1': (req) => {'received': 4},
        'POST /api/uploads/u1/complete': (req) => {'ok': true},
      }));
      api.chunkSize = 4;
      await api.upload('p1', 'a.bin', Uint8List.fromList([1, 2, 3, 4, 5, 6]));
      expect(startPath, 'a.bin');
      expect(chunks, [
        [1, 2, 3, 4],
        [5, 6]
      ]);
      expect(await api.uploadReceived('u1'), 4);
      final prog = <List<int>>[];
      await api.uploadChunked('p1', 'b.bin', 6,
          (a, b) async => Uint8List(b - a), (s, t) => prog.add([s, t]));
      expect(prog.last, [6, 6]);
    });

    test('chunked upload 413 stepdown and aborts', () async {
      final sizes = <int>[];
      var aborts = 0;
      final api = Api(FakeClient({
        'POST *': (req) => {'id': 'u1'},
        'PUT *': (req) {
          sizes.add(req.bodyBytes.length);
          return req.bodyBytes.length > 1048576
              ? http.Response('{"error":"too large"}', 413)
              : {'ok': true};
        },
        'DELETE *': (req) {
          aborts++;
          return {'ok': true};
        },
      }));
      api.chunkSize = 2 * 1048576;
      await api.uploadChunked(
          'p1', 'a', 3 * 1048576, (a, b) async => Uint8List(b - a));
      expect(sizes, [2 * 1048576, 1048576, 1048576, 1048576]);
      expect(aborts, 0);
      final api2 = Api(FakeClient({
        'POST *': (req) => {'id': 'u2'},
        'PUT *': (_) => http.Response('{"error":"too large"}', 413),
        'DELETE *': (req) {
          aborts++;
          return {'ok': true};
        },
      }));
      api2.chunkSize = 4;
      await expectLater(
          api2.upload('p1', 'b', Uint8List.fromList([1, 2, 3, 4, 5])),
          throwsA(isA<ApiException>()));
      expect(aborts, 1);
      final api3 = Api(FakeClient({
        'POST *': (req) => {'id': 'u3'},
        'PUT *': (_) => http.Response('{"error":"boom"}', 500),
        'DELETE *': (req) {
          aborts++;
          return {'ok': true};
        },
      }));
      api3.chunkSize = 2;
      await expectLater(api3.upload('p1', 'c', Uint8List.fromList([1, 2, 3])),
          throwsA(isA<ApiException>()));
      expect(aborts, 2);
    });

    test('urls', () {
      final api = Api(client({}));
      expect(api.projectUrl('p1'), '/filmcraft/wfm.html?project=p1');
      expect(api.projectUrl('p1', theme: 'dark'),
          '/filmcraft/wfm.html?project=p1&theme=dark');
      expect(api.scriptUrl('p1'), '/scriptcraft/wfm.html?project=p1');
      expect(api.scriptUrl('p1', theme: 'dark'),
          '/scriptcraft/wfm.html?project=p1&theme=dark');
      expect(api.deckUrl('p1'), '/deckcraft/wfm.html?project=p1');
      expect(api.deckUrl('p1', theme: 'dark'),
          '/deckcraft/wfm.html?project=p1&theme=dark');
      expect(api.downloadUrl('p1', 'a b.mp4'),
          '/api/projects/p1/download?path=a%20b.mp4');
      expect(api.downloadUrl('p1', 'a.mp4', dl: true),
          '/api/projects/p1/download?path=a.mp4&dl=true');
    });

    test('desktop baseUrl, bearer token and handoff', () async {
      final api = Api(client({
        'POST /api/login': {'user': userJson, 'csrf': 'c', 'token': 'sess'},
        'GET /api/me': {'user': userJson, 'csrf': 'c'},
        'POST /api/logout': {'ok': true},
        'POST /api/handoff': {'t': 'h9'},
      }));
      api.baseUrl = 'https://s.example';
      await api.login('ada', 'pw');
      expect(api.sessionToken, 'sess');
      await api.me();
      expect(lastRequest!.headers['authorization'], 'Bearer sess');
      expect(api.projectUrl('p1'),
          'https://s.example/filmcraft/wfm.html?project=p1');
      expect(api.scriptUrl('p1'),
          'https://s.example/scriptcraft/wfm.html?project=p1');
      expect(
          api.deckUrl('p1'), 'https://s.example/deckcraft/wfm.html?project=p1');
      expect(api.renderUrl('p1', 'r9'),
          'https://s.example/filmcraft/wfm.html?project=p1&render=r9');
      final u = await api.handoffUrl('/filmcraft/wfm.html?project=p1');
      expect(u,
          'https://s.example/api/handoff?t=h9&to=%2Ffilmcraft%2Fwfm.html%3Fproject%3Dp1');
      expect(jsonDecode(lastRequest!.body)['to'],
          '/filmcraft/wfm.html?project=p1');
      await api.logout();
      expect(api.sessionToken, '');
    });

    test('renders', () async {
      final api = Api(client({
        'GET /api/projects/p1/renders': [
          {'id': 'r1', 'status': 'done'}
        ],
        'POST /api/projects/p1/renders': {'id': 'r2', 'status': 'queued'},
        'POST /api/renders/r2/cancel': {'ok': true},
        'GET /api/projects/p1/render-info': {
          'sequences': [
            {'id': 21, 'name': 'Main Edit'}
          ],
          'activeSequence': 21,
          'serverRender': false,
          'project': true,
        },
      }));
      expect((await api.renders('p1')).single.id, 'r1');
      final r = await api.createRender('p1', {'mode': 'server'});
      expect(r.status, 'queued');
      expect(r.mode, 'server');
      await api.cancelRender('r2');
      expect(lastRequest!.url.path, '/api/renders/r2/cancel');
      final info = await api.renderInfo('p1');
      expect(info.sequences.single.name, 'Main Edit');
      expect(info.activeSequence, 21);
      expect(info.serverRender, isFalse);
      expect(info.project, isTrue);
      expect(api.renderUrl('p1', 'r9'),
          '/filmcraft/wfm.html?project=p1&render=r9');
      expect(api.renderUrl('p1', 'r9', theme: 'oled'),
          '/filmcraft/wfm.html?project=p1&render=r9&theme=oled');
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
  group('invites', () {
    test('Invite model and endpoints', () async {
      final api = Api(client({
        'GET /api/invites': [
          {
            'id': 'i1',
            'role': 'student',
            'presetUsername': 'ann',
            'presetName': 'Ann',
            'usedBy': '',
            'usedAt': 0,
            'expiresAt': 9999999999,
            'revoked': false,
            'createdAt': 1
          },
          {
            'id': 'i2',
            'role': 'mod',
            'usedBy': 'u9',
            'usedAt': 5,
            'expiresAt': 9999999999,
            'createdAt': 1
          },
          {'id': 'i3', 'role': 'student', 'expiresAt': 1, 'createdAt': 1},
          {
            'id': 'i4',
            'role': 'student',
            'expiresAt': 9999999999,
            'revoked': true,
            'createdAt': 1
          },
        ],
        'POST /api/invites': {'code': 'c9', 'invite': {}},
        'DELETE /api/invites/i1': {'ok': true},
        'GET /api/invites/c9': {'username': 'ann', 'name': 'Ann'},
        'POST /api/invites/c9/redeem': {
          'user': userJson,
          'csrf': 'tok',
          'token': 't'
        },
      }));
      final inv = await api.invites();
      expect(inv.length, 4);
      expect(inv[0].presetUsername, 'ann');
      expect(inv[0].pending(100), isTrue);
      expect(inv[0].expired(100), isFalse);
      expect(inv[2].expired(10), isTrue);
      expect(inv[2].pending(10), isFalse);
      expect(inv[3].pending(100), isFalse);
      expect(await api.inviteCreate('student', username: 'u', name: 'n'), 'c9');
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['username'], 'u');
      await api.inviteRevoke('i1');
      expect(await api.inviteGet('c9'), {'username': 'ann', 'name': 'Ann'});
      await api.inviteRedeem('c9', 'ann', 'Ann', 'password1');
      expect(api.user!.username, 'ada');
    });
  });
  group('shares', () {
    test('Share model and endpoints', () async {
      final api = Api(client({
        'GET /api/projects/p1/shares': [
          {
            'id': 's1',
            'projectId': 'p1',
            'projectName': 'Short Film',
            'inviterUsername': 'ada',
            'inviteeId': 'u2',
            'inviteeUsername': 'bob',
            'inviteeName': 'Bob',
            'level': 'view',
            'status': 'pending',
            'createdAt': 5
          }
        ],
        'GET /api/shares': [
          {'id': 's2', 'projectId': 'p2', 'level': 'edit', 'status': 'accepted'}
        ],
        'POST /api/projects/p1/shares': {'ok': true},
        'PATCH /api/projects/p1/shares/s1': {'ok': true},
        'DELETE /api/projects/p1/shares/s1': {'ok': true},
        'POST /api/shares/s2/accept': {'ok': true},
        'POST /api/shares/s3/decline': {'ok': true},
      }));
      final sh = (await api.projectShares('p1')).first;
      expect(sh.projectName, 'Short Film');
      expect(sh.inviteeUsername, 'bob');
      expect(sh.level, 'view');
      expect(sh.status, 'pending');
      expect((await api.shares()).first.projectId, 'p2');
      await api.shareProject('p1', 'bob', 'edit');
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['level'], 'edit');
      await api.shareLevel('p1', 's1', 'edit');
      await api.shareRevoke('p1', 's1');
      await api.shareRespond('s2', true);
      await api.shareRespond('s3', false);
      expect(lastRequest!.url.path, '/api/shares/s3/decline');
    });

    test('duplicate and template endpoints', () async {
      final api = Api(client({
        'POST /api/projects/p1/duplicate': {
          'id': 'p9',
          'name': 'x copy',
          'displayName': 'X (copy)',
          'template': true
        },
        'PATCH /api/projects/p1': {'ok': true},
        'GET /api/shares': [
          {
            'id': 's1',
            'projectId': 'p1',
            'level': 'edit',
            'status': 'accepted',
            'template': true
          }
        ],
      }));
      final p = await api.duplicateProject('p1');
      expect(lastRequest!.url.path, '/api/projects/p1/duplicate');
      expect(p.id, 'p9');
      expect(p.template, isTrue);
      await api.updateProject('p1', template: true);
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['template'], true);
      expect((await api.shares()).first.template, isTrue);
      expect(p.copyWith(displayName: 'N').displayName, 'N');
      expect(p.copyWith(displayName: 'N').template, isTrue);
      expect(p.copyWith(template: false).template, isFalse);
    });

    test('AutoShare model and endpoints', () async {
      final api = Api(client({
        'GET /api/auto-shares': [
          {
            'id': 'a1',
            'inviteeId': 'u2',
            'inviteeUsername': 'bob',
            'inviteeName': 'Bob',
            'level': 'edit',
            'createdAt': 7
          },
          {'id': 'a2', 'inviteeId': 'u3'}
        ],
        'POST /api/auto-shares': {'ok': true},
        'DELETE /api/auto-shares/a1': {'ok': true},
      }));
      final list = await api.autoShares();
      expect(list.first.inviteeUsername, 'bob');
      expect(list.first.level, 'edit');
      expect(list.last.level, 'view');
      expect(list.last.inviteeName, '');
      await api.autoShareAdd('bob', 'view');
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['level'], 'view');
      await api.autoShareDelete('a1');
      expect(lastRequest!.url.path, '/api/auto-shares/a1');
    });

    test('storage usage endpoints', () async {
      final api = Api(client({
        'GET /api/projects/p1/usage': {'bytes': 2048},
        'GET /api/accounts/u2/usage': {'bytes': 99},
      }));
      expect(await api.projectUsage('p1'), 2048);
      expect(await api.accountUsage('u2'), 99);
    });

    test('AppNotification model and endpoints', () async {
      final n = AppNotification.fromJson({});
      expect(n.id, '');
      expect(n.kind, '');
      expect(n.payload, isEmpty);
      expect(n.readAt, 0);
      final api = Api(client({
        'GET /api/notifications': {
          'list': [
            {
              'id': 'n1',
              'kind': 'render_done',
              'payload': {'project': 'p1'},
              'readAt': 5,
              'createdAt': 9
            }
          ],
          'unread': 2
        },
        'POST /api/notifications/n1/read': {'ok': true},
        'POST /api/notifications/read-all': {'ok': true},
      }));
      final (list, unread) = await api.notifications(before: 5, limit: 10);
      expect(unread, 2);
      expect(list.single.id, 'n1');
      expect(list.single.payload['project'], 'p1');
      expect(list.single.readAt, 5);
      expect(lastRequest!.url.query, contains('before=5'));
      expect(await api.notificationsUnread(), 2);
      await api.notificationRead('n1');
      expect(lastRequest!.url.path, '/api/notifications/n1/read');
      await api.notificationsReadAll();
      expect(lastRequest!.url.path, '/api/notifications/read-all');
    });

    test('ShareLink model and endpoints', () async {
      final l = ShareLink.fromJson({});
      expect(l.scope, 'project');
      expect(l.revoked, isFalse);
      final api = Api(client({
        'POST /api/projects/p1/links': {'id': 'l1', 'token': 'tok'},
        'GET /api/projects/p1/links': [
          {
            'id': 'l1',
            'projectId': 'p1',
            'scope': 'renders',
            'createdAt': 5,
            'expiresAt': 9,
            'revoked': false
          }
        ],
        'DELETE /api/projects/p1/links/l1': {'ok': true},
        'GET /api/link/tok': {
          'name': 'Cut',
          'scope': 'renders',
          'files': [
            {'path': 'Exports/final.mp4', 'size': 10}
          ]
        },
      }));
      final r = await api.linkCreate('p1', 'renders', expiresAt: 99);
      expect(r['token'], 'tok');
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['expiresAt'], 99);
      final links = await api.projectLinks('p1');
      expect(links.single.scope, 'renders');
      expect(links.single.expiresAt, 9);
      await api.linkRevoke('p1', 'l1');
      expect(lastRequest!.url.path, '/api/projects/p1/links/l1');
      final v = await api.linkResolve('tok');
      expect(v['name'], 'Cut');
      expect(api.linkFileUrl('tok', 'Exports/final.mp4'),
          contains('/api/link/tok/file?path='));
    });

    test('comments and review endpoints', () async {
      final api = Api(client({
        'GET /api/projects/p1/comments': [
          {
            'id': 'c1',
            'projectId': 'p1',
            'userId': 'u2',
            'username': 'bob',
            'body': 'nice cut',
            'createdAt': 5,
            'editedAt': 6
          },
          {'id': 'c2', 'userId': 'u3', 'displayName': 'Ms T'}
        ],
        'POST /api/projects/p1/comments': {'ok': true},
        'PATCH /api/projects/p1/comments/c1': {'ok': true},
        'DELETE /api/projects/p1/comments/c1': {'ok': true},
        'POST /api/projects/p1/submit': {'ok': true, 'status': 'submitted'},
        'POST /api/projects/p1/review': {'ok': true, 'status': 'reviewed'},
      }));
      final cs = await api.comments('p1');
      expect(cs.length, 2);
      expect(cs[0].body, 'nice cut');
      expect(cs[0].author, 'bob');
      expect(cs[0].editedAt, 6);
      expect(cs[1].author, 'Ms T');
      await api.addComment('p1', 'hi');
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['body'], 'hi');
      await api.editComment('p1', 'c1', 'revised');
      expect(lastRequest!.url.path, '/api/projects/p1/comments/c1');
      await api.deleteComment('p1', 'c1');
      expect(await api.submitProject('p1'), 'submitted');
      expect(lastRequest!.url.path, '/api/projects/p1/submit');
      expect(await api.reviewProject('p1', 'reviewed'), 'reviewed');
      expect(jsonDecode(utf8.decode(lastRequest!.bodyBytes))['status'],
          'reviewed');
      final p = Project.fromJson({
        'id': 'p1',
        'status': 'submitted',
        'submittedAt': 1,
        'reviewedBy': 't1'
      });
      expect(p.locked, isTrue);
      expect(p.editable, isFalse);
      expect(p.copyWith(status: 'draft').status, 'draft');
      expect(p.copyWith(status: 'draft').locked, isFalse);
    });
  });
}
