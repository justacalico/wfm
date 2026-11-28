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

/// A local mirror of one server project plus `.wfm/manifest.json` recording
/// what the server tree looked like at the last sync, so diffs need no
/// hashing.
class Checkout {
  Checkout(this.dir);
  final Directory dir;

  final manifest = <String, SyncEntry>{};

  /// Files a craft editor needs before it may launch; the rest of the tree
  /// (mostly media) streams in behind it.
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
    final known = manifest[rel];
    return known == null ||
        known.size != st.size ||
        known.mtime != st.modified.millisecondsSinceEpoch;
  }

  /// Local files differing from the synced baseline; the baseline itself is
  /// never reported.
  Future<List<String>> scan() async {
    final out = <String>[];
    final seen = <String>{};
    await for (final f in dir.list(recursive: true, followLinks: false)) {
      if (f is! File) continue;
      final rel = p
          .relative(f.path, from: dir.path)
          .replaceAll(Platform.pathSeparator, '/');
      if (rel == '.wfm' || rel.startsWith('.wfm/')) continue;
      seen.add(rel);
      final st = await f.stat();
      if (dirty(rel, st)) out.add(rel);
    }
    for (final rel in manifest.keys) {
      if (!seen.contains(rel)) out.add(rel);
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

/// Pulls/pushes between the server project tree and a [Checkout]. The caller
/// holds the write lock, so a rev change on the server means someone raced
/// us: both versions are kept as `(conflict ts)` files, never silently
/// overwritten.
class SyncEngine {
  SyncEngine(this.api, this.projectId, this.clientId, this.checkout);

  final Api api;
  final String projectId, clientId;
  final Checkout checkout;
  Future<void> _ops = Future.value();
  bool _busy = false;

  void Function(String rel, int done, int total)? onProgress;

  int _ts() => DateTime.now().millisecondsSinceEpoch;

  Future<SyncResult> _enqueue(Future<SyncResult> Function() op) {
    final res = _ops.then((_) {
      _busy = true;
      return op();
    }).whenComplete(() => _busy = false);
    _ops = res.then((_) {}, onError: (_) {});
    return res;
  }

  bool get busy => _busy;

  Future<SyncResult> pull({bool docOnly = false}) =>
      _enqueue(() => _pull(docOnly: docOnly));

  Future<SyncResult> _pull({bool docOnly = false}) async {
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
    final total =
        remote.values.where((e) => !docOnly || Checkout.docPath(e.path)).length;
    for (final e in remote.values) {
      if (docOnly && !Checkout.docPath(e.path)) continue;
      i++;
      final known = checkout.manifest[e.path];
      if (known?.rev == e.rev) continue;
      final st = await checkout.stat(e.path);
      if (st != null && checkout.dirty(e.path, st)) {
        await checkout
            .file(e.path)
            .rename(checkout.file(checkout.conflictPath(e.path, _ts())).path);
        res.conflicts.add(e.path);
      }
      await _fetch(e);
      res.pulled++;
      onProgress?.call(e.path, i, total);
    }
    await checkout.save();
    return res;
  }

  Future<void> _fetch(FileEntry e, [String? toRel]) async {
    final dest = toRel ?? e.path;
    final f = checkout.file(dest);
    await f.parent.create(recursive: true);
    final sink = f.openWrite();
    try {
      await api.downloadInto(projectId, e.path, sink);
    } finally {
      await sink.close();
    }
    final st = await f.stat();
    checkout.manifest[dest] = SyncEntry(
        rev: e.rev, size: st.size, mtime: st.modified.millisecondsSinceEpoch);
  }

  /// Push local changes: new files create with base "none", modified files
  /// update with their last-synced rev, and files deleted locally delete
  /// remotely. A 409 mid-push means the server moved; its bytes are kept as
  /// a conflict file and ours is retried over the fresh rev.
  Future<SyncResult> push() => _enqueue(_push);

  Future<SyncResult> _push() async {
    final res = SyncResult();
    await checkout.load();
    final changed = await checkout.scan();
    for (final rel in changed) {
      final f = checkout.file(rel);
      if (!f.existsSync()) {
        final base = checkout.manifest[rel]?.rev;
        if (base == null) continue;
        try {
          await api.deleteFile(projectId, rel, clientId: clientId, base: base);
          res.pushed++;
        } on ApiException catch (e) {
          if (e.status != 409) rethrow;
          // Remote changed under us: untrack so the next pull brings the
          // server's version back instead of losing it.
        }
        checkout.manifest.remove(rel);
        continue;
      }
      final base = checkout.manifest[rel]?.rev ?? 'none';
      await _put(rel, f, base, res.conflicts);
      final st = await f.stat();
      checkout.manifest[rel] = SyncEntry(
          rev: '', size: st.size, mtime: st.modified.millisecondsSinceEpoch);
      res.pushed++;
    }
    final remote = {
      for (final e in await api.manifest(projectId))
        if (!e.isDir) e.path: e
    };
    for (final e in remote.values) {
      final known = checkout.manifest[e.path];
      if (known != null) known.rev = e.rev;
    }
    await checkout.save();
    return res;
  }

  Future<void> _put(
      String rel, File f, String base, List<String> conflicts) async {
    try {
      return await _upload(rel, f, base);
    } on ApiException catch (e) {
      if (e.status != 409) rethrow;
      final fresh = e.rev;
      if (fresh == null) {
        // Deleted on the server while we edited: ours becomes the file.
        return _upload(rel, f, 'none');
      }
      final other = checkout.conflictPath(rel, _ts());
      await _fetch(
          FileEntry.fromJson(
              {'name': p.posix.basename(rel), 'path': rel, 'rev': fresh}),
          other);
      checkout.manifest.remove(other);
      conflicts.add(rel);
      return _upload(rel, f, fresh);
    }
  }

  Future<void> _upload(String rel, File f, String base) async {
    final size = await f.length();
    final raf = await f.open();
    try {
      await api.uploadChunked(projectId, rel, size, (a, b) async {
        await raf.setPosition(a);
        return raf.read(b - a);
      }, null, clientId, base);
    } finally {
      await raf.close();
    }
  }
}
