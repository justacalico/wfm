import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wfm/api.dart';
import 'package:wfm/craft/runner.dart';
import 'package:wfm/craft/sync.dart';

import 'helpers.dart';

class _Store {
  final files = <String, List<int>>{};
  final revs = <String, int>{};
  var uploads = 0;
  var staleOnce = <String>{};
  var deleteStale = false;
  var locked = false;
  final pending = <String, String>{};
  final chunks = <int>[];

  String? rev(String path) => revs[path] == null ? null : 'r${revs[path]}';

  FakeClient client(String pid) => FakeClient({
        'POST /api/projects/$pid/locks': (_) => locked
            ? http.Response(
                jsonEncode({
                  'acquired': false,
                  'lock': {'holder': 'ada', 'label': 'web', 'expiresAt': 0}
                }),
                409)
            : {'acquired': true, 'lock': {}},
        'POST /api/projects/$pid/locks/heartbeat': (_) =>
            locked ? http.Response('{"error":"lock lost"}', 409) : {'ok': true},
        'DELETE /api/projects/$pid/locks': (_) => {'ok': true},
        'GET /api/projects/$pid/manifest': (_) => [
              for (final e in files.entries)
                {
                  'name': e.key.split('/').last,
                  'path': e.key,
                  'type': 'file',
                  'rev': rev(e.key),
                  'size': e.value.length,
                  'modified': 0
                }
            ],
        'GET /api/projects/$pid/download': (req) {
          final path = req.url.queryParameters['path']!;
          final b = files[path];
          return b == null
              ? http.Response('{"error":"missing"}', 404)
              : http.Response.bytes(b, 200);
        },
        'POST /api/projects/$pid/files/upload': (req) {
          final body = jsonDecode(req.body);
          if (staleOnce.remove(body['path'])) {
            return http.Response(
                jsonEncode({'error': 'stale', 'rev': rev(body['path'])}), 409);
          }
          pending[pid] = body['path'] as String;
          return {'id': 'u1'};
        },
        'PUT /api/uploads/u1/chunk': (req) {
          chunks.addAll(req.bodyBytes);
          return {'ok': true};
        },
        'POST /api/uploads/u1/complete': (_) {
          final path = pending.remove(pid);
          if (path != null) {
            files[path] = List.of(chunks);
            revs[path] = (revs[path] ?? 0) + 1;
            uploads++;
          }
          chunks.clear();
          return {'ok': true};
        },
        'DELETE /api/uploads/u1': (_) => {'ok': true},
        'DELETE /api/projects/$pid/files': (req) {
          final path = req.url.queryParameters['path']!;
          final base = req.url.queryParameters['base']!;
          if (deleteStale && rev(path) != base) {
            return http.Response(
                jsonEncode({'error': 'stale', 'rev': rev(path)}), 409);
          }
          files.remove(path);
          revs.remove(path);
          return {'ok': true};
        },
        'GET /api/uploads/u1': (_) => {'received': 1},
      });
}

class _Proc implements CraftProcess {
  final done = Completer<int>();
  bool killed = false;
  @override
  Future<int> get exit => done.future;
  @override
  void kill() {
    killed = true;
    if (!done.isCompleted) done.complete(0);
  }
}

Directory _tmp() => Directory.systemTemp.createTempSync('craft_test');

