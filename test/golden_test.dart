import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadTestFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    pickFilesForTesting = null;
  });

  Future<void> snap(WidgetTester t, String name) async {
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  Future<void> tapNav(WidgetTester t, String label) =>
      t.tap(find.widgetWithText(ListTile, label).first).then((_) => settle(t));

  Future<void> pumpWfm(WidgetTester t) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(const WfmApp());
    await settle(t);
  }

  testWidgets('setup and login pages', (t) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': true},
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    await snap(t, 'setup');
    await t.pumpWidget(const SizedBox());

    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => http.Response('{"error":"x"}', 401),
      'GET *': (_) => [],
    }));
    await pumpWfm(t);
    await snap(t, 'login');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('shell pages', (t) async {
    installApi();
    await pumpWfm(t);
    await snap(t, 'home');

    await tapNav(t, 'Projects');
    await snap(t, 'projects');

    await t.tap(find.text('Short Film'));
    await settle(t);
    await snap(t, 'project_files');

    await t.tap(find.text('Renders'));
    await settle(t);
    await snap(t, 'project_renders');

    await t.pumpWidget(const SizedBox());
    await pumpWfm(t);
    await tapNav(t, 'Manage');
    await snap(t, 'manage_accounts');

    await t.tap(find.text('Activity'));
    await settle(t);
    await snap(t, 'manage_audit');

    await t.tap(find.text('Render nodes'));
    await settle(t);
    await snap(t, 'manage_nodes');

    await tapNav(t, 'Settings');
    await snap(t, 'settings');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('dark, oled and zh variants', (t) async {
    installApi();
    SharedPreferences.setMockInitialValues({'theme': AppTheme.dark.index});
    await pumpWfm(t);
    await snap(t, 'home_dark');
    await t.pumpWidget(const SizedBox());

    SharedPreferences.setMockInitialValues({'theme': AppTheme.oled.index});
    await pumpWfm(t);
    await snap(t, 'home_oled');
    await t.pumpWidget(const SizedBox());

    SharedPreferences.setMockInitialValues({'locale': 'zh'});
    await pumpWfm(t);
    await snap(t, 'home_zh');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('narrow layout', (t) async {
    installApi();
    await t.binding.setSurfaceSize(const Size(420, 800));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await snap(t, 'home_narrow');
    await t.pumpWidget(const SizedBox());
  });
}
