import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/link.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    openEditorForTesting = null;
  });
  tearDown(() => openExternalForTesting = null);

  Map<String, Object> resolve(
          {String scope = 'project', List<Object>? files}) =>
      {
        'name': 'Grad Film',
        'scope': scope,
        'files': files ??
            [
              {'path': 'Exports/final.mp4', 'size': 2048},
              {'path': 'notes.txt', 'size': 10},
            ]
      };

  testWidgets('link page lists files and opens media', (t) async {
    var url = '';
    openExternalForTesting = (u) => url = u;
    installApi(extra: {
      'GET /api/link/tok': (_) => resolve(),
    });
    await t.pumpWidget(testApp(const LinkPage(token: 'tok')));
    await settle(t);
    expect(find.text('Grad Film'), findsOneWidget);
    expect(find.text('Exports/final.mp4'), findsOneWidget);
    await t.tap(find.text('Exports/final.mp4'));
    expect(url, contains('/api/link/tok/file?path='));
    await t.tap(find.text('notes.txt'));
    expect(url, contains('notes.txt'));
    openExternalForTesting = (_) => throw 'no browser';
    await t.tap(find.text('notes.txt'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('renders scope shows note and empty state', (t) async {
    installApi(extra: {
      'GET /api/link/tok': (_) => resolve(scope: 'renders', files: []),
    });
    await t.pumpWidget(testApp(const LinkPage(token: 'tok')));
    await settle(t);
    expect(find.text('Nothing to show'), findsOneWidget);
  });

  testWidgets('renders scope header with files', (t) async {
    installApi(extra: {
      'GET /api/link/tok': (_) => resolve(scope: 'renders'),
    });
    await t.pumpWidget(testApp(const LinkPage(token: 'tok')));
    await settle(t);
    expect(find.text('Renders only'), findsOneWidget);
  });

  testWidgets('gone link shows error and retries', (t) async {
    var fail = true;
    installApi(extra: {
      'GET /api/link/tok': (_) =>
          fail ? http.Response('{"error":"no such link"}', 404) : resolve(),
    });
    await t.pumpWidget(testApp(const LinkPage(token: 'tok')));
    await settle(t);
    expect(find.text('no such link'), findsWidgets);
    fail = false;
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('Grad Film'), findsOneWidget);
  });

  testWidgets('gate follows the link deep link', (t) async {
    installApi(extra: {
      'GET /api/link/tok': (_) => resolve(),
    });
    await t.pumpWidget(testApp(Gate(uri: Uri.parse('https://x/app/link/tok'))));
    await settle(t);
    expect(find.byType(LinkPage), findsOneWidget);
  });
}
