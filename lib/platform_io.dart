import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart' as wvw;

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

/// Open the FilmCraft editor: a webview window on Windows/macOS, the system
/// browser elsewhere. Either way the one-time handoff URL carries the session.
Future<void> openEditor(BuildContext context, Api api, String url) async {
  final t = openEditorForTesting;
  if (t != null) {
    t(url);
    return;
  }
  var to = url;
  if (to.startsWith(api.baseUrl)) to = to.substring(api.baseUrl.length);
  final u = await api.handoffUrl(to);
  if (!context.mounted) return;
  if (Platform.isWindows || Platform.isMacOS) {
    // coverage:ignore-start
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => EditorPage(url: u)));
    // coverage:ignore-end
  } else {
    unawaited(launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication)
        .onError((_, __) => false));
  }
}

Future<List<PickedFile>> pickFiles({String? accept}) async {
  final test = pickFilesForTesting;
  if (test != null) return test();
  // coverage:ignore-start
  final r = await fp.FilePicker.pickFiles();
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

/// Full-window page hosting the platform webview pointed at the handoff URL.
// coverage:ignore-start
class EditorPage extends StatelessWidget {
  final String url;
  const EditorPage({super.key, required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('FilmCraft')),
        body: Platform.isMacOS
            ? InAppWebView(initialUrlRequest: URLRequest(url: WebUri(url)))
            : EditorWebViewWindows(url: url),
      );
}

class EditorWebViewWindows extends StatefulWidget {
  final String url;
  const EditorWebViewWindows({super.key, required this.url});

  @override
  State<EditorWebViewWindows> createState() => _EditorWebViewWindowsState();
}

class _EditorWebViewWindowsState extends State<EditorWebViewWindows> {
  final _ctl = wvw.WebviewController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctl.initialize().then((_) async {
      await _ctl.loadUrl(widget.url);
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) => _ready
      ? wvw.Webview(_ctl)
      : const Center(child: CircularProgressIndicator());
}
// coverage:ignore-end
