import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wfm/api.dart';
import 'package:wfm/comments.dart';
import 'package:wfm/main.dart';
import 'helpers.dart';

Map<String, Object> comment(String id,
        {String userId = 'u1',
        String body = 'hi',
        int createdAt = 1,
        int editedAt = 0,
        String avatar = ''}) =>
    {
      'id': id,
      'projectId': 'p1',
      'userId': userId,
      'username': 'u$userId',
      'displayName': '',
      'avatar': avatar,
      'body': body,
      'createdAt': createdAt,
      'editedAt': editedAt,
    };

void main() {
  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w));
    await settle(t);
  }

  final p1 = Project.fromJson({'id': 'p1', 'name': 'cut'});

  testWidgets('lists comments and posts one', (t) async {
    var posted = '';
    installApi(extra: {
      'GET /api/projects/p1/comments': (_) => [
            comment('c1', body: 'first'),
            comment('c2',
                userId: 'u2',
                body: 'teacher note',
                editedAt: 9,
                avatar: 'avatars/u2/x.png'),
          ],
      'POST /api/projects/p1/comments': (req) {
        posted = req.body;
        return {'ok': true};
      },
    });
    await pump(t, Scaffold(body: CommentsTab(project: p1)));
    expect(find.text('first'), findsOneWidget);
    expect(find.text('teacher note'), findsOneWidget);
    expect(find.textContaining('edited'), findsOneWidget);
    expect(find.text('first'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'looks good');
    await t.tap(find.byIcon(Icons.send));
    await settle(t);
    expect(posted, contains('looks good'));
    await t.enterText(find.byType(TextField), 'via key');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(posted, contains('via key'));
  });

  testWidgets('edit and delete own comment', (t) async {
    var edited = '', deleted = false;
    installApi(extra: {
      'GET /api/projects/p1/comments': (_) => [
            comment('c1', body: 'mine'),
            comment('c2', userId: 'u2', body: 'theirs'),
          ],
      'PATCH /api/projects/p1/comments/c1': (req) {
        edited = req.body;
        return {'ok': true};
      },
      'DELETE /api/projects/p1/comments/c2': (_) {
        deleted = true;
        return {'ok': true};
      },
    });
    await pump(t, Scaffold(body: CommentsTab(project: p1)));
    await t.tap(find.byType(PopupMenuButton<String>).first);
    await settle(t);
    expect(find.text('Edit comment'), findsOneWidget);
    await t.tap(find.text('Edit comment'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'changed');
    await t.tap(find.text('OK'));
    await settle(t);
    expect(edited, contains('changed'));
    await t.tap(find.byType(PopupMenuButton<String>).last);
    await settle(t);
    expect(find.text('Edit comment'), findsNothing);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(deleted, isTrue);
  });

  testWidgets('errors: load, post, edit, delete', (t) async {
    var failLoad = true;
    installApi(extra: {
      'GET /api/projects/p1/comments': (_) =>
          failLoad ? http.Response('{"error":"down"}', 500) : [comment('c1')],
      'POST /api/projects/p1/comments': (_) =>
          http.Response('{"error":"nope"}', 500),
      'PATCH /api/projects/p1/comments/c1': (_) =>
          http.Response('{"error":"nope"}', 500),
      'DELETE /api/projects/p1/comments/c1': (_) =>
          http.Response('{"error":"nope"}', 500),
    });
    await pump(t, Scaffold(body: CommentsTab(project: p1)));
    expect(find.text('down'), findsOneWidget);
    failLoad = false;
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('hi'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'x');
    await t.tap(find.byIcon(Icons.send));
    await settle(t);
    expect(find.text('nope'), findsWidgets);
    await t.tap(find.byType(PopupMenuButton<String>));
    await settle(t);
    await t.tap(find.text('Edit comment'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'y');
    await t.tap(find.text('OK'));
    await settle(t);
    await t.tap(find.byType(PopupMenuButton<String>));
    await settle(t);
    await t.tap(find.text('Delete'));
    await settle(t);
    await t.tap(find.text('Confirm'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
  });

  testWidgets('empty state and empty submit does nothing', (t) async {
    var posts = 0;
    installApi(extra: {
      'GET /api/projects/p1/comments': (_) => [],
      'POST /api/projects/p1/comments': (_) {
        posts++;
        return {'ok': true};
      },
    });
    await pump(t, Scaffold(body: CommentsTab(project: p1)));
    expect(find.text('No comments yet'), findsOneWidget);
    await t.tap(find.byIcon(Icons.send));
    await settle(t);
    expect(posts, 0);
  });
}
