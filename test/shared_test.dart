import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/main.dart';
import 'package:wfm/projects.dart';
import 'package:wfm/shared.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'server': 'http://test'});
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w));
    await settle(t);
  }

  Map<String, Object> share(String id,
          {String status = 'pending',
          String name = 'Other Cut',
          String level = 'view'}) =>
      {
        'id': id,
        'projectId': 'p-$id',
        'projectName': name,
        'inviterUsername': 'teacher',
        'level': level,
        'status': status,
        'createdAt': 1
      };

  testWidgets('shared invites accept decline and open', (t) async {
    var accepted = false, declined = false;
    installApi(extra: {
      'GET /api/shares': (_) => [
            share('s1', level: 'edit'),
            share('s4', name: ''),
            share('s3', status: 'accepted', name: '')
          ],
      'GET /api/projects/p-s3/files': (_) => [],
      'POST /api/shares/s1/accept': (_) {
        accepted = true;
        return {'ok': true};
      },
      'POST /api/shares/s1/decline': (_) {
        declined = true;
        return {'ok': true};
      },
    });
    await pump(t, const SharedPage());
    expect(find.textContaining('Invited by teacher'), findsWidgets);
    expect(find.text('p-s4'), findsOneWidget);
    await t.tap(find.text('Accept').first);
    await settle(t);
    expect(accepted, isTrue);
    await t.tap(find.text('Decline').first);
    await settle(t);
    expect(declined, isTrue);
    await t.tap(find.text('p-s3'));
    await settle(t);
    expect(find.byType(ProjectPage), findsOneWidget);
    expect(find.text('Read only'), findsWidgets);
  });

  testWidgets('template and plain shares offer copy actions', (t) async {
    var dup = 0;
    installApi(extra: {
      'GET /api/shares': (_) => [
            share('s1', status: 'accepted')..['template'] = true,
            share('s2', status: 'accepted', level: 'edit'),
          ],
      'POST /api/projects/p-s1/duplicate': (_) {
        dup++;
        return {'id': 'p9', 'name': 'c', 'displayName': 'C'};
      },
      'POST /api/projects/p-s2/duplicate': (_) =>
          http.Response('{"error":"nope"}', 500),
    });
    await pump(t, const SharedPage());
    expect(find.text('Use template'), findsOneWidget);
    expect(find.textContaining('Can edit'), findsOneWidget);
    await t.tap(find.text('Use template'));
    await settle(t);
    expect(dup, 1);
    expect(find.text('Copy created'), findsWidgets);
    await t.tap(find.byIcon(Icons.copy_outlined));
    await settle(t);
    expect(find.text('nope'), findsWidgets);
  });

  testWidgets('empty state and error retry', (t) async {
    var fail = true;
    installApi(extra: {
      'GET /api/shares': (_) =>
          fail ? http.Response('{"error":"oops"}', 500) : <dynamic>[],
    });
    await pump(t, const SharedPage());
    expect(find.text('oops'), findsWidgets);
    fail = false;
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(
        find.text(
            'Nothing shared with you yet. Projects others share with you appear here.'),
        findsOneWidget);
  });

  testWidgets('respond error shows snack', (t) async {
    installApi(extra: {
      'GET /api/shares': (_) => [share('s1')],
      'POST /api/shares/s1/accept': (_) =>
          http.Response('{"error":"nope"}', 409),
    });
    await pump(t, const SharedPage());
    await t.tap(find.text('Accept'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  Map<String, Object> autoShare(String id,
          {String status = 'pending',
          String level = 'view',
          String ownerName = 'Ms Teacher'}) =>
      {
        'id': id,
        'inviteeId': 'me',
        'inviteeUsername': 'me',
        'ownerUsername': 'teacher',
        'ownerName': ownerName,
        'level': level,
        'status': status,
        'createdAt': 1
      };

  testWidgets('auto-share invites accept and decline', (t) async {
    var hit = '';
    installApi(extra: {
      'GET /api/shares': (_) => <dynamic>[],
      'GET /api/auto-shares/incoming': (_) =>
          [autoShare('a1', level: 'edit'), autoShare('a2', status: 'declined')],
      'POST /api/auto-shares/a1/accept': (_) {
        hit = 'accept';
        return {'ok': true};
      },
      'POST /api/auto-shares/a1/decline': (_) {
        hit = 'decline';
        return {'ok': true};
      },
    });
    await pump(t, const SharedPage());
    expect(find.text('Ms Teacher'), findsWidgets);
    expect(find.textContaining('wants to automatically share'), findsWidgets);
    await t.tap(find.text('Accept').first);
    await settle(t);
    expect(hit, 'accept');
    await t.tap(find.text('Decline').first);
    await settle(t);
    expect(hit, 'decline');
  });

  testWidgets('active auto-share can be left and share left', (t) async {
    var leftAuto = false, leftShare = false;
    installApi(extra: {
      'GET /api/shares': (_) => [share('s1', status: 'accepted')],
      'GET /api/auto-shares/incoming': (_) =>
          [autoShare('a1', status: 'accepted')],
      'DELETE /api/auto-shares/a1': (_) {
        leftAuto = true;
        return {'ok': true};
      },
      'DELETE /api/shares/s1': (_) {
        leftShare = true;
        return {'ok': true};
      },
    });
    await pump(t, const SharedPage());
    await t.tap(find.text('Leave').first);
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(leftAuto, isTrue);
    await t.tap(find.byIcon(Icons.logout).first);
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(leftShare, isTrue);
  });

  testWidgets('auto-share respond error and cancel leave', (t) async {
    var deleted = false;
    installApi(extra: {
      'GET /api/shares': (_) => <dynamic>[],
      'GET /api/auto-shares/incoming': (_) =>
          [autoShare('a1'), autoShare('a2', status: 'accepted')],
      'POST /api/auto-shares/a1/accept': (_) =>
          http.Response('{"error":"nope"}', 409),
      'DELETE /api/auto-shares/a2': (_) {
        deleted = true;
        return {'ok': true};
      },
    });
    await pump(t, const SharedPage());
    await t.tap(find.text('Accept').first);
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
    await t.tap(find.text('Leave'));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(deleted, isFalse);
  });

  testWidgets('auto-share empty owner name and leave failure', (t) async {
    installApi(extra: {
      'GET /api/shares': (_) => <dynamic>[],
      'GET /api/auto-shares/incoming': (_) => [
            autoShare('a1', ownerName: ''),
            autoShare('a2', status: 'accepted', ownerName: '')
          ],
      'DELETE /api/auto-shares/a2': (_) =>
          http.Response('{"error":"nope"}', 500),
    });
    await pump(t, const SharedPage());
    expect(find.text('teacher'), findsWidgets);
    await t.tap(find.text('Leave'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('share leave failure shows snack', (t) async {
    installApi(extra: {
      'GET /api/shares': (_) => [share('s1', status: 'accepted')],
      'DELETE /api/shares/s1': (_) => http.Response('{"error":"nope"}', 404),
    });
    await pump(t, const SharedPage());
    await t.tap(find.byIcon(Icons.logout));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
  });

  testWidgets('shell nav shows shared page and badge', (t) async {
    installApi(extra: {
      'GET /api/shares': (_) => [
            share('s1'),
            share('s2', status: 'accepted', level: 'edit'),
          ],
      'GET /api/projects/p-s2/files': (_) => [],
    });
    await t.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    expect(find.text('1'), findsOneWidget);
    await t
        .tap(find.widgetWithText(ListTile, 'Shared with me').first)
        .then((_) => settle(t));
    expect(find.text('Pending invites'), findsOneWidget);
    expect(find.text('Shared projects'), findsOneWidget);
    await t.tap(find.text('Accept'));
    await settle(t);
    await t.tap(find.text('Other Cut').last);
    await settle(t);
    expect(find.byType(ProjectPage), findsOneWidget);
  });
}
