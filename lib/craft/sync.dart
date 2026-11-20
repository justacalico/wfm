import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../api.dart';

class SyncEntry {
  SyncEntry({required this.rev, required this.size, required this.mtime});
  String rev;
  int size, mtime;

  SyncEntry.fromJson(Map<String, dynamic> j)
      : rev = j['rev'] ?? '',
        size = j['size'] ?? 0,
        mtime = j['mtime'] ?? 0;

  Map<String, dynamic> toJson() => {'rev': rev, 'size': size, 'mtime': mtime};
}

class SyncResult {
  int pulled = 0, pushed = 0;
  final conflicts = <String>[];
}

/// A local mirror of one project plus `.wfm/manifest.json` describing what
/// the server tree looked like at the last sync, so a diff needs no hashes.
class Checkout {
  Checkout(this.dir);
  final Directory dir;

  final manifest = <String, SyncEntry>{};

  static bool docPath(String rel) =>
      rel == 'project.fcproj' ||
      rel == 'project.wfm.json' ||
      rel.startsWith('Script/') ||
      rel.startsWith('Boards/');

  File file(String rel) => File(p.joinAll([dir.path, ...rel.split('/')]));

  File get _manifestFile => File(p.join(dir.path, '.wfm', 'manifest.json'));

  Future<void> load() async {
    manifest.clear();
    final f = _manifestFile;
    if (!f.existsSync()) return;
    for (final e
        in (jsonDecode(await f.readAsString())['entries'] as Map).entries) {
      manifest[e.key] = SyncEntry.fromJson(e.value);
    }
  }

  Future<void> save() async {
    final f = _manifestFile;
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode({
      'entries': {for (final e in manifest.entries) e.key: e.value.toJson()}
    }));
  }

  Future<FileStat?> stat(String rel) async {
    final st = await file(rel).stat();
    return st.type == FileSystemEntityType.file ? st : null;
  }

  bool dirty(String rel, FileStat st) {
    final e = manifest[rel];
    return e == null ||
        e.size != st.size ||
        e.mtime != st.modified.millisecondsSinceEpoch;
  }

  /// Local files newer than the manifest signature, newest first.
  Future<List<String>> scan() async {
    final out = <String>[];
    await for (final f in dir.list(recursive: true, followLinks: false)) {
      if (f is! File) continue;
      final rel = p
          .relative(f.path, from: dir.path)
          .replaceAll(Platform.pathSeparator, '/');
      if (rel == '.wfm' || rel.startsWith('.wfm/')) continue;
      final st = await f.stat();
      if (dirty(rel, st)) out.add(rel);
    }
    return out;
  }

  String conflictPath(String rel, int ts) {
    final dir = p.posix.dirname(rel), base = p.posix.basename(rel);
    final dot = base.lastIndexOf('.');
    final stem = dot > 0 ? base.substring(0, dot) : base;
    final ext = dot > 0 ? base.substring(dot) : '';
    final name = '$stem (conflict $ts)$ext';
    return dir == '.' ? name : '$dir/$name';
  }
}

/// Pulls/pushes between the server project tree and a [Checkout]. The
/// caller holds the write lock, so rev changes on the server mean someone
/// raced us: both versions are kept as `… (conflict ts)` files, never
/// silently overwritten.
class SyncEngine {
  SyncEngine(this.api, this.projectId, this.clientId, this.checkout);

  final Api api;
  final String projectId, clientId;
  final Checkout checkout;
  Future<void> _ops = Future.value();

  void Function(String rel, int done, int total)? onProgress;

  int _ts() => DateTime.now().millisecondsSinceEpoch;

  Future<SyncResult> _enqueue(Future<SyncResult> Function() op) {
    final res = _ops.then((_) => op());
    _ops = res.then((_) {}, onError: (_) {});
    return res;
  }

  Future<SyncResult> pull({bool eagerOnly = false}) =>
      _enqueue(() => _pull(eagerOnly: eagerOnly));

