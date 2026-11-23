import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/main.dart';
import 'package:wfm/projects.dart';
import 'helpers.dart';

final p1 = Project.fromJson({
  'id': 'p1',
  'name': 'short-film',
  'displayName': 'Short Film',
  'createdAt': 1700000000
});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    openEditorForTesting = null;
    pickFilesForTesting = null;
    mediaPlayerForTesting = null;
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w));
    await settle(t);
  }

  group('ProjectsPage', () {
    testWidgets('lists projects and opens one', (t) async {
      installApi();
      await pump(t, const ProjectsPage());
      expect(find.text('Short Film'), findsOneWidget);
      var opened = '';
      openEditorForTesting = (u) => opened = u;
      await t.tap(find.text('Edit'));
      await settle(t);
      expect(opened, contains('/filmcraft/wfm.html?project=p1'));
      await t.tap(find.text('Write script'));
      await settle(t);
      expect(opened, contains('/scriptcraft/wfm.html?project=p1'));
      await t.tap(find.text('Plan storyboard'));
      await settle(t);
      expect(opened, contains('/deckcraft/wfm.html?project=p1'));
      await t.tap(find.text('Short Film'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      await t.tap(find.descendant(
          of: find.byType(AppBar), matching: find.byIcon(Icons.arrow_back)));
      await t.pumpAndSettle();
      expect(find.byType(ProjectPage), findsNothing);
    });

    testWidgets('system theme resolves to platform brightness for crafts',
        (t) async {
      installApi();
      await t.binding.setSurfaceSize(const Size(1280, 800));
      var opened = '';
      openEditorForTesting = (u) => opened = u;
      await t.pumpWidget(const WfmApp());
      await settle(t);
      await t
          .tap(find.widgetWithText(ListTile, 'Projects').first)
          .then((_) => settle(t));
      await t.tap(find.text('Write script'));
      await settle(t);
      expect(opened, contains('/scriptcraft/wfm.html?project=p1&theme=light'));
      t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
      await settle(t);
      await t.tap(find.text('Plan storyboard'));
      await settle(t);
      expect(opened, contains('/deckcraft/wfm.html?project=p1&theme=dark'));
      await t.binding.setSurfaceSize(const Size(800, 600));
    });

    testWidgets('project opens inside the shell and back returns', (t) async {
      installApi();
      await t.binding.setSurfaceSize(const Size(1280, 800));
      await t.pumpWidget(const WfmApp());
      await settle(t);
      await t
          .tap(find.widgetWithText(ListTile, 'Projects').first)
          .then((_) => settle(t));
      await t.tap(find.text('Short Film'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      final back = find.descendant(
          of: find.byType(AppBar), matching: find.byIcon(Icons.arrow_back));
      expect(back, findsOneWidget);
      await t.tap(back);
      await settle(t);
      expect(find.byType(ProjectPage), findsNothing);
      expect(find.text('Short Film'), findsOneWidget);
      await t.tap(find.byIcon(Icons.view_list));
      await settle(t);
      await t.tap(find.text('Short Film'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      await t.binding.setSurfaceSize(const Size(800, 600));
    });

    testWidgets('narrow layout opens a project and keeps the drawer',
        (t) async {
      installApi();
      await t.binding.setSurfaceSize(const Size(400, 800));
      await t.pumpWidget(const WfmApp());
      await settle(t);
      await t.tap(find.byIcon(Icons.menu));
      await settle(t);
      await t
          .tap(find.widgetWithText(ListTile, 'Projects').first)
          .then((_) => settle(t));
      await t.tap(find.text('Short Film'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      await t.flingFrom(const Offset(0, 300), const Offset(300, 0), 1000);
      await settle(t);
      expect(find.byIcon(Icons.logout), findsOneWidget);
      await t.tap(find.text('Settings'));
      await settle(t);
      expect(find.byType(ProjectPage), findsNothing);
      await t.binding.setSurfaceSize(const Size(800, 600));
    });

    testWidgets('list view toggle persists and restores', (t) async {
      installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p1',
                'name': 'p1',
                'displayName': 'Alpha',
                'createdAt': 1
              }
            ],
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byIcon(Icons.view_list));
      await settle(t);
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
      var opened = '';
      openEditorForTesting = (u) => opened = u;
      await t.tap(find.text('Edit'));
      await settle(t);
      expect(opened, contains('/filmcraft/wfm.html?project=p1'));
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('projectsView'), 1);
      await t.tap(find.text('Alpha'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await pump(t, const ProjectsPage());
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
    });

    testWidgets('search and sort projects', (t) async {
      installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p1',
                'name': 'alpha',
                'displayName': 'Alpha',
                'createdAt': 1,
                'lastActivity': 2
              },
              {
                'id': 'p2',
                'name': 'beta',
                'displayName': 'Beta',
                'createdAt': 2,
                'lastActivity': 1
              },
            ],
      });
      await pump(t, const ProjectsPage());
      await t.enterText(find.byType(TextField).first, 'alp');
      await settle(t);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      await t.enterText(find.byType(TextField).first, 'zzz');
      await settle(t);
      expect(find.text('No projects match your search.'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, '');
      await settle(t);
      await t.tap(find.byIcon(Icons.sort));
      await settle(t);
      await t.tap(find.text('Created date'));
      await settle(t);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('projectsSort'), 1);
      expect(t.getTopLeft(find.text('Beta')).dx,
          lessThan(t.getTopLeft(find.text('Alpha')).dx));
      await t.tap(find.byIcon(Icons.sort));
      await settle(t);
      await t.tap(find.text('Last activity'));
      await settle(t);
      expect(t.getTopLeft(find.text('Alpha')).dx,
          lessThan(t.getTopLeft(find.text('Beta')).dx));
      await t.pumpWidget(const SizedBox());
      await pump(t, const ProjectsPage());
    });

    testWidgets('managed project is read only and take over works', (t) async {
      var took = false;
      final api = installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p9',
                'name': 'p9',
                'displayName': 'Student Work',
                'ownerId': 's1',
                'ownerName': 'Sam',
                'takeOver': true,
                'createdAt': 1
              }
            ],
        'POST /api/projects/p9/take-over': (_) {
          took = true;
          return {'ok': true};
        },
        'GET /api/projects/p9/files': (_) => [
              {'name': 'Raw', 'path': 'Raw', 'type': 'dir'},
              {
                'name': 'c.mp4',
                'path': 'Raw/c.mp4',
                'type': 'file',
                'size': 1,
                'modified': 1
              }
            ],
      });
      api.user =
          User.fromJson({'id': 'u9', 'username': 'teach', 'role': 'teacher'});
      await pump(t, const ProjectsPage());
      expect(find.textContaining('by Sam'), findsOneWidget);
      expect(find.text('Render'), findsNothing);
      expect(find.text('Read only'), findsWidgets);
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Take ownership'));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(t);
      expect(took, isTrue);
      await t.tap(find.text('Student Work'));
      await settle(t);
      expect(find.text('Read only'), findsWidgets);
      expect(find.text('Open in FilmCraft'), findsNothing);
    });

    testWidgets('take over cancel and error', (t) async {
      var calls = 0;
      final api = installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p9',
                'name': 'p9',
                'displayName': 'Student Work',
                'ownerId': 's1',
                'ownerName': 'Sam',
                'takeOver': true,
                'createdAt': 1
              }
            ],
        'POST /api/projects/p9/take-over': (_) {
          calls++;
          return http.Response('{"error":"nope"}', 500);
        },
      });
      api.user =
          User.fromJson({'id': 'u9', 'username': 'teach', 'role': 'teacher'});
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Take ownership'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(calls, 0);
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Take ownership'));
      await settle(t);
      await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await settle(t);
      expect(calls, 1);
      expect(find.byType(Notice), findsOneWidget);
    });

    testWidgets('take over hidden when server would refuse', (t) async {
      final api = installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p9',
                'name': 'p9',
                'displayName': 'Student Work',
                'ownerId': 's1',
                'ownerName': 'Sam',
                'createdAt': 1
              },
              {
                'id': 'p8',
                'name': 'p8',
                'displayName': 'Locked Own',
                'status': 'submitted',
                'createdAt': 1
              }
            ],
      });
      api.user =
          User.fromJson({'id': 'u9', 'username': 'teach', 'role': 'teacher'});
      await pump(t, const ProjectsPage());
      for (final m in find.byType(PopupMenuButton<String>).evaluate()) {
        await t.tap(find.byWidget(m.widget));
        await settle(t);
        expect(find.text('Take ownership'), findsNothing);
        await t.tapAt(const Offset(5, 5));
        await settle(t);
      }
    });

    testWidgets('pin project sorts first', (t) async {
      final bodies = <String, String>{};
      installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p1',
                'name': 'alpha',
                'displayName': 'Alpha',
                'createdAt': 1
              },
              {
                'id': 'p2',
                'name': 'beta',
                'displayName': 'Beta',
                'createdAt': 2,
                'pinned': true
              },
            ],
        'PATCH /api/projects/p1': (req) {
          bodies['p1'] = req.body;
          return http.Response('{"error":"nope"}', 500);
        },
        'PATCH /api/projects/p2': (req) {
          bodies['p2'] = req.body;
          return {'ok': true};
        },
      });
      await pump(t, const ProjectsPage());
      expect(t.getTopLeft(find.text('Beta')).dx,
          lessThan(t.getTopLeft(find.text('Alpha')).dx));
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Unpin project'));
      await settle(t);
      expect(bodies['p2'], contains('"pinned":false'));
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Pin project'));
      await settle(t);
      expect(bodies['p1'], contains('"pinned":true'));
    });

    testWidgets('card render button opens the render dialog', (t) async {
      installApi();
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(RenderDialog), findsOneWidget);
    });

    testWidgets('card menu render lands on the renders tab', (t) async {
      var listed = 0;
      installApi(extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [
                {'id': 21, 'name': 'Main Edit'}
              ],
              'activeSequence': 21,
              'serverRender': true,
              'project': true,
            },
        'POST /api/projects/p1/renders': (_) =>
            {'id': 'r9', 'status': 'queued', 'mode': 'server'},
        'GET /api/projects/p1/renders': (_) {
          listed++;
          return [
            {'id': 'r9', 'status': 'queued', 'outputName': 'out9'}
          ];
        },
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Render'));
      await settle(t);
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      expect(listed, greaterThan(0));
      expect(find.text('out9'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('card menu share opens the share dialog', (t) async {
      installApi();
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Share'));
      await settle(t);
      expect(find.byType(Dialog), findsOneWidget);
    });

    testWidgets('status badge shows on card and row', (t) async {
      installApi(extra: {
        'GET /api/projects': (_) => [
              {
                'id': 'p1',
                'name': 'cut',
                'displayName': 'Cut',
                'status': 'submitted',
                'createdAt': 1
              },
              {
                'id': 'p2',
                'name': 'done',
                'displayName': 'Done',
                'status': 'reviewed',
                'createdAt': 1
              },
            ],
      });
      await pump(t, const ProjectsPage());
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget);
      await t.tap(find.byIcon(Icons.view_list));
      await settle(t);
      expect(find.text('Submitted'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget);
    });

    testWidgets('card menu duplicates a project, error then ok', (t) async {
      var calls = 0;
      installApi(extra: {
        'POST /api/projects/p1/duplicate': (_) => ++calls == 1
            ? http.Response('{"error":"quota"}', 413)
            : {'id': 'p9', 'name': 'c', 'displayName': 'C'},
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Duplicate'));
      await settle(t);
      expect(find.text('quota'), findsWidgets);
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Duplicate'));
      await settle(t);
      expect(calls, 2);
      expect(find.text('Copy created'), findsWidgets);
    });

    testWidgets('open in filmcraft error shows snack', (t) async {
      installApi();
      openEditorForTesting = (_) => throw 'no editor';
      await pump(t, const ProjectsPage());
      await t.tap(find.text('Edit'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.text('Write script'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.text('Plan storyboard'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('empty and error states', (t) async {
      installApi(extra: {'GET /api/projects': (_) => []});
      await pump(t, const ProjectsPage());
      expect(find.textContaining('No projects'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      installApi(extra: {
        'GET /api/projects': (_) => http.Response('{"error":"db down"}', 500)
      });
      await pump(t, const ProjectsPage());
      expect(find.text('db down'), findsOneWidget);
    });

    testWidgets('create project dialog cancel, empty, ok, error', (t) async {
      var created = 0;
      installApi(extra: {
        'GET /api/projects': (_) => [],
        'POST /api/projects': (req) {
          created++;
          return {'id': 'p9', 'name': 'x', 'displayName': 'x'};
        },
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      expect(find.byType(AlertDialog), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(created, 0);
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).last, '   ');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(created, 0);
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'New Film');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      expect(created, 1);
      expect(find.byType(ProjectPage), findsOneWidget);
    });

    testWidgets('create project error shows snack', (t) async {
      installApi(extra: {
        'GET /api/projects': (_) => [],
        'POST /api/projects': (_) => http.Response('{"error":"nope"}', 409),
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
    });

    Map<String, dynamic> proj(String id, String name, [String fid = '']) => {
          'id': id,
          'name': id,
          'displayName': name,
          'folderId': fid,
          'createdAt': 1
        };

    Future<void> openFolder(WidgetTester t, String name) async {
      await t.tap(find.text(name));
      await t.pump(kDoubleTapMinTime);
      await t.tap(find.text(name));
      await settle(t);
    }

    testWidgets('folder card opens folder view and back returns', (t) async {
      installApi(extra: {
        'GET /api/projects': (_) => [
              proj('p1', 'Alpha', 'f1'),
              proj('p2', 'Beta'),
              proj('p3', 'Gamma', 'gone'),
            ],
        'GET /api/folders': (_) => [
              {'id': 'f1', 'name': 'Class A'}
            ],
      });
      await pump(t, const ProjectsPage());
      expect(find.text('Class A'), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsWidgets);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Gamma'), findsOneWidget);
      await openFolder(t, 'Class A');
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      await t.tap(find.byIcon(Icons.arrow_back));
      await settle(t);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('empty folder and list view folder rows', (t) async {
      installApi(extra: {
        'GET /api/projects': (_) => [],
        'GET /api/folders': (_) => [
              {'id': 'f1', 'name': 'Class A'}
            ],
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byIcon(Icons.view_list));
      await settle(t);
      expect(find.text('Class A'), findsOneWidget);
      await openFolder(t, 'Class A');
      expect(find.text('Empty folder'), findsOneWidget);
    });

    testWidgets('new folder, rename, delete folder', (t) async {
      var have = false;
      var calls = <String>[];
      installApi(extra: {
        'GET /api/folders': (_) => have
            ? [
                {'id': 'f1', 'name': 'Class A'}
              ]
            : [],
        'POST /api/folders': (_) {
          have = true;
          calls.add('create');
          return {'id': 'f1', 'name': 'Class A'};
        },
        'PATCH /api/folders/f1': (_) {
          calls.add('rename');
          return {'ok': true};
        },
        'DELETE /api/folders/f1': (_) {
          have = false;
          calls.add('delete');
          return {'ok': true};
        },
      });
      await pump(t, const ProjectsPage());
      expect(find.text('Class A'), findsNothing);
      await t.tap(find.text('New folder'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(calls, isEmpty);
      await t.tap(find.text('New folder'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'Class A');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(calls, ['create']);
      expect(find.text('Class A'), findsOneWidget);

      await openFolder(t, 'Class A');
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'Class B');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(calls, ['create', 'rename']);

      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.text('Class A'), findsOneWidget);
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(calls, ['create', 'rename', 'delete']);
      expect(find.text('Class A'), findsNothing);
      expect(find.text('Short Film'), findsOneWidget);
    });

    testWidgets('add to folder dialog', (t) async {
      var patched = <String>[];
      installApi(extra: {
        'GET /api/folders': (_) => [
              {'id': 'f1', 'name': 'Class A'}
            ],
        'PATCH /api/projects/p1': (req) {
          patched.add(req.body);
          return {'ok': true};
        },
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Add to folder'));
      await settle(t);
      Navigator.of(t.element(find.byType(SimpleDialog)), rootNavigator: true)
          .pop();
      await settle(t);
      expect(patched, isEmpty);

      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Add to folder'));
      await settle(t);
      await t.tap(find.text('No folder'));
      await settle(t);
      expect(patched, isEmpty);

      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Add to folder'));
      await settle(t);
      await t.tap(find.descendant(
          of: find.byType(SimpleDialog), matching: find.text('Class A')));
      await settle(t);
      expect(patched.single, contains('"folderId":"f1"'));
    });

    testWidgets('project created inside a folder lands in it', (t) async {
      var body = '';
      installApi(extra: {
        'GET /api/folders': (_) => [
              {'id': 'f1', 'name': 'Class A'}
            ],
        'POST /api/projects': (req) {
          body = req.body;
          return {
            'id': 'p9',
            'name': 'x',
            'displayName': 'x',
            'createdAt': 1
          };
        },
      });
      await pump(t, const ProjectsPage());
      await openFolder(t, 'Class A');
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(body, contains('"folderId":"f1"'));
      expect(find.byType(ProjectPage), findsOneWidget);
    });

    testWidgets('folder errors show snack', (t) async {
      installApi(extra: {
        'GET /api/folders': (_) => [
              {'id': 'f1', 'name': 'Class A'}
            ],
        'POST /api/folders': (_) => http.Response('{"error":"dup"}', 409),
        'PATCH *': (_) => http.Response('{"error":"nope"}', 500),
        'DELETE *': (_) => http.Response('{"error":"nope"}', 500),
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.text('New folder'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.pumpWidget(const SizedBox());

      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Add to folder'));
      await settle(t);
      await t.tap(find.descendant(
          of: find.byType(SimpleDialog), matching: find.text('Class A')));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);

      await openFolder(t, 'Class A');
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'y');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('narrow layout hides appbar and spans cards', (t) async {
      installApi();
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await pump(t, const ProjectsPage());
      expect(find.byType(AppBar), findsNothing);
      expect(t.getSize(find.byType(Card)).width, greaterThan(340));
    });
  });

  testWidgets('share dialog send change level revoke', (t) async {
    var created = 0,
        leveled = 0,
        revoked = 0,
        loads = 0,
        lcalls = 0,
        ccalls = 0,
        rcalls = 0;
    installApi(extra: {
      'GET /api/projects/p1/shares': (_) {
        loads++;
        if (loads == 1) return http.Response('{"error":"x"}', 500);
        return [
          {
            'id': 's9',
            'projectId': 'p1',
            'inviteeUsername': 'bob',
            'inviteeName': 'Bob',
            'level': 'view',
            'status': 'accepted',
            'createdAt': 1
          },
          {
            'id': 's10',
            'projectId': 'p1',
            'inviteeUsername': 'cat',
            'level': 'edit',
            'status': 'pending',
            'createdAt': 1
          }
        ];
      },
      'POST /api/projects/p1/shares': (req) {
        created++;
        return created > 1
            ? {'ok': true}
            : http.Response('{"error":"no"}', 400);
      },
      'PATCH /api/projects/p1/shares/s9': (_) {
        leveled++;
        return leveled > 1 ? {'ok': true} : http.Response('{"error":"x"}', 500);
      },
      'DELETE /api/projects/p1/shares/s9': (_) {
        revoked++;
        return {'ok': true};
      },
      'GET /api/projects/p1/links': (_) {
        lcalls++;
        if (lcalls == 1) return http.Response('{"error":"x"}', 500);
        return [
          if (ccalls > 1)
            {
              'id': 'l3',
              'projectId': 'p1',
              'scope': 'project',
              'createdAt': 3,
              'expiresAt': 0,
              'revoked': false
            },
          {
            'id': 'l1',
            'projectId': 'p1',
            'scope': 'project',
            'createdAt': 1,
            'expiresAt': 0,
            'revoked': false
          },
          {
            'id': 'l2',
            'projectId': 'p1',
            'scope': 'renders',
            'createdAt': 2,
            'expiresAt': 1700000100,
            'revoked': false
          },
        ];
      },
      'POST /api/projects/p1/links': (_) {
        ccalls++;
        return ccalls == 1
            ? http.Response('{"error":"no"}', 400)
            : {'id': 'l3', 'token': 'tok3'};
      },
      'GET /api/share-targets': (_) => [
            {
              'id': 'u9',
              'username': 'bob',
              'displayName': 'Bob',
              'classId': 'c1'
            },
            {'id': 'u10', 'username': 'cat', 'classId': 'cu'}
          ],
      'GET /api/classes': (_) => [
            {'id': 'c1', 'name': 'Period 1', 'members': 2, 'createdAt': 1},
            {'id': 'cu', 'name': 'unmanaged', 'unmanaged': true, 'createdAt': 2}
          ],
      'DELETE /api/projects/p1/links/l1': (_) {
        rcalls++;
        return rcalls == 1 ? http.Response('{"error":"x"}', 500) : {'ok': true};
      },
    });
    await t.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await pump(
        t,
        ProjectPage(
            project: Project.fromJson({'id': 'p1', 'name': 'short-film'})));
    await t.tap(find.byIcon(Icons.share_outlined));
    await settle(t);
    expect(find.text('Share project'), findsOneWidget);
    expect(find.byType(Notice), findsWidgets);
    await t.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byIcon(Icons.send)));
    await settle(t);
    expect(created, 0);
    await t.tap(find.byType(DropdownMenu<User>));
    await settle(t);
    expect(find.text('cat · Unmanaged'), findsOneWidget);
    await t.tap(find.text('Bob (bob) · Period 1').last);
    await settle(t);
    await t.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byIcon(Icons.send)));
    await settle(t);
    expect(created, 1);
    expect(find.byType(Notice), findsWidgets);
    await t.tap(find.text('Can view').first);
    await settle(t);
    await t.tap(find.text('Can edit').last);
    await settle(t);
    await t.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byIcon(Icons.send)));
    await settle(t);
    expect(created, 2);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);
    await t.tap(find
        .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.more_vert))
        .first);
    await settle(t);
    await t.tap(find.text('Can edit').last);
    await settle(t);
    expect(leveled, 1);
    await t.tap(find
        .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.more_vert))
        .first);
    await settle(t);
    await t.tap(find.text('Can view').last);
    await settle(t);
    expect(leveled, 2);
    await t.tap(find
        .descendant(
            of: find.byType(AlertDialog),
            matching: find.byIcon(Icons.more_vert))
        .first);
    await settle(t);
    await t.tap(find.text('Revoke'));
    await settle(t);
    expect(revoked, 1);
    await t.tap(find.byIcon(Icons.add_link));
    await settle(t);
    expect(ccalls, 1);
    expect(find.text('Share links'), findsOneWidget);
    await t.tap(find.text('Renders only').first);
    await settle(t);
    await t.tap(find.text('Whole project').last);
    await settle(t);
    await t.tap(find.text('7 days').first);
    await settle(t);
    await t.tap(find.text('Never expires').last);
    await settle(t);
    await t.tap(find.byIcon(Icons.add_link));
    await settle(t);
    expect(ccalls, 2);
    expect(find.byIcon(Icons.copy), findsOneWidget);
    await t.tap(find.byIcon(Icons.copy));
    await settle(t);
    final del = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.delete_outline));
    await t.tap(del.at(1));
    await settle(t);
    expect(rcalls, 1);
    await t.tap(del.at(1));
    await settle(t);
    expect(rcalls, 2);
  });

  testWidgets('share dialog stacks pickers on narrow screens', (t) async {
    var created = 0;
    installApi(extra: {
      'GET /api/projects/p1/shares': (_) => [],
      'GET /api/projects/p1/links': (_) => [],
      'GET /api/share-targets': (_) => [
            {'id': 'u9', 'username': 'bob', 'displayName': 'Bob'}
          ],
      'POST /api/projects/p1/shares': (_) {
        created++;
        return {'ok': true};
      },
    });
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pump(t, ProjectPage(project: p1));
    await t.tap(find.byIcon(Icons.share_outlined));
    await settle(t);
    expect(find.text('Share project'), findsOneWidget);
    await t.tap(find.byType(DropdownMenu<User>));
    await settle(t);
    await t.tap(find.text('Bob (bob)').last);
    await settle(t);
    await t.tap(find.text('Can view').first);
    await settle(t);
    await t.tap(find.text('Can edit').last);
    await settle(t);
    await t.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byIcon(Icons.send)));
    await settle(t);
    expect(created, 1);
    expect(find.text('Renders only'), findsOneWidget);
    expect(find.text('7 days'), findsOneWidget);
  });

  testWidgets('narrow project page uses icon actions and scrollable tabs',
      (t) async {
    var opened = '';
    openEditorForTesting = (u) => opened = u;
    pickFilesForTesting = () async => [];
    installApi(extra: {
      'GET /api/projects/p1/comments': (_) => [],
    });
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
    await pump(t, ProjectPage(project: p1));
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Upload'), findsNothing);
    await t.tap(find.byIcon(Icons.movie_edit));
    await settle(t);
    expect(opened, contains('/filmcraft/wfm.html?project=p1'));
    await t.tap(find.byIcon(Icons.upload_file));
    await settle(t);
    await t.ensureVisible(find.text('Comments'));
    await settle(t);
    await t.tap(find.text('Comments'));
    await settle(t);
    expect(find.text('No comments yet'), findsOneWidget);
  });

  group('ProjectPage', () {
    testWidgets('open filmcraft, rename, delete', (t) async {
      var opened = '';
      openEditorForTesting = (u) => opened = u;
      installApi();
      await t.pumpWidget(testApp(Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                      builder: (_) => ProjectPage(project: p1))),
                  child: const Text('open'))))));
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      await t.tap(find.byIcon(Icons.edit_note));
      expect(opened, contains('/scriptcraft/wfm.html?project=p1'));
      await t.tap(find.byIcon(Icons.view_carousel_outlined));
      expect(opened, contains('/deckcraft/wfm.html?project=p1'));
      await t.tap(find.text('Edit'));
      expect(opened, contains('project=p1'));

      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'Renamed Film');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.text('Renamed Film'), findsOneWidget);

      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t, 30);
      expect(find.byType(ProjectPage), findsNothing);
    });

    testWidgets('open error snack, rename and delete errors', (t) async {
      installApi(extra: {
        'PATCH *': (_) => http.Response('{"error":"nope"}', 500),
        'DELETE *': (_) => http.Response('{"error":"nope"}', 500),
      });
      openEditorForTesting = (_) => throw 'no editor';
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.byIcon(Icons.view_carousel_outlined));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byIcon(Icons.edit_note));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.text('Edit'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'X');
      await t.tap(find.text('OK'));
      await settle(t);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
    });

    testWidgets('menu duplicates and toggles template', (t) async {
      var dup = 0, patches = 0;
      String patch = '';
      installApi(extra: {
        'POST /api/projects/p1/duplicate': (_) => ++dup == 1
            ? http.Response('{"error":"nope"}', 500)
            : {'id': 'p9', 'name': 'c', 'displayName': 'C'},
        'PATCH /api/projects/p1': (req) {
          patch = req.body;
          return ++patches == 1
              ? http.Response('{"error":"nope"}', 500)
              : {'ok': true};
        },
      });
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Duplicate'));
      await settle(t);
      expect(find.text('nope'), findsWidgets);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Duplicate'));
      await settle(t);
      expect(dup, 2);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Mark as template'));
      await settle(t);
      expect(find.text('nope'), findsWidgets);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Mark as template'));
      await settle(t);
      expect(patch, contains('"template":true'));
      expect(find.text('Template'), findsOneWidget);
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Unmark template'));
      await settle(t);
      expect(patch, contains('"template":false'));
    });

    testWidgets('shared page shows use template and save copy', (t) async {
      var dup = 0;
      installApi(extra: {
        'GET /api/projects/p1/files': (_) => [],
        'POST /api/projects/p1/duplicate': (_) {
          dup++;
          return {'id': 'p9', 'name': 'c', 'displayName': 'C'};
        },
      });
      await pump(
          t,
          ProjectPage(
              project: Project.fromJson({
            'id': 'p1',
            'name': 'shared',
            'displayName': 'Shared Cut',
            'access': 'view',
            'template': true
          })));
      expect(find.text('Template'), findsOneWidget);
      await t.tap(find.text('Use template'));
      await settle(t);
      expect(dup, 1);
      await pump(
          t,
          ProjectPage(
              project: Project.fromJson({
            'id': 'p1',
            'name': 'shared',
            'displayName': 'Shared Cut',
            'access': 'view'
          })));
      expect(find.byIcon(Icons.copy_outlined), findsOneWidget);
      await t.tap(find.byIcon(Icons.copy_outlined));
      await settle(t);
      expect(dup, 2);
      expect(find.text('Copy created'), findsWidgets);
    });

    testWidgets('submit toggles lock and review buttons work', (t) async {
      var review = '', submits = 0, reviews = 0;
      installApi(extra: {
        'GET /api/projects/p1/files': (_) => [],
        'POST /api/projects/p1/submit': (_) => ++submits == 1
            ? http.Response('{"error":"nope"}', 500)
            : {'ok': true, 'status': 'submitted'},
        'POST /api/projects/p2/review': (req) {
          review = req.body;
          if (++reviews == 1) {
            return http.Response('{"error":"nope"}', 500);
          }
          return {
            'ok': true,
            'status': req.body.contains('draft') ? 'draft' : 'reviewed'
          };
        },
      });
      await pump(t, ProjectPage(project: p1));
      expect(find.byIcon(Icons.send_outlined), findsOneWidget);
      await t.tap(find.byIcon(Icons.send_outlined));
      await settle(t);
      await t.tap(find.byIcon(Icons.send_outlined));
      await settle(t);
      expect(find.text('Submitted'), findsWidgets);
      expect(find.byIcon(Icons.undo_outlined), findsOneWidget);
      expect(find.text('Read only'), findsWidgets);
      await pump(
          t,
          ProjectPage(
              project: Project.fromJson({
            'id': 'p2',
            'name': 'other',
            'displayName': 'Their Cut',
            'access': 'view',
            'ownerId': 'x',
            'status': 'submitted'
          })));
      await t.tap(find.byIcon(Icons.check_circle_outline));
      await settle(t);
      await t.tap(find.byIcon(Icons.check_circle_outline));
      await settle(t);
      expect(review, contains('reviewed'));
      expect(find.text('Reviewed'), findsOneWidget);
      await pump(
          t,
          ProjectPage(
              project: Project.fromJson({
            'id': 'p2',
            'name': 'other',
            'displayName': 'Their Cut',
            'access': 'view',
            'ownerId': 'x',
            'status': 'submitted'
          })));
      await t.tap(find.byIcon(Icons.undo_outlined));
      await settle(t);
      expect(review, contains('draft'));
    });

    testWidgets('comments tab lists and posts', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/comments': (_) => [
              {
                'id': 'c1',
                'projectId': 'p1',
                'userId': 'u2',
                'username': 'bob',
                'body': 'nice',
                'createdAt': 1
              }
            ],
      });
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.text('Comments'));
      await settle(t);
      expect(find.text('nice'), findsOneWidget);
    });
  });

  group('FilesTab', () {
    testWidgets('usage shows in header and with quota', (t) async {
      final api = installApi(extra: {
        'GET /api/projects/p1/usage': (_) => {'bytes': 2048},
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.text('2.0 KB'), findsOneWidget);
      api.user = User.fromJson({...userJson, 'quotaBytes': 4194304});
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.text('2.0 KB of 4.0 MB used'), findsOneWidget);
    });

    testWidgets('browse, crumbs, file menu actions', (t) async {
      var opened = '';
      openExternalForTesting = (u) => opened = u;
      var moved = 0;
      installApi(extra: {
        'GET /api/projects/p1/files': (req) {
          final path = req.url.queryParameters['path'] ?? '';
          if (path == 'Raw') {
            return [
              {'name': 'inner', 'path': 'Raw/inner', 'type': 'dir'},
              {
                'name': 'b.mp4',
                'path': 'Raw/b.mp4',
                'type': 'file',
                'size': 2048,
                'modified': 1
              },
            ];
          }
          return [
            {'name': 'Raw', 'path': 'Raw', 'type': 'dir'},
            {
              'name': 'clip.mp4',
              'path': 'clip.mp4',
              'type': 'file',
              'size': 2048,
              'modified': 1
            },
          ];
        },
        'POST /api/projects/p1/files/move': (req) {
          moved++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.text('clip.mp4'), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsWidgets);
      await t.tap(find.text('Raw'));
      await settle(t);
      expect(find.text('b.mp4'), findsOneWidget);
      await t.tap(find.byIcon(Icons.home_outlined));
      await settle(t);
      expect(find.text('clip.mp4'), findsOneWidget);
      await t.tap(find.text('Raw'));
      await settle(t);
      await t.tap(find.text('Raw').first);
      await settle(t);

      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      expect(find.text('Download'), findsNothing);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'renamed');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 1);

      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Download'));
      await settle(t);
      expect(opened, contains('dl=true'));

      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
    });

    testWidgets(
        'rename same name fires no request, collision shows friendly text',
        (t) async {
      var moved = 0;
      installApi(extra: {
        'GET /api/projects/p1/files': (_) => [
              {
                'name': 'clip.mp4',
                'path': 'clip.mp4',
                'type': 'file',
                'size': 2048,
                'modified': 1
              },
            ],
        'POST /api/projects/p1/files/move': (req) {
          moved++;
          return moved == 1
              ? http.Response('{"error":"exists"}', 409)
              : http.Response('{"error":"boom"}', 500);
        },
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.text('clip.mp4'), findsOneWidget);

      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'CLIP.MP4');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 0);

      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'clip.txt');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 0);
      expect(
          find.text(
              'Changing the file extension would break the file, so this action is blocked.'),
          findsWidgets);

      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'taken.mp4');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 1);
      expect(find.text('A file with that name already exists.'), findsWidgets);

      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'other.mp4');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 2);
      expect(find.text("Couldn't rename the file."), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('selection mode: bulk move, zip and delete', (t) async {
      var opened = '';
      var moved = 0;
      var deleted = 0;
      openExternalForTesting = (u) => opened = u;
      installApi(extra: {
        'POST /api/projects/p1/files/move': (_) {
          moved++;
          return {'ok': true};
        },
        'DELETE /api/projects/p1/files': (_) {
          deleted++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.byIcon(Icons.checklist));
      await settle(t);
      expect(find.byType(Checkbox), findsWidgets);
      await t.tap(find.byIcon(Icons.select_all));
      await settle(t);
      expect(find.text('5 selected'), findsOneWidget);
      await t.tap(find.byIcon(Icons.download));
      await settle(t);
      expect(opened, contains('/api/projects/p1/zip?paths='));
      await t.tap(find.byIcon(Icons.drive_file_move_outline));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'Audio');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 5);
      await t.tap(find.byIcon(Icons.checklist));
      await settle(t);
      await t.tap(find.byType(Checkbox).first);
      await settle(t);
      await t.tap(find.text('clip.mp4'));
      await settle(t);
      expect(find.text('2 selected'), findsOneWidget);
      await t.tap(find.text('clip.mp4'));
      await settle(t);
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(find.byIcon(Icons.delete_outline));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(deleted, 0);
      await t.tap(find.byIcon(Icons.delete_outline));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(deleted, 1);
    });

    testWidgets('folder menu offers zip download', (t) async {
      var opened = '';
      openExternalForTesting = (u) => opened = u;
      installApi();
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Download zip'));
      await settle(t);
      expect(opened, contains('/api/projects/p1/zip?paths=Raw'));
      openExternalForTesting = (_) => throw 'no browser';
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Download zip'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
    });

    testWidgets('selection errors and grid toggles', (t) async {
      openExternalForTesting = (_) => throw 'no browser';
      installApi(extra: {
        'POST /api/projects/p1/files/move': (_) =>
            http.Response('{"error":"mv"}', 500),
        'DELETE /api/projects/p1/files': (_) =>
            http.Response('{"error":"del"}', 500),
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.byIcon(Icons.grid_view));
      await settle(t);
      await t.tap(find.byIcon(Icons.checklist));
      await settle(t);
      await t.tap(find.text('clip.mp4'));
      await settle(t);
      expect(find.text('1 selected'), findsOneWidget);
      await t.tap(find.byType(Checkbox).last);
      await settle(t);
      await t.tap(find.byIcon(Icons.download));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.byIcon(Icons.drive_file_move_outline));
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      await t.tap(find.byIcon(Icons.checklist));
      await settle(t);
      await t.tap(find.text('clip.mp4'));
      await settle(t);
      await t.tap(find.byIcon(Icons.delete_outline));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });

    testWidgets('media preview modal: image, video, download, close',
        (t) async {
      var opened = '';
      openExternalForTesting = (u) => opened = u;
      installApi(extra: {
        'GET /api/projects/p1/files': (_) => [
              {
                'name': 'pic.png',
                'path': 'pic.png',
                'type': 'file',
                'size': 100,
                'modified': 1
              },
              {
                'name': 'clip.mp4',
                'path': 'clip.mp4',
                'type': 'file',
                'size': 2048,
                'modified': 1
              },
            ],
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.text('pic.png'));
      await settle(t);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('pic.png'), findsNWidgets(2));
      await t.tap(find.byTooltip('Close'));
      await settle(t);
      expect(find.byType(Dialog), findsNothing);
      await t.tap(find.text('clip.mp4'));
      await settle(t);
      expect(find.byType(Dialog), findsOneWidget);
      await t.tap(find.text('Play in browser'));
      await settle(t);
      expect(opened, contains('download?path=clip.mp4'));
      expect(opened, isNot(contains('dl=true')));
      await t.tap(find.byTooltip('Download'));
      await settle(t);
      expect(opened, contains('dl=true'));
      openExternalForTesting = (_) => throw 'no browser';
      await t.tap(find.byTooltip('Download'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byTooltip('Close'));
      await settle(t);
      expect(find.byType(Dialog), findsNothing);
      await t.tap(find.byIcon(Icons.grid_view));
      await settle(t);
      await t.tap(find.text('pic.png'));
      await settle(t);
      expect(find.byType(Dialog), findsOneWidget);
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(t);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('media preview uses an injected player', (t) async {
      var madeAudio = false;
      mediaPlayerForTesting = (url, audio) {
        if (audio) madeAudio = true;
        return const Text('player');
      };
      installApi(extra: {
        'GET /api/projects/p1/files': (_) => [
              {
                'name': 'song.mp3',
                'path': 'song.mp3',
                'type': 'file',
                'size': 512,
                'modified': 0
              },
            ],
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.text('song.mp3'));
      await settle(t);
      expect(find.text('player'), findsOneWidget);
      expect(madeAudio, isTrue);
    });

    testWidgets('grid view toggle persists and restores', (t) async {
      installApi();
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.byType(ListView), findsOneWidget);
      await t.tap(find.byIcon(Icons.grid_view));
      await settle(t);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.text('clip.mp4'), findsOneWidget);
      var opened = '';
      openExternalForTesting = (u) => opened = u;
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Download'));
      await settle(t);
      expect(opened, contains('dl=true'));
      await t.tap(find.text('Raw'));
      await settle(t);
      final p = await SharedPreferences.getInstance();
      expect(p.getInt('filesView'), 1);
      await t.pumpWidget(const SizedBox());
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('upload picked files', (t) async {
      var uploads = 0;
      pickFilesForTesting = () async => [
            PickedFile('a.mp4', Uint8List(3)),
            PickedFile('evil.exe', Uint8List(1)),
            PickedFile('b.mp4', Uint8List(1))
          ];
      installApi(extra: {
        'PUT /api/projects/p1/files': (req) {
          uploads++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.text('Upload'));
      await settle(t);
      expect(find.textContaining("isn't allowed: evil.exe"), findsOneWidget);
      expect(find.text('Uploading files'), findsNothing);
      expect(uploads, 2);
      pickFilesForTesting = () async => [PickedFile('x.sh', Uint8List(2))];
      await t.tap(find.text('Upload'));
      await settle(t);
      expect(find.textContaining("isn't allowed: x.sh"), findsOneWidget);
      expect(uploads, 2);
    });

    testWidgets('upload in subfolder, empty pick, pick error, upload error',
        (t) async {
      var uploads = 0;
      installApi(extra: {
        'PUT /api/projects/p1/files': (req) {
          uploads++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.text('Raw'));
      await settle(t);
      pickFilesForTesting = () async => [];
      await t.tap(find.text('Upload'));
      await settle(t);
      expect(uploads, 0);
      pickFilesForTesting = () => throw Exception('no picker');
      await t.tap(find.text('Upload'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      pickFilesForTesting = () async => [PickedFile('v.mp4', Uint8List(2))];
      installApi(extra: {
        'PUT /api/projects/p1/files': (_) =>
            http.Response('{"error":"full"}', 507),
      });
      await t.tap(find.text('Upload'));
      await settle(t);
      expect(find.textContaining('full'), findsOneWidget);
      await t.tap(find.byWidgetPredicate(
          (w) => w is Icon && w.icon == Icons.close && w.size == 16));
      await settle(t);
      expect(find.textContaining('full'), findsNothing);
    });

    testWidgets('mkdir via dialog', (t) async {
      var made = 0;
      installApi(extra: {
        'POST /api/projects/p1/files/mkdir': (req) {
          made++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      await t.tap(find.byIcon(Icons.create_new_folder_outlined));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      await t.tap(find.byIcon(Icons.create_new_folder_outlined));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'Scenes');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(made, 1);
      await t.tap(find.byIcon(Icons.refresh));
      await settle(t);
    });

    testWidgets('file icons and error state', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/files': (_) =>
            http.Response('{"error":"lost"}', 404),
      });
      await pump(t, Scaffold(body: FilesTab(project: p1)));
      expect(find.text('lost'), findsOneWidget);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.mp4'})),
          Icons.movie_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.mxf'})),
          Icons.movie_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.wav'})),
          Icons.audio_file_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.opus'})),
          Icons.audio_file_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.jpg'})),
          Icons.image_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.exr'})),
          Icons.image_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.srt'})),
          Icons.subtitles_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.txt'})),
          Icons.insert_drive_file_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a', 'type': 'dir'})),
          Icons.folder_outlined);
    });
  });

  group('RendersTab', () {
    testWidgets('lists jobs, cancel and download', (t) async {
      var opened = '';
      var canceled = 0;
      openExternalForTesting = (u) => opened = u;
      installApi(extra: {
        'GET /api/projects/p1/files': (req) =>
            req.url.queryParameters['path'] == 'Exports'
                ? [
                    {
                      'name': 'final.mp4',
                      'path': 'Exports/final.mp4',
                      'type': 'file',
                      'size': 1,
                      'modified': 0
                    },
                  ]
                : [],
        'POST /api/renders/r2/cancel': (req) {
          canceled++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: RendersTab(project: p1)));
      expect(find.text('final'), findsOneWidget);
      expect(find.text('scene2.mp4'), findsOneWidget);
      expect(find.text('ffmpeg exploded'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      await t.tap(find.byIcon(Icons.download));
      await settle(t);
      expect(opened, contains('Exports%2Ffinal.mp4'));
      expect(find.byIcon(Icons.stop), findsNWidgets(2));
      await t.tap(find.byIcon(Icons.stop).first);
      await settle(t);
      expect(canceled, 1);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('retry and delete a finished render', (t) async {
      var retried = 0;
      var deleted = 0;
      var opened = '';
      openEditorForTesting = (u) => opened = u;
      installApi(extra: {
        'POST /api/renders/r3/retry': (req) {
          retried++;
          return {'id': 'r4', 'status': 'queued', 'mode': 'server'};
        },
        'POST /api/renders/r1/retry': (req) {
          retried++;
          return {'id': 'r5', 'status': 'running', 'mode': 'device'};
        },
        'POST /api/renders/r4/retry': (_) =>
            http.Response('{"error":"boom"}', 500),
        'DELETE /api/renders/r3': (req) {
          deleted++;
          return {'ok': true};
        },
        'DELETE /api/renders/r1': (_) => http.Response('{"error":"boom"}', 500),
      });
      await pump(t, Scaffold(body: RendersTab(project: p1)));
      await t.tap(find.byIcon(Icons.refresh).at(1));
      await settle(t);
      expect(retried, 1);
      expect(opened, isEmpty);
      await t.tap(find.byIcon(Icons.refresh).last);
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.byIcon(Icons.refresh).first);
      await settle(t);
      expect(retried, 2);
      expect(opened, contains('render=r5'));
      await t.tap(find.byIcon(Icons.delete_outline).at(1));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(deleted, 0);
      await t.tap(find.byIcon(Icons.delete_outline).at(1));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(deleted, 1);
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('load more appends the next page', (t) async {
      var fetches = 0;
      installApi(extra: {
        'GET /api/projects/p1/renders': (req) {
          final off = int.parse(req.url.queryParameters['offset'] ?? '0');
          if (off == 0) {
            return [
              for (var i = 0; i < 50; i++)
                {'id': 'j$i', 'status': 'done', 'outputName': 'out$i'}
            ];
          }
          if (++fetches == 1) {
            return http.Response('{"error":"boom"}', 500);
          }
          return [
            {'id': 'j50', 'status': 'done', 'outputName': 'out50'}
          ];
        },
      });
      await pump(t, Scaffold(body: RendersTab(project: p1)));
      await t.scrollUntilVisible(find.text('Load more'), 300);
      await t.tap(find.text('Load more'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.text('Load more'));
      await settle(t);
      await t.scrollUntilVisible(find.text('out50'), 300);
      expect(find.text('Load more'), findsNothing);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('new render FAB is disabled while a job is active', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/renders': (_) => [
              {'id': 'r1', 'status': 'running', 'outputName': 'out1'}
            ],
        'GET /api/projects/p1/files': (_) => [],
      });
      await pump(t, Scaffold(body: RendersTab(project: p1)));
      expect(find.text('out1'), findsOneWidget);
      expect(
          t
              .widget<FloatingActionButton>(find.byType(FloatingActionButton))
              .onPressed,
          isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('empty renders state', (t) async {
      installApi(extra: {'GET /api/projects/p1/renders': (_) => []});
      await pump(t, Scaffold(body: RendersTab(project: p1)));
      expect(find.textContaining('No renders'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('RenderDialog', () {
    testWidgets('submits a server render and pops true', (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      String? renderBody;
      installApi(extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [
                {'id': 21, 'name': 'Main Edit'}
              ],
              'activeSequence': 21,
              'serverRender': true,
              'project': true,
            },
        'POST /api/projects/p1/renders': (req) {
          renderBody = req.body;
          return {'id': 'r9', 'status': 'queued'};
        },
      });
      await t.pumpWidget(testApp(Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () async {
                    final r = await showDialog<bool>(
                        context: c, builder: (_) => RenderDialog(project: p1));
                    Navigator.of(c).push(MaterialPageRoute(
                        builder: (_) => Scaffold(body: Text('$r'))));
                  },
                  child: const Text('open'))))));
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      expect(find.byType(RenderDialog), findsOneWidget);
      await t.tap(find.text('Render'));
      await settle(t);
      expect(renderBody, contains('"mode":"server"'));
      expect(renderBody, contains('"sequence":21'));
      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('cancel closes dialog', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [],
              'serverRender': false,
              'project': true,
            },
      });
      await t.pumpWidget(testApp(Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () => showDialog<bool>(
                      context: c, builder: (_) => RenderDialog(project: p1)),
                  child: const Text('open'))))));
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byType(RenderDialog), findsNothing);
    });

    testWidgets('submit error shows snack', (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      installApi(extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [
                {'id': 21, 'name': 'Main Edit'}
              ],
              'activeSequence': 21,
              'serverRender': true,
              'project': true,
            },
        'POST /api/projects/p1/renders': (_) =>
            http.Response('{"error":"bad spec"}', 400),
      });
      await t.pumpWidget(testApp(Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () => showDialog<bool>(
                      context: c, builder: (_) => RenderDialog(project: p1)),
                  child: const Text('open'))))));
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });
  });

  group('Assignments', () {
    Map<String, dynamic> aJson(
            {bool? locked, bool? withdraw, int? max, int? due}) =>
        {
          'id': 'a1',
          'projectId': 'p0',
          'teacherId': 'u9',
          'allowWithdraw': withdraw ?? true,
          'maxSubmissions': max ?? 0,
          'dueAt': due ?? 0,
          'hidden': false,
          'locked': locked ?? false,
          'createdAt': 1
        };

    testWidgets('assign dialog picks students and manages submissions',
        (t) async {
      var assigned = false, patchFails = true, unassignFails = true;
      var patches = 0;
      var subs = [
        {
          'projectId': 'c1',
          'projectName': 'P - Kid',
          'studentId': 'u2',
          'studentUsername': 'kid',
          'studentName': 'Kid',
          'status': 'submitted',
          'submittedAt': 1,
          'submissions': 1,
          'late': true
        },
        {
          'projectId': 'c2',
          'projectName': 'P - x',
          'studentId': 'u4',
          'studentUsername': 'noname',
          'studentName': '',
          'status': 'reviewed',
          'submittedAt': 1,
          'submissions': 3,
          'late': false
        },
      ];
      final allSubs = List.of(subs);
      final due = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 86400;
      installApi(extra: {
        'GET /api/share-targets': (_) => [
              {
                'id': 'u2',
                'username': 'kid',
                'displayName': 'Kid',
                'role': 'student'
              },
              {'id': 'u3', 'username': 'teachx', 'role': 'teacher'},
            ],
        'GET /api/projects/p1/assignment': (_) => assigned
            ? {
                'assignment': aJson(due: due, max: patches < 2 ? 5 : 0),
                'submissions': subs
              }
            : http.Response('{"error":"no"}', 404),
        'POST /api/projects/p1/assign': (_) {
          assigned = true;
          return {'assignment': {}, 'copies': [], 'failed': []};
        },
        'PATCH /api/assignments/a1': (_) {
          if (patchFails) {
            patchFails = false;
            return http.Response('{"error":"nope"}', 500);
          }
          subs = ++patches == 1 ? [] : allSubs;
          return aJson(due: due);
        },
        'DELETE /api/assignments/a1': (_) {
          if (unassignFails) {
            unassignFails = false;
            return http.Response('{"error":"nope"}', 500);
          }
          return {'ok': true};
        },
      });
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Assign'));
      await settle(t);
      expect(find.text('Kid (kid)'), findsOneWidget);
      expect(find.text('teachx'), findsNothing);
      await t.tap(find.text('Kid (kid)'));
      await settle(t);
      await t.tap(find.text('Kid (kid)'));
      await settle(t);
      await t.tap(find.text('Kid (kid)'));
      await settle(t);
      await t.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Assign')));
      await settle(t);
      expect(find.text('Submissions'), findsOneWidget);
      expect(find.textContaining('Kid'), findsWidgets);
      expect(find.text('late'), findsOneWidget);
      expect(find.text('Reviewed'), findsOneWidget);
      expect(find.text('3 of 5 attempts'), findsOneWidget);
      expect(find.textContaining('Due date'), findsOneWidget);
      await t.tap(find.byType(SwitchListTile).at(0));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.byType(SwitchListTile).at(0));
      await settle(t);
      await t.tap(find.byType(SwitchListTile).at(2));
      await settle(t);
      expect(find.text('No student copies yet'), findsNothing);
      await t.enterText(find.byType(TextField).last, '5');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      await t.tap(find.byIcon(Icons.event_outlined));
      await settle(t);
      await t.tap(find.text('OK').last);
      await settle(t);
      await t.tap(find.byIcon(Icons.clear));
      await settle(t);
      await t.ensureVisible(find.text('Remove assignment'));
      await settle(t);
      await t.tap(find.text('Remove assignment'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(AlertDialog), findsWidgets);
      await t.ensureVisible(find.text('Remove assignment'));
      await settle(t);
      await t.tap(find.text('Remove assignment'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('assign form picks due date and reports errors', (t) async {
      installApi(extra: {
        'GET /api/share-targets': (_) => [
              {'id': 'u2', 'username': 'kid', 'role': 'student'},
            ],
        'POST /api/projects/p1/assign': (_) =>
            http.Response('{"error":"nope"}', 500),
        'GET /api/projects/p1/assignment': (_) =>
            http.Response('{"error":"no"}', 404),
      });
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(PopupMenuButton<String>)));
      await settle(t);
      await t.tap(find.text('Assign'));
      await settle(t);
      expect(find.text('kid'), findsOneWidget);
      await t.tap(find.text('kid'));
      await settle(t);
      await t.ensureVisible(find.byIcon(Icons.event_outlined));
      await settle(t);
      await t.tap(find.byIcon(Icons.event_outlined));
      await settle(t);
      await t.tap(find.text('OK').last);
      await settle(t);
      expect(find.textContaining('Due date'), findsOneWidget);
      await t.ensureVisible(find.byIcon(Icons.clear));
      await settle(t);
      await t.tap(find.byIcon(Icons.clear));
      await settle(t);
      await t.ensureVisible(find.byType(SwitchListTile).at(1));
      await settle(t);
      await t.tap(find.byType(SwitchListTile).at(1));
      await settle(t);
      await t.tap(find.byType(SwitchListTile).at(2));
      await settle(t);
      await t.ensureVisible(find.byType(TextField).last);
      await settle(t);
      await t.enterText(find.byType(TextField).last, '3');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await settle(t);
      await t.tap(find.descendant(
          of: find.byType(AlertDialog), matching: find.text('Assign')));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('card menu opens assign dialog and empty targets', (t) async {
      installApi(extra: {
        'GET /api/share-targets': (_) => http.Response('{"error":"nope"}', 500),
      });
      await pump(t, const ProjectsPage());
      await t.tap(find.byType(PopupMenuButton<String>).first);
      await settle(t);
      await t.tap(find.text('Assign'));
      await settle(t);
      expect(find.text('No students to assign'), findsOneWidget);
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.text('Cancel'));
      await settle(t);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('assignment copy shows chips and locks submit', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/assignment': (_) => {
              'assignment': aJson(locked: true, due: 1),
              'copy': {
                'projectId': 'p1',
                'assignmentId': 'a1',
                'studentId': 'u1',
                'submissions': 0
              }
            },
      });
      await pump(t, ProjectPage(project: p1));
      expect(find.text('Assignment'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      final send = t.widget<IconButton>(find.descendant(
          of: find.byType(AppBar),
          matching: find.widgetWithIcon(IconButton, Icons.send_outlined)));
      expect(send.onPressed, isNull);
    });

    testWidgets('assignment copy gates withdraw and the attempts cap',
        (t) async {
      installApi(extra: {
        'GET /api/projects/p1/assignment': (_) => {
              'assignment': aJson(withdraw: false, max: 1),
              'copy': {
                'projectId': 'p1',
                'assignmentId': 'a1',
                'studentId': 'u1',
                'submissions': 1
              }
            },
      });
      final submitted = Project.fromJson(
          {'id': 'p1', 'name': 'x', 'displayName': 'X', 'status': 'submitted'});
      await pump(t, ProjectPage(project: submitted));
      final undo = t.widget<IconButton>(find.descendant(
          of: find.byType(AppBar),
          matching: find.widgetWithIcon(IconButton, Icons.undo_outlined)));
      expect(undo.onPressed, isNull);
      await pump(t, ProjectPage(project: p1));
      final send = t.widget<IconButton>(find.descendant(
          of: find.byType(AppBar),
          matching: find.widgetWithIcon(IconButton, Icons.send_outlined)));
      expect(send.onPressed, isNull);
    });
  });
}
