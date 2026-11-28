import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/manage.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/projects.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'server': 'http://test'});
    openExternalForTesting = null;
    openEditorForTesting = null;
    pickFilesForTesting = null;
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w is ManagePage ? w : Scaffold(body: w)));
    await settle(t);
  }

  group('ManagePage', () {
    testWidgets('nothing to manage for plain student', (t) async {
      installApi();
      Api.i.user = User.fromJson({'role': 'student'});
      Api.i.caps = Caps.fromJson(
          {'creatable': [], 'canManage': false, 'canAudit': false});
      await pump(t, const ManagePage());
      expect(find.textContaining('Nothing to manage'), findsOneWidget);
    });

    testWidgets('shows only permitted tabs', (t) async {
      installApi();
      Api.i.user = User.fromJson({'role': 'mod'});
      Api.i.caps = Caps.fromJson({
        'creatable': ['student'],
        'canManage': true,
        'canAudit': false
      });
      await pump(t, const ManagePage());
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Activity'), findsNothing);
      expect(find.text('Render nodes'), findsNothing);
    });

    testWidgets('all tabs for owner', (t) async {
      installApi();
      await pump(t, const ManagePage());
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('Render nodes'), findsOneWidget);
    });

    testWidgets('narrow layout drops the duplicate title', (t) async {
      installApi();
      t.view.physicalSize = const Size(500, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await pump(t, const ManagePage());
      expect(find.text('Manage'), findsNothing);
      expect(find.text('Accounts'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
    });
  });

  group('AccountsTab', () {
    testWidgets('lists users, toggle disable, reset password', (t) async {
      var disables = 0;
      installApi(extra: {
        'POST /api/accounts/u2/status': (req) {
          disables++;
          return {'ok': true};
        },
        'POST /api/accounts/u1/password': (_) => {'ok': true},
      });
      await pump(t, const AccountsTab());
      expect(find.textContaining('Ada Lovelace'), findsOneWidget);
      expect(find.textContaining('bob'), findsWidgets);
      await t.tap(find.byIcon(Icons.play_circle_outline));
      await settle(t);
      expect(disables, 1);
      await t.tap(find.byIcon(Icons.key).first);
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'newpassword1');
      await t.pump();
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byIcon(Icons.key).first);
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });

    testWidgets('empty list shows placeholder and keeps FAB', (t) async {
      installApi(extra: {'GET /api/accounts': (_) => []});
      await pump(t, const AccountsTab());
      expect(find.text('No accounts'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('accounts render as a tree and children expand', (t) async {
      installApi(extra: {
        'GET /api/accounts': (_) => [
              {
                'id': 't1',
                'username': 'teachx',
                'role': 'teacher',
                'createdBy': 'u1'
              },
              {
                'id': 's1',
                'username': 'pupilx',
                'role': 'student',
                'createdBy': 't1'
              },
              {'id': 's9', 'username': 'orphanx', 'createdBy': 'gone'}
            ]
      });
      await pump(t, const AccountsTab());
      expect(find.textContaining('teachx'), findsWidgets);
      expect(find.textContaining('pupilx'), findsNothing);
      expect(find.textContaining('orphanx'), findsWidgets);
      await t.tap(find.byIcon(Icons.chevron_right));
      await settle(t);
      expect(find.textContaining('pupilx'), findsWidgets);
      await t.tap(find.byIcon(Icons.expand_more));
      await settle(t);
      expect(find.textContaining('pupilx'), findsNothing);
    });

    test('accountTree nests children and surfaces orphans', () {
      User u(Map<String, dynamic> j) => User.fromJson(j);
      final users = [
        u({'id': 't1', 'username': 'a', 'createdBy': 'me'}),
        u({'id': 's1', 'username': 'b', 'createdBy': 't1'}),
        u({'id': 's2', 'username': 'c', 'createdBy': 't1'}),
        u({'id': 'x1', 'username': 'd', 'createdBy': 'gone'}),
      ];
      final flat = accountTree(users, 'me', {});
      expect(flat.map((r) => r.$1.id), ['t1', 'x1']);
      final deep = accountTree(users, 'me', {'t1'});
      expect(deep.map((r) => '${r.$1.id}:${r.$2}'),
          ['t1:0', 's1:1', 's2:1', 'x1:0']);
    });

    testWidgets('reset password and disable error snacks', (t) async {
      installApi(extra: {
        'POST *': (_) => http.Response('{"error":"denied"}', 403),
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byIcon(Icons.key).first);
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x2345678');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byIcon(Icons.block).first);
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('delete account with confirm', (t) async {
      var deleted = 0;
      installApi(extra: {
        'DELETE /api/accounts/u1': (req) {
          deleted++;
          return {'ok': true};
        },
        'DELETE /api/accounts/u2': (_) =>
            http.Response('{"error":"has projects"}', 409),
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(deleted, 0);
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(deleted, 1);
      await t.tap(find.byIcon(Icons.delete_outline).last);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('create account dialog', (t) async {
      String? body;
      installApi(extra: {
        'POST /api/accounts': (req) {
          body = req.body;
          return userJson;
        },
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).at(0), 'Bob');
      await t.enterText(find.byType(TextField).at(1), 'bob2');
      await t.enterText(find.byType(TextField).at(2), 'password1');
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await settle(t);
      await t.tap(find.text('teacher').last);
      await settle(t);
      await t.enterText(find.byType(TextField).at(3), 'S77');
      await t.enterText(find.byType(TextField).at(4), 'note');
      await t.tap(find.text('Create'));
      await settle(t);
      expect(body, contains('"role":"teacher"'));
      expect(body, contains('S77'));
    });

    testWidgets('create invite, copy and revoke', (t) async {
      String? body;
      var creates = 0;
      var revoked = 0;
      installApi(extra: {
        'GET /api/invites': (_) => [
              {
                'id': 'i1',
                'role': 'student',
                'presetUsername': 'ann',
                'usedBy': '',
                'usedAt': 0,
                'expiresAt': 9999999999,
                'createdAt': 1
              },
              {
                'id': 'i2',
                'role': 'mod',
                'usedBy': 'u9',
                'usedByUsername': 'sam',
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
        'POST /api/invites': (req) {
          creates++;
          if (creates > 1) {
            return http.Response('{"error":"dup"}', 409);
          }
          body = req.body;
          return {'code': 'c9', 'invite': {}};
        },
        'DELETE /api/invites/i1': (req) {
          revoked++;
          return revoked > 1
              ? http.Response('{"error":"gone"}', 410)
              : {'ok': true};
        },
      });
      await pump(t, const AccountsTab());
      expect(find.text('Invites'), findsOneWidget);
      expect(find.textContaining('Pending'), findsOneWidget);
      expect(find.textContaining('Used by sam'), findsOneWidget);
      expect(find.textContaining('Expired'), findsOneWidget);
      expect(find.textContaining('Revoked'), findsNothing);
      await t.tap(find.byIcon(Icons.delete_outline).last);
      await settle(t);
      expect(revoked, 1);
      await t.tap(find.byIcon(Icons.delete_outline).last);
      await settle(t);
      expect(revoked, 2);
      expect(find.byType(Notice), findsWidgets);

      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.tap(find.text('Invite'));
      await settle(t);
      expect(find.text('New invite'), findsOneWidget);
      await t.enterText(find.byType(TextField).at(1), 'newkid');
      await t.tap(find.text('Create'));
      await settle(t);
      expect(body, contains('"username":"newkid"'));
      expect(find.text('Invite ready'), findsOneWidget);
      await t.tap(find.byIcon(Icons.copy).first);
      await settle(t);
      expect(find.text('Copied'), findsOneWidget);
      await t.tap(find.text('OK'));
      await settle(t);

      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.tap(find.text('Invite'));
      await settle(t);
      await t.tap(find.text('Create'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('create account cancel and error', (t) async {
      installApi(extra: {
        'POST /api/accounts': (_) => http.Response('{"error":"taken"}', 409),
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).at(0), 'Bob');
      await t.enterText(find.byType(TextField).at(1), 'bob2');
      await t.enterText(find.byType(TextField).at(2), 'password1');
      await t.pump();
      await t.tap(find.text('Create'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
    });

    testWidgets('create blocks invalid input before submit', (t) async {
      var posts = 0;
      installApi(extra: {
        'POST /api/accounts': (_) {
          posts++;
          return userJson;
        }
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      final create =
          t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'));
      expect(create.onPressed, isNull);
      await t.enterText(find.byType(TextField).at(0), 'Bob');
      await t.enterText(find.byType(TextField).at(1), 'b');
      await t.enterText(find.byType(TextField).at(2), 'password1');
      await settle(t);
      expect(
          t
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Create'))
              .onPressed,
          isNull);
      await t.enterText(find.byType(TextField).at(1), 'bob2');
      await t.pump();
      await t.tap(find.text('Create'));
      await settle(t);
      expect(posts, 1);
    });

    testWidgets('edit account dialog', (t) async {
      String? body;
      installApi(extra: {
        'PATCH /api/accounts/u1': (req) {
          body = req.body;
          return userJson;
        },
        'GET /api/accounts/u1/usage': (_) => {'bytes': 1048576},
        'GET /api/accounts': (_) => [
              {...userJson, 'quotaBytes': 104857600}
            ],
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(t);
      expect(find.text('Edit account'), findsOneWidget);
      await t.enterText(find.byType(TextField).at(0), 'Ada L');
      await t.enterText(find.byType(TextField).at(1), 'ada2');
      await t.tap(find.byType(DropdownButtonFormField<String>));
      await settle(t);
      await t.tap(find.text('mod').last);
      await settle(t);
      await t.enterText(find.byType(TextField).at(2), 'S99');
      await t.enterText(find.byType(TextField).at(3), 'hi');
      expect(find.text('1.0 MB of 100 MB used'), findsOneWidget);
      await t.tap(find.text('Save'));
      await settle(t);
      expect(body, contains('"username":"ada2"'));
      expect(body, contains('"role":"mod"'));
      expect(body, contains('S99'));
      expect(body, contains('"quotaBytes":104857600'));
    });

    testWidgets('edit account cancel, error, and hidden role', (t) async {
      installApi(extra: {
        'PATCH *': (_) => http.Response('{"error":"denied"}', 403),
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(t);
      await t.tap(find.text('Save'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      Api.i.caps = Caps.fromJson({'creatable': [], 'canManage': true});
      await t.tap(find.byIcon(Icons.edit_outlined).last);
      await settle(t);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });

    testWidgets('error state and no fab without creatable', (t) async {
      installApi(extra: {
        'GET /api/accounts': (_) => http.Response('{"error":"nope"}', 500)
      });
      Api.i.caps = Caps.fromJson({'creatable': [], 'canManage': true});
      await pump(t, const AccountsTab());
      expect(find.text('nope'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('narrow layout moves actions below the user line', (t) async {
      installApi();
      t.view.physicalSize = const Size(420, 900);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await pump(t, const AccountsTab());
      final tile = t.widget<ListTile>(find.byType(ListTile).first);
      expect(tile.trailing, isNull);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.key), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(t);
      expect(find.text('Edit account'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });
  });

  group('ClassesTab', () {
    Map<String, dynamic Function(http.Request)> classRoutes() => {
          'GET /api/classes': (_) => [
                {
                  'id': 'cu',
                  'name': 'unmanaged',
                  'ownerId': 'u1',
                  'unmanaged': true,
                  'members': 1,
                  'createdAt': 1
                },
                {
                  'id': 'c1',
                  'name': 'Period 1',
                  'ownerId': 'u1',
                  'members': 1,
                  'createdAt': 2
                },
                {
                  'id': 'c2',
                  'name': 'Foreign',
                  'ownerId': 't9',
                  'members': 1,
                  'createdAt': 3
                },
              ],
          'GET /api/accounts': (_) => [
                userJson,
                {
                  'id': 's1',
                  'username': 'stu',
                  'role': 'student',
                  'classId': 'cu'
                },
                {
                  'id': 's2',
                  'username': 'stu2',
                  'role': 'student',
                  'classId': 'c1'
                },
                {
                  'id': 's3',
                  'username': 'far',
                  'role': 'student',
                  'classId': 'c2'
                },
              ],
        };

    testWidgets('lists classes and members, moves and edits them', (t) async {
      var moves = 0, renames = 0, deletes = 0, creates = 0;
      installApi(extra: {
        ...classRoutes(),
        'POST /api/classes': (req) {
          creates++;
          return {'id': 'cn', 'name': 'New', 'ownerId': 'u1', 'createdAt': 4};
        },
        'PATCH /api/classes/c1': (req) {
          renames++;
          return {'ok': true};
        },
        'DELETE /api/classes/c1': (req) {
          deletes++;
          return {'ok': true};
        },
        'PATCH /api/accounts/s1': (req) {
          moves++;
          return userJson;
        },
      });
      Api.i.user = User.fromJson({'id': 'u1', 'role': 'teacher'});
      await pump(t, const ClassesTab());
      expect(find.text('Unmanaged'), findsOneWidget);
      expect(find.text('Period 1'), findsOneWidget);
      expect(find.text('Foreign'), findsOneWidget);
      expect(find.text('1 members'), findsWidgets);

      await t.tap(find.text('Unmanaged'));
      await settle(t);
      expect(find.text('stu · student'), findsOneWidget);
      await t.tap(find.byIcon(Icons.drive_file_move_outline).first);
      await settle(t);
      await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Period 1'));
      await settle(t);
      expect(moves, 1);

      await t.tap(find.text('Period 1'));
      await settle(t);
      expect(find.text('stu2 · student'), findsOneWidget);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      expect(renames, 0, reason: 'unchanged names are skipped');
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Period 2');
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      expect(renames, 1);

      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(deletes, 0);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(deletes, 1);

      await t.tap(find.text('Foreign'));
      await settle(t);
      expect(find.text('far · student'), findsOneWidget);
      final foreign = find.ancestor(
          of: find.text('far · student'), matching: find.byType(ExpansionTile));
      expect(
          find.descendant(
              of: foreign,
              matching: find.byIcon(Icons.drive_file_move_outline)),
          findsNothing,
          reason: 'foreign classes stay read-only');
      expect(
          find.descendant(
              of: foreign, matching: find.widgetWithText(TextButton, 'Rename')),
          findsNothing);

      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(creates, 0);
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField), 'Period 3');
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      expect(creates, 1);
    });

    testWidgets('co-teachers list, add, create and remove', (t) async {
      var added = 0, removed = 0, created = 0;
      installApi(extra: {
        'GET /api/classes': (_) => [
              {
                'id': 'c1',
                'name': 'Period 1',
                'ownerId': 'u1',
                'members': 1,
                'teachers': 1,
                'createdAt': 1
              },
              {
                'id': 'c2',
                'name': 'Foreign',
                'ownerId': 't9',
                'members': 0,
                'createdAt': 2
              },
            ],
        'GET /api/accounts': (_) => [],
        'GET /api/classes/c1/teachers': (_) => [
              {
                'id': 't2',
                'username': 'co',
                'displayName': 'Co Teacher',
                'role': 'teacher'
              },
              {'id': 't3', 'username': 'plain', 'role': 'teacher'},
            ],
        'GET /api/classes/c2/teachers': (_) =>
            http.Response('{"error":"x"}', 500),
        'POST /api/classes/c1/teachers': (req) {
          added++;
          if (added == 1) return http.Response('{"error":"boom"}', 500);
          return {'id': 't4', 'username': 'linked', 'role': 'teacher'};
        },
        'DELETE /api/classes/c1/teachers/t3': (req) {
          removed++;
          if (removed == 1) return http.Response('{"error":"boom"}', 500);
          return {'ok': true};
        },
        'POST /api/accounts': (req) {
          created++;
          return {'id': 't5', 'username': 'fresh', 'role': 'teacher'};
        },
      });
      Api.i.user = User.fromJson({'id': 'u1', 'role': 'teacher'});
      await pump(t, const ClassesTab());
      expect(find.text('1 members · 1 co-teachers'), findsOneWidget);

      await t.tap(find.text('Period 1'));
      await settle(t);
      expect(find.text('Co Teacher'), findsOneWidget);
      expect(find.text('plain'), findsWidgets);

      final foreign = find.ancestor(
          of: find.text('Foreign'), matching: find.byType(ExpansionTile));
      expect(
          find.descendant(
              of: foreign,
              matching: find.widgetWithText(TextButton, 'Add co-teacher')),
          findsNothing,
          reason: 'foreign classes stay read-only');

      await t.tap(find.text('Add co-teacher'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(added, 0);

      await t.tap(find.text('Add co-teacher'));
      await settle(t);
      await t.enterText(find.byType(TextField).first, 'linked');
      await settle(t);
      await t.tap(find.text('Add'));
      await settle(t);
      expect(added, 1);
      expect(find.textContaining('boom'), findsOneWidget);
      await t.tap(find.text('Add'));
      await settle(t);
      expect(added, 2);

      await t.tap(find.text('Add co-teacher'));
      await settle(t);
      await t.tap(find.byType(CheckboxListTile));
      await settle(t);
      await t.enterText(find.byType(TextField).at(0), 'fresh');
      await t.enterText(find.byType(TextField).at(1), 'Fresh Teach');
      await t.enterText(find.byType(TextField).at(2), 'password1');
      await settle(t);
      await t.tap(find.text('Create'));
      await settle(t);
      expect(created, 1);

      await t.tap(find.byIcon(Icons.person_remove_outlined).last);
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(removed, 0);
      await t.tap(find.byIcon(Icons.person_remove_outlined).last);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(removed, 1);
      await t.tap(find.byIcon(Icons.person_remove_outlined).last);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(removed, 2);
    });

    testWidgets('empty, error and failing actions', (t) async {
      installApi(extra: {
        'GET /api/classes': (_) => [],
        'GET /api/accounts': (_) => [],
      });
      await pump(t, const ClassesTab());
      expect(find.text('No classes yet'), findsOneWidget);

      await t.pumpWidget(const SizedBox());
      installApi(extra: {
        'GET /api/classes': (_) => http.Response('{"error":"nope"}', 500)
      });
      await pump(t, const ClassesTab());
      expect(find.text('nope'), findsOneWidget);

      await t.pumpWidget(const SizedBox());
      installApi(extra: {
        'GET /api/classes': (_) => [
              {
                'id': 'c1',
                'name': 'P1',
                'ownerId': 'u1',
                'members': 1,
                'createdAt': 1
              },
              {
                'id': 'cu',
                'name': 'unmanaged',
                'ownerId': 'u1',
                'unmanaged': true,
                'members': 0,
                'createdAt': 2
              },
            ],
        'GET /api/accounts': (_) => [
              {
                'id': 's1',
                'username': 'stu',
                'role': 'student',
                'classId': 'c1'
              }
            ],
        'POST /api/classes': (_) => http.Response('{"error":"x"}', 500),
        'PATCH /api/classes/c1': (_) => http.Response('{"error":"x"}', 500),
        'DELETE /api/classes/c1': (_) => http.Response('{"error":"x"}', 500),
        'PATCH /api/accounts/s1': (_) => http.Response('{"error":"x"}', 500),
      });
      Api.i.user = User.fromJson({'id': 'u1', 'role': 'teacher'});
      await pump(t, const ClassesTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField), 'x');
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.text('P1'));
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField), 'P2');
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.byIcon(Icons.drive_file_move_outline));
      await settle(t);
      await t.tap(find.widgetWithText(PopupMenuItem<String>, 'Unmanaged'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('student account dialog picks a class', (t) async {
      String? body;
      installApi(extra: {
        'GET /api/classes': (_) => [
              {
                'id': 'cu',
                'name': 'unmanaged',
                'ownerId': 'u1',
                'unmanaged': true,
                'members': 0,
                'createdAt': 1
              },
              {
                'id': 'c1',
                'name': 'Period 1',
                'ownerId': 'u1',
                'members': 0,
                'createdAt': 2
              },
            ],
        'POST /api/accounts': (req) {
          body = req.body;
          return userJson;
        },
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      await t.tap(find.byType(DropdownButtonFormField<String>).last);
      await settle(t);
      await t.tap(find.text('Period 1').last);
      await settle(t);
      await t.enterText(find.byType(TextField).at(0), 'Bob');
      await t.enterText(find.byType(TextField).at(1), 'bob2');
      await t.enterText(find.byType(TextField).at(2), 'password1');
      await settle(t);
      await t.tap(find.text('Create'));
      await settle(t);
      expect(body, contains('"classId":"c1"'));
    });

    testWidgets('class picker falls back without unmanaged', (t) async {
      installApi(extra: {
        'GET /api/classes': (_) => [
              {
                'id': 'c1',
                'name': 'Period 1',
                'ownerId': 'u1',
                'members': 0,
                'createdAt': 1
              },
            ],
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(2));
      await t.tap(find.text('Cancel'));
      await settle(t);
    });

    testWidgets('editing a student keeps a foreign class listed', (t) async {
      installApi(extra: {
        'GET /api/classes': (_) => [
              {
                'id': 'c1',
                'name': 'Period 1',
                'ownerId': 'u1',
                'members': 0,
                'createdAt': 1
              },
            ],
        'GET /api/accounts': (_) => [
              {
                'id': 's1',
                'username': 'stu',
                'displayName': 'Stu',
                'role': 'student',
                'classId': 'c9'
              }
            ],
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byIcon(Icons.edit_outlined).first);
      await settle(t);
      expect(find.text('c9'), findsWidgets);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });
  });

  group('AuditTab', () {
    testWidgets('shows entries, scope switch, refresh', (t) async {
      var scopes = <String?>[];
      installApi(extra: {
        'GET /api/audit': (req) {
          scopes.add(req.url.queryParameters['scope']);
          return [
            {
              'ts': 1700000000,
              'actorName': 'Ada',
              'action': 'login',
              'target': '',
              'detail': 'ok'
            },
          ];
        },
      });
      Api.i.user = User.fromJson({'role': 'owner'});
      await pump(t, const AuditTab());
      expect(find.textContaining('login'), findsOneWidget);
      await t.tap(find.text('Projects'));
      await settle(t);
      expect(scopes, contains('project'));
      await t.tap(find.byIcon(Icons.refresh));
      await settle(t);
    });

    testWidgets('empty and error states', (t) async {
      installApi(extra: {'GET /api/audit': (_) => []});
      await pump(t, const AuditTab());
      expect(find.textContaining('Nothing'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      installApi(extra: {
        'GET /api/audit': (_) => http.Response('{"error":"audit err"}', 500)
      });
      await pump(t, const AuditTab());
      expect(find.text('audit err'), findsOneWidget);
    });

    testWidgets('filters, pagination, clear', (t) async {
      final reqs = <Map<String, String>>[];
      installApi(extra: {
        'GET /api/audit': (req) {
          final q = req.url.queryParameters;
          reqs.add(q);
          final n = q['offset'] == '0' ? 200 : 3;
          return List.generate(
              n,
              (i) => {
                    'ts': 1700000000 + i,
                    'actorName': 'Ada',
                    'action': 'login',
                    'target': '',
                    'detail': ''
                  });
        },
      });
      Api.i.user = User.fromJson({'role': 'owner'});
      await pump(t, const AuditTab());
      await t.enterText(find.byType(TextField).first, 'upload');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(reqs.last['action'], 'upload');
      await t.enterText(find.byType(TextField).at(1), 'ada');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(reqs.last['actor'], 'ada');
      await t.tap(find.byIcon(Icons.search));
      await settle(t);
      await t.dragUntilVisible(find.text('Load more'),
          find.byType(Scrollable).last, const Offset(0, -400));
      await t.tap(find.text('Load more'));
      await settle(t);
      expect(reqs.last['offset'], '200');
      expect(find.text('Load more'), findsNothing);
      await t.tap(find.byIcon(Icons.filter_alt_off));
      await settle(t);
      expect(reqs.last['action'], '');
      expect(reqs.last['offset'], '0');
    });

    testWidgets('date range pickers', (t) async {
      installApi(extra: {'GET /api/audit': (_) => []});
      await pump(t, const AuditTab());
      await t.tap(find.byType(ActionChip).first);
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(find.text('From'), findsOneWidget);
      await t.tap(find.byType(ActionChip).first);
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.byType(ActionChip).at(1));
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.byIcon(Icons.search));
      await settle(t);
      expect(lastRequest!.url.queryParameters['from'], isNot('0'));
      expect(lastRequest!.url.queryParameters['to'], isNot('0'));
    });
  });

  group('NodesTab', () {
    testWidgets('list, disable, delete', (t) async {
      var disabled = 0;
      var deleted = 0;
      installApi(extra: {
        'PATCH *': (req) {
          disabled++;
          return {'ok': true};
        },
        'DELETE *': (req) {
          deleted++;
          return {'ok': true};
        },
      });
      await pump(t, const NodesTab());
      expect(find.text('render-box'), findsOneWidget);
      expect(find.textContaining('laptop'), findsOneWidget);
      await t.tap(find.byIcon(Icons.pause_circle_outline));
      await settle(t);
      expect(disabled, 1);
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(deleted, 0);
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(deleted, 1);
    });

    testWidgets('create node shows token dialog', (t) async {
      installApi(extra: {
        'POST /api/nodes': (_) =>
            {'id': 'n9', 'name': 'newbox', 'token': 'tok123'},
      });
      await pump(t, const NodesTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'newbox');
      await t.tap(find.text('OK'));
      await settle(t, 20);
      expect(find.textContaining('wfm --worker'), findsOneWidget);
      await t.tap(find.text('Done'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('node create cancel and error', (t) async {
      installApi(extra: {
        'POST /api/nodes': (_) => http.Response('{"error":"node err"}', 500),
      });
      await pump(t, const NodesTab());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
    });

    testWidgets('empty and error states', (t) async {
      installApi(extra: {'GET /api/nodes': (_) => []});
      await pump(t, const NodesTab());
      expect(find.textContaining('No render nodes'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      installApi(extra: {
        'GET /api/nodes': (_) => http.Response('{"error":"node fail"}', 500)
      });
      await pump(t, const NodesTab());
      expect(find.text('node fail'), findsOneWidget);
    });
  });

  group('UserProjectsPage', () {
    final bob =
        User.fromJson({'id': 'u2', 'username': 'bob', 'role': 'student'});

    Map<String, Object> proj(String id, String name,
            {String status = 'draft', bool takeOver = false}) =>
        {
          'id': id,
          'name': id,
          'displayName': name,
          'ownerId': 'u2',
          'access': 'view',
          'takeOver': takeOver,
          'status': status,
          'createdAt': 1
        };

    testWidgets('tapping an account opens their projects', (t) async {
      installApi(extra: {'GET /api/accounts/u2/projects': (_) => []});
      await pump(t, const AccountsTab());
      await t.tap(find.textContaining('bob').first);
      await settle(t);
      expect(find.byType(UserProjectsPage), findsOneWidget);
      expect(find.text("bob's projects"), findsOneWidget);
      expect(find.text('No projects yet.'), findsOneWidget);
    });

    testWidgets('lists projects and opens one', (t) async {
      final named = User.fromJson(
          {'id': 'u2', 'username': 'bob', 'displayName': 'Bobby'});
      installApi(extra: {
        'GET /api/accounts/u2/projects': (_) => [
              proj('p9', 'Student Work', status: 'submitted'),
              proj('p8', 'Second Cut', status: 'reviewed'),
              proj('p7', 'First Draft'),
            ]
      });
      await pump(t, UserProjectsPage(user: named));
      expect(find.text("Bobby's projects"), findsOneWidget);
      expect(find.text('Student Work'), findsOneWidget);
      expect(find.textContaining('Submitted'), findsOneWidget);
      expect(find.textContaining('Reviewed'), findsOneWidget);
      await t.tap(find.text('First Draft'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
    });

    testWidgets('take over confirms and reloads', (t) async {
      var calls = 0;
      installApi(extra: {
        'GET /api/accounts/u2/projects': (_) =>
            [proj('p9', 'Student Work', takeOver: true)],
        'POST /api/projects/p9/take-over': (_) {
          calls++;
          return {'ok': true};
        },
      });
      await pump(t, UserProjectsPage(user: bob));
      await t.tap(find.byType(PopupMenuButton<String>));
      await settle(t);
      await t.tap(find.text('Take ownership'));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(t);
      expect(calls, 1);
    });

    testWidgets('take over cancel and error', (t) async {
      var calls = 0;
      installApi(extra: {
        'GET /api/accounts/u2/projects': (_) =>
            [proj('p9', 'Student Work', takeOver: true)],
        'POST /api/projects/p9/take-over': (_) {
          calls++;
          return http.Response('{"error":"nope"}', 500);
        },
      });
      await pump(t, UserProjectsPage(user: bob));
      await t.tap(find.byType(PopupMenuButton<String>));
      await settle(t);
      await t.tap(find.text('Take ownership'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(calls, 0);
      await t.tap(find.byType(PopupMenuButton<String>));
      await settle(t);
      await t.tap(find.text('Take ownership'));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(t);
      expect(calls, 1);
      expect(find.byType(Notice), findsOneWidget);
    });

    testWidgets('load error retries', (t) async {
      var fails = true;
      installApi(extra: {
        'GET /api/accounts/u2/projects': (_) => fails
            ? http.Response('{"error":"boom"}', 500)
            : [proj('p9', 'Late Work')],
      });
      await pump(t, UserProjectsPage(user: bob));
      expect(find.text('boom'), findsOneWidget);
      fails = false;
      await t.tap(find.text('Retry'));
      await settle(t);
      expect(find.text('Late Work'), findsOneWidget);
    });
  });
}
