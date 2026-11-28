import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../api.dart';
import 'sync.dart';

class CraftOpenException implements Exception {
  CraftOpenException(this.kind);
  final String kind; // alreadyOpen | declined | locked | missing
}

String newRunId() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

/// The part of a spawned craft process the runner needs; real builds hand
/// back a [Process], tests a fake.
abstract class CraftProcess {
  Future<int> get exit;
  void kill();
}

class _SpawnedProcess implements CraftProcess {
  _SpawnedProcess(this.p);
  final Process p;
  @override
  Future<int> get exit => p.exitCode;
  @override
  void kill() => p.kill();
}

typedef CraftSpawn = Future<CraftProcess> Function(
    String exe, List<String> args,
    {String? workingDirectory, Map<String, String>? env});

Future<CraftProcess> _start(String exe, List<String> args,
        {String? workingDirectory, Map<String, String>? env}) async =>
    _SpawnedProcess(await Process.start(exe, args,
        workingDirectory: workingDirectory,
        environment: env,
        mode: ProcessStartMode.normal));

/// One open native craft window: a spawned upstream binary pointed at a
/// local checkout, a heartbeat on its write lock, and a periodic diff-push
/// back to the server. The process never talks to the server itself.
class CraftRun {
  CraftRun(this.craft, this.projectId, this.runId, this.proc, this.engine,
      this.checkout);

  final String craft, projectId, runId;
  final CraftProcess proc;
  final SyncEngine engine;
  final Checkout checkout;
  final done = Completer<void>();
  Timer? heartbeat, scanner;
  bool lockLost = false, released = false;
  Object? lastError;

  String get lockKind => CraftRunner.lockKindOf(craft);

  String get clientId => '$craft:$runId';
}

typedef LockLost = void Function(CraftRun run);
typedef SyncStatus = void Function(String phase, int done, int total);

/// Owns all live native craft sessions. One run per (craft, project); a
/// second open of the same pair is refused, everything else runs side by
/// side.
class CraftRunner {
  CraftRunner(this.api,
      {CraftSpawn? spawn,
      this.pushInterval = const Duration(seconds: 5),
      this.beatInterval = const Duration(seconds: 20)})
      : _spawn = spawn ?? _start;

  final Api api;
  final CraftSpawn _spawn;
  final Duration pushInterval, beatInterval;
  final runs = <String, CraftRun>{};

  static String lockKindOf(String craft) =>
      const {
        'scriptcraft': 'script',
        'deckcraft': 'deck',
      }[craft] ??
      'edit';

  /// Acquiring the lock, pulling the doc eagerly, spawning the binary and
  /// arming sync. [takeOver] decides whether a held lock is forced; it gets
  /// the conflict detail from the server.
  Future<CraftRun> open(
    String craft,
    String projectId,
    Directory checkoutDir,
    String exe, {
    required Future<bool> Function(String detail) takeOver,
    required LockLost lockLost,
    SyncStatus? status,
    String? dataDir,
    bool pullMedia = true,
  }) async {
    final key = '$craft:$projectId';
    if (runs.containsKey(key)) throw CraftOpenException('alreadyOpen');
    if (!File(exe).existsSync()) throw CraftOpenException('missing');
    final runId = newRunId();
    final clientId = '$craft:$runId';
    final kind = lockKindOf(craft);
    var (ok, detail) = await api.lockAcquire(projectId, kind, clientId);
    if (!ok) {
      if (!await takeOver(detail)) throw CraftOpenException('declined');
      (ok, detail) =
          await api.lockAcquire(projectId, kind, clientId, force: true);
      if (!ok) throw CraftOpenException('locked');
    }
    final checkout = Checkout(checkoutDir);
    await checkoutDir.create(recursive: true);
    final engine = SyncEngine(api, projectId, clientId, checkout)
      ..onProgress = (rel, done, total) => status?.call('pull', done, total);
    CraftProcess proc;
    late CraftRun run;
    try {
      await engine.pull(docOnly: !pullMedia);
      final doc = '${checkoutDir.path}/project.fcproj';
      proc = await _spawn(exe, [doc],
          workingDirectory: checkoutDir.path,
          env: {
            if (dataDir != null) 'FILMCRAFT_DATA_DIR': dataDir,
            if (!pullMedia) ...{
              'FILMCRAFT_REMOTE_URL': api.baseUrl,
              'FILMCRAFT_REMOTE_TOKEN': api.sessionToken,
              'FILMCRAFT_REMOTE_PROJECT': projectId,
              'FILMCRAFT_REMOTE_ROOT': checkoutDir.path,
            },
          });
    } catch (_) {
      try {
        await api.lockRelease(projectId, kind, clientId);
      } catch (_) {}
      rethrow;
    }
    run = CraftRun(craft, projectId, runId, proc, engine, checkout);
    run.heartbeat = Timer.periodic(beatInterval, (_) async {
      try {
        if (!await api.lockHeartbeat(projectId, kind, clientId)) {
          run.lockLost = true;
          lockLost(run);
        }
      } catch (_) {}
    });
    run.scanner = Timer.periodic(pushInterval, (_) {
      if (engine.busy) return;
      unawaited(engine.push().onError((e, _) {
        run.lastError = e;
        return SyncResult();
      }));
    });
    runs[key] = run;
    unawaited(proc.exit.then((_) async {
      run.heartbeat?.cancel();
      run.scanner?.cancel();
      try {
        await engine.push();
      } catch (e) {
        run.lastError = e;
      }
      try {
        await api.lockRelease(projectId, kind, clientId);
        run.released = true;
      } catch (_) {}
      runs.remove(key);
      run.done.complete();
    }));
    return run;
  }

  /// Best-effort shutdown for app exit: kill children, push, release.
  Future<void> shutdown() async {
    for (final run in runs.values.toList()) {
      run.heartbeat?.cancel();
      run.scanner?.cancel();
      run.proc.kill();
      try {
        await run.engine.push();
      } catch (_) {}
      try {
        await api.lockRelease(run.projectId, run.lockKind, run.clientId);
      } catch (_) {}
      runs.remove('${run.craft}:${run.projectId}');
    }
  }
}
