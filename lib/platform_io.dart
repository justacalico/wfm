import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart' as wvw;

import 'api.dart';
import 'craft/runner.dart';
import 'main.dart' show L10n, snack;

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

/// Open a craft editor. In `native` mode (Settings > Editor mode) a bundled
/// upstream binary is spawned on a local checkout; otherwise the web editor
/// opens in a webview on Windows/macOS or the system browser on Linux.
Future<void> openEditor(BuildContext context, Api api, String url,
    {String? projectName}) async {
  final t = openEditorForTesting;
  if (t != null) {
    t(url);
    return;
  }
  final prefs = await SharedPreferences.getInstance();
  final parsed = Uri.parse(url);
  final segs = parsed.pathSegments;
  final i = segs.indexOf('wfm.html');
  final craft = i > 0 ? segs[i - 1] : '';
  final isEditor =
      craft.isNotEmpty && !parsed.queryParameters.containsKey('render');
  if ((prefs.getString('craftMode') ?? 'web') == 'native' &&
      isEditor &&
      context.mounted) {
    return _openNative(context, api, parsed, craft, prefs, projectName);
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

CraftRunner? _runner;
CraftRunner? runnerForTesting;
String Function(String craft)? craftExeForTesting;
Future<void> Function(Directory, CraftRun)? writeRunFileForTesting;

CraftRunner craftRunner(Api api) {
  final r = runnerForTesting;
  if (r != null) return r;
  // coverage:ignore-start
  return _runner ??= CraftRunner(api);
  // coverage:ignore-end
}

/// Kill open craft processes, flush their checkouts and drop their locks
/// before the window goes away.
Future<void> shutdownCrafts() {
  final r = runnerForTesting ?? _runner;
  return r?.shutdownAll() ?? Future.value();
}

/// `~/WFM/Projects` on every desktop OS.
Map<String, String>? envForTesting;

String defaultCheckoutRoot() => p.join(
    (envForTesting ?? Platform.environment)['HOME'] ??
        (envForTesting ?? Platform.environment)['USERPROFILE'] ??
        Directory.current.path,
    'WFM',
    'Projects');

/// Pull the project, spawn the bundled binary, and let the runner push in
/// the background. Lock conflicts offer a takeover; anything else lands as
/// a snackbar.
Future<void> _openNative(BuildContext context, Api api, Uri u, String craft,
    SharedPreferences prefs, String? projectName) async {
  final l10n = context.l10n;
  final pid = u.queryParameters['project'] ?? '';
  final root = prefs.getString('craftDir') ?? defaultCheckoutRoot();
  final clean =
      (projectName ?? pid).replaceAll(RegExp(r'[^A-Za-z0-9._ -]'), '_');
  final checkout = Directory(p.join(root, '$clean-$pid'));
  final exe = craftExeForTesting?.call(craft) ??
      p.join(craftBundleDir().path, craftExeName(craft));
  final prog = ValueNotifier<String>(l10n.syncPulling);
  unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SyncDialog(prog)));
  String? err;
  try {
    final run = await craftRunner(api).open(craft, pid, checkout, exe,
        pullMedia: prefs.getString('importPolicy') != 'server',
        takeOver: (_) => _askTakeOver(context, craft),
        lockLost: (r) {
          if (context.mounted) snack(context, l10n.syncLockLost);
        },
        status: (phase, _, __) =>
            prog.value = phase == 'pull' ? l10n.syncPulling : l10n.syncPushing);
    await (writeRunFileForTesting ?? writeRunFile)(checkout, run);
  } on CraftOpenException catch (e) {
    err = switch (e.kind) {
      'alreadyOpen' => l10n.craftAlreadyOpen(craft),
      'missing' => l10n.craftMissing(craft),
      _ => l10n.craftLocked(craft)
    };
  } catch (e) {
    err = '$e';
  }
  if (context.mounted) {
    Navigator.of(context).pop();
    if (err != null) snack(context, err);
  }
}

Future<bool> _askTakeOver(BuildContext context, String craft) async {
  final l10n = context.l10n;
  final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
              title: Text(l10n.takeOver),
              content: Text(l10n.craftTakeOverBody(craft)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(c).pop(false),
                    child: Text(l10n.cancel)),
                FilledButton(
                    onPressed: () => Navigator.of(c).pop(true),
                    child: Text(l10n.takeOver)),
              ]));
  return r == true;
}

class _SyncDialog extends StatelessWidget {
  final ValueNotifier<String> phase;
  const _SyncDialog(this.phase);

  @override
  Widget build(BuildContext context) => AlertDialog(
          content: Row(children: [
        const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 3)),
        const SizedBox(width: 16),
        ValueListenableBuilder(
            valueListenable: phase, builder: (_, s, __) => Text(s)),
      ]));
}

/// Native craft editors only exist for the desktop OSes.
bool get supportsNativeCrafts =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

Future<String?> Function()? pickDirectoryForTesting;

Future<String?> pickDirectory() async {
  final test = pickDirectoryForTesting;
  if (test != null) return test();
  // coverage:ignore-start
  return fp.FilePicker.getDirectoryPath();
  // coverage:ignore-end
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
