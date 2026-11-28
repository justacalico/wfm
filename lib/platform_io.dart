import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

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

Future<void> Function()? initNativeWindowForTesting;
Future<bool> Function()? windowIsMaximizedForTesting;
Future<void> Function()? windowMinimizeForTesting;
Future<bool> Function()? windowToggleMaximizeForTesting;
Future<void> Function()? windowCloseForTesting;
Future<bool> Function()? windowIsFullScreenForTesting;

Future<void> initNativeWindow() =>
    initNativeWindowForTesting?.call() ?? _initNativeWindow();
Future<bool> windowIsMaximized() =>
    windowIsMaximizedForTesting?.call() ?? windowManager.isMaximized();
Future<void> windowMinimize() =>
    windowMinimizeForTesting?.call() ?? windowManager.minimize();
Future<bool> windowToggleMaximize() =>
    windowToggleMaximizeForTesting?.call() ?? _toggleMaximize();
Future<void> windowClose() =>
    windowCloseForTesting?.call() ?? windowManager.close();
Future<bool> windowIsFullScreen() =>
    windowIsFullScreenForTesting?.call() ?? windowManager.isFullScreen();

// coverage:ignore-start
Future<void> _showWindow() async {
  await windowManager.show();
  await windowManager.focus();
}

Future<void> _initNativeWindow() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
        const WindowOptions(title: 'WFM', titleBarStyle: TitleBarStyle.hidden),
        _showWindow);
  } on MissingPluginException {
    return;
  }
}

Future<bool> _toggleMaximize() async => await windowManager.isMaximized()
    ? windowManager.unmaximize().then((_) => false)
    : windowManager.maximize().then((_) => true);
// coverage:ignore-end

Widget nativeTitleBar() => const NativeTitleBar();

class NativeTitleBar extends StatefulWidget {
  const NativeTitleBar({super.key});
  @override
  State<NativeTitleBar> createState() => _NativeTitleBarState();
}

class _NativeTitleBarState extends State<NativeTitleBar> with WindowListener {
  bool _max = false, _full = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowIsMaximized()
        .then((v) => mounted ? setState(() => _max = v) : null)
        .catchError((_) {});
    windowIsFullScreen()
        .then((v) => mounted ? setState(() => _full = v) : null)
        .catchError((_) {});
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() => setState(() => _full = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _full = false);

  @override
  Widget build(BuildContext context) {
    if (_full) return const SizedBox.shrink();
    final c = Theme.of(context).colorScheme;
    return Material(
      color: c.surfaceContainerHighest,
      child: SizedBox(
        height: 40,
        child: Row(children: [
          Expanded(
              child: DragToMoveArea(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        Image.asset('assets/icon.png', width: 18, height: 18),
                        const SizedBox(width: 8),
                        Text('WFM',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.onSurface.withValues(alpha: 0.7))),
                      ])))),
          _btn(Icons.remove, () => windowMinimize().catchError((_) {})),
          _btn(
              _max ? Icons.filter_none : Icons.crop_square_outlined,
              () => windowToggleMaximize()
                  .then((v) => mounted ? setState(() => _max = v) : null)
                  .catchError((_) {})),
          _btn(Icons.close, () => windowClose().catchError((_) {})),
        ]),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) => InkWell(
      onTap: onTap,
      child: SizedBox(
          width: 46,
          height: 40,
          child: Icon(icon,
              size: 18,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7))));
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

CraftRunner? craftRunnerForTesting;
CraftRunner? _runner;
CraftRunner runnerFor(Api api) {
  final test = craftRunnerForTesting;
  if (test != null) return test;
  return _runner ??= CraftRunner(api);
}

/// Where bundled helper binaries live: the packaged app's `craft/` folder
/// first, then the repo's `desktop/craft/` staging dir for dev runs.
String? craftDirForTesting;
Future<Directory?> craftDir() async {
  final test = craftDirForTesting;
  if (test != null) return test.isEmpty ? null : Directory(test);
  final env = Platform.environment['WFM_CRAFT_DIR'];
  // coverage:ignore-start
  if (env != null && env.isNotEmpty) return Directory(env);
  // coverage:ignore-end
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
Future<Directory> appSupport() async {
  if (appSupportForTesting != null) return appSupportForTesting!;
  // coverage:ignore-start
  return getApplicationSupportDirectory();
  // coverage:ignore-end
}

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

  final navCtx = Navigator.of(context, rootNavigator: true).context;
  try {
    await runnerFor(api).open(
        'filmcraft', pid, await checkoutDirFor(api, pid), exe,
        dataDir: (await craftDataDirFor(api, pid)).path,
        pullMedia: false,
        takeOver: (detail) async =>
            context.mounted &&
            await confirm(
                context, l10n.editLockTitle, l10n.editLockHeld(detail)),
        lockLost: (run) =>
            snack(context.mounted ? context : navCtx, l10n.editLockLost),
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
