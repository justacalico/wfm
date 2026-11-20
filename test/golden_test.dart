import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart';
import 'package:wfm/platform.dart';
import 'helpers.dart';

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(Uri basedir) : super(basedir.resolve('t.dart'));

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
        imageBytes, await getGoldenBytes(golden));
    if (!result.passed && result.diffPercent < 0.005) {
      debugPrint('golden $golden diff ${result.diffPercent} tolerated');
      return true;
    }
    return result.passed;
  }
}

void main() {
  setUpAll(loadTestFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    openEditorForTesting = null;
    isDesktopApp = false;
    pickFilesForTesting = null;
    final prev = goldenFileComparator;
    if (prev is LocalFileComparator) {
      goldenFileComparator = _TolerantComparator(prev.basedir);
      addTearDown(() => goldenFileComparator = prev);
    }
  });

  Future<void> snap(WidgetTester t, String name) async {
    await expectLater(
        find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  Future<void> tapNav(WidgetTester t, String label) =>
      t.tap(find.widgetWithText(ListTile, label).first).then((_) => settle(t));

  Future<void> pumpWfm(WidgetTester t, {Uri? uri}) async {
    await t.binding.setSurfaceSize(const Size(1280, 800));
    await t.pumpWidget(WfmApp(uri: uri));
    await settle(t);
  }

  final shellData = <String, dynamic>{
    'GET /api/assignments': (_) => [
          {
            'id': 'a1',
            'projectId': 'p1',
            'projectName': 'Short Film',
            'teacherName': 'Mr. Doe',
            'dueAt': 1700000000,
            'createdAt': 1699990000,
            'status': 'draft',
            'copy': {
              'projectId': 'p1',
              'assignmentId': 'a1',
              'studentId': 'u1',
              'submissions': 1
            },
          },
        ],
    'GET /api/shares': (_) => [
          {
            'id': 'sh1',
            'projectId': 'p9',
            'projectName': 'Group doc',
            'inviterUsername': 'bob',
            'level': 'view',
            'status': 'pending',
            'createdAt': 1700000000,
          },
          {
            'id': 'sh2',
            'projectId': 'p8',
            'projectName': 'Shared film',
            'inviterUsername': 'carol',
            'level': 'edit',
            'status': 'accepted',
            'createdAt': 1700000000,
          },
        ],
    'GET /api/notifications': (_) => {
          'unread': 1,
          'list': [
            {
              'id': 'n1',
              'kind': 'share_invite',
              'payload': {'from': 'bob', 'projectName': 'Group doc'},
              'createdAt': 1700000000,
              'readAt': 0,
            },
            {
              'id': 'n2',
              'kind': 'render_done',
              'payload': {'name': 'final.mp4', 'projectName': 'Short Film'},
              'createdAt': 1699999000,
              'readAt': 1,
            },
            {
              'id': 'n3',
              'kind': 'comment',
              'payload': {'from': 'carol', 'projectName': 'Short Film'},
              'createdAt': 1699998000,
              'readAt': 1,
            },
          ],
        },
    'GET /api/projects/p1/comments': (_) => [
          {
            'id': 'c1',
            'userId': 'u2',
            'username': 'bob',
            'displayName': 'Bob',
            'body': 'Establishing shot runs long',
            'createdAt': 1700000000,
          },
          {
            'id': 'c2',
            'userId': 'u1',
            'username': 'ada',
            'displayName': 'Ada Lovelace',
            'body': 'Will trim it today',
            'createdAt': 1700000100,
            'editedAt': 1700000200,
          },
        ],
    'GET /api/sessions': (_) => [
          {
            'id': 's1',
            'ua': 'Firefox on Linux',
            'ip': '10.0.0.5',
            'current': true,
            'lastSeen': 1700000000,
          },
          {
            'id': 's2',
            'ua': 'Chrome on Windows',
            'ip': '10.0.0.9',
            'current': false,
            'lastSeen': 1699990000,
          },
        ],
    'GET /api/shortcuts/catalog': (_) => [
          {
            'id': 'play',
            'label': 'Play / pause',
            'category': 'Playback',
            'menu': ['Playback'],
            'shortcuts': [
              {'keys': 'Space'}
            ],
          },
          {
            'id': 'split',
            'label': 'Split clip',
            'category': 'Edit',
            'menu': ['Edit', 'Clip'],
            'shortcuts': [
              {'keys': 'S'},
              {'keys': 'B', 'panel': 'Timeline'}
            ],
          },
          {
            'id': 'save',
            'label': 'Save project',
            'category': 'File',
            'menu': ['File'],
            'shortcuts': [
              {'keys': 'Cmd+S'}
            ],
          },
        ],
    'GET /api/shortcuts': (_) => {
          'bindings': {'play': 'P'}
        },
    'GET /api/auto-shares': (_) => [
          {
            'id': 'as1',
            'inviteeId': 'u9',
            'inviteeUsername': 'sam',
            'inviteeName': '',
            'level': 'view',
            'createdAt': 1700000000,
          },
        ],
  };

  Future<void> tour(WidgetTester t, String dir) async {
    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': true},
    }));
    await pumpWfm(t);
    await snap(t, '$dir/setup');
    await t.pumpWidget(const SizedBox());

    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => http.Response('{"error":"x"}', 401),
    }));
    await pumpWfm(t);
    await snap(t, '$dir/login');
    await t.pumpWidget(const SizedBox());

    Api.i = Api(FakeClient({
      'GET /api/setup': (_) => http.Response('{"error":"down"}', 500),
    }));
    await pumpWfm(t);
    await snap(t, '$dir/gate_error');
    await t.pumpWidget(const SizedBox());

    isDesktopApp = true;
    Api.i = Api(FakeClient({}));
    await pumpWfm(t);
    await snap(t, '$dir/connect');
    await t.pumpWidget(const SizedBox());
    isDesktopApp = false;

    Api.i = Api(FakeClient({
      'GET /api/invites/abc': (_) =>
          {'role': 'student', 'username': '', 'name': ''},
    }));
    await pumpWfm(t, uri: Uri.parse('/invite/abc'));
    await snap(t, '$dir/invite');
    await t.pumpWidget(const SizedBox());

    Api.i = Api(FakeClient({
      'GET /api/link/tok': (_) => {
            'name': 'Short Film exports',
            'scope': 'renders',
            'files': [
              {'path': 'final.mp4', 'size': 2048},
              {'path': 'scene2.mp4', 'size': 4096},
            ],
          },
    }));
    await pumpWfm(t, uri: Uri.parse('/link/tok'));
    await snap(t, '$dir/link');
    await t.pumpWidget(const SizedBox());

    installApi(extra: shellData);
    await pumpWfm(t);
    await snap(t, '$dir/home');

    await tapNav(t, 'Projects');
    await snap(t, '$dir/projects');

    await t.tap(find.text('Short Film'));
    await settle(t);
    await snap(t, '$dir/project_files');
    await t.tap(find.text('Renders'));
    await settle(t);
    await snap(t, '$dir/project_renders');
    await t.tap(find.text('Comments'));
    await settle(t);
    await snap(t, '$dir/project_comments');

    await tapNav(t, 'Shared with me');
    await snap(t, '$dir/shared');
    await tapNav(t, 'Notifications');
    await snap(t, '$dir/notifications');
    await tapNav(t, 'Manage');
    await snap(t, '$dir/manage_accounts');
    await t.tap(find.text('Activity'));
    await settle(t);
    await snap(t, '$dir/manage_audit');
    await t.tap(find.text('Render nodes'));
    await settle(t);
    await snap(t, '$dir/manage_nodes');

    await tapNav(t, 'Settings');
    await snap(t, '$dir/settings');
    await t.tap(find.text('Sessions'));
    await settle(t);
    await snap(t, '$dir/sessions');

    await t.pumpWidget(const SizedBox());
    await pumpWfm(t);
    await tapNav(t, 'Settings');
    await t.tap(find.text('FilmCraft shortcuts'));
    await settle(t);
    await snap(t, '$dir/shortcuts');

    await t.pumpWidget(const SizedBox());
    await pumpWfm(t);
    await tapNav(t, 'Settings');
    await t.tap(find.text('ScriptCraft shortcuts'));
    await settle(t);
    await snap(t, '$dir/shortcuts_scriptcraft');
    await t.pumpWidget(const SizedBox());
  }

  for (final (dir, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
    ('oled', AppTheme.oled),
  ]) {
    testWidgets('$dir pages', (t) async {
      SharedPreferences.setMockInitialValues({'theme': theme.index});
      await tour(t, dir);
    });
  }

  testWidgets('locale and narrow variants', (t) async {
    installApi(extra: shellData);
    SharedPreferences.setMockInitialValues({'locale': 'zh'});
    await pumpWfm(t);
    await snap(t, 'light/home_zh');
    await t.pumpWidget(const SizedBox());

    SharedPreferences.setMockInitialValues({});
    installApi(extra: shellData);
    await t.binding.setSurfaceSize(const Size(420, 800));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await snap(t, 'light/home_narrow');
    await t.pumpWidget(const SizedBox());
  });
}
