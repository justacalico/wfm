import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/main.dart';
import 'package:wfm/notifications.dart';
import 'package:wfm/projects.dart';
import 'package:wfm/shared.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w));
    await settle(t);
  }

  Future<void> pumpShell(WidgetTester t) async {
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t
        .tap(find.widgetWithText(ListTile, 'Notifications').first)
        .then((_) => settle(t));
  }

  Map<String, Object> notif(String id, String kind,
          {Map<String, Object> payload = const {},
          int readAt = 0,
          int createdAt = 1}) =>
      {
        'id': id,
        'kind': kind,
        'payload': payload,
        'readAt': readAt,
        'createdAt': createdAt
      };

  List<Map<String, Object>> allKinds() => [
        notif('n1', 'share_invite',
            payload: {'from': 'ada', 'projectName': 'Cut'}),
        notif('n2', 'share_auto',
            payload: {'from': 'ada', 'projectName': 'Cut'}),
        notif('n3', 'share_accepted',
            payload: {'from': 'bob', 'projectName': 'Cut'}),
        notif('n4', 'share_declined',
            payload: {'from': 'bob', 'projectName': 'Cut'}),
        notif('n5', 'render_done',
            payload: {'name': 'final.mp4', 'projectName': 'Cut'}),
        notif('n6', 'render_failed',
            payload: {'name': 'final.mp4', 'projectName': 'Cut'}),
        notif('n7', 'node_offline', payload: {'name': 'farm-1'}),
        notif('n8', 'comment', payload: {'from': 'ada', 'projectName': 'Cut'}),
        notif('n9', 'submit', payload: {'from': 'bob', 'projectName': 'Cut'}),
        notif('n10', 'review', payload: {'from': 'ada', 'projectName': 'Cut'}),
        notif('n11', 'review',
            payload: {'from': 'ada', 'projectName': 'Cut', 'status': 'draft'}),
        notif('n12', 'mystery', readAt: 5),
      ];

  testWidgets('list renders every kind', (t) async {
    installApi(extra: {
      'GET /api/notifications': (_) => {'list': allKinds(), 'unread': 7},
    });
    await t.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await pump(t, const NotificationsPage());
    for (final s in [
      'invited you to',
      'shared',
      'accepted your invite',
      'declined your invite',
      'Render finished',
      'Render failed',
      'went offline',
      'commented on',
      'submitted',
      'marked',
      'returned',
    ]) {
      expect(find.textContaining(s), findsWidgets);
    }
    await t.scrollUntilVisible(find.text('mystery'), 200);
    expect(find.text('mystery'), findsWidgets);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('tap marks read and navigates in shell', (t) async {
    var read = '';
    installApi(extra: {
      'GET /api/notifications': (_) => {
            'list': [
              notif('n1', 'share_invite',
                  payload: {'from': 'ada', 'projectName': 'Cut'}),
              notif('n5', 'render_done', payload: {
                'name': 'final.mp4',
                'project': 'p1',
                'projectName': 'Cut'
              }),
              notif('n6', 'render_failed',
                  payload: {'name': 'x', 'projectName': ''}),
              notif('n7', 'comment',
                  payload: {'project': 'p1', 'projectName': 'Cut'}),
              notif('n8', 'submit',
                  payload: {'project': 'p1', 'projectName': 'Cut'}),
              notif('n9', 'review',
                  payload: {'project': 'p1', 'projectName': 'Cut'}),
            ],
            'unread': 3
          },
      'POST /api/notifications/n1/read': (_) {
        read = 'n1';
        return {'ok': true};
      },
      'POST /api/notifications/n5/read': (_) => {'ok': true},
      'POST /api/notifications/n7/read': (_) => {'ok': true},
      'POST /api/notifications/n8/read': (_) => {'ok': true},
      'POST /api/notifications/n9/read': (_) => {'ok': true},
      'GET /api/shares': (_) => <dynamic>[],
    });
    await pumpShell(t);
    expect(find.text('3'), findsWidgets);
    await t.tap(find.textContaining('invited you to'));
    await settle(t);
    expect(read, 'n1');
    expect(find.byType(SharedPage), findsOneWidget);
    await t
        .tap(find.widgetWithText(ListTile, 'Notifications').first)
        .then((_) => settle(t));
    await t.tap(find.textContaining('Render finished'));
    await settle(t);
    expect(find.byType(ProjectPage), findsOneWidget);
    await t
        .tap(find.widgetWithText(ListTile, 'Notifications').first)
        .then((_) => settle(t));
    await t.tap(find.textContaining('Render failed'));
    await settle(t);
    expect(find.byType(SharedPage), findsNothing);
    for (final s in ['commented on', 'submitted', 'marked']) {
      await t
          .tap(find.widgetWithText(ListTile, 'Notifications').first)
          .then((_) => settle(t));
      await t.tap(find.textContaining(s).first);
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
    }
  });

  testWidgets('mark all read and read error snack', (t) async {
    var calls = 0;
    installApi(extra: {
      'GET /api/notifications': (_) {
        calls++;
        return {
          'list': [
            notif('n1', 'render_done',
                payload: {'name': 'f.mp4', 'projectName': 'p'})
          ],
          'unread': calls == 1 ? 1 : 0
        };
      },
      'POST /api/notifications/read-all': (_) => {'ok': true},
      'POST /api/notifications/n1/read': (_) =>
          http.Response('{"error":"nope"}', 500),
    });
    await pump(t, const NotificationsPage());
    await t.tap(find.textContaining('Render finished'));
    await settle(t);
    expect(find.textContaining('nope'), findsWidgets);
    await t.tap(find.text('Mark all read'));
    await settle(t);
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('non-shell taps push pages', (t) async {
    installApi(extra: {
      'GET /api/notifications': (_) => {
            'list': [
              notif('n1', 'share_invite',
                  payload: {'from': 'a', 'projectName': 'p'}),
              notif('n5', 'render_done',
                  payload: {'name': 'f', 'project': 'p1', 'projectName': 'p'}),
            ],
            'unread': 0
          },
      'POST /api/notifications/n1/read': (_) => {'ok': true},
      'POST /api/notifications/n5/read': (_) => {'ok': true},
      'GET /api/shares': (_) => <dynamic>[],
      'GET /api/projects/p1/renders': (_) => <dynamic>[],
    });
    await pump(t, const NotificationsPage());
    await t.tap(find.textContaining('invited you to'));
    await settle(t);
    expect(find.byType(SharedPage), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Render finished'));
    await settle(t);
    expect(find.byType(ProjectPage), findsOneWidget);
  });

  testWidgets('load more pages and error snack', (t) async {
    var calls = 0;
    installApi(extra: {
      'GET /api/notifications': (_) {
        calls++;
        if (calls == 1) {
          return {
            'list': [
              for (var i = 0; i < 50; i++)
                notif('n$i', 'node_offline',
                    payload: {'name': 'n$i'}, createdAt: 100 - i)
            ],
            'unread': 0
          };
        }
        if (calls == 2) {
          return {
            'list': [notif('tail', 'mystery', createdAt: 1)],
            'unread': 0
          };
        }
        return http.Response('{"error":"boom"}', 500);
      },
    });
    await pump(t, const NotificationsPage());
    await t.scrollUntilVisible(find.text('Load more'), 200);
    await t.tap(find.text('Load more'));
    await settle(t);
    expect(find.text('mystery'), findsOneWidget);
    expect(find.text('Load more'), findsNothing);
  });

  testWidgets('load more and read-all errors show snacks', (t) async {
    var calls = 0;
    installApi(extra: {
      'GET /api/notifications': (_) {
        calls++;
        if (calls > 1) return http.Response('{"error":"boom"}', 500);
        return {
          'list': [
            for (var i = 0; i < 50; i++)
              notif('n$i', 'node_offline',
                  payload: {'name': 'n$i'}, createdAt: 100 - i)
          ],
          'unread': 1
        };
      },
      'POST /api/notifications/read-all': (_) =>
          http.Response('{"error":"ra"}', 500),
    });
    await pump(t, const NotificationsPage());
    await t.tap(find.text('Mark all read'));
    await settle(t);
    expect(find.textContaining('ra'), findsWidgets);
    await t.scrollUntilVisible(find.text('Load more'), 200);
    await t.tap(find.text('Load more'));
    await settle(t);
    expect(find.textContaining('boom'), findsWidgets);
  });

  testWidgets('empty state and retry', (t) async {
    var fail = true;
    installApi(extra: {
      'GET /api/notifications': (_) => fail
          ? http.Response('{"error":"oops"}', 500)
          : {'list': <dynamic>[], 'unread': 0},
    });
    await pump(t, const NotificationsPage());
    expect(find.text('oops'), findsWidgets);
    fail = false;
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('No notifications yet'), findsOneWidget);
  });
}
