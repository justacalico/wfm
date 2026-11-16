import 'package:flutter_test/flutter_test.dart';
import 'package:wfm/main.dart';

void main() {
  testWidgets('app boots to a loading indicator', (tester) async {
    await tester.pumpWidget(const WfmApp());
    expect(find.byType(WfmApp), findsOneWidget);
  });
}
