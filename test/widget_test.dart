import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/l10n/app_localizations.dart';
import 'package:wfm/main.dart';
import 'package:wfm/manage.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/projects.dart';
import 'package:wfm/settings.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    pickFilesForTesting = null;
  });

  Future<void> pumpWfm(WidgetTester t) async {
    await t.pumpWidget(const WfmApp());
    await settle(t);
  }

  Future<void> tapNav(WidgetTester t, String label) =>
      t.tap(find.widgetWithText(ListTile, label).first).then((_) => settle(t));

  testWidgets('gate shows setup when needed', (t) async {
    Api.i = Api(sessionClient(extra: {
      'GET /api/setup': (_) => {'needsSetup': true}
    }));
    await pumpWfm(t);
    expect(find.byType(SetupPage), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Trusted proxies'), findsNothing);
  });

  testWidgets('setup creates owner and lands on shell', (t) async {
    String? body;
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': true},
      'POST /api/setup': (req) {
        body = req.body;
        return {'csrf': 'c', 'user': userJson};
      },
      'GET /api/roles': (_) => {
            'creatable': ['student'],
            'canManage': true,
            'canAudit': true
          },
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    await t.enterText(find.byType(TextField).at(0), 'Ada');
    await t.enterText(find.byType(TextField).at(1), 'ada');
    await t.enterText(find.byType(TextField).at(2), 'pw');
    await t.tap(find.byType(FilledButton));
    await settle(t);
    expect(body, isNot(contains('trustedProxies')));
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('setup error is displayed', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': true},
      'POST /api/setup': (_) => http.Response('{"error":"taken"}', 409),
    }));
    await pumpWfm(t);
    await t.tap(find.byType(FilledButton));
    await settle(t);
    expect(find.text('taken'), findsOneWidget);
    expect(find.byType(SetupPage), findsOneWidget);
  });

  testWidgets('gate shows login when signed out, login works', (t) async {
    var posts = 0;
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => http.Response('{"error":"auth"}', 401),
      'POST /api/login': (_) {
        posts++;
        return {'csrf': 'c', 'user': userJson};
      },
      'GET /api/roles': (_) => {
            'creatable': ['student'],
            'canManage': true,
            'canAudit': true
          },
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    expect(find.byType(LoginPage), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'ada');
    await t.enterText(find.byType(TextField).at(1), 'pw');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(posts, 1);
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('login failure shows error', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => http.Response('{"error":"auth"}', 401),
      'POST /api/login': (_) => http.Response('{"error":"bad"}', 403),
    }));
    await pumpWfm(t);
    await t.tap(find.byType(FilledButton));
    await settle(t);
    expect(find.textContaining('bad'), findsWidgets);
  });

  testWidgets('gate shows error and retry when server is down', (t) async {
    var down = true;
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) =>
          down ? http.Response('x', 500) : {'needsSetup': false},
      'GET /api/me': (_) => http.Response('{"error":"auth"}', 401),
    }));
    await pumpWfm(t);
    expect(find.byType(GateError), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    down = false;
    await t.tap(find.byType(FilledButton));
    await settle(t);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('gate shows error when me fails non-auth', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => http.Response('{"error":"boom"}', 500),
    }));
    await pumpWfm(t);
    expect(find.byType(GateError), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('mid-session 401 returns to login', (t) async {
    var expired = false;
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => expired
          ? http.Response('{"error":"auth"}', 401)
          : {'csrf': 'c', 'user': userJson},
      'GET /api/roles': (_) => {
            'creatable': ['student'],
            'canManage': true,
            'canAudit': true
          },
      'GET /api/version': (_) => http.Response('{"error":"x"}', 401),
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    expect(find.byType(Shell), findsOneWidget);
    expired = true;
    await Api.i.get('/version').catchError((_) => null);
    await settle(t);
    expect(Api.i.user, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('pages do not crash on a null user', (t) async {
    installApi(extra: {'GET *': (_) => []});
    Api.i.user = null;
    Future<void> bare(Widget w) => t.pumpWidget(MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: appLocales,
          home: w,
        ));
    await bare(const Shell());
    await bare(const HomePage());
    await bare(const SettingsPage());
    await settle(t);
  });

  testWidgets('session resume goes straight to shell', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await pumpWfm(t);
    expect(find.byType(Shell), findsOneWidget);
    expect(find.textContaining('Ada'), findsWidgets);
  });

  testWidgets('shell nav and logout', (t) async {
    var authed = true;
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => authed
          ? {'csrf': 'c', 'user': userJson}
          : http.Response('{"error":"auth"}', 401),
      'GET /api/roles': (_) => {
            'creatable': ['student'],
            'canManage': true,
            'canAudit': true
          },
      'GET /api/version': (_) => {'version': '1.0'},
      'POST /api/logout': (_) {
        authed = false;
        return {'ok': true};
      },
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    expect(find.byType(Shell), findsOneWidget);
    await tapNav(t, 'Projects');
    expect(find.byType(ProjectsPage), findsOneWidget);
    await tapNav(t, 'Manage');
    expect(find.byType(ManagePage), findsOneWidget);
    await tapNav(t, 'Settings');
    expect(find.byType(SettingsPage), findsOneWidget);
    await t.tap(find.byIcon(Icons.logout));
    await settle(t);
    expect(Api.i.user, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('home cards navigate', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await pumpWfm(t);
    await t.tap(find.text('Open your film projects'));
    await settle(t);
    expect(find.byType(ProjectsPage), findsOneWidget);
    await tapNav(t, 'Home');
    await t.tap(find.text('Accounts and permissions'));
    await settle(t);
    expect(find.byType(ManagePage), findsOneWidget);
  });

  testWidgets('narrow layout uses drawer', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(500, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await pumpWfm(t);
    await t.tap(find.byIcon(Icons.menu));
    await settle(t);
    expect(find.byType(Drawer), findsOneWidget);
    await t.tap(find.widgetWithText(ListTile, 'Projects'));
    await settle(t);
    expect(find.byType(ProjectsPage), findsOneWidget);
  });

  testWidgets('student without manage caps sees fewer tabs', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => {
            'csrf': 'c',
            'user': {
              'id': 'u9',
              'username': 'stu',
              'role': 'student',
              'displayName': ''
            }
          },
      'GET /api/roles': (_) =>
          {'creatable': [], 'canManage': false, 'canAudit': false},
      'GET /api/version': (_) => {'version': '1.0'},
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    expect(find.byType(Shell), findsOneWidget);
    expect(find.text('Manage'), findsNothing);
    await tapNav(t, 'Settings');
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('theme and locale persist', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await pumpWfm(t);
    await tapNav(t, 'Settings');
    await t.tap(find.byType(DropdownButtonFormField<AppTheme>));
    await settle(t);
    await t.tap(find.text('OLED').last);
    await settle(t);
    final p = await SharedPreferences.getInstance();
    expect(p.getInt('theme'), AppTheme.oled.index);
    await t.tap(find.byType(DropdownButtonFormField<Locale?>));
    await settle(t);
    await t.tap(find.text('Gaeilge').last);
    await settle(t);
    expect(p.getString('locale'), 'ga');
    expect(find.textContaining('Socruithe'), findsWidgets);
  });

  testWidgets('saved theme and locale restore on boot', (t) async {
    SharedPreferences.setMockInitialValues(
        {'theme': 3, 'locale': 'zh', 'chunkMb': 16});
    installApi(extra: {'GET *': (_) => []});
    await pumpWfm(t);
    final app = t.state<WfmAppState>(find.byType(WfmApp));
    expect(app.appTheme, AppTheme.oled);
    expect(app.appLocale?.languageCode, 'zh');
    expect(Api.i.chunkSize, 16 * 1048576);
  });

  testWidgets('country-coded locale serializes with underscore', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await pumpWfm(t);
    t
        .state<WfmAppState>(find.byType(WfmApp))
        .setLocale(const Locale('en', 'GB'));
    final p = await SharedPreferences.getInstance();
    expect(p.getString('locale'), 'en_GB');
  });

  testWidgets('no saved theme defaults to system', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await pumpWfm(t);
    expect(t.state<WfmAppState>(find.byType(WfmApp)).appTheme, AppTheme.system);
  });
}
