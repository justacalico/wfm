import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wfm/invite.dart';
import 'package:wfm/main.dart';
import 'helpers.dart';

void main() {
  setUpAll(loadTestFonts);

  testWidgets('invite page loads preview and redeems', (t) async {
    installApi(extra: {
      'GET /api/invites/c9': (_) => {'username': 'ann', 'name': ''},
      'POST /api/invites/c9/redeem': (_) =>
          {'user': userJson, 'csrf': 'x', 'token': 't'},
    });
    await t.pumpWidget(
        WfmApp(uri: Uri.parse('https://x/app/invite/c9')));
    await settle(t);
    expect(find.byType(InvitePage), findsOneWidget);
    expect(find.text('ann'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Display name'), findsOneWidget);
    await t.enterText(
        find.widgetWithText(TextField, 'Display name'), 'Ann A');
    await t.enterText(find.widgetWithText(TextField, 'Password'), 'hunter22');
    await t.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'hunter22');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(find.byType(Shell), findsOneWidget);
  });

  testWidgets('invite page validates and surfaces errors', (t) async {
    installApi(extra: {
      'GET /api/invites/c8': (_) => {'username': '', 'name': 'Named'},
      'POST /api/invites/c8/redeem': (_) =>
          http.Response('{"error":"gone"}', 410),
    });
    await t.pumpWidget(testApp(const InvitePage(code: 'c8')));
    await settle(t);
    expect(find.text('Named'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Username'), 'newkid');
    await t.enterText(find.widgetWithText(TextField, 'Password'), 'a');
    await t.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'b');
    await t.tap(find.text('Sign up'));
    await settle(t);
    expect(find.text('Passwords do not match'), findsOneWidget);
    await t.enterText(
        find.widgetWithText(TextField, 'Confirm password'), 'a');
    await t.tap(find.text('Sign up'));
    await settle(t);
    expect(find.text('gone'), findsOneWidget);
  });

  testWidgets('invite page shows load failure', (t) async {
    installApi(extra: {
      'GET /api/invites/dead': (_) =>
          http.Response('{"error":"no"}', 404),
    });
    await t.pumpWidget(testApp(const InvitePage(code: 'dead')));
    await settle(t);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('gate follows the invite deep link', (t) async {
    installApi(extra: {
      'GET /api/invites/zz': (_) => {'username': '', 'name': ''},
    });
    await t.pumpWidget(
        testApp(Gate(uri: Uri.parse('https://x/app/invite/zz'))));
    await settle(t);
    expect(find.byType(InvitePage), findsOneWidget);
  });
}
