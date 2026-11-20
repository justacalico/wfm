import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/api.dart';
import 'package:wfm/craft/runner.dart';
import 'package:wfm/craft/sync.dart';
import 'package:wfm/main.dart' show Notice;
import 'package:wfm/platform_io.dart';

import 'helpers.dart';

class FakeRunner implements CraftRunner {
  @override
  final runs = <String, CraftRun>{};
  bool opened = false, conflict = false, pullMedia = false;
  Object? error;

  @override
  Future<CraftRun> open(
      String craft, String projectId, Directory dir, String exe,
      {required Future<bool> Function(String detail) takeOver,
      required LockLost lockLost,
      SyncStatus? status,
      bool pullMedia = true}) async {
    this.pullMedia = pullMedia;
    status?.call('pull', 0, 1);
    if (error != null) throw error!;
    if (conflict && !await takeOver('held')) {
      throw CraftOpenException('declined');
    }
    opened = true;
    final r = FakeRun(craft, projectId);
    runs['$craft:$projectId'] = r;
    lockLost(r);
    return r;
  }

  @override
  Future<void> shutdownAll() async {}

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class FakeRun implements CraftRun {
  FakeRun(this.craft, this.projectId);
  @override
  final String craft, projectId;
  @override
  String get runId => 'run-1';
  @override
  String get clientId => '$craft:$runId';
  @override
  String get lockKind => 'edit';
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError('$i');
}

class Remote {
  final files = <String, List<int>>{
    'project.fcproj': utf8.encode('{"doc":1}'),
    'project.wfm.json': utf8.encode('{}'),
    'Script/main.fountain': utf8.encode('INT. A'),
    'Boards/b1/board.zip': utf8.encode('zip'),
    'Raw/clip.mp4': List.filled(64, 7),
  };
  final revs = <String, int>{};

  int revOf(String p) => revs[p] ??= 1;

  Map<String, dynamic Function(http.Request)> routes() => {
        'GET /api/projects/p1/manifest': (_) {
          if (manifestFails) return http.Response('{"error":"down"}', 500);
          return [
            for (final e in files.entries)
              {
                'name': e.key.split('/').last,
                'path': e.key,
                'type': 'file',
                'size': e.value.length,
                'modified': 1,
                'rev': 'r${revOf(e.key)}',
              }
          ];
        },
        'GET /api/projects/p1/download': (req) {
          final p = req.url.queryParameters['path']!;
          final b = files[p];
          if (b == null) return http.Response('{"error":"no"}', 404);
          return http.Response.bytes(b, 200);
        },
        'PUT /api/projects/p1/files': (req) {
          if (putFails) return http.Response('{"error":"down"}', 500);
          final p = req.url.queryParameters['path']!;
          final base = req.url.queryParameters['base'] ?? '';
          final cur = revs[p];
          if (base == 'none' && cur != null) {
            return http.Response('{"error":"stale"}', 409);
          }
          if (base.isNotEmpty && base != 'none' && base != 'r$cur') {
            return http.Response('{"error":"stale"}', 409);
          }
          if (base.isEmpty && cur != null) {
            return http.Response('{"error":"stale"}', 409);
          }
          files[p] = req.bodyBytes;
          revs[p] = (cur ?? 0) + 1;
          return {'ok': true};
        },
        'DELETE /api/projects/p1/files': (req) {
          if (deleteStatus != 200) {
            return http.Response('{"error":"no"}', deleteStatus);
          }
          files.remove(req.url.queryParameters['path']);
          return {'ok': true};
        },
        'POST /api/projects/p1/locks': (req) {
          final force = jsonDecode(req.body)['force'] == true;
          if (heldLock != null && (!force || forceFails)) {
            return http.Response('{"error":"held by ${heldLock!}"}', 409);
          }
          heldLock = jsonDecode(req.body)['clientId'];
          return {'ok': true};
        },
        'POST /api/projects/p1/locks/heartbeat': (req) {
          if (heartbeatFails) {
            return http.Response('{"error":"down"}', 500);
          }
          return jsonDecode(req.body)['clientId'] == heldLock
              ? {'ok': true}
              : http.Response('{"error":"lock lost"}', 409);
        },
        'DELETE /api/projects/p1/locks': (req) {
          if (releaseFails) return http.Response('{"error":"down"}', 500);
          heldLock = null;
          return {'ok': true};
        },
        'POST /api/projects/p1/files/upload': (_) => {'id': 'u1'},
      };

