import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/comments.dart';
import 'package:wfm/main.dart';
import 'package:wfm/manage.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/projects.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'server': 'http://test'});
    openExternalForTesting = null;
  });

  final me = Project.fromJson(
      {'id': 'p1', 'name': 'mine', 'displayName': 'Mine', 'ownerId': 'u1'});

  Future<void> pump(WidgetTester t, Widget w) async {
    const pages = [Shell, ManagePage, ProjectPage, HomePage];
    await t.pumpWidget(
        testApp(pages.contains(w.runtimeType) ? w : Scaffold(body: w)));
    await settle(t);
  }

  testWidgets('storage tab lists pools and user breakdown', (t) async {
    installApi(extra: {
      'GET /api/storage': (_) => {
            'pools': [
              {'id': 'media', 'used': 26214400, 'total': 1099511627776},
              {'id': 'database', 'used': 1048576, 'total': 0},
            ],
            'users': [
              {'id': 'u2', 'username': 'bob', 'name': 'Bob', 'bytes': 2000},
              {'id': 'u3', 'username': 'ann', 'name': '', 'bytes': 3000},
            ],
          },
    });
    await pump(t, const StorageTab());
    expect(find.text('Media storage'), findsOneWidget);
    expect(find.text('25.0 MB/1.0 TB'), findsOneWidget);
    expect(find.text('Database'), findsOneWidget);
    await t.tap(find.text('Media storage'));
    await settle(t);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('ann'), findsOneWidget);
    expect(find.text('2.9 KB'), findsWidgets);
    await t.tap(find.text('Done'));
    await settle(t);
  });

  testWidgets('storage tab error and empty breakdown', (t) async {
    var empty = false;
    installApi(extra: {
      'GET /api/storage': (_) => empty
          ? {
              'pools': [
                {'id': 'media', 'used': 0, 'total': 0}
              ],
              'users': []
            }
          : http.Response('{"error":"x"}', 500),
    });
    await pump(t, const StorageTab());
    await t.tap(find.text('Retry'));
    await settle(t);
    empty = true;
    await t.tap(find.text('Retry'));
    await settle(t);
    await t.tap(find.text('Media storage'));
    await settle(t);
    expect(find.text('No one is using storage yet.'), findsOneWidget);
    await t.tap(find.text('Done'));
    await settle(t);
  });

  testWidgets('audit wipe is offered to the owner', (t) async {
    var wiped = '';
    var fail = true;
    installApi(extra: {
      'DELETE /api/audit': (req) {
        if (fail) return http.Response('{"error":"boom"}', 500);
        wiped = req.url.query;
        return {'ok': true};
      },
    });
    await pump(t, const AuditTab());
    await t.tap(find.byIcon(Icons.delete_sweep_outlined));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(wiped, isEmpty);
    fail = false;
    await t.tap(find.byIcon(Icons.delete_sweep_outlined));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(wiped, contains('scope=account'));
  });

  testWidgets('nodes tab shows the setup hint and guide link', (t) async {
    String? opened;
    openExternalForTesting = (u) => opened = u;
    installApi(extra: {'GET /api/nodes': (_) => []});
    await pump(t, const NodesTab());
    await t.tap(find.text('Setup guide'));
    await settle(t);
    expect(opened, nodeGuideUrl);

    var created = false;
    Api.i = Api(FakeClient({
      'GET /api/nodes': (_) => [],
      'POST /api/nodes': (_) => {'id': 'n9', 'name': 'rig', 'token': 'tok9'},
      ...apiRoutes({}),
    }));
    Api.i
      ..csrf = 'tok'
      ..user = User.fromJson(userJson)
      ..caps =
          Caps.fromJson({'creatable': [], 'canManage': true, 'canAudit': true});
    await pump(t, const NodesTab());
    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'rig');
    await t.tap(find.text('OK'));
    await settle(t);
    created = true;
    expect(created, isTrue);
    expect(find.textContaining('WFM_WORKER_TOKEN=tok9'), findsOneWidget);
    opened = null;
    await t.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Setup guide')));
    await settle(t);
    expect(opened, nodeGuideUrl);
    await t.tap(find.text('Done'));
    await settle(t);
  });

  testWidgets('comments thread and reply', (t) async {
    var posted = '';
    installApi(extra: {
      'GET /api/projects/p1/comments': (_) => [
            {
              'id': 'c1',
              'projectId': 'p1',
              'userId': 'u1',
              'username': 'ada',
              'body': 'top',
              'createdAt': 1
            },
            {
              'id': 'c2',
              'projectId': 'p1',
              'userId': 'u2',
              'username': 'bob',
              'body': 'mid',
              'parentId': 'c1',
              'createdAt': 2
            },
            {
              'id': 'c3',
              'projectId': 'p1',
              'userId': 'u1',
              'username': 'ada',
              'body': 'deep',
              'parentId': 'c2',
              'createdAt': 3
            },
          ],
      'POST /api/projects/p1/comments': (req) {
        posted = req.body;
        return {'ok': true};
      },
    });
    await pump(t, Scaffold(body: CommentsTab(project: me)));
    expect(find.text('deep'), findsOneWidget);
    await t.tap(find.text('Reply').first);
    await settle(t);
    expect(find.textContaining('Replying to'), findsOneWidget);
    await t.tap(find.byIcon(Icons.close));
    await settle(t);
    expect(find.textContaining('Replying to'), findsNothing);
    await t.tap(find.text('Reply').first);
    await settle(t);
    await t.enterText(
        find.widgetWithText(TextField, 'Write a reply'), 'back at you');
    await t.tap(find.byIcon(Icons.send));
    await settle(t);
    expect(posted, contains('"parentId":"c1"'));
  });

  testWidgets('home shows recent projects and activity', (t) async {
    installApi(extra: {
      'GET /api/notifications': (_) => {
            'list': [
              {
                'id': 'n1',
                'kind': 'reply',
                'payload': {'from': 'bob', 'projectName': 'Short Film'},
                'createdAt': 1,
                'readAt': 0
              }
            ],
            'unread': 1
          },
      'GET /api/projects/p1/assignment': (_) =>
          http.Response('{"error":"none"}', 404),
    });
    await pump(t, const HomePage());
    expect(find.text('Recent projects'), findsOneWidget);

    expect(find.text('Latest activity'), findsOneWidget);
    expect(find.text('bob replied to you in Short Film'), findsOneWidget);
    await t.tap(find.text('bob replied to you in Short Film'));
    await settle(t);
    expect(find.byType(HomePage), findsOneWidget);
    await t.tap(find.widgetWithText(ListTile, 'Short Film').first);
    await settle(t);
    expect(find.byType(ProjectPage), findsOneWidget);
  });

  testWidgets('home tolerates load failures', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/projects': (_) => http.Response('{"error":"down"}', 500),
      'GET *': (_) => [],
    }))
      ..csrf = 'tok'
      ..user = User.fromJson(userJson)
      ..caps = Caps.fromJson({'creatable': [], 'canManage': true});
    await pump(t, const HomePage());
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('account projects open inside the shell', (t) async {
    installApi(extra: {
      'GET /api/accounts/u2/projects': (_) => [
            {
              'id': 'p9',
              'name': 'theirs',
              'displayName': 'Their Film',
              'createdAt': 1
            }
          ],
      'GET /api/invites': (_) => [],
    });
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Manage').first);
    await settle(t);
    await t.tap(find.textContaining('bob').first);
    await settle(t);
    expect(find.byType(UserProjectsPage), findsOneWidget);
    expect(find.text('Manage'), findsWidgets, reason: 'sidebar stays');
    expect(find.text('Their Film'), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back));
    await settle(t);
    expect(find.byType(ManagePage), findsOneWidget);
  });

  testWidgets('invite list shows used names', (t) async {
    installApi(extra: {
      'GET /api/invites': (_) => [
            {
              'id': 'i1',
              'role': 'student',
              'usedBy': 'u9',
              'usedByName': 'Samantha',
              'usedByUsername': 'sam',
              'expiresAt': 9999999999,
              'createdAt': 1
            },
            {
              'id': 'i2',
              'role': 'student',
              'usedBy': 'u8',
              'expiresAt': 9999999999,
              'createdAt': 1
            },
          ],
    });
    await pump(t, const AccountsTab());
    expect(find.textContaining('Used by Samantha'), findsOneWidget);
    expect(find.textContaining('Used by u8'), findsOneWidget);
  });

  testWidgets('home project tile opens inside the shell', (t) async {
    installApi();
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Short Film').first);
    await settle(t);
    expect(find.byType(ProjectPage), findsOneWidget);
    expect(find.text('Manage'), findsWidgets, reason: 'sidebar stays');
  });

  testWidgets('staff opens submissions on a student project', (t) async {
    var toggles = 0;
    var fail = true;
    installApi(extra: {
      'GET /api/projects/p2/files': (_) => [],
      'GET /api/projects/p2/assignment': (_) =>
          http.Response('{"error":"none"}', 404),
      'POST /api/projects/p2/submit-allowed': (req) {
        if (fail) return http.Response('{"error":"nope"}', 500);
        toggles++;
        return {'ok': true};
      },
    });
    final p2 = Project.fromJson({
      'id': 'p2',
      'name': 'other',
      'displayName': 'Theirs',
      'access': 'view',
      'ownerId': 'x'
    });
    await pump(t, ProjectPage(project: p2));
    expect(find.byIcon(Icons.lock_outlined), findsOneWidget);
    await t.tap(find.byIcon(Icons.lock_outlined));
    await settle(t);
    expect(toggles, 0);
    fail = false;
    await t.tap(find.byIcon(Icons.lock_outlined));
    await settle(t);
    expect(toggles, 1);
    expect(find.byIcon(Icons.lock_open_outlined), findsOneWidget);
    await t.tap(find.byIcon(Icons.lock_open_outlined));
    await settle(t);
    expect(toggles, 2);
  });
}
