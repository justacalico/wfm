import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'api.dart';

class PickedFile {
  final String name;
  final Uint8List bytes;
  final web.File? file;
  final String? path;
  final int? _size;
  const PickedFile(this.name, this.bytes, {this.file, this.path, int? size})
      : _size = size;
  int get size => file?.size ?? _size ?? bytes.length;
}

bool get isNativeApp => false;
bool? isNativeAppForTesting;

Future<void> initNativeWindow() async {}
Future<bool> windowIsMaximized() async => false;
Future<void> windowMinimize() async {}
Future<bool> windowToggleMaximize() async => false;
Future<void> windowClose() async {}
Widget nativeTitleBar() => const SizedBox.shrink();

void Function(String url)? openExternalForTesting;
Future<List<PickedFile>> Function()? pickFilesForTesting;

Future<void> openExternal(String url) async {
  final f = openExternalForTesting;
  if (f != null) {
    f(url);
    return;
  }
  web.window.open(url, '_blank');
}

void Function(String url)? openEditorForTesting;

Future<void> openEditor(BuildContext context, Api api, String url,
    {String? projectName}) async {
  final t = openEditorForTesting;
  if (t != null) {
    t(url);
    return;
  }
  web.window.open(url, '_blank');
}

Future<List<PickedFile>> pickFiles({List<String>? exts}) async {
  final test = pickFilesForTesting;
  if (test != null) return test();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..style.display = 'none';
  if (exts != null) input.accept = exts.map((e) => '.$e').join(',');
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
        out.add(PickedFile(f.name, Uint8List(0), file: f));
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
  final total = file?.size ?? f.bytes.length;
  if (file == null || total > api.chunkSize) {
    onProgress?.call(0, total);
    if (file == null) {
      await api.upload(pid, path, f.bytes);
    } else {
      await _uploadChunked(api, pid, path, file, onProgress);
    }
    onProgress?.call(total, total);
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
  _checkStatus(api, xhr);
}

/// Chunked upload that sends each `Blob.slice` straight to XHR, so chunk
/// bytes stay in the browser and never copy into the Dart heap. Mirrors
/// Api.uploadChunked's protocol, including halving the size on 413.
Future<void> _uploadChunked(Api api, String pid, String path, web.File file,
    [void Function(int sent, int total)? onProgress]) async {
  final total = file.size;
  final uid = await api.uploadStart(pid, path);
  var off = 0;
  var size = api.chunkSize;
  try {
    while (off < total) {
      final end = math.min(off + size, total);
      try {
        final base = off;
        await _putBlob(
            api,
            '${api.baseUrl}/api/uploads/$uid/chunk?offset=$off',
            file.slice(off, end),
            onProgress == null
                ? null
                : (loaded, _) => onProgress(base + loaded, total));
        off = end;
        onProgress?.call(off, total);
      } on ApiException catch (e) {
        if (e.status == 413 && size > 1048576) {
          size ~/= 2;
        } else {
          rethrow;
        }
      }
    }
    await api.uploadFinish(uid);
  } catch (_) {
    try {
      await api.uploadAbort(uid);
    } catch (_) {}
    rethrow;
  }
}

Future<void> _putBlob(Api api, String url, web.Blob body,
    [void Function(int loaded, int total)? onProgress]) async {
  final done = Completer<void>();
  final xhr = web.XMLHttpRequest();
  xhr.open('PUT', url);
  if (api.csrf.isNotEmpty) xhr.setRequestHeader('x-csrf-token', api.csrf);
  if (onProgress != null) {
    xhr.upload.onprogress = ((web.ProgressEvent e) {
      if (e.lengthComputable) onProgress(e.loaded, e.total);
    }).toJS;
  }
  xhr.onloadend = ((web.Event _) {
    if (!done.isCompleted) done.complete();
  }).toJS;
  xhr.send(body);
  await done.future;
  _checkStatus(api, xhr);
}

void _checkStatus(Api api, web.XMLHttpRequest xhr) {
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

Widget Function(String url, bool audio)? mediaPlayerForTesting;

var _mediaSeq = 0;

/// Inline media player for the preview modal: a native <video>/<audio>
/// element, so the browser streams with Range requests and cookies.
Widget mediaPlayer(String url,
    {required bool audio, required String openLabel}) {
  final t = mediaPlayerForTesting;
  if (t != null) return t(url, audio);
  final viewType = 'wfm-media-${_mediaSeq++}';
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
    if (audio) {
      return web.HTMLAudioElement()
        ..src = url
        ..controls = true
        ..style.width = '100%';
    }
    return web.HTMLVideoElement()
      ..src = url
      ..controls = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.background = '#000';
  });
  return HtmlElementView(viewType: viewType);
}

Future<void> uploadAvatarPicked(Api api, PickedFile f) async {
  final file = f.file;
  if (file == null) {
    await api.uploadAvatar(f.bytes);
    return;
  }
  const base = String.fromEnvironment('WFM_API');
  final done = Completer<void>();
  final xhr = web.XMLHttpRequest();
  xhr.open('PUT', '$base/api/me/avatar');
  if (api.csrf.isNotEmpty) xhr.setRequestHeader('x-csrf-token', api.csrf);
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
    out.add(PickedFile('$prefix${f.name}', Uint8List(0), file: f));
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
