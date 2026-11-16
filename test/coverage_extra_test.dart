import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart' as app;
import 'package:wfm/manage.dart';
import 'package:wfm/platform.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    pickFilesForTesting = null;
  });

  testWidgets('setup submits via password field done action', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': true},
      'POST /api/setup': (_) => {'csrf': 'c', 'user': userJson},
      'GET /api/roles': (_) => {
            'creatable': ['student'],
            'canManage': true,
            'canAudit': true
          },
      'GET *': (_) => [],
    }));
    await t.pumpWidget(const app.WfmApp());
    await settle(t);
    expect(find.byType(app.SetupPage), findsOneWidget);
    await t.enterText(find.byType(TextField).at(0), 'Ada');
    await t.enterText(find.byType(TextField).at(1), 'ada');
    await t.enterText(find.byType(TextField).at(2), 'pw');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(find.byType(app.Shell), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('language selection persists locale', (t) async {
    installApi(extra: {'GET *': (_) => []});
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const app.WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
    await t.tap(find.byType(DropdownButtonFormField<Locale?>));
    await settle(t);
    await t.tap(find.text('简体中文').last);
    await t.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), 'zh_');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('system language clears locale preference', (t) async {
    installApi(extra: {'GET *': (_) => []});
    SharedPreferences.setMockInitialValues({'locale': 'zh'});
    await t.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const app.WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, '设置').first);
    await settle(t);
    await t.tap(find.byType(DropdownButtonFormField<Locale?>));
    await settle(t);
    await t.tap(find.text('跟随系统').last);
    await t.pump();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('locale'), isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('create account uses first creatable role', (t) async {
    Api.i = Api(sessionClient())
      ..csrf = 'tok'
      ..user = User.fromJson(userJson)
      ..caps = Caps.fromJson({
        'creatable': ['teacher'],
        'canManage': true,
        'canAudit': true
      });
    await t.pumpWidget(testApp(const ManagePage()));
    await settle(t);
    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('teacher'), findsWidgets);
    await t.tap(find.text('Cancel'));
    await settle(t);
    await t.pumpWidget(const SizedBox());
  });
}
