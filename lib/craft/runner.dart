import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../api.dart';
import 'sync.dart';

class CraftOpenException implements Exception {
  CraftOpenException(this.kind);
  final String kind; // alreadyOpen | declined | locked | missing
}

String newRunId() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

typedef CraftSpawn = Future<Process> Function(
    String exe, List<String> args, Map<String, String> env);

/// One open native craft window: a spawned upstream binary pointed at a
/// local checkout, a heartbeat on its write lock, and a periodic diff-push
/// back to the server. The process never talks to the server itself.
class CraftRun {
  CraftRun(this.craft, this.projectId, this.runId, this.process, this.engine,
      this.checkout);

  final String craft, projectId, runId;
  final Process process;
  final SyncEngine engine;
  final Checkout checkout;
  final done = Completer<void>();
  Timer? heartbeat, scanner;
  bool lockLost = false;
  Object? lastError;

  String get lockKind =>
      const {
        'scriptcraft': 'script',
        'deckcraft': 'deck',
      }[craft] ??
      'edit';

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

  // coverage:ignore-start
  static Future<Process> _start(
          String exe, List<String> args, Map<String, String> env) =>
      Process.start(exe, args, environment: env, mode: ProcessStartMode.normal);
  // coverage:ignore-end

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
    Process process;
    late CraftRun run;
    try {
      await engine.pull(eagerOnly: true);
      if (pullMedia) {
        unawaited(engine.pull().onError((e, _) {
          run.lastError = e;
          return SyncResult();
        }));
      }
      final doc =
          p.joinAll([checkoutDir.path, ...craftDocPath(craft).split('/')]);
      await Directory(p.dirname(doc)).create(recursive: true);
      process = await _spawn(exe, [
        doc
      ], {
        'WFM_RUN_ID': runId,
        'WFM_PROJECT': projectId,
        'WFM_CRAFT': craft,
      });
    } catch (_) {
      await api.lockRelease(projectId, kind, clientId);
      rethrow;
    }
    run = CraftRun(craft, projectId, runId, process, engine, checkout);
    run.scanner = Timer.periodic(pushInterval, (_) => _tick(run));
    run.heartbeat = Timer.periodic(
        beatInterval, (_) => _beat(api, projectId, run, lockLost));
    unawaited(process.exitCode.then((_) => _finish(run)));
    runs[key] = run;
    return run;
  }

  static Future<void> _tick(CraftRun run) async {
    try {
      if (!run.lockLost) await run.engine.push();
    } on ApiException catch (e) {
      run.lastError = e;
    } on FileSystemException catch (e) {
      run.lastError = e;
    }
  }

  static Future<void> _beat(
      Api api, String pid, CraftRun run, LockLost onLost) async {
    bool ok;
    try {
      ok = await api.lockHeartbeat(pid, run.lockKind, run.clientId);
    } on ApiException catch (e) {
      run.lastError = e;
      return;
    }
    if (ok) return;
    run.lockLost = true;
    run.process.kill();
    onLost(run);
  }

  Future<void> _finish(CraftRun run) async {
    run.scanner?.cancel();
    run.heartbeat?.cancel();
    try {
      if (!run.lockLost) {
        run.engine.onProgress = null;
        await run.engine.push();
      }
    } on ApiException catch (e) {
      run.lastError = e;
    } on FileSystemException catch (e) {
      run.lastError = e;
    }
    try {
      await api.lockRelease(run.projectId, run.lockKind, run.clientId);
    } on ApiException catch (e) {
      run.lastError = e;
    }
    runs.remove('${run.craft}:${run.projectId}');
    if (!run.done.isCompleted) run.done.complete();
  }

  /// SIGTERM the children, flush their checkouts and drop the locks. Called
  /// when the WFM window closes.
  Future<void> shutdownAll() async {
    for (final run in runs.values.toList()) {
      run.process.kill();
      await run.done.future;
    }
  }
}

/// Where bundled craft binaries live inside the installed app: next to the
/// executable on Windows/Linux, in the app bundle's Resources on macOS.
Directory craftBundleDir() {
  final exe = File(Platform.resolvedExecutable);
  // coverage:ignore-start
  if (Platform.isMacOS) {
    return Directory(
        p.normalize(p.join(exe.parent.path, '..', 'Resources', 'craft')));
  }
  // coverage:ignore-end
  return Directory(p.join(exe.parent.path, 'craft'));
}

String craftExeName(String craft) =>
    Platform.isWindows ? 'wfm-$craft.exe' : 'wfm-$craft';

/// The document a native craft opens and saves inside a checkout.
String craftDocPath(String craft) => switch (craft) {
      'scriptcraft' => 'Script/script.fountain',
      'deckcraft' => 'Boards/boards.deckcraft',
      _ => 'project.fcproj',
    };

/// Serialize run diagnostics for crash recovery.
Future<void> writeRunFile(Directory checkout, CraftRun run) async {
  final f = File(p.join(checkout.path, '.wfm', 'run.json'));
  await f.parent.create(recursive: true);
  await f.writeAsString(jsonEncode({
    'runId': run.runId,
    'craft': run.craft,
    'project': run.projectId,
    'clientId': run.clientId
  }));
}