  String? heldLock;
  bool forceFails = false,
      manifestFails = false,
      putFails = false,
      heartbeatFails = false,
      releaseFails = false;
  int deleteStatus = 200;
}

class FakeProcess implements Process {
  final _exit = Completer<int>();
  bool killed = false;

  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 42;
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    if (!_exit.isCompleted) _exit.complete(0);
    return true;
  }

  void exit([int code = 0]) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

Future<Directory> tempDir() async =>
    Directory.systemTemp.createTemp('wfm-craft-test');

void main() {
  late Directory dir;
  late Remote remote;

  setUp(() async {
    dir = await tempDir();
    remote = Remote();
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  SyncEngine engine(Api api, [String clientId = 'test:run']) =>
      SyncEngine(api, 'p1', clientId, Checkout(dir));

  test('pull materializes the whole tree and writes the manifest', () async {
    final api = Api(FakeClient(remote.routes()));
    final res = await engine(api).pull();
    expect(res.pulled, 5);
    expect(res.conflicts, isEmpty);
    for (final rel in remote.files.keys) {
      expect(File('${dir.path}/$rel').readAsBytesSync(), remote.files[rel]);
    }
    expect(File('${dir.path}/.wfm/manifest.json').existsSync(), isTrue);
    expect(
        utf8.decode(File('${dir.path}/.wfm/manifest.json').readAsBytesSync()),
        contains('project.fcproj'));
  });

  test('eager pull skips media paths', () async {
    final api = Api(FakeClient(remote.routes()));
    final res = await engine(api).pull(eagerOnly: true);
    expect(res.pulled, 4);
    expect(File('${dir.path}/Raw/clip.mp4').existsSync(), isFalse);
    expect(File('${dir.path}/Script/main.fountain').existsSync(), isTrue);
  });

  test('pull only re-downloads files whose server rev changed', () async {
    final api = Api(FakeClient(remote.routes()));
    var res = await engine(api).pull();
    expect(res.pulled, 5);
    res = await engine(api).pull();
    expect(res.pulled, 0);
  });

  test('pull keeps a changed local file as a conflict copy', () async {
    final api = Api(FakeClient(remote.routes()));
    await engine(api).pull();
    remote.files['project.fcproj'] = utf8.encode('{"doc":2}');
    remote.revs['project.fcproj'] = 2;
    File('${dir.path}/project.fcproj').writeAsStringSync('{"doc":"mine"}');
    final res = await engine(api).pull();
    expect(res.conflicts, ['project.fcproj']);
    expect(File('${dir.path}/project.fcproj').readAsStringSync(), '{"doc":2}');
    final conflicts =
        dir.listSync().whereType<File>().map((f) => f.path).toList();
    expect(conflicts.any((p) => p.contains('(conflict ')), isTrue);
  });

  test('pull drops a remotely deleted clean file but keeps a dirty one',
      () async {
    final api = Api(FakeClient(remote.routes()));
    await engine(api).pull();
    remote.files.remove('project.wfm.json');
    remote.revs.remove('project.wfm.json');
    var res = await engine(api).pull();
    expect(File('${dir.path}/project.wfm.json').existsSync(), isFalse);

    remote.files.remove('Script/main.fountain');
    remote.revs.remove('Script/main.fountain');
    File('${dir.path}/Script/main.fountain')
        .writeAsStringSync('edited longer text');
    res = await engine(api).pull();
    expect(res.conflicts, ['Script/main.fountain']);
    expect(File('${dir.path}/Script/main.fountain').existsSync(), isFalse);
    expect(
        dir
            .listSync(recursive: true)
            .whereType<File>()
            .any((f) => f.path.contains('main (conflict ')),
        isTrue);
  });

  test('push uploads new and changed files with base revs', () async {
    final api = Api(FakeClient(remote.routes()));
    await engine(api).pull();
    File('${dir.path}/Raw/new.mp4').writeAsBytesSync([1, 2, 3]);
    File('${dir.path}/project.fcproj').writeAsStringSync('{"doc":9}');
    final res = await engine(api).push();
    expect(res.pushed, 2);
    expect(remote.files['Raw/new.mp4'], [1, 2, 3]);
    expect(utf8.decode(remote.files['project.fcproj']!), '{"doc":9}');
    final res2 = await engine(api).push();
    expect(res2.pushed, 0);
  });

  test('push deletes remote files removed locally', () async {
    final api = Api(FakeClient(remote.routes()));
    await engine(api).pull();
    File('${dir.path}/Raw/clip.mp4').deleteSync();
    await engine(api).push();
    expect(remote.files.containsKey('Raw/clip.mp4'), isFalse);
  });

  test('a stale push keeps the server copy as a conflict and retries',
      () async {
    var stale = true;
    final routes = remote.routes();
    routes['PUT /api/projects/p1/files'] = (req) {
      if (stale) {
        stale = false;
        return http.Response('{"error":"stale","rev":"r2"}', 409);
      }
      final p = req.url.queryParameters['path']!;
      remote.files[p] = req.bodyBytes;
      remote.revs[p] = (remote.revs[p] ?? 0) + 1;
      return {'ok': true};
    };
    remote.files['project.fcproj'] = utf8.encode('theirs');
    remote.revs['project.fcproj'] = 2;
    final api = Api(FakeClient(routes));
    File('${dir.path}/project.fcproj').writeAsStringSync('mine');
    final res = await engine(api).push();
    expect(res.pushed, 1);
    expect(utf8.decode(remote.files['project.fcproj']!), 'mine');
    expect(File('${dir.path}/project.fcproj (conflict ').existsSync(), isFalse);
    expect(
        dir
            .listSync()
            .whereType<File>()
            .any((f) => f.path.contains('(conflict ')),
        isTrue);
  });

  test('checkout helpers', () {
    final c = Checkout(dir);
    expect(Checkout.docPath('project.fcproj'), isTrue);
    expect(Checkout.docPath('Script/a.fountain'), isTrue);
    expect(Checkout.docPath('Boards/x/y'), isTrue);
    expect(Checkout.docPath('Raw/clip.mp4'), isFalse);
    expect(c.conflictPath('Raw/clip.mp4', 5), 'Raw/clip (conflict 5).mp4');
    expect(c.conflictPath('README', 5), 'README (conflict 5)');
  });

  test('newRunId and craft path helpers', () {
    expect(newRunId().length, 32);
    expect(CraftRunner.lockKindOf('scriptcraft'), 'script');
    expect(CraftRunner.lockKindOf('deckcraft'), 'deck');
    expect(CraftRunner.lockKindOf('filmcraft'), 'edit');
    expect(craftExeName('filmcraft'), contains('wfm-filmcraft'));
    expect(craftBundleDir().path, contains('craft'));
  });

  test('runner acquires the lock, spawns, syncs on exit, releases', () async {
    final api = Api(FakeClient(remote.routes()));
    final spawned = <FakeProcess>[];
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, args, env) async {
      expect(args, [contains('project.fcproj')]);
      expect(env['WFM_PROJECT'], 'p1');
      expect(env['WFM_RUN_ID']!.length, 32);
      final p = FakeProcess();
      spawned.add(p);
      return p;
    });
    final run = await runner.open(
        'filmcraft', 'p1', Directory('${dir.path}/checkout'), exe.path,
        takeOver: (_) async => false, lockLost: (_) {});
    expect(run.clientId, 'filmcraft:${run.runId}');
    expect(remote.heldLock, run.clientId);
    expect(runner.runs.containsKey('filmcraft:p1'), isTrue);
    expect(File('${dir.path}/checkout/project.fcproj').existsSync(), isTrue);

    final raw = Directory('${dir.path}/checkout/Raw')..createSync();
    File('${raw.path}/x.mp4').writeAsBytesSync([9]);
    spawned.first.exit();
    await run.done.future;
    await pumpEventQueue();
    expect(remote.files['Raw/x.mp4'], [9]);
    expect(remote.heldLock, isNull);
    expect(runner.runs, isEmpty);
  });

  test('runner refuses a second open and honors declined takeover', () async {
    final api = Api(FakeClient(remote.routes()));
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async => FakeProcess());
    await runner.open('filmcraft', 'p1', Directory('${dir.path}/c1'), exe.path,
        takeOver: (_) async => true, lockLost: (_) {});
    expect(
        () => runner.open(
            'filmcraft', 'p1', Directory('${dir.path}/c2'), exe.path,
            takeOver: (_) async => true, lockLost: (_) {}),
        throwsA(predicate(
            (e) => e is CraftOpenException && e.kind == 'alreadyOpen')));
    await runner.shutdownAll();

    remote.heldLock = 'browser-session';
    expect(
        () => runner.open(
            'filmcraft', 'p1', Directory('${dir.path}/c3'), exe.path,
            takeOver: (_) async => false, lockLost: (_) {}),
        throwsA(
            predicate((e) => e is CraftOpenException && e.kind == 'declined')));
  });

