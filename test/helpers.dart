import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wfm/api.dart';
import 'package:wfm/l10n/app_localizations.dart';
import 'package:wfm/main.dart';

class FakeClient extends MockClient {
  FakeClient(Map<String, dynamic Function(http.Request)> routes)
      : super((req) async {
          final key = '${req.method} ${req.url.path}';
          final f = routes[key] ?? routes['${req.method} *'];
          if (f == null)
            return http.Response(jsonEncode({'error': 'no route $key'}), 404);
          final v = await f(req);
          if (v is http.Response) return v;
          return http.Response(jsonEncode(v), 200);
        });
}

http.Request? lastRequest;

Map<String, dynamic Function(http.Request)> apiRoutes(
    Map<String, dynamic> canned) {
  return {
    for (final e in canned.entries)
      '${e.key.split(' ').first} ${e.key.split(' ').last}': (req) {
        lastRequest = req;
        final v = canned[e.key];
        if (v is int) return http.Response('{"error":"forced"}', v);
        return v;
      },
  };
}

const userJson = {
  'id': 'u1',
  'username': 'ada',
  'displayName': 'Ada Lovelace',
  'role': 'owner',
  'studentId': 'S42',
  'note': '',
  'disabled': false,
  'createdAt': 1700000000,
  'lastLogin': 1700000100,
};

FakeClient sessionClient({Map<String, dynamic> extra = const {}}) =>
    FakeClient({
      'GET /api/setup': (_) => {'needsSetup': false},
      'GET /api/me': (_) => {'csrf': 'tok', 'user': userJson},
      'GET /api/roles': (_) => {
            'creatable': ['student', 'mod', 'teacher'],
            'canManage': true,
            'canAudit': true
          },
      'GET /api/version': (_) => {'version': '1.2.3'},
      'GET /api/settings': (_) => {'trustedProxies': '10.0.0.0/8, 172.16.0.1'},
      'PUT /api/settings': (_) => {'ok': true},
      'GET /api/projects': (_) => [
            {
              'id': 'p1',
              'name': 'short-film',
              'displayName': 'Short Film',
              'createdAt': 1700000000
            },
          ],
      'GET /api/groups': (_) => [],
      'GET /api/projects/p1/files': (_) => [
            {'name': 'Raw', 'path': 'Raw', 'type': 'dir'},
            {
              'name': 'clip.mp4',
              'path': 'clip.mp4',
              'type': 'file',
              'size': 2048,
              'modified': 1700000000
            },
            {
              'name': 'song.mp3',
              'path': 'song.mp3',
              'type': 'file',
              'size': 512,
              'modified': 0
            },
            {
              'name': 'poster.png',
              'path': 'poster.png',
              'type': 'file',
              'size': 99,
              'modified': 1
            },
            {
              'name': 'notes.txt',
              'path': 'notes.txt',
              'type': 'file',
              'size': 10,
              'modified': 0
            },
          ],
      'GET /api/projects/p1/renders': (_) => [
            {
              'id': 'r1',
              'status': 'done',
              'outputName': 'final',
              'worker': 'local',
              'createdAt': 1700000000,
              'finishedAt': 1700000060
            },
            {
              'id': 'r2',
              'status': 'running',
              'outputName': 'scene2.mp4',
              'progress': 0.5,
              'worker': '',
              'createdAt': 1700000000
            },
            {
              'id': 'r3',
              'status': 'failed',
              'outputName': 'bad',
              'error': 'ffmpeg exploded',
              'worker': 'n1',
              'createdAt': 0
            },
            {
              'id': 'r4',
              'status': 'canceled',
              'outputName': 'nope',
              'worker': '',
              'createdAt': 0
            },
            {
              'id': 'r5',
              'status': 'queued',
              'outputName': 'wait',
              'worker': '',
              'createdAt': 0
            },
          ],
      'GET /api/accounts': (_) => [
            userJson,
            {'id': 'u2', 'username': 'bob', 'role': 'student', 'disabled': true}
          ],
      'GET /api/audit': (_) => [
            {
              'ts': 1700000000,
              'actorName': 'Ada',
              'action': 'login',
              'target': '',
              'detail': 'ok'
            },
            {
              'ts': 0,
              'actorName': 'Bob',
              'action': 'upload',
              'target': 'clip.mp4',
              'detail': ''
            },
          ],
      'GET /api/nodes': (_) => [
            {
              'id': 'n1',
              'name': 'render-box',
              'disabled': false,
              'createdAt': 0,
              'lastSeen': 1700000000
            },
            {
              'id': 'n2',
              'name': 'laptop',
              'disabled': true,
              'createdAt': 0,
              'lastSeen': 9999999999
            },
          ],
      'POST *': (_) => {'ok': true},
      'PATCH *': (_) => {'ok': true},
      'PUT *': (_) => {'ok': true},
      'DELETE *': (_) => {'ok': true},
      ...extra,
    });

Api installApi({Map<String, dynamic> extra = const {}}) {
  final api = Api(sessionClient(extra: extra))
    ..csrf = 'tok'
    ..user = User.fromJson(userJson)
    ..caps = Caps.fromJson({
      'creatable': ['student', 'mod', 'teacher'],
      'canManage': true,
      'canAudit': true
    });
  Api.i = api;
  return api;
}

Future<void> settle(WidgetTester t, [int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Future<void> loadTestFonts() async {
  final reg = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
  final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
  final loader = FontLoader('Noto Sans')
    ..addFont(Future.value(reg.buffer.asByteData()))
    ..addFont(Future.value(bold.buffer.asByteData()));
  await loader.load();
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
        '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final iconLoader = FontLoader('MaterialIcons')
        ..addFont(Future.value(icons.readAsBytesSync().buffer.asByteData()));
      await iconLoader.load();
    }
  }
}

Widget testApp(Widget home,
    {Locale? locale, ThemeMode mode = ThemeMode.light}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: appLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData(fontFamily: 'Noto Sans'),
    themeMode: mode,
    home: home,
  );
}
