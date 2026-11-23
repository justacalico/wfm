import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart';
import 'package:wfm/mcp.dart';
import 'package:wfm/settings.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final tokenJson = {
    'id': 't1',
    'name': 'claude',
    'createdAt': 1700000000,
    'expiresAt': 1730000000,
    'lastSeen': 1700000100,
  };

  Map<String, dynamic Function(http.Request)> routes(
      {List<dynamic>? tokens, dynamic post, dynamic del}) {
    return {
      'GET /api/mcp/tokens': (_) => tokens ?? [tokenJson],
      'POST /api/mcp/tokens': post ??
          (_) => {
                ...tokenJson,
                'token': 'sekrit',
                'url': '/api/mcp',
              },
      'DELETE /api/mcp/tokens/t1': del ?? (_) => {'ok': true},
    };
  }

  Future<void> pumpPage(WidgetTester t,
      {Map<String, dynamic Function(http.Request)>? extra}) async {
    installApi(extra: extra ?? const {});
    await t.pumpWidget(testApp(const McpPage()));
    await settle(t);
  }

  testWidgets('lists tokens, shows server url and copies it', (t) async {
    await pumpPage(t, extra: routes());
    expect(find.text('AI assistant'), findsWidgets);
    expect(find.text('claude'), findsOneWidget);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text(Api.i.mcpUrl), findsOneWidget);
    await t.tap(find.byTooltip('Copy'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
  });

  testWidgets('empty list explains how to start', (t) async {
    await pumpPage(t, extra: routes(tokens: []));
    expect(find.textContaining('No tokens yet'), findsOneWidget);
  });

  testWidgets('load failure shows error view', (t) async {
    await pumpPage(t, extra: {
      'GET /api/mcp/tokens': (_) => http.Response('{"error":"down"}', 500),
    });
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('create flow names the token and reveals it once', (t) async {
    var created = '';
    await pumpPage(t, extra: {
      'GET /api/mcp/tokens': (_) =>
          created.isEmpty ? [] : [{...tokenJson, 'name': created}],
      'POST /api/mcp/tokens': (req) {
        created = 'my agent';
        return {...tokenJson, 'name': created, 'token': 'sekrit'};
      },
    });
    await t.tap(find.text('New token'));
    await settle(t);
    expect(find.byType(AlertDialog), findsOneWidget);
    await t.enterText(find.byType(TextField), 'my agent');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(find.text('Token ready'), findsOneWidget);
    expect(find.textContaining('sekrit'), findsWidgets);
    expect(find.textContaining(Api.i.mcpUrl), findsWidgets);
    for (final copy in find
        .descendant(
            of: find.byType(AlertDialog), matching: find.byTooltip('Copy'))
        .evaluate()
        .toList()) {
      await t.tap(find.byWidget(copy.widget));
      await settle(t, 2);
    }
    await t.tap(find.text('Done'));
    await settle(t);
    expect(find.text('my agent'), findsOneWidget);
  });

  testWidgets('create cancelled leaves the list alone', (t) async {
    await pumpPage(t, extra: routes());
    await t.tap(find.text('New token'));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('claude'), findsOneWidget);
  });

  testWidgets('create failure snacks', (t) async {
    await pumpPage(t,
        extra: routes(
            post: (_) => http.Response('{"error":"no room"}', 500)));
    await t.tap(find.text('New token'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.text('Save'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
  });

  testWidgets('revoke confirms then removes the row', (t) async {
    await pumpPage(t, extra: routes());
    await t.tap(find.text('Revoke'));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(find.text('claude'), findsOneWidget);
    await t.tap(find.text('Revoke'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(find.text('claude'), findsNothing);
  });

  testWidgets('revoke failure snacks', (t) async {
    await pumpPage(t,
        extra: routes(
            del: (_) => http.Response('{"error":"stuck"}', 500)));
    await t.tap(find.text('Revoke'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
    expect(find.text('claude'), findsOneWidget);
  });

  testWidgets('settings tile opens the page', (t) async {
    installApi(extra: routes());
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
    await t.scrollUntilVisible(
        find.widgetWithText(ListTile, 'AI assistant'), 300,
        scrollable: find.descendant(
            of: find.byType(SettingsPage),
            matching: find.byType(Scrollable)));
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'AI assistant'));
    await settle(t);
    expect(find.byType(McpPage), findsOneWidget);
  });

  test('api exposes the mcp endpoints', () async {
    installApi(extra: routes());
    final toks = await Api.i.mcpTokens();
    expect(toks.single.name, 'claude');
    expect(toks.single.lastSeen, 1700000100);
    final t = await Api.i.mcpTokenCreate('a');
    expect(t.token, 'sekrit');
    await Api.i.mcpTokenDelete('t1');
    expect(lastRequest!.url.path, '/api/mcp/tokens/t1');
    Api.i.baseUrl = 'https://wfm.example';
    expect(Api.i.mcpUrl, 'https://wfm.example/api/mcp');
    Api.i.baseUrl = '';
    expect(Api.i.mcpUrl.endsWith('/api/mcp'), isTrue);
  });
}