  test('pullMedia false fetches only the doc tree', () async {
    final api = Api(FakeClient(remote.routes()));
    final spawned = <FakeProcess>[];
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async {
      final p = FakeProcess();
      spawned.add(p);
      return p;
    });
    final checkout = Directory('${dir.path}/c');
    final run = await runner.open('filmcraft', 'p1', checkout, exe.path,
        takeOver: (_) async => true, lockLost: (_) {}, pullMedia: false);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(File('${checkout.path}/project.fcproj').existsSync(), isTrue);
    expect(File('${checkout.path}/Raw/clip.mp4').existsSync(), isFalse);
    spawned.first.exit();
    await run.done.future;
  });

  test('missing binary and lost heartbeat', () async {
    final api = Api(FakeClient(remote.routes()));
    final runner = CraftRunner(api, spawn: (e, a, env) async => FakeProcess());
    expect(
        () => runner.open(
            'filmcraft', 'p1', Directory('${dir.path}/c'), '${dir.path}/nope',
            takeOver: (_) async => true, lockLost: (_) {}),
        throwsA(
            predicate((e) => e is CraftOpenException && e.kind == 'missing')));
  });

  test('timer pushes changes and a stolen lock kills the run', () async {
    final api = Api(FakeClient(remote.routes()));
    final spawned = <FakeProcess>[];
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    var lost = false;
    final runner = CraftRunner(api, spawn: (e, a, env) async {
      final p = FakeProcess();
      spawned.add(p);
      return p;
    },
        pushInterval: const Duration(milliseconds: 40),
        beatInterval: const Duration(milliseconds: 40));
    final checkout = Directory('${dir.path}/c');
    final run = await runner.open('filmcraft', 'p1', checkout, exe.path,
        takeOver: (_) async => true, lockLost: (_) => lost = true);
    File('${checkout.path}/tick.bin').writeAsBytesSync([1]);
    await Future.delayed(const Duration(milliseconds: 150));
    expect(remote.files['tick.bin'], [1]);

    remote.heldLock = 'someone-else';
    await Future.delayed(const Duration(milliseconds: 150));
    expect(lost, isTrue);
    expect(spawned.first.killed, isTrue);
    await run.done.future;
    expect(runner.runs, isEmpty);
  });

  test('forced takeover that still loses gives locked', () async {
    remote.heldLock = 'browser';
    remote.forceFails = true;
    final api = Api(FakeClient(remote.routes()));
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async => FakeProcess());
    expect(
        () => runner.open(
            'filmcraft', 'p1', Directory('${dir.path}/c'), exe.path,
            takeOver: (_) async => true, lockLost: (_) {}),
        throwsA(
            predicate((e) => e is CraftOpenException && e.kind == 'locked')));
  });

  test('a failing pull releases the lock', () async {
    remote.manifestFails = true;
    final api = Api(FakeClient(remote.routes()));
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async => FakeProcess());
    await expectLater(
        runner.open('filmcraft', 'p1', Directory('${dir.path}/c'), exe.path,
            takeOver: (_) async => true, lockLost: (_) {}),
        throwsA(isA<ApiException>()));
    expect(remote.heldLock, isNull);
  });

  test('tick, heartbeat and exit failures land on lastError', () async {
    final api = Api(FakeClient(remote.routes()));
    final spawned = <FakeProcess>[];
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async {
      final p = FakeProcess();
      spawned.add(p);
      return p;
    },
        pushInterval: const Duration(milliseconds: 40),
        beatInterval: const Duration(milliseconds: 40));
    final checkout = Directory('${dir.path}/c');
    final run = await runner.open('filmcraft', 'p1', checkout, exe.path,
        takeOver: (_) async => true, lockLost: (_) {});

    remote.putFails = true;
    File('${checkout.path}/changed.bin').writeAsBytesSync([1]);
    await Future.delayed(const Duration(milliseconds: 150));
    expect(run.lastError, isA<ApiException>());

    await checkout.delete(recursive: true);
    await Future.delayed(const Duration(milliseconds: 150));
    expect(run.lastError, isA<FileSystemException>());

    remote.heartbeatFails = true;
    run.lastError = null;
    await Future.delayed(const Duration(milliseconds: 150));
    expect(run.lastError, isNotNull);
    expect(run.lockLost, isFalse);

    remote.heartbeatFails = false;
    remote.releaseFails = true;
    await checkout.create(recursive: true);
    spawned.first.exit();
    await run.done.future;
    expect(run.lastError, isA<ApiException>());
    expect(runner.runs, isEmpty);
    remote.releaseFails = false;
  });

  test('a lazy pull failure lands on lastError', () async {
    var calls = 0;
    final routes = remote.routes();
    routes['GET /api/projects/p1/manifest'] = (req) {
      calls++;
      if (calls > 1) return http.Response('{"error":"down"}', 500);
      return remote.routes()['GET /api/projects/p1/manifest']!(req);
    };
    final api = Api(FakeClient(routes));
    final spawned = <FakeProcess>[];
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async {
      final p = FakeProcess();
      spawned.add(p);
      return p;
    });
    final run = await runner.open(
        'filmcraft', 'p1', Directory('${dir.path}/c'), exe.path,
        takeOver: (_) async => true, lockLost: (_) {});
    for (var i = 0; i < 100 && run.lastError == null; i++) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    expect(run.lastError, isA<ApiException>());
    spawned.first.exit();
    await run.done.future;
    expect(runner.runs, isEmpty);
  });

  test('exit sync failures still release and finish', () async {
    final api = Api(FakeClient(remote.routes()));
    final spawned = <FakeProcess>[];
    final exe = File('${dir.path}/wfm-filmcraft')..writeAsBytesSync([0]);
    final runner = CraftRunner(api, spawn: (e, a, env) async {
      final p = FakeProcess();
      spawned.add(p);
      return p;
    });
    final checkout = Directory('${dir.path}/c');
    var run = await runner.open('filmcraft', 'p1', checkout, exe.path,
        takeOver: (_) async => true, lockLost: (_) {});
    remote.putFails = true;
    File('${checkout.path}/changed.bin').writeAsBytesSync([1]);
    spawned.first.exit();
    await run.done.future;
    expect(run.lastError, isA<ApiException>());
    remote.putFails = false;

    run = await runner.open('filmcraft', 'p1', checkout, exe.path,
        takeOver: (_) async => true, lockLost: (_) {});
    await Directory('${checkout.path}/.wfm').delete(recursive: true);
    File('${checkout.path}/.wfm').writeAsBytesSync([0]);
    spawned.last.exit();
    await run.done.future;
    expect(run.lastError, isA<FileSystemException>());
    expect(runner.runs, isEmpty);
  });

  test('push conflict aborts when the remote state cannot be read', () async {
    remote.files['project.fcproj'] = utf8.encode('theirs');
    remote.revs['project.fcproj'] = 2;
    File('${dir.path}/project.fcproj').writeAsStringSync('mine');

    var calls = 0;
    final routes = remote.routes();
    routes['PUT /api/projects/p1/files'] = (_) {
      calls++;
      return http.Response('{"error":"stale"}', 409);
    };
    routes['GET /api/projects/p1/manifest'] = (_) {
      if (calls > 0) return http.Response('{"error":"down"}', 500);
      return [
        for (final e in remote.files.entries)
          {
            'name': e.key,
            'path': e.key,
            'type': 'file',
            'size': e.value.length,
            'modified': 1,
            'rev': 'r1',
          }
      ];
    };
    final api = Api(FakeClient(routes));
    await expectLater(engine(api).push(),
        throwsA(predicate((e) => e is ApiException && e.status == 409)));
  });

  test('push conflict aborts when the file vanished remotely', () async {
    final routes = remote.routes();
    routes['PUT /api/projects/p1/files'] =
        (_) => http.Response('{"error":"stale"}', 409);
    routes['GET /api/projects/p1/manifest'] = (_) => [];
    File('${dir.path}/orphan.txt').writeAsStringSync('mine');
    final api = Api(FakeClient(routes));
    await expectLater(engine(api).push(),
        throwsA(predicate((e) => e is ApiException && e.status == 409)));
  });

  test('sweep drops entries gone on both sides and tolerates delete races',
      () async {
    final api = Api(FakeClient(remote.routes()));
    await engine(api).pull();
    remote.files.remove('Raw/clip.mp4');
    remote.revs.remove('Raw/clip.mp4');
    File('${dir.path}/Raw/clip.mp4').deleteSync();
    await engine(api).push();

    remote.deleteStatus = 409;
    remote.files['Audio/gone.mp3'] = utf8.encode('x');
    remote.revs['Audio/gone.mp3'] = 3;
    await engine(api).pull();
    File('${dir.path}/Audio/gone.mp3').deleteSync();
    await engine(api).push();
    remote.deleteStatus = 200;

    remote.deleteStatus = 500;
    File('${dir.path}/Script/main.fountain').deleteSync();
    await expectLater(engine(api).push(), throwsA(isA<ApiException>()));
    remote.deleteStatus = 200;
  });

  test('downloadInto surfaces auth and server errors', () async {
    final c = StreamController<List<int>>();
    final api401 = Api(FakeClient({
      'GET /api/projects/p1/download': (_) => http.Response('{}', 401),
    }))
      ..user = User.fromJson(userJson);
    var signedOut = false;
    api401.onSignedOut = () => signedOut = true;
    await expectLater(api401.downloadInto('p1', 'x', c.sink),
        throwsA(predicate((e) => e is ApiException && e.status == 401)));
    expect(signedOut, isTrue);

    final api500 = Api(FakeClient({
      'GET /api/projects/p1/download': (_) => http.Response('{}', 500),
    }));
    await expectLater(api500.downloadInto('p1', 'x', c.sink),
        throwsA(predicate((e) => e is ApiException && e.status == 500)));
  });

  test('platform craft helpers', () async {
    expect(defaultCheckoutRoot(), contains('WFM'));
    envForTesting = {'USERPROFILE': r'C:\win'};
    expect(defaultCheckoutRoot(), contains('win'));
    envForTesting = {};
    expect(defaultCheckoutRoot(), contains('WFM'));
    envForTesting = null;
    expect(craftExeName('filmcraft'), contains('wfm-filmcraft'));
    pickDirectoryForTesting = () async => '/tmp/picked';
    expect(await pickDirectory(), '/tmp/picked');
    pickDirectoryForTesting = null;
    final run = FakeRun('filmcraft', 'p1');
    await writeRunFile(dir, run);
    expect(File('${dir.path}/.wfm/run.json').existsSync(), isTrue);
  });

  testWidgets('native open flows through the sync dialog', (t) async {
    SharedPreferences.setMockInitialValues(
        {'craftMode': 'native', 'craftDir': dir.path});
    final api = installApi(extra: remote.routes());
    final runner = FakeRunner();
    runnerForTesting = runner;
    craftExeForTesting = (_) => 'fake-exe';
    var runFileWritten = false;
    writeRunFileForTesting = (_, __) async => runFileWritten = true;

    await t.pumpWidget(testApp(Builder(
        builder: (c) => TextButton(
            onPressed: () => openEditor(c, api, api.projectUrl('p1'),
                projectName: 'My Film'),
            child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t);
    expect(runner.opened, isTrue);
    expect(runner.pullMedia, isTrue);
    expect(runFileWritten, isTrue);
    await shutdownCrafts();
    runnerForTesting = null;
    craftExeForTesting = null;
    writeRunFileForTesting = null;
  });

  testWidgets('server import policy skips the media pull', (t) async {
    SharedPreferences.setMockInitialValues({
      'craftMode': 'native',
      'craftDir': dir.path,
      'importPolicy': 'server'
    });
    final api = installApi(extra: remote.routes());
    final runner = FakeRunner();
    runnerForTesting = runner;
    craftExeForTesting = (_) => 'fake-exe';
    writeRunFileForTesting = (_, __) async {};

    await t.pumpWidget(testApp(Builder(
        builder: (c) => TextButton(
            onPressed: () => openEditor(c, api, api.projectUrl('p1')),
            child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t);
    expect(runner.opened, isTrue);
    expect(runner.pullMedia, isFalse);
    await shutdownCrafts();
    runnerForTesting = null;
    craftExeForTesting = null;
    writeRunFileForTesting = null;
  });

  testWidgets('native open offers takeover on a held lock', (t) async {
    SharedPreferences.setMockInitialValues(
        {'craftMode': 'native', 'craftDir': dir.path});
    final api = installApi(extra: remote.routes());
    final runner = FakeRunner()..conflict = true;
    runnerForTesting = runner;
    craftExeForTesting = (_) => 'fake-exe';
    writeRunFileForTesting = (_, __) async {};

    await t.pumpWidget(testApp(Builder(
        builder: (c) => TextButton(
            onPressed: () => openEditor(c, api, api.projectUrl('p1')),
            child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Take ownership'));
    await settle(t);
    expect(runner.opened, isTrue);
    runnerForTesting = null;
    craftExeForTesting = null;
    writeRunFileForTesting = null;
  });

  testWidgets('missing binary shows a snack', (t) async {
    SharedPreferences.setMockInitialValues(
        {'craftMode': 'native', 'craftDir': dir.path});
    final api = installApi(extra: remote.routes());
    runnerForTesting = FakeRunner()..error = CraftOpenException('missing');
    writeRunFileForTesting = (_, __) async {};

    await t.pumpWidget(testApp(Builder(
        builder: (c) => TextButton(
            onPressed: () => openEditor(c, api, api.scriptUrl('p1')),
            child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t);
    expect(find.byType(Notice), findsOneWidget);
    expect(find.textContaining('scriptcraft'), findsWidgets);
    runnerForTesting = null;
    writeRunFileForTesting = null;
  });

  testWidgets('declined takeover, duplicate open and failures snack',
      (t) async {
    SharedPreferences.setMockInitialValues(
        {'craftMode': 'native', 'craftDir': dir.path});
    final api = installApi(extra: remote.routes());
    final runner = FakeRunner()..conflict = true;
    runnerForTesting = runner;
    craftExeForTesting = (_) => 'fake-exe';
    writeRunFileForTesting = (_, __) async {};

    await t.pumpWidget(testApp(Builder(
        builder: (c) => TextButton(
            onPressed: () => openEditor(c, api, api.projectUrl('p1')),
            child: const Text('open')))));
    await t.tap(find.text('open'));
    await settle(t);
    await t.tap(find.text('Cancel'));
    await settle(t);
    expect(runner.opened, isFalse);
    expect(find.byType(Notice), findsWidgets);

    runner.conflict = false;
    runner.error = CraftOpenException('alreadyOpen');
    await t.tap(find.text('open'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);

    runner.error = Exception('boom');
    await t.tap(find.text('open'));
    await settle(t);
    expect(find.byType(Notice), findsWidgets);
    runnerForTesting = null;
    craftExeForTesting = null;
    writeRunFileForTesting = null;
  });
}
