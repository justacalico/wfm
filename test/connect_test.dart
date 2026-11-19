import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart';
import 'helpers.dart';

void main() {
  Future<void> pumpDesktop(WidgetTester t, Map<String, Object> values) async {
    installApi(extra: {
      'GET /api/setup': (_) => {'needsSetup': false},
    });
    isDesktopApp = true;
    addTearDown(() => isDesktopApp = false);
    SharedPreferences.setMockInitialValues(values);
    await t.pumpWidget(const WfmApp());
    await settle(t);
  }

  testWidgets('connect page saves the server and lands on login', (t) async {
    await pumpDesktop(t, {});
    expect(find.byType(ConnectPage), findsOneWidget);
    await t.enterText(find.byType(TextField), 'wfm.school.example/');
    await t.tap(find.byType(FilledButton));
    await settle(t);
    expect(Api.i.baseUrl, 'https://wfm.school.example');
    final p = await SharedPreferences.getInstance();
    expect(p.getString('serverUrl'), 'https://wfm.school.example');
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('connect page points at the browser when setup is needed',
      (t) async {
    installApi(extra: {
      'GET /api/setup': (_) => {'needsSetup': true},
    });
    isDesktopApp = true;
    addTearDown(() => isDesktopApp = false);
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.enterText(find.byType(TextField), 'https://wfm.school.example');
    await t.tap(find.byType(FilledButton));
    await settle(t);
    expect(find.textContaining('Finish setup in a browser'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('connect page shows a snack when the server is down', (t) async {
    installApi(extra: {
      'GET /api/setup': (_) => 500,
    });
    isDesktopApp = true;
    addTearDown(() => isDesktopApp = false);
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.enterText(find.byType(TextField), 'wfm.school.example');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('desktop gate with a saved url signs straight in', (t) async {
    await pumpDesktop(t, {'serverUrl': 'https://wfm.school.example'});
    expect(Api.i.baseUrl, 'https://wfm.school.example');
    expect(find.byType(Shell), findsOneWidget);
  });
}
