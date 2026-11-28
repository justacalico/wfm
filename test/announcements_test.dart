import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/announcements.dart';
import 'package:wfm/api.dart';
import 'helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'server': 'http://test'});
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w));
    await settle(t);
  }

  Map<String, Object> ann(String id,
          {String title = 'Term dates',
          bool comments = true,
          bool reactions = true,
          List reactionsList = const [],
          int count = 0,
          int editedAt = 0,
          String authorId = 'u9'}) =>
      {
        'id': id,
        'authorId': authorId,
        'authorUsername': 'staff',
        'authorName': 'Ms Staff',
        'title': title,
        'body': 'body **bold**',
        'commentsEnabled': comments,
        'reactionsEnabled': reactions,
        'reactions': reactionsList,
        'commentCount': count,
        'createdAt': 1,
        'editedAt': editedAt
      };

  Map<String, Object> annComment(String id,
          {String body = 'hi', String authorId = 'u9', int editedAt = 0}) =>
      {
        'id': id,
        'announcementId': 'a1',
        'authorId': authorId,
        'authorUsername': 'writer',
        'authorName': 'Writer Name',
        'body': body,
        'createdAt': 1,
        'editedAt': editedAt
      };

  testWidgets('list renders, reacts, opens detail and comments flow',
      (t) async {
    var posted = '';
    var deleted = '';
    installApi(extra: {
      'GET /api/announcements': (_) => [
            ann('a1',
                reactionsList: [
                  {'emoji': '👍', 'count': 2, 'mine': true}
                ],
                count: 1,
                editedAt: 5),
            ann('a2', title: 'Quiet', comments: false, reactions: false)
          ],
      'POST /api/announcements/a1/react': (_) => {'ok': true, 'added': true},
      'GET /api/announcements/a1/comments': (_) =>
          [annComment('c1', authorId: 'u1'), annComment('c2', editedAt: 3)],
      'POST /api/announcements/a1/comments': (_) {
        posted = 'add';
        return {'id': 'c9', 'body': 'x'};
      },
      'PATCH /api/announcements/a1/comments/c1': (_) {
        posted = 'edit';
        return {'ok': true};
      },
      'DELETE /api/announcements/a1/comments/c2': (_) {
        deleted = 'c2';
        return {'ok': true};
      },
    });
    await pump(t, const AnnouncementsPage());
    expect(find.text('Term dates'), findsOneWidget);
    expect(find.textContaining('Ms Staff'), findsWidgets);
    expect(find.textContaining('edited'), findsWidgets);
    expect(find.textContaining('👍 2'), findsOneWidget);
    expect(find.text('1 comments'), findsOneWidget);
    expect(find.text('Comments are off'), findsOneWidget);
    await t.tap(find.byIcon(Icons.add_reaction_outlined).first);
    await settle(t);
    await t.tap(find.text('🎉'));
    await settle(t);
    await t.tap(find.text('1 comments'));
    await settle(t);
    expect(find.byType(AnnouncementPage), findsOneWidget);
    expect(find.text('hi'), findsWidgets);
    await t.enterText(find.byType(TextField).last, 'new comment');
    await t.tap(find.byIcon(Icons.send));
    await settle(t);
    expect(posted, 'add');
    await t.tap(find.byIcon(Icons.more_vert).first);
    await settle(t);
    await t.tap(find.text('Edit').last);
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'changed');
    await t.tap(find.text('OK'));
    await settle(t);
    expect(posted, 'edit');
    await t.tap(find.byIcon(Icons.more_vert).last);
    await settle(t);
    await t.tap(find.text('Delete').last);
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(deleted, 'c2');
  });

  testWidgets('compose edit and delete announcement', (t) async {
    var created = false, updated = false, removed = false;
    installApi(extra: {
      'GET /api/announcements': (_) => [ann('a1', authorId: 'u1')],
      'POST /api/announcements': (_) {
        created = true;
        return {'ok': true};
      },
      'PATCH /api/announcements/a1': (_) {
        updated = true;
        return {'ok': true};
      },
      'DELETE /api/announcements/a1': (_) {
        removed = true;
        return {'ok': true};
      },
    });
    await pump(t, const AnnouncementsPage());
    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'Hi all');
    await t.enterText(find.byType(TextField).last, 'welcome **back**');
    await t.tap(find.byType(SwitchListTile).first);
    await settle(t);
    await t.tap(find.text('Post'));
    await settle(t);
    expect(created, isTrue);
    await t.tap(find.byIcon(Icons.more_vert));
    await settle(t);
    await t.tap(find.text('Edit'));
    await settle(t);
    await t.tap(find.text('Save'));
    await settle(t);
    expect(updated, isTrue);
    await t.tap(find.byIcon(Icons.more_vert));
    await settle(t);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(removed, isFalse);
    await t.tap(find.byIcon(Icons.more_vert));
    await settle(t);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(removed, isTrue);
  });

  testWidgets('empty state, error retry and pagination', (t) async {
    var fail = true;
    var before = '';
    installApi(extra: {
      'GET /api/announcements': (req) {
        if (fail) return http.Response('{"error":"oops"}', 500);
        before = '${req.url.queryParameters['before'] ?? ''}';
        if (before.isEmpty || before == '0') {
          return [for (var i = 0; i < 50; i++) ann('a$i', title: 'T$i')];
        }
        return [ann('old', title: 'Old one')];
      },
    });
    await pump(t, const AnnouncementsPage());
    expect(find.text('oops'), findsWidgets);
    fail = false;
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('T0'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Load more'), 400);
    await t.tap(find.text('Load more'));
    await settle(t);
    expect(before, '1');
    expect(find.text('Old one'), findsOneWidget);
    fail = true;
    await t.pumpWidget(const SizedBox());
    installApi(extra: {'GET /api/announcements': (_) => <dynamic>[]});
    await t.pumpWidget(testApp(const AnnouncementsPage()));
    await settle(t);
    expect(find.text('No announcements yet.'), findsWidgets);
  });

  testWidgets('comments disabled on detail hides composer', (t) async {
    installApi(extra: {
      'GET /api/announcements': (_) =>
          [ann('a1', comments: false, reactions: false)],
      'GET /api/announcements/a1/comments': (_) => [annComment('c1')],
    });
    await pump(t, const AnnouncementPage(announcementId: 'a1'));
    expect(find.text('Comments are off'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('list action failures snackbar', (t) async {
    var moreCalls = 0;
    installApi(extra: {
      'GET /api/announcements': (req) {
        final b = req.url.queryParameters['before'] ?? '';
        if (b.isNotEmpty && b != '0') {
          moreCalls++;
          return http.Response('{"error":"more"}', 500);
        }
        return [
          for (var i = 0; i < 50; i++) ann('a$i', title: 'T$i', editedAt: 5)
        ];
      },
      'POST /api/announcements/a0/react': (_) =>
          http.Response('{"error":"r"}', 500),
      'POST /api/announcements': (_) => http.Response('{"error":"c"}', 500),
      'DELETE /api/announcements/a0': (_) => http.Response('{"error":"d"}', 500),
    });
    await pump(t, const AnnouncementsPage());
    await t.tap(find.byIcon(Icons.add_reaction_outlined).first);
    await settle(t);
    await t.tap(find.text('🎉'));
    await settle(t);
    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    await t.tap(find.byType(SwitchListTile).last);
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'T');
    await t.enterText(find.byType(TextField).last, 'body');
    await t.tap(find.text('Post'));
    await settle(t);
    await t.tap(find.byType(FloatingActionButton));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    await t.tap(find.byIcon(Icons.more_vert).first);
    await settle(t);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    await t.scrollUntilVisible(find.text('Load more'), 400);
    await t.tap(find.text('Load more'));
    await settle(t);
    expect(moreCalls, 1);
  });

  testWidgets('detail failures, keyboard submit and markdown link',
      (t) async {
    var fail = true;
    installApi(extra: {
      'GET /api/announcements': (_) => fail
          ? http.Response('{"error":"x"}', 500)
          : [
              {
                ...ann('a1', title: 'Linked'),
                'body': 'go [there](https://example.test/y)'
              }
            ],
      'GET /api/announcements/a1/comments': (_) =>
          fail ? http.Response('{"error":"y"}', 500) : [annComment('c1', authorId: 'u1')],
      'POST /api/announcements/a1/comments': (_) =>
          http.Response('{"error":"p"}', 500),
      'PATCH /api/announcements/a1/comments/c1': (_) =>
          http.Response('{"error":"e"}', 500),
      'DELETE /api/announcements/a1/comments/c1': (_) =>
          http.Response('{"error":"d"}', 500),
    });
    await pump(t, const AnnouncementPage(announcementId: 'a1'));
    expect(find.text('Retry'), findsOneWidget);
    fail = false;
    await t.tap(find.text('Retry'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'typed');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    await t.tap(find.byIcon(Icons.more_vert).first);
    await settle(t);
    await t.tap(find.text('Edit').last);
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'changed');
    await t.tap(find.text('OK'));
    await settle(t);
    await t.tap(find.byIcon(Icons.more_vert).first);
    await settle(t);
    await t.tap(find.text('Delete').last);
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async => true);
    await t.tapOnText(find.textRange.ofSubstring('there'));
    await settle(t);
  });

  testWidgets('own announcement menu for a teacher', (t) async {
    final api = installApi(extra: {
      'GET /api/announcements': (_) => [ann('a1', authorId: 'u1')],
    });
    api.user = User.fromJson({...userJson, 'role': 'teacher'});
    await pump(t, const AnnouncementsPage());
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('list markdown body link tap', (t) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async => true);
    installApi(extra: {
      'GET /api/announcements': (_) => [
            {
              ...ann('a1'),
              'body': 'see [here](https://example.test/x) now'
            }
          ],
    });
    await pump(t, const AnnouncementsPage());
    await t.tapOnText(find.textRange.ofSubstring('here'));
    await settle(t);
  });
}
