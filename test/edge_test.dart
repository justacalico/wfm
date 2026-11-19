import 'dart:async';
import 'dart:convert';
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
    openEditorForTesting = null;
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
      openExternalForTesting = (_) => throw 'no browser';
      await pump(t, FilesTab(project: p1));
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Download'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
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
      expect(find.byType(Notice), findsOneWidget);
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
      expect(find.byType(Notice), findsWidgets);
      await t.tap(find.byType(PopupMenuButton<String>).last);
      await settle(t);
      await t.tap(find.text('Delete'));
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
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
      expect(find.byType(Notice), findsOneWidget);
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
      expect(find.byType(Notice), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('FAB opens dialog and queues render', (t) async {
      var renderPosts = 0;
      openEditorForTesting = (_) {};
      installApi(extra: {
        'GET /api/projects/p1/renders': (_) => [
              {'id': 'r1', 'status': 'done', 'outputName': 'x'},
            ],
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [
                {'id': 21, 'name': 'Main Edit'}
              ],
              'activeSequence': 21,
              'serverRender': true,
              'project': true,
            },
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
      await t.tap(find.text('Render'));
      await settle(t);
      expect(renderPosts, 1);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('download opens the produced export', (t) async {
      String? url;
      openExternalForTesting = (u) => url = u;
      installApi(extra: {
        'GET /api/projects/p1/renders': (_) => [
              {'id': 'r1', 'status': 'done', 'outputName': 'final'},
            ],
        'GET /api/projects/p1/files': (_) => [
              {
                'name': 'final.mp4',
                'path': 'Exports/final.mp4',
                'type': 'file'
              },
              {
                'name': 'other.txt',
                'path': 'Exports/other.txt',
                'type': 'file'
              },
            ],
      });
      await pump(t, RendersTab(project: p1));
      await t.tap(find.byIcon(Icons.download));
      await settle(t);
      expect(url, contains('Exports%2Ffinal.mp4'));
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

    testWidgets('files tab keeps its folder across tab switches', (t) async {
      final asked = <String>[];
      installApi(extra: {
        'GET /api/projects/p1/files': (req) {
          asked.add(req.url.queryParameters['path'] ?? '');
          return asked.last == ''
              ? [
                  {'name': 'Images', 'path': 'Images', 'type': 'dir'}
                ]
              : [];
        },
      });
      await pump(t, ProjectPage(project: p1));
      await t.tap(find.text('Images'));
      await settle(t);
      expect(find.text('Empty folder'), findsOneWidget);
      await t.tap(find.text('Renders'));
      await settle(t);
      await t.tap(find.text('Files'));
      await settle(t);
      expect(asked.last, 'Images');
      expect(find.text('Images'), findsOneWidget);
    });

    testWidgets('files tab follows a host-driven path change', (t) async {
      final asked = <String>[];
      installApi(extra: {
        'GET /api/projects/p1/files': (req) {
          asked.add(req.url.queryParameters['path'] ?? '');
          return [];
        },
      });
      await pump(t, FilesTab(project: p1, path: 'Images', onPath: (_) {}));
      expect(asked.last, 'Images');
      await pump(t, FilesTab(project: p1, path: '', onPath: (_) {}));
      expect(asked.last, '');
    });
  });

  group('RenderDialog leftovers', () {
    const infoJson = {
      'sequences': [
        {'id': 21, 'name': 'Main Edit'},
        {'id': 27, 'name': 'Rough Cut'},
      ],
      'activeSequence': 21,
      'serverRender': true,
      'project': true,
    };

    Future<void> openDialog(WidgetTester t,
        {Map<String, dynamic> extra = const {}}) async {
      installApi(extra: {
        'GET /api/projects/p1/render-info': (_) => infoJson,
        ...extra,
      });
      await t.binding.setSurfaceSize(const Size(1400, 900));
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
      expect(find.byType(RenderDialog), findsOneWidget);
    }

    Finder drop(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is DropdownButtonFormField));

    Future<void> choose(WidgetTester t, String label, String option) async {
      final f = drop(label).first;
      await t.ensureVisible(f);
      await t.tap(f);
      await settle(t);
      await t.tap(find.text(option).last);
      await settle(t);
    }

    Future<void> enter(WidgetTester t, String label, String v) async {
      final f = find.widgetWithText(TextField, label);
      await t.ensureVisible(f);
      await t.enterText(f, v);
    }

    Map<String, dynamic> posted() =>
        jsonDecode((lastRequest!.body)) as Map<String, dynamic>;

    testWidgets('posts match-source defaults for the active sequence',
        (t) async {
      openEditorForTesting = (_) {};
      await openDialog(t);
      await t.tap(find.text('Render'));
      await settle(t);
      final body = posted();
      expect(body['mode'], 'device');
      expect(body['sequence'], 21);
      expect(body['output'], 'export');
      final p = body['params'] as Map<String, dynamic>;
      expect(p['format'], 'h264');
      expect(p.containsKey('width'), isFalse);
      expect(p.containsKey('height'), isFalse);
      expect(p.containsKey('fps'), isFalse);
    });

    testWidgets('sequence dropdown selects another sequence', (t) async {
      openEditorForTesting = (_) {};
      await openDialog(t);
      await choose(t, 'Sequence', 'Rough Cut');
      await t.tap(find.text('Render'));
      await settle(t);
      expect(posted()['sequence'], 27);
    });

    testWidgets('device mode opens the render page', (t) async {
      String? url;
      openEditorForTesting = (u) => url = u;
      await openDialog(t, extra: {
        'POST /api/projects/p1/renders': (_) =>
            {'id': 'r9', 'status': 'running'},
      });
      await choose(t, 'Render on', 'This device');
      await t.tap(find.text('Render'));
      await settle(t);
      expect(posted()['mode'], 'device');
      expect(url, '/filmcraft/wfm.html?project=p1&render=r9');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('server option hidden without render capacity', (t) async {
      openEditorForTesting = (_) {};
      await openDialog(t, extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [
                {'id': 21, 'name': 'Main Edit'}
              ],
              'activeSequence': 21,
              'serverRender': false,
              'project': true,
            },
      });
      await t.tap(find.text('Render'));
      await settle(t);
      expect(posted()['mode'], 'device');
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('missing project shows the FilmCraft hint', (t) async {
      await openDialog(t, extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [],
              'serverRender': false,
              'project': false,
            },
      });
      expect(find.textContaining('FilmCraft'), findsWidgets);
      expect(t.widget<FilledButton>(find.byType(FilledButton).last).enabled,
          isFalse);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('no sequences disables render', (t) async {
      await openDialog(t, extra: {
        'GET /api/projects/p1/render-info': (_) => {
              'sequences': [],
              'serverRender': true,
              'project': true,
            },
      });
      expect(find.textContaining('no sequences'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('render-info failure shows the error', (t) async {
      await openDialog(t, extra: {
        'GET /api/projects/p1/render-info': (_) =>
            http.Response('{"error":"inspect broke"}', 502),
      });
      expect(find.textContaining('inspect broke'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('custom range needs both times', (t) async {
      await openDialog(t);
      await choose(t, 'Range', 'Custom');
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('all options map into params', (t) async {
      openEditorForTesting = (_) {};
      await openDialog(t);
      await choose(t, 'Format', 'ProRes');
      await choose(t, 'Range', 'Custom');
      await enter(t, 'Start (seconds)', '1');
      await enter(t, 'End (seconds)', '2');
      await choose(t, 'Resolution', '720p');
      await t.ensureVisible(find.text('Audio'));
      await t.tap(find.text('Audio'));
      await t.pump();
      await enter(t, 'Preset (optional)', 'my-preset');
      await t.ensureVisible(find.text('Advanced options'));
      await t.tap(find.text('Advanced options'));
      await settle(t);
      await enter(t, 'Quality (0-100)', '80');
      await enter(t, 'Bitrate (kbps)', '5000');
      await enter(t, 'CRF', '20');
      await choose(t, 'Bitrate mode', 'CRF');
      await choose(t, 'Audio codec', 'FLAC');
      await enter(t, 'FLAC level', '8');
      await choose(t, 'Hardware encoding', 'Off');
      await enter(t, 'Scale', '0.5');
      await enter(t, 'Loudness (LUFS)', '-14');
      await choose(t, 'H.264 profile', 'High');
      await choose(t, 'ProRes profile', 'HQ');
      await choose(t, 'DNx profile', 'SQ');
      await choose(t, 'APV profile', '444-10');
      await choose(t, 'MXF video codec', 'ProRes');
      await choose(t, 'EXR compression', 'ZIP');
      await choose(t, 'Caption sidecar', 'SRT');
      for (final chip in [
        'H.264 intra-only',
        'Burn captions',
        'Alpha channel'
      ]) {
        await t.ensureVisible(find.text(chip));
        await t.tap(find.text(chip));
        await t.pump();
      }
      await enter(t, 'Extra export params (JSON)', '{"fps": 60}');
      await t.tap(find.text('Render'));
      await settle(t);
      final p = posted()['params'] as Map<String, dynamic>;
      expect(p['format'], 'prores');
      expect(p['range'], 'custom');
      expect(p['startSeconds'], 1.0);
      expect(p['endSeconds'], 2.0);
      expect(p['width'], 1280);
      expect(p['height'], 720);
      expect(p['audio'], false);
      expect(p['preset'], 'my-preset');
      expect(p['quality'], 80);
      expect(p['bitrateKbps'], 5000);
      expect(p['crf'], 20);
      expect(p['bitrateMode'], 'crf');
      expect(p['audioCodec'], 'flac');
      expect(p['flacLevel'], 8);
      expect(p['hardwareEncoding'], 'off');
      expect(p['scale'], 0.5);
      expect(p['loudnessLufs'], -14.0);
      expect(p['h264Profile'], 'high');
      expect(p['proresProfile'], 'hq');
      expect(p['dnxProfile'], 'sq');
      expect(p['apvProfile'], '444-10');
      expect(p['mxfVideoCodec'], 'proRes');
      expect(p['exrCompression'], 'zip');
      expect(p['captionSidecar'], 'srt');
      expect(p['h264IntraOnly'], true);
      expect(p['burnCaptions'], true);
      expect(p['alpha'], true);
      expect(p['fps'], 60);
    });

    testWidgets('invalid extra json shows a snack', (t) async {
      await openDialog(t);
      await t.ensureVisible(find.text('Advanced options'));
      await t.tap(find.text('Advanced options'));
      await settle(t);
      await enter(t, 'Extra export params (JSON)', '[1,2]');
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('malformed extra json shows a snack', (t) async {
      await openDialog(t);
      await t.ensureVisible(find.text('Advanced options'));
      await t.tap(find.text('Advanced options'));
      await settle(t);
      await enter(t, 'Extra export params (JSON)', '{oops');
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('submit failure shows a snack', (t) async {
      await openDialog(t, extra: {
        'POST /api/projects/p1/renders': (_) =>
            http.Response('{"error":"queue full"}', 409),
      });
      await t.tap(find.text('Render'));
      await settle(t);
      expect(find.byType(Notice), findsOneWidget);
      await t.pumpWidget(const SizedBox());
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
      expect(find.byType(Notice), findsOneWidget);
      await t.tap(find.byIcon(Icons.delete_outline).first);
      await settle(t);
      await t.tap(find.text('Confirm'));
      await settle(t);
      expect(find.byType(Notice), findsWidgets);
    });
  });
}
