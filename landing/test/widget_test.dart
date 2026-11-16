import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm_landing/main.dart';
import 'package:wfm_landing/releases.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LandingPage.releaseFactoryForTesting =
        () => ReleaseFetcher(MockClient((_) async => http.Response('[]', 200)));
  });

  testWidgets('landing page renders', (tester) async {
    await tester.pumpWidget(const LandingApp());
    expect(find.text('WFM'), findsOneWidget);
    await tester.dragUntilVisible(find.text('Open the app'),
        find.byType(ListView), const Offset(0, -300));
    expect(find.text('Open the app'), findsOneWidget);
  });
}
