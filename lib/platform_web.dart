import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import 'api.dart';

class PickedFile {
  final String name;
  final Uint8List bytes;
  final web.File? file;
  const PickedFile(this.name, this.bytes, [this.file]);
  int get size => file?.size ?? bytes.length;
}

void Function(String url)? openExternalForTesting;
Future<List<PickedFile>> Function()? pickFilesForTesting;

void openExternal(String url) {
  final f = openExternalForTesting;
  if (f != null) {
    f(url);
    return;
  }
  web.window.open(url, '_blank');
}

Future<List<PickedFile>> pickFiles() async {
  final test = pickFilesForTesting;
  if (test != null) return test();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..style.display = 'none';
  web.document.body?.appendChild(input);
  final done = Completer<List<PickedFile>>();
  void finish(List<PickedFile> files) {
    input.remove();
    if (!done.isCompleted) done.complete(files);
  }

  input.onChange.listen((_) async {
    final files = input.files;
    final out = <PickedFile>[];
    if (files != null) {
      for (var i = 0; i < files.length; i++) {
        final f = files.item(i)!;
        // Keep the File handle: uploadPicked sends it as a fetch() Blob body,
        // which the browser streams without buffering into JS memory.
        out.add(PickedFile(f.name, Uint8List(0), f));
      }
    }
    finish(out);
  });
  web.EventStreamProviders.cancelEvent
      .forElement(input)
      .listen((_) => finish([]));
  input.click();
  return done.future;
}

/// Upload a picked file with byte-level progress. File-backed picks go over
/// XMLHttpRequest (fetch cannot report upload progress); byte-backed picks go
/// through the Api client and report coarse start/done marks.
Future<void> uploadPicked(Api api, String pid, String path, PickedFile f,
    [void Function(int sent, int total)? onProgress]) async {
  final file = f.file;
  if (file == null) {
    onProgress?.call(0, f.bytes.length);
    await api.upload(pid, path, f.bytes);
    onProgress?.call(f.bytes.length, f.bytes.length);
    return;
  }
  const base = String.fromEnvironment('WFM_API');
  final q = Uri(queryParameters: {'path': path}).query;
  final done = Completer<void>();
  final xhr = web.XMLHttpRequest();
  xhr.open('PUT', '$base/api/projects/$pid/files?$q');
  if (api.csrf.isNotEmpty) xhr.setRequestHeader('x-csrf-token', api.csrf);
  xhr.upload.onprogress = ((web.ProgressEvent e) {
    if (e.lengthComputable) onProgress?.call(e.loaded, e.total);
  }).toJS;
  xhr.onloadend = ((web.Event _) {
    if (!done.isCompleted) done.complete();
  }).toJS;
  xhr.send(file);
  await done.future;
  if (xhr.status == 0) {
    throw ApiException(0, 'network error');
  }
  if (xhr.status == 401) {
    api.user = null;
    throw ApiException(401, 'auth');
  }
  if (xhr.status >= 400) {
    var msg = 'error ${xhr.status}';
    try {
      final b = jsonDecode(xhr.responseText);
      if (b is Map && b['error'] != null) msg = '${b['error']}';
    } catch (_) {}
    throw ApiException(xhr.status, msg);
  }
}

bool _dropWired = false;
void Function(List<PickedFile>)? _onDrop;

/// One-shot install of document-level drag/drop handlers (web only). Dropped
/// folders are walked via webkitGetAsEntry; names carry their relative path.
void installDropHandler(void Function(List<PickedFile>) onDrop) {
  _onDrop = onDrop;
  if (_dropWired) return;
  _dropWired = true;
  web.document.addEventListener(
      'dragover',
      ((web.Event e) {
        e.preventDefault();
      }).toJS);
  web.document.addEventListener(
      'drop',
      ((web.Event e) {
        e.preventDefault();
        final de = e as web.DragEvent;
        final items = de.dataTransfer?.items;
        if (items == null) return;
        final out = <PickedFile>[];
        final pending = <Future<void>>[];
        for (var i = 0; i < items.length; i++) {
          final entry = items[i].webkitGetAsEntry();
          if (entry != null) pending.add(_walk(entry, '', out));
        }
        Future.wait(pending).then((_) {
          final cb = _onDrop;
          if (cb != null && out.isNotEmpty) cb(out);
        });
      }).toJS);
}

Future<void> _walk(
    web.FileSystemEntry entry, String prefix, List<PickedFile> out) async {
  if (entry.isFile) {
    final got = Completer<web.File>();
    (entry as web.FileSystemFileEntry)
        .file(((web.File f) => got.complete(f)).toJS);
    final f = await got.future;
    out.add(PickedFile('$prefix${f.name}', Uint8List(0), f));
    return;
  }
  if (!entry.isDirectory) return;
  final dir = entry as web.FileSystemDirectoryEntry;
  final reader = dir.createReader();
  final next = '$prefix${dir.name}/';
  while (true) {
    final got = Completer<JSArray<web.FileSystemEntry>>();
    reader.readEntries(
        ((JSArray<web.FileSystemEntry> batch) => got.complete(batch)).toJS);
    final batch = (await got.future).toDart;
    if (batch.isEmpty) break;
    for (final e in batch) {
      await _walk(e, next, out);
    }
  }
}
