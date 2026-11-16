import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wfm_landing/main.dart';

void main() {
  testWidgets('landing page renders', (tester) async {
    await tester.pumpWidget(const LandingApp());
    expect(find.text('WFM'), findsOneWidget);
    await tester.dragUntilVisible(
        find.text('Open the app'), find.byType(ListView), const Offset(0, -300));
    expect(find.text('Open the app'), findsOneWidget);
  });
}
