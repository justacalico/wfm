import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';

class PickedFile {
  final String name;
  final Uint8List bytes;
  final String? path;
  final int size;
  PickedFile(this.name, this.bytes, {this.path, int? size})
      : size = size ?? bytes.length;
}

void Function(String url)? openExternalForTesting;
void Function(String url)? openEditorForTesting;
Future<List<PickedFile>> Function()? pickFilesForTesting;

Future<void> openExternal(String url) async {
  final f = openExternalForTesting;
  if (f != null) {
    f(url);
    return;
  }
  var u = url;
  final api = Api.i;
  if (u.startsWith('${api.baseUrl}/api/')) {
    u = await api.handoffUrl(u.substring(api.baseUrl.length));
  }
  unawaited(launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)
      .onError((_, __) => false));
}

/// Open a craft editor in the system browser, swapped for a one-shot handoff
/// URL so the session carries over.
Future<void> openEditor(BuildContext context, Api api, String url,
    {String? projectName}) async {
  final t = openEditorForTesting;
  if (t != null) {
    t(url);
    return;
  }
  var to = url;
  if (to.startsWith(api.baseUrl)) to = to.substring(api.baseUrl.length);
  final u = await api.handoffUrl(to);
  unawaited(launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)
      .onError((_, __) => false));
}

Future<List<PickedFile>> pickFiles({List<String>? exts}) async {
  final test = pickFilesForTesting;
  if (test != null) return test();
  // coverage:ignore-start
  final r = await fp.FilePicker.pickFiles(
      type: exts == null ? fp.FileType.any : fp.FileType.custom,
      allowedExtensions: exts);
  final out = <PickedFile>[];
  for (final f in r) {
    final p = f.path;
    if (p != null) {
      out.add(PickedFile(f.name, Uint8List(0),
          path: p, size: await f.length() ?? 0));
    }
  }
  return out;
  // coverage:ignore-end
}

/// Upload a picked file. File-backed picks stream off disk through the chunked
/// upload path instead of loading the file into memory.
Future<void> uploadPicked(Api api, String pid, String path, PickedFile f,
    [void Function(int sent, int total)? onProgress]) async {
  final disk = f.path;
  if (disk == null) {
    onProgress?.call(0, f.bytes.length);
    await api.upload(pid, path, f.bytes);
    onProgress?.call(f.bytes.length, f.bytes.length);
    return;
  }
  final raf = await File(disk).open();
  try {
    await api.uploadChunked(pid, path, f.size, (a, b) async {
      await raf.setPosition(a);
      return raf.read(b - a);
    }, onProgress);
  } finally {
    await raf.close();
  }
}

Future<void> uploadAvatarPicked(Api api, PickedFile f) async {
  final disk = f.path;
  if (disk == null) return api.uploadAvatar(f.bytes);
  await api.uploadAvatar(await File(disk).readAsBytes());
}

void installDropHandler(void Function(List<PickedFile>) onDrop) {}

Widget Function(String url, bool audio)? mediaPlayerForTesting;

/// Inline media player for the preview modal. Native builds have no media
/// element, so the fallback offers an external-open button instead.
Widget mediaPlayer(String url,
    {required bool audio, required String openLabel}) {
  final t = mediaPlayerForTesting;
  if (t != null) return t(url, audio);
  return Center(
      child: TextButton.icon(
          onPressed: () => openExternal(url),
          icon: const Icon(Icons.play_circle_outline, size: 40),
          label: Text(openLabel)));
}
