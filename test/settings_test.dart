import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/settings.dart';
import 'package:wfm/version_check.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'server': 'http://test'});
    openExternalForTesting = null;
    openEditorForTesting = null;
    pickFilesForTesting = null;
    UpdateChecker.factoryForTesting = null;
  });

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const WfmApp());
    await settle(t);
  }

  Future<void> goSettings(WidgetTester t) async {
    await pumpApp(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
  }

  testWidgets('avatar upload picks a file and refreshes the user', (t) async {
    final withAvatar = {...userJson, 'avatar': 'avatars/u1/x.png'};
    installApi(extra: {
      'GET /api/me': (_) => {'csrf': 'tok', 'user': withAvatar},
      'PUT /api/me/avatar': (_) => {'ok': true, 'avatar': 'avatars/u1/x.png'},
    });
    pickFilesForTesting = () async => [
          PickedFile('me.png', Uint8List.fromList(const [137, 80, 78, 71]))
        ];
    await goSettings(t);
    expect(find.byType(CircleAvatar), findsWidgets);
    await t.tap(find.byTooltip('Change photo'));
    await settle(t);
    expect(Api.i.user!.avatar, 'avatars/u1/x.png');
  });

  testWidgets('avatar upload errors snack and cancelled picks do nothing',
      (t) async {
    installApi(extra: {
      'PUT /api/me/avatar': (_) => http.Response('{"error":"nope"}', 500),
    });
    pickFilesForTesting = () async => [PickedFile('me.png', Uint8List(4))];
    await goSettings(t);
    await t.tap(find.byTooltip('Change photo'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
    pickFilesForTesting = () async => [];
    await t.tap(find.byTooltip('Change photo'));
    await settle(t);
  });

  testWidgets('shows user line, language and theme pickers', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await goSettings(t);
    expect(find.textContaining('ada'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<Locale?>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<AppTheme>), findsOneWidget);
    await t.ensureVisible(find.byType(DropdownButtonFormField<AppTheme>));
    await settle(t);
    await t.tap(find.byType(DropdownButtonFormField<AppTheme>));
    await settle(t);
    await t.tap(find.text('Dark').last);
    await settle(t);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('theme'), AppTheme.dark.index);
  });

  testWidgets('upload chunk size persists to prefs', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await goSettings(t);
    await t.ensureVisible(find.byType(DropdownButtonFormField<int>));
    await settle(t);
    await t.tap(find.byType(DropdownButtonFormField<int>));
    await settle(t);
    await t.tap(find.text('16 MB').last);
    await settle(t);
    expect(Api.i.chunkSize, 16 * 1048576);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('chunkMb'), 16);
  });

  testWidgets('narrow settings uses popup theme and inline password',
      (t) async {
    installApi(extra: {'GET *': (_) => []});
    t.view.physicalSize = const Size(400, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pumpApp(t);
    await t.tap(find.byIcon(Icons.menu));
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').last);
    await settle(t);
    expect(find.byType(DropdownButtonFormField<AppTheme>), findsNothing);
    expect(find.byType(PopupMenuButton<AppTheme>), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    await t.tap(find.byType(PopupMenuButton<AppTheme>));
    await settle(t);
    await t.tap(find.text('Light').last);
    await settle(t);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('theme'), AppTheme.light.index);
  });

  testWidgets('lists sessions and revokes them', (t) async {
    String? deleted;
    installApi(extra: {
      'GET /api/sessions': (_) => [
            {
              'id': 'a1',
              'ip': '10.0.0.2',
              'ua': 'Agent/1.0',
              'createdAt': 100,
              'expiresAt': 999,
              'lastSeen': 0,
              'current': true,
            },
            {
              'id': 'b2',
              'ip': '10.0.0.9',
              'ua': 'Agent/2.0',
              'createdAt': 100,
              'expiresAt': 999,
              'lastSeen': 200,
              'current': false,
            },
          ],
      'DELETE /api/sessions/b2': (_) {
        deleted = 'b2';
        return {};
      },
      'GET *': (_) => [],
    });
    await goSettings(t);
    await t.tap(find.text('Sessions'));
    await settle(t);
    expect(find.textContaining('This session'), findsOneWidget);
    expect(find.text('Revoke'), findsOneWidget);
    await t.tap(find.text('Revoke'));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.textContaining('10.0.0.9'), findsOneWidget);
    await t.tap(find.text('Revoke'));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(deleted, 'b2');
    expect(find.textContaining('10.0.0.9'), findsNothing);
  });

  testWidgets('session revoke error keeps the row', (t) async {
    installApi(extra: {
      'GET /api/sessions': (_) => [
            {
              'id': 'b2',
              'ip': '10.0.0.9',
              'ua': 'Agent/2.0',
              'createdAt': 100,
              'expiresAt': 999,
              'lastSeen': 200,
              'current': false,
            },
          ],
      'DELETE /api/sessions/b2': (_) => http.Response('{"error":"nope"}', 500),
      'GET *': (_) => [],
    });
    await goSettings(t);
    await t.tap(find.text('Sessions'));
    await settle(t);
    await t.tap(find.text('Revoke'));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(find.textContaining('10.0.0.9'), findsOneWidget);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('sessions page shows error and retries', (t) async {
    var calls = 0;
    installApi(extra: {
      'GET /api/sessions': (_) {
        calls++;
        return calls == 1
            ? http.Response('{"error":"down"}', 500)
            : [
                {
                  'id': 'a1',
                  'ip': '10.0.0.2',
                  'ua': 'Agent/1.0',
                  'createdAt': 100,
                  'expiresAt': 999,
                  'lastSeen': 0,
                  'current': true,
                },
              ];
      },
      'GET *': (_) => [],
    });
    await goSettings(t);
    await t.tap(find.text('Sessions'));
    await settle(t);
    expect(find.textContaining('down'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.textContaining('Agent/1.0'), findsOneWidget);
  });

  testWidgets('owner sees and saves trusted proxies', (t) async {
    String? saved;
    var backupSaveCount = 0;
    installApi(extra: {
      'PUT /api/settings': (req) {
        saved = req.body;
        if (jsonDecode(req.body)['backupCount'] != null &&
            ++backupSaveCount == 2) {
          return http.Response('{"error":"save failed"}', 500);
        }
        return {'ok': true};
      },
      'GET *': (_) => [],
    });
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await goSettings(t);
    expect(find.text('Trusted proxies'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '192.168.1.1, 10.0.0.0/8');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(saved, contains('192.168.1.1'));
    expect(find.byType(Notice), findsOneWidget);
    final field = find.byType(DropdownButtonFormField<String>);
    await t.ensureVisible(field);
    await t.tap(field);
    await settle(t);
    await t.tap(find.text('6').last);
    await settle(t);
    await t.tap(field);
    await settle(t);
    await t.tap(find.text('10').last);
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
  });

  testWidgets('proxies edits survive a rebuild', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(1000, 1200));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.enterText(find.byType(TextField).last, '192.168.1.1, 10.0.0.0/8');
    // Switching theme rebuilds the page; a build()-scoped controller
    // would wipe the unsaved text here.
    await t.tap(find.byType(DropdownButtonFormField<AppTheme>));
    await settle(t);
    await t.tap(find.text('Dark').last);
    await settle(t);
    expect(t.widget<TextField>(find.byType(TextField).last).controller!.text,
        '192.168.1.1, 10.0.0.0/8');
  });

  testWidgets('save proxies error and submit via keyboard', (t) async {
    installApi(extra: {
      'PUT /api/settings': (_) => http.Response('{"error":"bad list"}', 400),
      'GET *': (_) => [],
    });
    t.view.physicalSize = const Size(800, 1400);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await goSettings(t);
    await t.enterText(find.byType(TextField).last, 'bad');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
    await t.tap(find.text('Save'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
  });

  testWidgets('non-owner hides server settings', (t) async {
    installApi(extra: {
      'GET /api/me': (_) => {
            'csrf': 'c',
            'user': {'id': 'u9', 'username': 'tea', 'role': 'teacher'}
          },
      'GET *': (_) => [],
    });
    await pumpApp(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
    expect(find.text('Server'), findsNothing);
    expect(find.text('Trusted proxies'), findsNothing);
  });

  testWidgets('change password dialog', (t) async {
    String? body;
    installApi(extra: {
      'POST /api/me/password': (req) {
        body = req.body;
        return {'ok': true};
      },
      'GET *': (_) => [],
    });
    await goSettings(t);
    await t.tap(find.byIcon(Icons.key));
    await settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField))
            .at(0),
        'oldpass1');
    await t.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField))
            .at(1),
        'newpass12');
    await t.pump();
    await t.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.text('Save')));
    await settle(t);
    expect(body, contains('"next":"newpass12"'));
    expect(find.byType(Notice), findsOneWidget);

    await t.tap(find.byIcon(Icons.key));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
  });

  testWidgets('change password error', (t) async {
    installApi(extra: {
      'POST /api/me/password': (_) => http.Response('{"error":"wrong"}', 400),
      'GET *': (_) => [],
    });
    await goSettings(t);
    await t.tap(find.byIcon(Icons.key));
    await settle(t);
    final save = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Save'));
    final field = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    expect(t.widget<FilledButton>(save).onPressed, isNull);
    await t.enterText(field.at(0), 'oldpass1');
    await t.enterText(field.at(1), 'short');
    await settle(t);
    expect(t.widget<FilledButton>(save).onPressed, isNull);
    await t.enterText(field.at(1), 'newpass12');
    await settle(t);
    await t.tap(save);
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('update check up to date', (t) async {
    installApi(extra: {
      'GET /api/update-check': (_) => {'upToDate': true},
      'GET *': (_) => []
    });
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.scrollUntilVisible(find.text('Check for updates'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await settle(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.textContaining('up to date'), findsOneWidget);
  });

  testWidgets('license tile opens dialog and GitLab link', (t) async {
    var opened = '';
    openExternalForTesting = (u) => opened = u;
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.tap(find.text('View on GitLab'));
    await settle(t);
    expect(opened, 'https://gitlab.com/HttpAnimations/wfm');
    openExternalForTesting = (_) => throw 'no browser';
    await t.tap(find.text('View on GitLab'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
    await t.tap(find.text('Licensed under AGPL-3.0'));
    await settle(t);
    expect(find.textContaining('GNU AFFERO'), findsOneWidget);
    await t.tap(find.text('Done'));
    await settle(t);
    expect(find.textContaining('GNU AFFERO'), findsNothing);
  });

  testWidgets('update available opens release', (t) async {
    var opened = '';
    openExternalForTesting = (u) => opened = u;
    installApi(extra: {
      'GET /api/update-check': (_) =>
          {'latest': '9.9.9', 'tag': 'v9.9.9', 'url': 'https://page/v9.9.9'},
      'GET *': (_) => []
    });
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.scrollUntilVisible(find.text('Check for updates'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await settle(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.textContaining('9.9.9'), findsOneWidget);
    await t.tap(find.text('View release'));
    await settle(t);
    expect(opened, 'https://page/v9.9.9');
  });

  testWidgets('view release without browser shows snack', (t) async {
    installApi(extra: {
      'GET /api/update-check': (_) =>
          {'latest': '9.9.9', 'tag': 'v9.9.9', 'url': 'https://page/v9.9.9'},
      'GET *': (_) => []
    });
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    openExternalForTesting = (_) => throw 'no browser';
    await goSettings(t);
    await t.scrollUntilVisible(find.text('Check for updates'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await settle(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    await t.tap(find.text('View release'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('update check failure', (t) async {
    installApi(extra: {
      'GET /api/update-check': (_) => http.Response('x', 502),
      'GET *': (_) => []
    });
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.scrollUntilVisible(find.text('Check for updates'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await settle(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.text('Update check failed'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Check for updates'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await settle(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.text('Update check failed'), findsOneWidget);
  });

  testWidgets('all languages render the page', (t) async {
    for (final code in ['zh', 'ru', 'ga']) {
      SharedPreferences.setMockInitialValues(
          {'server': 'http://test', 'locale': code});
      installApi(extra: {'GET *': (_) => []});
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(t);
      expect(find.byType(Scaffold), findsWidgets);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('auto-share list add and remove', (t) async {
    var added = false, removed = false, addFail = true;
    installApi(extra: {
      'GET /api/auto-shares': (_) => [
            {
              'id': 'a1',
              'inviteeId': 'u2',
              'inviteeUsername': 'bob',
              'inviteeName': '',
              'level': 'edit',
              'createdAt': 1
            },
            {
              'id': 'a2',
              'inviteeId': 'u3',
              'inviteeUsername': 'carol',
              'inviteeName': '',
              'level': 'view',
              'createdAt': 1
            }
          ],
      'POST /api/auto-shares': (_) {
        if (addFail) return http.Response('{"error":"nope"}', 400);
        added = true;
        return {'ok': true};
      },
      'DELETE /api/auto-shares/a1': (_) {
        removed = true;
        return {'ok': true};
      },
      'DELETE /api/auto-shares/a2': (_) =>
          http.Response('{"error":"nope"}', 400),
    });
    await t.binding.setSurfaceSize(const Size(1000, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    expect(find.text('Auto-share'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('Can edit'), findsOneWidget);
    await t.tap(find.text('Add auto-share'));
    await settle(t);
    await t.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'dave');
    await t.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(DropdownButtonFormField<String>)));
    await settle(t);
    await t.tap(find.text('Can edit').last);
    await settle(t);
    await t.tap(find.text('Send'));
    await settle(t);
    expect(added, isFalse);
    expect(find.byType(Notice), findsOneWidget);
    addFail = false;
    await t.tap(find.text('Add auto-share'));
    await settle(t);
    await t.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'dave');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(added, isTrue);
    await t.tap(find.descendant(
        of: find.widgetWithIcon(ListTile, Icons.close).at(1),
        matching: find.byIcon(Icons.close)));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
    await t.tap(find.descendant(
        of: find.widgetWithIcon(ListTile, Icons.close).first,
        matching: find.byIcon(Icons.close)));
    await settle(t);
    expect(removed, isTrue);
  });

  testWidgets('auto-share hidden for students', (t) async {
    installApi(extra: {
      'GET /api/roles': (_) =>
          {'creatable': <dynamic>[], 'canManage': false, 'canAudit': false},
    });
    await goSettings(t);
    expect(find.text('Auto-share'), findsNothing);
  });

  testWidgets('update check without factory uses real checker', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.scrollUntilVisible(find.text('Check for updates'), 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await settle(t);
    await t.tap(find.text('Check for updates'));
    await settle(t, 60);
    expect(find.text('Update check failed'), findsOneWidget);
  });

  testWidgets('editors external toggle persists the preference', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    final tile = find.byType(SwitchListTile);
    await t.scrollUntilVisible(tile, 200,
        scrollable: find
            .descendant(
                of: find.byType(SettingsPage),
                matching: find.byType(Scrollable))
            .first);
    await t.tap(tile);
    await settle(t);
    expect((await SharedPreferences.getInstance()).getBool('editorsExternal'),
        isTrue);
  });
}
