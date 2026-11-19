import 'dart:typed_data';

import 'api.dart';

class PickedFile {
  final String name;
  final Uint8List bytes;
  const PickedFile(this.name, this.bytes);
  int get size => bytes.length;
}

void Function(String url)? openExternalForTesting;
Future<List<PickedFile>> Function()? pickFilesForTesting;

void openExternal(String url) {
  final f = openExternalForTesting;
  if (f != null) {
    f(url);
    return;
  }
  throw UnsupportedError('openExternal is only supported in the web build');
}

Future<List<PickedFile>> pickFiles() {
  final f = pickFilesForTesting;
  if (f != null) return f();
  throw UnsupportedError('pickFiles is only supported in the web build');
}

/// Upload a picked file. Non-web builds only have in-memory picks and no
/// byte-level progress, so [onProgress] gets coarse start/done marks.
Future<void> uploadPicked(Api api, String pid, String path, PickedFile f,
    [void Function(int sent, int total)? onProgress]) async {
  onProgress?.call(0, f.bytes.length);
  await api.upload(pid, path, f.bytes);
  onProgress?.call(f.bytes.length, f.bytes.length);
}

void installDropHandler(void Function(List<PickedFile>) onDrop) {}
