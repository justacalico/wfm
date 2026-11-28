import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'main.dart';
import 'platform.dart';

String? appVersionForTesting;
Future<String> appVersion() async =>
    appVersionForTesting ?? (await PackageInfo.fromPlatform()).version;

/// Where updates live: the GitHub mirror's releases, tagged v{server}.
String releaseUrl(String version) =>
    'https://github.com/justacalico/wfm/releases/tag/v$version';

String normalizeServerUrl(String raw) {
  var u = raw.trim();
  if (u.isEmpty) return u;
  if (!u.contains('://')) u = 'http://$u';
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// (matches, server version). The native app may only run the same release
/// as the server it talks to.
Future<(bool, String)> serverMatches(Api api) async {
  final server = await api.serverVersion();
  final mine = await appVersion();
  return (mine.isNotEmpty && server == mine, server);
}

/// The native-only part of the gate: resolves the saved server and session,
/// then enforces the version match. Returns a page when the normal gate
/// should not run.
Future<Widget?> nativeGate(Api api) async {
  final prefs = await SharedPreferences.getInstance();
  final server = prefs.getString('server');
  if (server == null || server.isEmpty) return const ConnectPage();
  api.baseUrl = server;
  api.sessionToken = prefs.getString('session') ?? '';
  final (ok, ver) = await serverMatches(api);
  if (!ok) return UpdatePage(serverVersion: ver);
  return null;
}

Future<void> changeServer(BuildContext context) async {
  (await SharedPreferences.getInstance()).remove('server');
  if (context.mounted) {
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConnectPage()), (_) => false);
  }
}

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key});
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _url = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final url = normalizeServerUrl(_url.text);
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try {
      Api.i.baseUrl = url;
      final (ok, ver) = await serverMatches(Api.i);
      if (!mounted) return;
      if (!ok) {
        Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => UpdatePage(serverVersion: ver)));
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('server', url);
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const Gate()));
      }
    } catch (e) {
      if (mounted) snack(context, context.l10n.notAWfmServer);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, actions: const [
        Padding(padding: EdgeInsets.only(right: 8), child: AuthPickers()),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/icon.png', width: 36, height: 36),
                  const SizedBox(width: 10),
                  Text(l10n.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium),
                ]),
                const SizedBox(height: 24),
                Text(l10n.connectSubtitle, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                TextField(
                    controller: _url,
                    decoration:
                        dec(l10n.serverAddress, 'https://wfm.school.example'),
                    autofocus: true,
                    keyboardType: TextInputType.url,
                    onSubmitted: (_) => _go()),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _go,
                    child: Text(_busy ? l10n.connecting : l10n.connect)),
              ]),
        ),
      ),
    );
  }
}

/// Blocks the app when the server runs a different release; the only ways
/// out are updating the app or pointing it at another server.
class UpdatePage extends StatefulWidget {
  final String serverVersion;
  const UpdatePage({super.key, required this.serverVersion});
  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  bool _busy = false;
  String _mine = '';

  @override
  void initState() {
    super.initState();
    appVersion().then((v) {
      if (mounted) setState(() => _mine = v);
    });
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    try {
      final (ok, _) = await serverMatches(Api.i);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const Gate()));
      } else {
        snack(context, context.l10n.updateStillRequired);
      }
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.system_update_alt, size: 40),
              const SizedBox(height: 12),
              Text(l10n.updateRequired,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  l10n.updateRequiredBody(
                      widget.serverVersion.isEmpty ? '?' : widget.serverVersion,
                      _mine.isEmpty ? '?' : _mine),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton(
                    onPressed: _busy
                        ? null
                        : () => openExternal(releaseUrl(widget.serverVersion)),
                    child: Text(l10n.downloadUpdate)),
                OutlinedButton(
                    onPressed: _busy ? null : _check,
                    child: Text(_busy ? l10n.checking : l10n.checkAgain)),
                TextButton(
                    onPressed: _busy ? null : () => changeServer(context),
                    child: Text(l10n.changeServer)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
