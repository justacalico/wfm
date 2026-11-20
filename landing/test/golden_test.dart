import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm_landing/main.dart';
import 'package:wfm_landing/releases.dart';

/// The screenshots section embeds the app's own golden PNGs. Their decode is
/// racy under the test binding, so fail fast and let the cards collapse via
/// their error builders instead of landing mid-decode.
class _NoScreenshots extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => key.startsWith('assets/screenshots/')
      ? throw FlutterError('blocked in golden test')
      : rootBundle.load(key);

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      key.startsWith('assets/screenshots/')
          ? throw FlutterError('blocked in golden test')
          : rootBundle.loadString(key, cache: cache);
}

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

  Future<void> settle(WidgetTester t, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> tour(WidgetTester t, String dir) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(DefaultAssetBundle(
        bundle: _NoScreenshots(), child: const LandingApp()));
    await settle(t);
    await snap(t, '$dir/landing_top');

    final scroll =
        t.state<ScrollableState>(find.byType(Scrollable).first).position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await settle(t);
    await snap(t, '$dir/landing_bottom');
    await t.pumpWidget(const SizedBox());
  }

  for (final (dir, theme) in [
    ('light', LandingTheme.light),
    ('dark', LandingTheme.dark),
    ('oled', LandingTheme.oled),
  ]) {
    testWidgets('landing $dir', (t) async {
      SharedPreferences.setMockInitialValues({'theme': theme.index});
      await tour(t, dir);
    });
  }

  testWidgets('landing dark zh', (t) async {
    SharedPreferences.setMockInitialValues(
        {'theme': LandingTheme.dark.index, 'locale': 'zh'});
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(DefaultAssetBundle(
        bundle: _NoScreenshots(), child: const LandingApp()));
    await settle(t);
    await snap(t, 'dark/landing_zh');
    await t.pumpWidget(const SizedBox());
  });
}
