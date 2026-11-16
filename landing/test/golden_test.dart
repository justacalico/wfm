import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm_landing/main.dart';
import 'package:wfm_landing/releases.dart';

Future<void> _fonts() async {
  final reg = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final loader = FontLoader('Noto Sans')
    ..addFont(Future.value(reg.buffer.asByteData()))
    ..addFont(Future.value(bold.buffer.asByteData()));
  await loader.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(icons.readAsBytesSync().buffer.asByteData()));
      await iconLoader.load();
    }
  }
}

void main() {
  setUpAll(_fonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LandingPage.releaseFactoryForTesting = () => ReleaseFetcher(MockClient(
        (_) async => http.Response(
            '[{"tag_name":"v1.0.0","name":"WFM 1.0","_links":{"self":"https://gitlab.com/x"},"assets":{"links":[{"name":"wfm-linux.tar.gz","direct_asset_url":"https://gitlab.com/x/dl"}]}}]',
            200)));
  });

  Future<void> snap(WidgetTester t, String name) async {
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('landing goldens', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(const LandingApp());
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await snap(t, 'landing_top');

    await t.dragUntilVisible(find.text('Open the app'), find.byType(ListView),
        const Offset(0, -400));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await snap(t, 'landing_bottom');

    SharedPreferences.setMockInitialValues({'theme': 2, 'locale': 'zh'});
    await t.pumpWidget(const LandingApp());
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    await snap(t, 'landing_dark_zh');
    await t.pumpWidget(const SizedBox());
  });
}
