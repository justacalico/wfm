import 'dart:async';
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

/// Upload a picked file. File-backed picks stream via fetch()'s Blob body
/// (no full in-memory copy); byte-backed picks go through the Api client.
Future<void> uploadPicked(
    Api api, String pid, String path, PickedFile f) async {
  final file = f.file;
  if (file == null) {
    await api.upload(pid, path, f.bytes);
    return;
  }
  const base = String.fromEnvironment('WFM_API');
  final q = Uri(queryParameters: {'path': path}).query;
  final headers = web.Headers();
  if (api.csrf.isNotEmpty) headers.set('x-csrf-token', api.csrf);
  final resp = await web.window
      .fetch('$base/api/projects/$pid/files?$q'.toJS,
          web.RequestInit(method: 'PUT', body: file, headers: headers))
      .toDart;
  if (resp.status == 401) {
    api.user = null;
    throw ApiException(401, 'auth');
  }
  if (resp.status >= 400) {
    var msg = 'error ${resp.status}';
    try {
      final b = (await resp.json().toDart).dartify();
      if (b is Map && b['error'] != null) msg = '${b['error']}';
    } catch (_) {}
    throw ApiException(resp.status, msg);
  }
}
