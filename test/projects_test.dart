import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/platform.dart';
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
    pickFilesForTesting = null;
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
      openExternalForTesting = (u) => opened = u;
      await t.tap(find.text('Open in Filmcraft'));
      expect(opened, contains('/filmcraft/wfm.html?project=p1'));
      await t.tap(find.text('Short Film'));
      await settle(t);
      expect(find.byType(ProjectPage), findsOneWidget);
    });

    testWidgets('open in filmcraft error shows snack', (t) async {
      installApi();
      await pump(t, const ProjectsPage());
      await t.tap(find.text('Open in Filmcraft'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
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
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('ProjectPage', () {
    testWidgets('open filmcraft, rename, delete', (t) async {
      var opened = '';
      openExternalForTesting = (u) => opened = u;
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
      await t.tap(find.text('Open in Filmcraft'));
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
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.text('Open in Filmcraft'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
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
  });

  group('FilesTab', () {
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

    testWidgets('upload picked files', (t) async {
      var uploads = 0;
      pickFilesForTesting = () async => [
            PickedFile('a.mp4', Uint8List(3)),
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
      expect(find.byType(SnackBar), findsOneWidget);
      pickFilesForTesting = () async => [PickedFile('v.mp4', Uint8List(2))];
      installApi(extra: {
        'PUT /api/projects/p1/files': (_) =>
            http.Response('{"error":"full"}', 507),
      });
      await t.tap(find.text('Upload'));
      await settle(t);
      expect(find.byType(SnackBar), findsWidgets);
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
      expect(fileIcon(FileEntry.fromJson({'name': 'a.wav'})),
          Icons.audio_file_outlined);
      expect(fileIcon(FileEntry.fromJson({'name': 'a.jpg'})),
          Icons.image_outlined);
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
        'POST /api/renders/r2/cancel': (req) {
          canceled++;
          return {'ok': true};
        },
      });
      await pump(t, Scaffold(body: RendersTab(project: p1)));
      expect(find.text('final.mp4'), findsOneWidget);
      expect(find.text('scene2.mp4'), findsOneWidget);
      expect(find.text('ffmpeg exploded'), findsOneWidget);
      expect(find.byIcon(Icons.download), findsOneWidget);
      await t.tap(find.byIcon(Icons.download));
      expect(opened, contains('Exports%2Ffinal.mp4'));
      expect(find.byIcon(Icons.stop), findsNWidgets(2));
      await t.tap(find.byIcon(Icons.stop).first);
      await settle(t);
      expect(canceled, 1);
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
    testWidgets('pick clips, reorder, submit', (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      String? renderBody;
      installApi(extra: {
        'GET /api/projects/p1/files': (req) {
          final path = req.url.queryParameters['path'] ?? '';
          if (path == 'Raw/A-Roll' || path == 'Raw') {
            return [
              {
                'name': 'a.mp4',
                'path': 'Raw/A-Roll/a.mp4',
                'type': 'file',
                'size': 10,
                'modified': 0
              },
              {
                'name': 'b.mp4',
                'path': 'Raw/A-Roll/b.mp4',
                'type': 'file',
                'size': 10,
                'modified': 0
              },
            ];
          }
          return [];
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
      expect(find.byType(FilledButton), findsOneWidget);

      await t.tap(find.byIcon(Icons.add).first);
      await t.pump();
      await t.tap(find.byIcon(Icons.add).first);
      await t.pump();
      expect(find.text('Raw/A-Roll/a.mp4'), findsOneWidget);

      final list = find.byType(ReorderableListView);
      expect(list, findsOneWidget);
      final first = find.text('Raw/A-Roll/a.mp4');
      final g = await t.startGesture(t.getCenter(first));
      await t.pump(const Duration(milliseconds: 600));
      await g.moveBy(const Offset(0, 60));
      await t.pump();
      await g.up();
      await settle(t);

      await t.tap(find.byIcon(Icons.close).first);
      await t.pump();

      await t.tap(find.byType(DropdownButtonFormField<(int, int)>));
      await settle(t);
      await t.tap(find.text('720p').last);
      await settle(t);
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await settle(t);
      await t.tap(find.text('60').last);
      await settle(t);
      await t.enterText(find.byType(TextField).last, '  ');
      await t.tap(find.text('Render'));
      await settle(t);
      expect(renderBody, contains('Raw/A-Roll'));
      expect(renderBody, contains('"fps":60'));
      expect(renderBody, contains('"height":720'));
      await settle(t);
    });

    testWidgets('cancel closes dialog', (t) async {
      installApi();
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
      await t.tap(find.byIcon(Icons.add).first);
      await t.pump();
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(SnackBar), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await settle(t);
    });
  });
}
