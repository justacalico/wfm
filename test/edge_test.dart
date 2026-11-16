import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/main.dart' as app;
import 'package:wfm/manage.dart';
import 'package:wfm/platform.dart';
import 'package:wfm/projects.dart';
import 'package:wfm/main.dart';
import 'helpers.dart';

final p1 = Project.fromJson(
    {'id': 'p1', 'name': 'n', 'displayName': 'P', 'createdAt': 1});

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    openExternalForTesting = null;
    pickFilesForTesting = null;
  });

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(Scaffold(body: w)));
    await settle(t);
  }

  test('main entrypoint exists', () {
    app.main;
  });

  testWidgets('boots via runApp entry', (t) async {
    installApi(extra: {'GET *': (_) => []});
    app.main();
    await settle(t);
    expect(find.byType(WfmApp), findsOneWidget);
  });

  group('FilesTab leftovers', () {
    testWidgets('empty folder state', (t) async {
      installApi(extra: {'GET /api/projects/p1/files': (_) => []});
      await pump(t, FilesTab(project: p1));
      expect(find.text('Empty folder'), findsOneWidget);
    });

    testWidgets('download open error shows snack', (t) async {
      installApi();
      await pump(t, FilesTab(project: p1));
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Download'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('mkdir error shows snack', (t) async {
      installApi(extra: {
        'POST /api/projects/p1/files/mkdir': (_) =>
            http.Response('{"error":"mk fail"}', 500),
      });
      await pump(t, FilesTab(project: p1));
      await t.tap(find.byIcon(Icons.create_new_folder_outlined));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'x');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('rename and delete errors show snacks', (t) async {
      installApi(extra: {
        'POST /api/projects/p1/files/move': (_) =>
            http.Response('{"error":"mv fail"}', 500),
        'DELETE /api/projects/p1/files': (_) =>
            http.Response('{"error":"del fail"}', 500),
      });
      await pump(t, FilesTab(project: p1));
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.enterText(find.byType(TextField).last, 'renamed.txt');
      await t.tap(find.text('OK'));
      await settle(t);
      expect(find.byType(SnackBar), findsWidgets);
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(SnackBar), findsWidgets);
    });

    testWidgets('rename cancelled dialog and unchanged name', (t) async {
      var moved = 0;
      installApi(extra: {
        'POST /api/projects/p1/files/move': (_) {
          moved++;
          return {'ok': true};
        },
      });
      await pump(t, FilesTab(project: p1));
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Rename'));
      await settle(t);
      await t.tap(find.text('OK'));
      await settle(t);
      expect(moved, 0);
    });

    testWidgets('upload spinner shows while uploading', (t) async {
      final done = Completer<http.Response>();
      installApi(extra: {
        'PUT /api/projects/p1/files': (_) async => done.future,
      });
      pickFilesForTesting = () async => [PickedFile('a.bin', Uint8List(4))];
      await pump(t, FilesTab(project: p1));
      await t.tap(find.text('Upload'));
      await t.pump();
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsWidgets);
      done.complete(http.Response('{}', 200));
      await settle(t);
    });
  });

  group('RendersTab leftovers', () {
    testWidgets('timer refresh and cancel error snack', (t) async {
      var loads = 0;
      installApi(extra: {
        'GET /api/projects/p1/renders': (_) {
          loads++;
          return [
            {
              'id': 'r1',
              'status': 'running',
              'outputName': 'x',
              'progress': 0.4
            },
          ];
        },
        'POST /api/renders/r1/cancel': (_) =>
            http.Response('{"error":"cant"}', 409),
      });
      await pump(t, RendersTab(project: p1));
      await t.tap(find.byIcon(Icons.stop));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      final before = loads;
      await t.pump(const Duration(seconds: 6));
      await settle(t, 3);
      expect(loads, greaterThan(before));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('download error snack', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/renders': (_) => [
              {'id': 'r1', 'status': 'done', 'outputName': 'x'},
            ],
      });
      await pump(t, RendersTab(project: p1));
      await t.tap(find.byIcon(Icons.download));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('FAB opens dialog and queues render', (t) async {
      var renderPosts = 0;
      installApi(extra: {
        'GET /api/projects/p1/renders': (_) => [
              {'id': 'r1', 'status': 'done', 'outputName': 'x'},
            ],
        'POST /api/projects/p1/renders': (_) {
          renderPosts++;
          return {'id': 'r9', 'status': 'queued'};
        },
      });
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await pump(t, RendersTab(project: p1));
      await t.tap(find.byType(FloatingActionButton));
      await settle(t);
      expect(find.byType(RenderDialog), findsOneWidget);
      await t.tap(find
          .descendant(
              of: find.byType(AlertDialog), matching: find.byIcon(Icons.add))
          .first);
      await t.pump();
      await t.tap(find.text('Render'));
      await settle(t);
      expect(renderPosts, 1);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('ProjectPage leftovers', () {
    testWidgets('switch to renders tab', (t) async {
      installApi();
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.text('Renders'));
      await settle(t);
      expect(find.byType(RendersTab), findsOneWidget);
      await t.tap(find.text('Files'));
      await settle(t);
      expect(find.byType(FilesTab), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('RenderDialog leftovers', () {
    testWidgets('folder up navigation and load error', (t) async {
      var calls = 0;
      installApi(extra: {
        'GET /api/projects/p1/files': (_) {
          calls++;
          if (calls == 1) {
            return [
              {'name': 'sub', 'path': 'Raw/A-Roll/sub', 'type': 'dir'},
            ];
          }
          return http.Response('{"error":"gone"}', 404);
        },
      });
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(testApp(Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () => showDialog<bool>(
                      context: c, builder: (_) => RenderDialog(project: p1)),
                  child: const Text('open'))))));
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      await t.tap(find.text('sub'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      await t.tap(find.text('..'));
      await settle(t);
      expect(find.text('Cancel'), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });

    testWidgets('reorder moves clips', (t) async {
      installApi(extra: {
        'GET /api/projects/p1/files': (_) => [
              {
                'name': 'a.mp4',
                'path': 'Raw/A-Roll/a.mp4',
                'type': 'file',
                'size': 1,
                'modified': 0
              },
              {
                'name': 'b.mp4',
                'path': 'Raw/A-Roll/b.mp4',
                'type': 'file',
                'size': 1,
                'modified': 0
              },
              {
                'name': 'c.mp4',
                'path': 'Raw/A-Roll/c.mp4',
                'type': 'file',
                'size': 1,
                'modified': 0
              },
            ],
      });
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(testApp(Scaffold(
          body: Builder(
              builder: (c) => TextButton(
                  onPressed: () => showDialog<bool>(
                      context: c, builder: (_) => RenderDialog(project: p1)),
                  child: const Text('open'))))));
      await settle(t);
      await t.tap(find.text('open'));
      await settle(t);
      for (var i = 0; i < 3; i++) {
        await t.tap(find.byIcon(Icons.add).first);
        await t.pump();
      }
      final a = find.text('Raw/A-Roll/a.mp4');
      final c = find.text('Raw/A-Roll/c.mp4');
      expect(a, findsOneWidget);
      final g = await t.startGesture(t.getCenter(c));
      await t.pump(const Duration(milliseconds: 600));
      await g.moveBy(const Offset(0, -80));
      await t.pump(const Duration(milliseconds: 300));
      await g.up();
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await settle(t);
    });
  });

  group('NodesTab error snacks', () {
    testWidgets('disable and delete failures', (t) async {
      installApi(extra: {
        'PATCH *': (_) => http.Response('{"error":"patch fail"}', 500),
        'DELETE *': (_) => http.Response('{"error":"del fail"}', 500),
      });
      await pump(t, const NodesTab());
      await t.tap(find.byIcon(Icons.pause_circle_outline));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(SnackBar), findsWidgets);
    });
  });
}