  Future<SyncResult> _pull({bool eagerOnly = false}) async {
    final res = SyncResult();
    await checkout.load();
    final remote = {
      for (final e in await api.manifest(projectId))
        if (!e.isDir) e.path: e
    };

    for (final rel in checkout.manifest.keys.toList()) {
      if (remote.containsKey(rel)) continue;
      final st = await checkout.stat(rel);
      if (st == null || !checkout.dirty(rel, st)) {
        if (st != null) await checkout.file(rel).delete();
        checkout.manifest.remove(rel);
      } else {
        await checkout
            .file(rel)
            .rename(checkout.file(checkout.conflictPath(rel, _ts())).path);
        checkout.manifest.remove(rel);
        res.conflicts.add(rel);
      }
    }

    var i = 0;
    final total = remote.values
        .where((e) => !eagerOnly || Checkout.docPath(e.path))
        .length;
    for (final e in remote.values) {
      if (eagerOnly && !Checkout.docPath(e.path)) continue;
      i++;
      final known = checkout.manifest[e.path];
      if (known?.rev == e.rev) continue;
      final st = await checkout.stat(e.path);
      if (st != null && checkout.dirty(e.path, st)) {
        final other = checkout.conflictPath(e.path, _ts());
        await checkout.file(e.path).rename(checkout.file(other).path);
        res.conflicts.add(e.path);
      }
      await _fetch(e);
      res.pulled++;
      onProgress?.call(e.path, i, total);
    }
    await checkout.save();
    return res;
  }

  Future<void> _fetch(FileEntry e) async {
    final f = checkout.file(e.path);
    await f.parent.create(recursive: true);
    final sink = f.openWrite();
    try {
      await api.downloadInto(projectId, e.path, sink);
    } finally {
      await sink.close();
    }
    final st = await f.stat();
    checkout.manifest[e.path] = SyncEntry(
        rev: e.rev, size: st.size, mtime: st.modified.millisecondsSinceEpoch);
  }

  /// Push local changes: new files create with base "none", modified files
  /// update with their last-synced rev, and files deleted locally delete
  /// remotely. A 409 mid-push means the server moved; we keep its bytes as
  /// a conflict file and retry ours over the fresh rev.
  Future<SyncResult> push() => _enqueue(_push);

  Future<SyncResult> _push() async {
    final res = SyncResult();
    await checkout.load();
    final changed = await checkout.scan();
    var i = 0;
    for (final rel in changed) {
      i++;
      final f = checkout.file(rel);
      final bytes = await f.readAsBytes();
      final base = checkout.manifest[rel]?.rev ?? 'none';
      try {
        await api.upload(projectId, rel, bytes, clientId: clientId, base: base);
      } on ApiException catch (err) {
        if (err.status == 409 &&
            err.message.contains('stale') &&
            await _resolvePushConflict(rel)) {
          await api.upload(projectId, rel, bytes,
              clientId: clientId, base: checkout.manifest[rel]!.rev);
        } else {
          rethrow;
        }
      }
      res.pushed++;
      onProgress?.call(rel, i, changed.length);
    }
    await _revSweep(changed, res);
    await checkout.save();
    return res;
  }

  /// Server copy of a file we lost a race on becomes a conflict download,
  /// then our local version is retried over its fresh rev.
  Future<bool> _resolvePushConflict(String rel) async {
    FileEntry? remote;
    try {
      remote = {for (final e in await api.manifest(projectId)) e.path: e}[rel];
    } on ApiException {
      return false;
    }
    if (remote == null || remote.isDir) return false;
    final stamped = checkout.conflictPath(rel, _ts());
    final f = checkout.file(stamped);
    await f.parent.create(recursive: true);
    final sink = f.openWrite();
    try {
      await api.downloadInto(projectId, rel, sink);
    } finally {
      await sink.close();
    }
    checkout.manifest[rel] =
        SyncEntry(rev: remote.rev, size: remote.size, mtime: 0);
    return true;
  }

  Future<void> _revSweep(List<String> changed, SyncResult res) async {
    final remote = {for (final e in await api.manifest(projectId)) e.path: e};
    for (final rel in changed) {
      final e = remote[rel];
      final st = await checkout.stat(rel);
      if (e != null && st != null) {
        checkout.manifest[rel] = SyncEntry(
            rev: e.rev,
            size: st.size,
            mtime: st.modified.millisecondsSinceEpoch);
      }
    }
    for (final rel in checkout.manifest.keys.toList()) {
      if (await checkout.stat(rel) != null) continue;
      final e = remote[rel];
      if (e == null) {
        checkout.manifest.remove(rel);
        continue;
      }
      try {
        await api.deleteFile(projectId, rel, clientId: clientId, base: e.rev);
        checkout.manifest.remove(rel);
      } on ApiException catch (err) {
        if (err.status != 404 && err.status != 409) rethrow;
        checkout.manifest.remove(rel);
      }
    }
  }
}
