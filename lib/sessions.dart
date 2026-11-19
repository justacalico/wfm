import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'util.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});
  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  List<SessionInfo>? _sessions;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.sessions();
      if (mounted) {
        setState(() {
          _sessions = v;
          _err = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _revoke(SessionInfo se) async {
    if (!await confirm(
        context, context.l10n.revoke, context.l10n.revokeSessionBody)) {
      return;
    }
    try {
      await Api.i.revokeSession(se.id);
      if (mounted) {
        setState(() => _sessions!.removeWhere((x) => x.id == se.id));
      }
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sessions)),
      body: _err.isNotEmpty
          ? errorView(context, _err, _load)
          : sessions == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(24), children: [
                  for (final se in sessions)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.devices_outlined, size: 18),
                      title: Text(se.ua.isEmpty ? '—' : se.ua,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Text([
                        if (se.current) l10n.currentSession,
                        if (se.ip.isNotEmpty) se.ip,
                        if (se.lastSeen > 0)
                          l10n.sessionLastSeen(fmtAgo(l10n, se.lastSeen)),
                      ].join('  ·  ')),
                      trailing: se.current
                          ? null
                          : TextButton(
                              onPressed: () => _revoke(se),
                              child: Text(l10n.revoke)),
                    ),
                ]),
    );
  }
}
