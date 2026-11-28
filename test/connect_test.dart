import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/connect.dart';
import 'package:wfm/craft/runner.dart';
import 'package:wfm/l10n/app_localizations_en.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform_io.dart';

import 'helpers.dart';

class _Proc implements CraftProcess {
  final done = Completer<int>();
  bool killed = false;
  @override
  Future<int> get exit => done.future;
  @override
  void kill() {
    killed = true;
    if (!done.isCompleted) done.complete(0);
  }
}

void main() {
  final l10n = AppLocalizationsEn();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('connect_test');
    SharedPreferences.setMockInitialValues({'server': 'http://test'});
    appVersionForTesting = '1.2.3';
    openExternalForTesting = null;
    openEditorForTesting = null;
    craftRunnerForTesting = null;
    craftDirForTesting = '';
    appSupportForTesting = tmp;
    editorsInBrowserForTesting = null;
    spawnHelperForTesting = null;
    isNativeAppForTesting = null;
  });

  tearDown(() async {
    appVersionForTesting = null;
    appSupportForTesting = null;
    await tmp.delete(recursive: true);
  });

  test('normalizeServerUrl fixes user input', () {
    expect(normalizeServerUrl('  '), '');
    expect(normalizeServerUrl('wfm.school'), 'http://wfm.school');
    expect(normalizeServerUrl('http://a/b//'), 'http://a/b');
    expect(normalizeServerUrl('https://x/'), 'https://x');
  });

  test('releaseUrl points at the mirror tag', () {
    expect(releaseUrl('1.2.3'),
        'https://github.com/justacalico/wfm/releases/tag/v1.2.3');
  });

  test('serverMatches compares exact versions', () async {
    final api = installApi();
    expect(await serverMatches(api), (true, '1.2.3'));
    final bad = Api(FakeClient({
      'GET /api/version': (_) => {'version': '9.9'}
    }))
      ..baseUrl = 'http://x';
    expect(await serverMatches(bad), (false, '9.9'));
  });

  test('nativeGate sends unset servers to connect', () async {
    SharedPreferences.setMockInitialValues({});
    installApi();
    expect(await nativeGate(Api.i), isA<ConnectPage>());
  });

  test('nativeGate gates on version mismatch', () async {
    final api = Api(FakeClient({
      'GET /api/version': (_) => {'version': '9.9'}
    }))
      ..baseUrl = 'http://x';
    final w = await nativeGate(api);
    expect(w, isA<UpdatePage>());
    expect((w as UpdatePage).serverVersion, '9.9');
  });

  test('nativeGate restores base url and session token', () async {
    SharedPreferences.setMockInitialValues(
        {'server': 'http://test', 'session': 'tok'});
    installApi();
    expect(await nativeGate(Api.i), isNull);
    expect(Api.i.baseUrl, 'http://test');
    expect(Api.i.sessionToken, 'tok');
  });

  testWidgets('connect page connects to a matching server', (t) async {
    SharedPreferences.setMockInitialValues({});
    installApi();
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.byType(ConnectPage), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, l10n.connect));
    await settle(t);
    expect(find.byType(ConnectPage), findsOneWidget);
    await t.enterText(find.byType(TextField), 'wfm.school');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t, 20);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('server'), 'http://wfm.school');
  });

  testWidgets('connect page jumps to update on mismatch', (t) async {
    SharedPreferences.setMockInitialValues({});
    Api.i = Api(FakeClient({
      'GET /api/version': (_) => {'version': '9.9'}
    }));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.enterText(find.byType(TextField), 'a.b');
    await t.tap(find.widgetWithText(FilledButton, l10n.connect));
    await settle(t);
    expect(find.byType(UpdatePage), findsOneWidget);
  });

  testWidgets('connect page reports a non-wfm server', (t) async {
    SharedPreferences.setMockInitialValues({});
    Api.i = Api(
        FakeClient({'GET /api/version': (_) => http.Response('nope', 404)}));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.enterText(find.byType(TextField), 'a.b');
    await t.tap(find.widgetWithText(FilledButton, l10n.connect));
    await settle(t);
    expect(find.text(l10n.notAWfmServer), findsOneWidget);
  });

  testWidgets('update page offers download, recheck and change server',
      (t) async {
    String? opened;
    openExternalForTesting = (u) => opened = u;
    Api.i = Api(FakeClient({
      'GET /api/version': (_) => {'version': '9.9'}
    }));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.byType(UpdatePage), findsOneWidget);
    expect(find.text(l10n.updateRequiredBody('9.9', '1.2.3')), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, l10n.downloadUpdate));
    expect(opened, releaseUrl('9.9'));
    await t.tap(find.widgetWithText(OutlinedButton, l10n.checkAgain));
    await settle(t);
    expect(find.text(l10n.updateStillRequired), findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, l10n.changeServer));
    await settle(t);
    expect(find.byType(ConnectPage), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('server'), isNull);
  });

  testWidgets('update page rechecks into the gate', (t) async {
    var ver = '9.9';
    installApi(extra: {
      'GET /api/version': (_) => {'version': ver}
    });
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.byType(UpdatePage), findsOneWidget);
    expect(find.text(l10n.updateRequiredBody('9.9', '1.2.3')), findsOneWidget);
    ver = '1.2.3';
    await t.tap(find.widgetWithText(OutlinedButton, l10n.checkAgain));
    await settle(t, 20);
    expect(find.byType(UpdatePage), findsNothing);
  });

  testWidgets('update page surfaces recheck errors', (t) async {
    var boom = false;
    Api.i = Api(FakeClient({
      'GET /api/version': (_) =>
          boom ? http.Response('down', 500) : {'version': '9.9'}
    }));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.byType(UpdatePage), findsOneWidget);
    boom = true;
    await t.tap(find.widgetWithText(OutlinedButton, l10n.checkAgain));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('the app boots into connect without a server', (t) async {
    SharedPreferences.setMockInitialValues({});
    installApi();
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.byType(ConnectPage), findsOneWidget);
  });

  testWidgets('the app blocks on a version mismatch', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/version': (_) => {'version': '9.9'}
    }))
      ..baseUrl = 'x';
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.byType(UpdatePage), findsOneWidget);
  });

  test('serverKey and checkout paths derive from the server', () async {
    expect(serverKey('https://a.b:8443/x'), 'https_a_b_8443_x');
    final api = installApi()..baseUrl = 'https://a.b';
    expect((await checkoutDirFor(api, 'p9')).path,
        '${tmp.path}/checkouts/https_a_b/p9');
    expect((await craftDataDirFor(api, 'p9')).path,
        '${tmp.path}/craftdata/https_a_b/p9');
  });

  test('craftDir honors the seam, env and dev staging dir', () async {
    Directory('desktop/craft').createSync(recursive: true);
    craftDirForTesting = null;
    final dev = await craftDir();
    expect(dev!.path, endsWith('desktop/craft'));
    craftDirForTesting = '';
    expect(await craftDir(), isNull);
    craftDirForTesting = tmp.path;
    expect((await craftDir())!.path, tmp.path);
    expect(await craftBinary('wfm-webview'), '${tmp.path}/wfm-webview');
  });

  test('editorsInBrowser reads the preference', () async {
    expect(await editorsInBrowser(), isFalse);
    SharedPreferences.setMockInitialValues({'editorsExternal': true});
    expect(await editorsInBrowser(), isTrue);
    editorsInBrowserForTesting = false;
    expect(await editorsInBrowser(), isFalse);
  });

  test('openExternal hands api urls through handoff', () async {
    final api = installApi(extra: {
      'POST /api/handoff': (_) => {'t': 'tt'}
    })
      ..baseUrl = 'http://test';
    await openExternal('${api.baseUrl}/api/projects/p1/download?path=a');
    expect(lastRequest!.url.path, '/api/handoff');
    String? got;
    openExternalForTesting = (u) => got = u;
    await openExternal('https://elsewhere.example/x');
    expect(got, 'https://elsewhere.example/x');
  });

  Widget launcher(Future<void> Function(BuildContext) f) => testApp(Scaffold(
      body: Builder(
          builder: (ctx) => FilledButton(
              onPressed: () => unawaited(f(ctx)), child: const Text('go')))));

  Future<void> drainIo(WidgetTester t, [int n = 30]) async {
    for (var i = 0; i < n; i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
      await t.pump();
    }
  }

  Future<void> tapGo(WidgetTester t) async {
    await t.tap(find.text('go'));
    await drainIo(t);
    await settle(t);
  }

  testWidgets('openEditor routes scriptcraft to the webview helper', (t) async {
    final api = installApi(extra: {
      'POST /api/handoff': (_) => {'t': 'tt'}
    });
    File('${tmp.path}/wfm-webview').createSync();
    craftDirForTesting = tmp.path;
    String? exe;
    List<String>? args;
    spawnHelperForTesting = (e, a, env) async {
      exe = e;
      args = a;
    };
    await t.pumpWidget(launcher((ctx) => openEditor(
        ctx, api, '${api.baseUrl}/scriptcraft/wfm.html?project=p1',
        projectName: 'Short Film')));
    await tapGo(t);
    expect(exe, '${tmp.path}/wfm-webview');
    expect(args!.first, contains('/api/handoff?t=tt'));
    expect(args, containsAll(['--title', 'Short Film']));
  });

  testWidgets('openEditor honors the browser preference', (t) async {
    final api = installApi(extra: {
      'POST /api/handoff': (_) => {'t': 'tt'}
    });
    File('${tmp.path}/wfm-webview').createSync();
    craftDirForTesting = tmp.path;
    editorsInBrowserForTesting = true;
    var spawned = false;
    spawnHelperForTesting = (e, a, env) async => spawned = true;
    await t.pumpWidget(launcher((ctx) =>
        openEditor(ctx, api, '${api.baseUrl}/deckcraft/wfm.html?project=p1')));
    await tapGo(t);
    expect(spawned, isFalse);
  });

  testWidgets('openEditor falls back to browser without the helper', (t) async {
    final api = installApi(extra: {
      'POST /api/handoff': (_) => {'t': 'tt'}
    });
    craftDirForTesting = tmp.path;
    var spawned = false;
    spawnHelperForTesting = (e, a, env) async => spawned = true;
    await t.pumpWidget(launcher((ctx) => openEditor(
        ctx, api, 'https://other.example/deckcraft/wfm.html?project=p1')));
    await tapGo(t);
    expect(spawned, isFalse);
  });

  testWidgets('filmcraft without a bundled binary falls back to hosted',
      (t) async {
    final api = installApi(extra: {
      'POST /api/handoff': (_) => {'t': 'tt'}
    });
    craftDirForTesting = tmp.path;
    var spawned = false;
    spawnHelperForTesting = (e, a, env) async => spawned = true;
    await t.pumpWidget(launcher((ctx) => openEditor(
        ctx, api, '${api.baseUrl}/filmcraft/wfm.html?project=p1&render=r1')));
    await tapGo(t);
    expect(spawned, isFalse);
  });

  testWidgets('filmcraft opens the native editor against a checkout',
      (t) async {
    final proc = _Proc();
    final api = installApi(extra: {
      'POST /api/projects/p1/locks': (_) => {'acquired': true},
      'GET /api/projects/p1/manifest': (_) => [
            {
              'name': 'project.fcproj',
              'path': 'project.fcproj',
              'type': 'file',
              'rev': 'r1',
              'size': 2,
              'modified': 0
            }
          ],
      'GET /api/projects/p1/download': (_) =>
          http.Response.bytes('{}'.codeUnits, 200),
    });
    File('${tmp.path}/wfm-filmcraft').createSync();
    craftDirForTesting = tmp.path;
    List<String>? spawned;
    craftRunnerForTesting =
        CraftRunner(api, spawn: (e, a, {workingDirectory, env}) async {
      spawned = [e, ...a];
      return proc;
    });
    await t.pumpWidget(launcher((ctx) =>
        openEditor(ctx, api, '${api.baseUrl}/filmcraft/wfm.html?project=p1')));
    await tapGo(t);
    expect(spawned, isNotNull);
    expect(spawned!.first, '${tmp.path}/wfm-filmcraft');
    expect(spawned!.last, endsWith('project.fcproj'));
    expect(find.byType(AlertDialog), findsNothing);
    proc.done.complete(0);
    await drainIo(t);
    expect(craftRunnerForTesting!.runs, isEmpty);
  });

  testWidgets('filmcraft lock take-over asks the user first', (t) async {
    var calls = 0;
    final proc = _Proc();
    final api = installApi(extra: {
      'POST /api/projects/p1/locks': (_) {
        calls++;
        return calls == 1
            ? http.Response(
                '{"acquired":false,"lock":{"holder":"ada","label":"","expiresAt":0}}',
                409)
            : {'acquired': true};
      },
      'GET /api/projects/p1/manifest': (_) => [],
    });
    File('${tmp.path}/wfm-filmcraft').createSync();
    craftDirForTesting = tmp.path;
    craftRunnerForTesting =
        CraftRunner(api, spawn: (e, a, {workingDirectory, env}) async => proc);
    await t.pumpWidget(launcher((ctx) =>
        openEditor(ctx, api, '${api.baseUrl}/filmcraft/wfm.html?project=p1')));
    await t.tap(find.text('go'));
    for (var i = 0;
        i < 50 && find.text(l10n.editLockHeld('ada')).evaluate().isEmpty;
        i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
      await t.pump();
    }
    expect(find.text(l10n.editLockHeld('ada')), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await drainIo(t);
    expect(calls, 2);
    proc.done.complete(0);
    await drainIo(t);
  });

  testWidgets('filmcraft open failures snack the reason', (t) async {
    final proc = _Proc();
    final api = installApi(extra: {
      'POST /api/projects/p1/locks': (_) => {'acquired': true},
      'GET /api/projects/p1/manifest': (_) => [],
    });
    File('${tmp.path}/wfm-filmcraft').createSync();
    craftDirForTesting = tmp.path;
    craftRunnerForTesting =
        CraftRunner(api, spawn: (e, a, {workingDirectory, env}) async => proc);
    await t.pumpWidget(launcher((ctx) =>
        openEditor(ctx, api, '${api.baseUrl}/filmcraft/wfm.html?project=p1')));
    await tapGo(t);
    await t.tap(find.text('go'));
    await drainIo(t);
    expect(find.text(l10n.editAlreadyOpen), findsOneWidget);
    proc.done.complete(0);
    await drainIo(t);
  });

  testWidgets('filmcraft declined take-over snacks', (t) async {
    final api = installApi(extra: {
      'POST /api/projects/p1/locks': (_) => http.Response(
          '{"acquired":false,"lock":{"holder":"ada","label":"","expiresAt":0}}',
          409),
    });
    File('${tmp.path}/wfm-filmcraft').createSync();
    craftDirForTesting = tmp.path;
    craftRunnerForTesting = CraftRunner(api,
        spawn: (e, a, {workingDirectory, env}) async => _Proc());
    await t.pumpWidget(launcher((ctx) =>
        openEditor(ctx, api, '${api.baseUrl}/filmcraft/wfm.html?project=p1')));
    await t.tap(find.text('go'));
    for (var i = 0;
        i < 50 &&
            find.widgetWithText(FilledButton, l10n.confirm).evaluate().isEmpty;
        i++) {
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
      await t.pump();
    }
    await t.tap(find.widgetWithText(TextButton, l10n.cancel));
    await drainIo(t);
    expect(find.text(l10n.editDeclined), findsOneWidget);
  });

  testWidgets('filmcraft spawn failure snacks the error', (t) async {
    final api = installApi(extra: {
      'POST /api/projects/p1/locks': (_) => {'acquired': true},
      'GET /api/projects/p1/manifest': (_) => [],
    });
    File('${tmp.path}/wfm-filmcraft').createSync();
    craftDirForTesting = tmp.path;
    craftRunnerForTesting = CraftRunner(api,
        spawn: (e, a, {workingDirectory, env}) async =>
            throw StateError('dead binary'));
    await t.pumpWidget(launcher((ctx) =>
        openEditor(ctx, api, '${api.baseUrl}/filmcraft/wfm.html?project=p1')));
    await tapGo(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  test('spawnHelper starts a detached process', () async {
    await spawnHelper('/bin/true', [], {});
  });

  testWidgets('mediaPlayer offers an external open button', (t) async {
    String? url;
    openExternalForTesting = (u) => url = u;
    await t.pumpWidget(testApp(
        mediaPlayer('http://m/x.mp4', audio: false, openLabel: 'Open')));
    await t.tap(find.text('Open'));
    expect(url, 'http://m/x.mp4');
  });
}