void main() {
  late Directory dir;
  late _Store store;
  late Api api;
  const pid = 'p1';

  setUp(() {
    dir = _tmp();
    store = _Store();
    api = Api(store.client(pid))..baseUrl = 'http://test';
  });

  tearDown(() async {
    await dir.delete(recursive: true);
  });

  File w(String rel, String content) {
    final f = File('${dir.path}/$rel');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(content);
    return f;
  }

  test('docPath classifies craft docs', () {
    expect(Checkout.docPath('project.fcproj'), isTrue);
    expect(Checkout.docPath('project.wfm.json'), isTrue);
    expect(Checkout.docPath('Script/a.fountain'), isTrue);
    expect(Checkout.docPath('Boards/b.json'), isTrue);
    expect(Checkout.docPath('Raw/clip.mp4'), isFalse);
  });

  test('pull downloads the tree and records revs', () async {
    store.files['project.fcproj'] = utf8.encode('{"v":1}');
    store.revs['project.fcproj'] = 3;
    store.files['Raw/clip.mp4'] = utf8.encode('media-bytes');
    store.revs['Raw/clip.mp4'] = 1;
    final co = Checkout(dir);
    final res = await SyncEngine(api, pid, 'c1', co).pull();
    expect(res.pulled, 2);
    expect(File('${dir.path}/project.fcproj').readAsStringSync(), '{"v":1}');
    expect(File('${dir.path}/Raw/clip.mp4').readAsStringSync(), 'media-bytes');
    expect(co.manifest['project.fcproj']?.rev, 'r3');
    expect(File('${dir.path}/.wfm/manifest.json').existsSync(), isTrue);
    final co2 = Checkout(dir);
    await co2.load();
    expect(co2.manifest['Raw/clip.mp4']?.rev, 'r1');
  });

  test('docOnly pull fetches just docs', () async {
    store.files['project.fcproj'] = utf8.encode('{}');
    store.revs['project.fcproj'] = 1;
    store.files['Raw/big.mp4'] = utf8.encode('x');
    store.revs['Raw/big.mp4'] = 1;
    final res =
        await SyncEngine(api, pid, 'c1', Checkout(dir)).pull(docOnly: true);
    expect(res.pulled, 1);
    expect(File('${dir.path}/Raw/big.mp4').existsSync(), isFalse);
  });

  test('pull keeps a dirty local file as a conflict copy', () async {
    store.files['project.fcproj'] = utf8.encode('remote');
    store.revs['project.fcproj'] = 2;
    w('project.fcproj', 'local-edit');
    final res = await SyncEngine(api, pid, 'c1', Checkout(dir)).pull();
    expect(res.conflicts, ['project.fcproj']);
    expect(File('${dir.path}/project.fcproj').readAsStringSync(), 'remote');
    expect(
        dir
            .listSync()
            .map((e) => e.path.split('/').last)
            .where((n) => n.contains('conflict')),
        isNotEmpty);
  });

  test('pull drops clean files removed on the server, keeps dirty', () async {
    store.files['gone.txt'] = utf8.encode('x');
    store.revs['gone.txt'] = 1;
    final co = Checkout(dir);
    await SyncEngine(api, pid, 'c1', co).pull();
    store.files.remove('gone.txt');
    store.revs.remove('gone.txt');
    var res = await SyncEngine(api, pid, 'c1', co).pull();
    expect(File('${dir.path}/gone.txt').existsSync(), isFalse);
    expect(res.conflicts, isEmpty);

    store.files['dirty.txt'] = utf8.encode('remote');
    store.revs['dirty.txt'] = 1;
    await SyncEngine(api, pid, 'c1', co).pull();
    w('dirty.txt', 'edited-locally');
    store.files.remove('dirty.txt');
    res = await SyncEngine(api, pid, 'c1', co).pull();
    expect(res.conflicts, ['dirty.txt']);
    expect(File('${dir.path}/dirty.txt').existsSync(), isFalse);
    expect(
        dir
            .listSync()
            .map((e) => e.path.split('/').last)
            .where((n) => n.contains('conflict')),
        isNotEmpty);
  });

  test('push uploads new, changed and deleted paths', () async {
    store.files['project.fcproj'] = utf8.encode('v1');
    store.revs['project.fcproj'] = 1;
    store.files['old.txt'] = utf8.encode('old');
    store.revs['old.txt'] = 1;
    final co = Checkout(dir);
    await SyncEngine(api, pid, 'c1', co).pull();

    w('project.fcproj', 'v2');
    w('new.txt', 'fresh');
    File('${dir.path}/old.txt').deleteSync();

    final res = await SyncEngine(api, pid, 'c1', co).push();
    expect(res.pushed, 3);
    expect(utf8.decode(store.files['project.fcproj']!), 'v2');
    expect(utf8.decode(store.files['new.txt']!), 'fresh');
    expect(store.files.containsKey('old.txt'), isFalse);
    // The manifest revs were refreshed from the server.
    expect(co.manifest['project.fcproj']!.rev, 'r2');
    expect(co.manifest['new.txt']!.rev, 'r1');
  });

  test('push conflict keeps server bytes and retries ours', () async {
    store.files['a.txt'] = utf8.encode('remote-v1');
    store.revs['a.txt'] = 1;
    final co = Checkout(dir);
    final eng = SyncEngine(api, pid, 'c1', co);
    await eng.pull();
    w('a.txt', 'local-v2');
    // Someone else wrote rev 2 server-side.
    store.files['a.txt'] = utf8.encode('remote-v2');
    store.revs['a.txt'] = 2;
    store.staleOnce = {'a.txt'};
    final res = await eng.push();
    expect(res.conflicts, ['a.txt']);
    expect(utf8.decode(store.files['a.txt']!), 'local-v2');
    expect(
        dir
            .listSync()
            .map((e) => e.path.split('/').last)
            .where((n) => n.contains('conflict')),
        isNotEmpty);
  });

  test('push recreates a file deleted server-side', () async {
    store.files['b.txt'] = utf8.encode('remote');
    store.revs['b.txt'] = 1;
    final co = Checkout(dir);
    await SyncEngine(api, pid, 'c1', co).pull();
    w('b.txt', 'local-new');
    store.files.remove('b.txt');
    store.revs.remove('b.txt');
    store.staleOnce = {'b.txt'};
    final res = await SyncEngine(api, pid, 'c1', co).push();
    expect(res.pushed, 1);
    expect(utf8.decode(store.files['b.txt']!), 'local-new');
  });

  test('delete conflict leaves the remote file to be pulled back', () async {
    store.files['c.txt'] = utf8.encode('remote');
    store.revs['c.txt'] = 1;
    final co = Checkout(dir);
    final eng = SyncEngine(api, pid, 'c1', co);
    await eng.pull();
    File('${dir.path}/c.txt').deleteSync();
    store.deleteStale = true;
    store.revs['c.txt'] = 2;
    await eng.push();
    expect(store.files.containsKey('c.txt'), isTrue);
    await eng.pull();
    expect(File('${dir.path}/c.txt').readAsStringSync(), 'remote');
  });

  test('conflictPath nests inside the parent folder', () {
    final co = Checkout(dir);
    expect(co.conflictPath('Raw/a.mp4', 5), 'Raw/a (conflict 5).mp4');
    expect(co.conflictPath('a.txt', 5), 'a (conflict 5).txt');
    expect(co.conflictPath('noext', 5), 'noext (conflict 5)');
  });

  test('scan reports only divergent files', () async {
    store.files['same.txt'] = utf8.encode('x');
    store.revs['same.txt'] = 1;
    final co = Checkout(dir);
    await SyncEngine(api, pid, 'c1', co).pull();
    expect(await co.scan(), isEmpty);
    w('same.txt', 'changed');
    w('extra.txt', 'untracked');
    expect((await co.scan()).toSet(), {'same.txt', 'extra.txt'});
    File('${dir.path}/extra.txt').deleteSync();
    File('${dir.path}/same.txt').deleteSync();
    expect((await co.scan()).toSet(), {'same.txt'});
  });

  group('runner', () {
    late File exe;
    late _Proc proc;
    late List<List<String>> spawned;
    late CraftRunner runner;

    setUp(() {
      exe = File('${dir.path}/wfm-filmcraft')..createSync();
      spawned = [];
      proc = _Proc();
      runner = CraftRunner(api,
          spawn: (e, args, {workingDirectory, env}) async {
        spawned.add([e, ...args]);
        return proc;
      },
          pushInterval: const Duration(milliseconds: 20),
          beatInterval: const Duration(milliseconds: 15));
    });

    test('open locks, pulls, spawns and releases on exit', () async {
      store.files['project.fcproj'] = utf8.encode('{}');
      store.revs['project.fcproj'] = 1;
      final run = await runner.open('filmcraft', pid, dir, exe.path,
          takeOver: (_) async => false, lockLost: (_) {});
      expect(spawned.single.last, endsWith('project.fcproj'));
      expect(run.clientId, startsWith('filmcraft:'));
      expect(run.lockKind, 'edit');
      w('project.fcproj', '{"edited":true}');
      proc.done.complete(0);
      await run.done.future;
      expect(utf8.decode(store.files['project.fcproj']!), '{"edited":true}');
      expect(run.released, isTrue);
      expect(runner.runs, isEmpty);
    });

    test('refuses a second open of the same project', () async {
      await runner.open('filmcraft', pid, dir, exe.path,
          takeOver: (_) async => false, lockLost: (_) {});
      expect(
          runner.open('filmcraft', pid, dir, exe.path,
              takeOver: (_) async => false, lockLost: (_) {}),
          throwsA(isA<CraftOpenException>()));
      proc.done.complete(0);
      await runner.runs.values.first.done.future;
    });

    test('missing binary refuses before locking', () {
      expect(
          runner.open('filmcraft', pid, dir, '${dir.path}/nope',
              takeOver: (_) async => false, lockLost: (_) {}),
          throwsA(predicate(
              (e) => e is CraftOpenException && e.kind == 'missing')));
    });

    test('declined take-over leaves the lock alone', () {
      store.locked = true;
      expect(
          runner.open('filmcraft', pid, dir, exe.path,
              takeOver: (_) async => false, lockLost: (_) {}),
          throwsA(predicate(
              (e) => e is CraftOpenException && e.kind == 'declined')));
    });

    test('forced take-over reacquires and continues', () async {
      var calls = 0;
      final api2 = Api(FakeClient({
        'POST /api/projects/p1/locks': (_) {
          calls++;
          return calls == 1
              ? http.Response(
                  jsonEncode({
                    'acquired': false,
                    'lock': {'holder': 'ada', 'label': '', 'expiresAt': 0}
                  }),
                  409)
              : {'acquired': true, 'lock': {}};
        },
        'GET /api/projects/p1/manifest': (_) => [],
        'GET /api/projects/p1/download': (_) => http.Response.bytes([], 200),
      }))
        ..baseUrl = 'http://test';
      final r2 = CraftRunner(api2,
          spawn: (e, a, {workingDirectory, env}) async => proc);
      final run = await r2.open('filmcraft', pid, dir, exe.path,
          takeOver: (holder) async {
        expect(holder, 'ada');
        return true;
      }, lockLost: (_) {}, pullMedia: false);
      expect(calls, 2);
      proc.done.complete(0);
      await run.done.future;
    });

    test('force-fail when still locked reports locked', () {
      store.locked = true;
      expect(
          runner.open('filmcraft', pid, dir, exe.path,
              takeOver: (_) async => true, lockLost: (_) {}),
          throwsA(
              predicate((e) => e is CraftOpenException && e.kind == 'locked')));
    });

    test('spawn failure releases the lock', () async {
      var releases = 0;
      final api2 = Api(FakeClient({
        'POST /api/projects/p1/locks': (_) => {'acquired': true},
        'DELETE /api/projects/p1/locks': (_) {
          releases++;
          return {'ok': true};
        },
        'GET /api/projects/p1/manifest': (_) => [],
      }))
        ..baseUrl = 'http://test';
      final r2 = CraftRunner(api2,
          spawn: (e, a, {workingDirectory, env}) async =>
              throw StateError('no spawn'));
      await expectLater(
          r2.open('filmcraft', pid, dir, exe.path,
              takeOver: (_) async => false, lockLost: (_) {}),
          throwsStateError);
      expect(releases, 1);
    });

    test('heartbeat loss marks the run', () async {
      var lost = false;
      final run = await runner.open('filmcraft', pid, dir, exe.path,
          takeOver: (_) async => false, lockLost: (_) => lost = true);
      store.locked = true;
      await Future.delayed(const Duration(milliseconds: 80));
      expect(lost, isTrue);
      expect(run.lockLost, isTrue);
      proc.done.complete(0);
      await run.done.future;
    });

    test('scanner pushes dirty files while open', () async {
      await runner.open('filmcraft', pid, dir, exe.path,
          takeOver: (_) async => false, lockLost: (_) {});
      w('note.txt', 'sync-me');
      await Future.delayed(const Duration(milliseconds: 90));
      expect(store.files['note.txt'] != null, isTrue);
      proc.done.complete(0);
      await runner.runs.values.first.done.future;
    });

    test('shutdown kills children and releases', () async {
      await runner.open('filmcraft', pid, dir, exe.path,
          takeOver: (_) async => false, lockLost: (_) {});
      await runner.shutdown();
      expect(proc.killed, isTrue);
      expect(runner.runs, isEmpty);
    });

    test('lockKindOf maps the other crafts', () {
      expect(CraftRunner.lockKindOf('scriptcraft'), 'script');
      expect(CraftRunner.lockKindOf('deckcraft'), 'deck');
      expect(CraftRunner.lockKindOf('filmcraft'), 'edit');
      expect(newRunId().length, 32);
    });
  });
}
