import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/version_check.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
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

  testWidgets('shows user line, language and theme pickers', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await goSettings(t);
    expect(find.textContaining('ada'), findsWidgets);
    expect(find.byType(DropdownButtonFormField<Locale?>), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<AppTheme>), findsOneWidget);
    await t.tap(find.byType(DropdownButtonFormField<AppTheme>));
    await settle(t);
    await t.tap(find.text('Dark').last);
    await settle(t);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('theme'), AppTheme.dark.index);
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

  testWidgets('owner sees and saves trusted proxies', (t) async {
    String? saved;
    installApi(extra: {
      'PUT /api/settings': (req) {
        saved = req.body;
        return {'ok': true};
      },
      'GET *': (_) => [],
    });
    await goSettings(t);
    expect(find.text('Trusted proxies'), findsOneWidget);
    await t.enterText(find.byType(TextField).last, '192.168.1.1, 10.0.0.0/8');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(saved, contains('192.168.1.1'));
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('proxies edits survive a rebuild', (t) async {
    installApi(extra: {'GET *': (_) => []});
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
    installApi(extra: {'GET *': (_) => []});
    UpdateChecker.factoryForTesting = () => UpdateChecker(
        _StaticClient((_) async => http.Response('[]', 200)),
        apiUrl: 'https://x');
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.textContaining('up to date'), findsOneWidget);
  });

  testWidgets('update available opens release', (t) async {
    var opened = '';
    openExternalForTesting = (u) => opened = u;
    installApi(extra: {'GET *': (_) => []});
    UpdateChecker.factoryForTesting = () => UpdateChecker(
        _StaticClient(
            (_) async => http.Response('[{"tag_name":"v9.9.9"}]', 200)),
        apiUrl: 'https://x',
        pageUrl: 'https://page');
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.textContaining('9.9.9'), findsOneWidget);
    await t.tap(find.text('View release'));
    await settle(t);
    expect(opened, 'https://page/v9.9.9');
  });

  testWidgets('view release without browser shows snack', (t) async {
    installApi(extra: {'GET *': (_) => []});
    UpdateChecker.factoryForTesting = () => UpdateChecker(
        _StaticClient(
            (_) async => http.Response('[{"tag_name":"v9.9.9"}]', 200)),
        apiUrl: 'https://x',
        pageUrl: 'https://page');
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    await t.tap(find.text('View release'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('update check failure', (t) async {
    installApi(extra: {'GET *': (_) => []});
    UpdateChecker.factoryForTesting = () => UpdateChecker(
        _StaticClient((_) async => http.Response('x', 500)),
        apiUrl: 'https://x');
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.text('Update check failed'), findsOneWidget);
    await t.tap(find.text('Check for updates'));
    await settle(t);
    expect(find.text('Update check failed'), findsOneWidget);
  });

  testWidgets('all languages render the page', (t) async {
    for (final code in ['zh', 'ru', 'ga']) {
      SharedPreferences.setMockInitialValues({'locale': code});
      installApi(extra: {'GET *': (_) => []});
      await pumpApp(t);
      await t.tap(find.byIcon(Icons.settings_outlined).first);
      await settle(t);
      expect(find.byType(Scaffold), findsWidgets);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('update check without factory uses real checker', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await goSettings(t);
    await t.tap(find.text('Check for updates'));
    await settle(t, 60);
    expect(find.text('Update check failed'), findsOneWidget);
  });
}

class _StaticClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest) f;
  _StaticClient(this.f);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = await f(request);
    return http.StreamedResponse(Stream.value(r.bodyBytes), r.statusCode,
        headers: r.headers, request: request);
  }
}
