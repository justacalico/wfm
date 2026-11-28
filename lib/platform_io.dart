import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'craft/runner.dart';
import 'main.dart';

class PickedFile {
  final String name;
  final Uint8List bytes;
  final String? path;
  final int size;
  PickedFile(this.name, this.bytes, {this.path, int? size})
      : size = size ?? bytes.length;
}

bool get isNativeApp =>
    isNativeAppForTesting ??
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;
bool? isNativeAppForTesting;

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

CraftRunner? craftRunnerForTesting;
CraftRunner? _runner;
CraftRunner runnerFor(Api api) =>
    craftRunnerForTesting ?? (_runner ??= CraftRunner(api));

/// Where bundled helper binaries live: the packaged app's `craft/` folder
/// first, then the repo's `desktop/craft/` staging dir for dev runs.
String? craftDirForTesting;
Future<Directory?> craftDir() async {
  final test = craftDirForTesting;
  if (test != null) return test.isEmpty ? null : Directory(test);
  final env = Platform.environment['WFM_CRAFT_DIR'];
  if (env != null && env.isNotEmpty) return Directory(env);
  final beside =
      Directory(p.join(p.dirname(Platform.resolvedExecutable), 'craft'));
  if (await beside.exists()) return beside;
  final dev = Directory(p.join(Directory.current.path, 'desktop', 'craft'));
  return await dev.exists() ? dev : null;
}

Future<String> craftBinary(String name) async {
  final exe = Platform.isWindows ? '$name.exe' : name;
  final dir = await craftDir();
  return dir == null ? '' : p.join(dir.path, exe);
}

Directory? appSupportForTesting;
Future<Directory> appSupport() async =>
    appSupportForTesting ?? await getApplicationSupportDirectory();

/// A stable per-server folder name without any crypto dependency.
String serverKey(String baseUrl) =>
    baseUrl.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

Future<Directory> checkoutDirFor(Api api, String pid) async => Directory(p.join(
    (await appSupport()).path, 'checkouts', serverKey(api.baseUrl), pid));

Future<Directory> craftDataDirFor(Api api, String pid) async => Directory(p
    .join((await appSupport()).path, 'craftdata', serverKey(api.baseUrl), pid));

Future<bool> editorsInBrowser() async {
  final t = editorsInBrowserForTesting;
  if (t != null) return t;
  return (await SharedPreferences.getInstance()).getBool('editorsExternal') ??
      false;
}

bool? editorsInBrowserForTesting;

Future<void> spawnHelper(
        String exe, List<String> args, Map<String, String> env) =>
    Process.start(exe, args, environment: env, mode: ProcessStartMode.detached)
        .then((_) {});

Future<void> Function(String exe, List<String> args, Map<String, String> env)?
    spawnHelperForTesting;

/// FilmCraft runs as a real binary against a synced local checkout; the
/// other crafts open in the embedded webview helper (or the browser when
/// that is enabled or the helper is missing).
Future<void> openEditor(BuildContext context, Api api, String url,
    {String? projectName}) async {
  final t = openEditorForTesting;
  if (t != null) {
    t(url);
    return;
  }
  final uri = Uri.parse(url);
  final seg = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  final pid = uri.queryParameters['project'] ?? '';
  if (seg == 'filmcraft' &&
      pid.isNotEmpty &&
      !uri.queryParameters.containsKey('render')) {
    return _openFilmcraft(context, api, pid);
  }
  var to = url;
  if (to.startsWith(api.baseUrl)) to = to.substring(api.baseUrl.length);
  return _openHosted(api, to, projectName);
}

/// The hosted craft page, in the embedded webview helper or the system
/// browser per the user's setting.
Future<void> _openHosted(Api api, String to, String? projectName) async {
  if (await editorsInBrowser()) {
    unawaited(launchUrl(Uri.parse(await api.handoffUrl(to)),
            mode: LaunchMode.externalApplication)
        .onError((_, __) => false));
    return;
  }
  final exe = await craftBinary('wfm-webview');
  if (exe.isNotEmpty && await File(exe).exists()) {
    final spawn = spawnHelperForTesting ?? spawnHelper;
    await spawn(exe, [
      await api.handoffUrl(to),
      if (projectName != null) ...['--title', projectName],
    ], {});
    return;
  }
  unawaited(launchUrl(Uri.parse(await api.handoffUrl(to)),
          mode: LaunchMode.externalApplication)
      .onError((_, __) => false));
}

Future<void> _openFilmcraft(BuildContext context, Api api, String pid) async {
  final l10n = context.l10n;
  final exe = await craftBinary('wfm-filmcraft');
  if (exe.isEmpty || !await File(exe).exists()) {
    // No bundled editor: fall back to the hosted one.
    var to = api.projectUrl(pid);
    if (to.startsWith(api.baseUrl)) to = to.substring(api.baseUrl.length);
    return _openHosted(api, to, null);
  }
  if (!context.mounted) return;
  final status = ValueNotifier<String>(l10n.editPreparing);
  unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
              content: Row(children: [
            const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 14),
            Expanded(
                child: ValueListenableBuilder<String>(
                    valueListenable: status, builder: (_, v, __) => Text(v))),
          ]))));
  var popped = false;
  void pop() {
    if (!popped && context.mounted) {
      popped = true;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  try {
    await runnerFor(api).open(
        'filmcraft', pid, await checkoutDirFor(api, pid), exe,
        dataDir: (await craftDataDirFor(api, pid)).path,
        takeOver: (detail) async =>
            context.mounted &&
            await confirm(
                context, l10n.editLockTitle, l10n.editLockHeld(detail)),
        lockLost: (run) {
          final ctx = context.mounted
              ? context
              : context
                  .findAncestorStateOfType<WfmAppState>()
                  ?.navKey
                  .currentContext;
          if (ctx != null) snack(ctx, l10n.editLockLost);
        },
        status: (phase, done, total) =>
            status.value = l10n.editPulling(done, total));
  } on CraftOpenException catch (e) {
    pop();
    if (context.mounted) {
      snack(
          context,
          switch (e.kind) {
            'alreadyOpen' => l10n.editAlreadyOpen,
            'declined' || 'locked' => l10n.editDeclined,
            _ => l10n.editMissing,
          });
    }
    return;
  } catch (e) {
    pop();
    if (context.mounted) snack(context, e);
    return;
  }
  pop();
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
