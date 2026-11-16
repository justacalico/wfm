import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/manage.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
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
      await t.enterText(find.byType(TextField).last, 'newpw');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byIcon(Icons.key).first);
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });

    testWidgets('reset password and disable error snacks', (t) async {
      installApi(extra: {
        'POST *': (_) => http.Response('{"error":"denied"}', 403),
      });
      await pump(t, const AccountsTab());
      await t.tap(find.byIcon(Icons.key).first);
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byIcon(Icons.block).first);
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
      await t.enterText(find.byType(TextField).at(2), 'pw');
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
      await t.tap(find.text('Create'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
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
}
