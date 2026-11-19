import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'main.dart';
import 'platform.dart';
import 'util.dart';
import 'version_check.dart';

final langNames = <Locale?, String>{
  null: '',
  Locale('en'): 'English',
  Locale('en', 'GB'): 'Traditional English',
  Locale('zh'): '简体中文',
  Locale('ru'): 'Русский',
  Locale('ga'): 'Gaeilge',
};

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _proxies;
  final _proxiesCtl = TextEditingController();
  bool _savingProxies = false;
  UpdateResult _update = UpdateResult.idle;
  AppUpdate? _latest;
  String _version = '';
  List<SessionInfo>? _sessions;

  @override
  void initState() {
    super.initState();
    if (Api.i.user?.isOwner ?? false) {
      Api.i.serverSettings().then((v) {
        if (mounted) {
          setState(() {
            _proxies = v;
            _proxiesCtl.text = v;
          });
        }
      }).catchError((_) {});
    }
    Api.i.serverVersion().then((v) {
      if (mounted) setState(() => _version = v);
    }).catchError((_) {});
    Api.i.sessions().then((v) {
      if (mounted) setState(() => _sessions = v);
    }).catchError((_) {});
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
  void dispose() {
    _proxiesCtl.dispose();
    super.dispose();
  }

  Future<void> _saveProxies() async {
    final value = _proxiesCtl.text;
    setState(() => _savingProxies = true);
    try {
      await Api.i.saveSettings(value);
      if (mounted) {
        _proxies = value;
        snack(context, context.l10n.settingsSaved, good: true);
      }
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      if (mounted) setState(() => _savingProxies = false);
    }
  }

  Future<void> _checkUpdates() async {
    if (_update == UpdateResult.checking) return;
    setState(() => _update = UpdateResult.checking);
    try {
      final checker = UpdateChecker.factoryForTesting?.call() ??
          UpdateChecker(http.Client());
      final u = await checker.check(_version);
      if (mounted) {
        setState(() {
          _latest = u;
          _update = u == null ? UpdateResult.upToDate : UpdateResult.available;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _update = UpdateResult.failed);
    }
  }

  Future<void> _changePassword() async {
    final r = await showDialog<(String, String)>(
        context: context, builder: (_) => const _PasswordDialog());
    if (r == null || !mounted) return;
    try {
      await Api.i.changePassword(r.$1, r.$2);
      if (mounted) snack(context, context.l10n.passwordChanged, good: true);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = Api.i.user;
    if (u == null) return const SizedBox.shrink();
    final app = context.findAncestorStateOfType<WfmAppState>()!;
    final tight = MediaQuery.sizeOf(context).width < 720;
    return ListView(padding: const EdgeInsets.all(24), children: [
      if (!tight) ...[
        Text(l10n.settings, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
      ],
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(u.name.isEmpty ? u.username : u.name),
        subtitle: Text(
            '@${u.username}${u.studentId.isNotEmpty ? '  ·  ${u.studentId}' : ''}  ·  ${u.role}'),
        trailing: tight
            ? null
            : TextButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.key, size: 16),
                label: Text(l10n.changePassword),
              ),
      ),
      if (tight)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.key, size: 16),
            label: Text(l10n.changePassword),
          ),
        ),
      const SizedBox(height: 16),
      if (_sessions != null) ...[
        const SizedBox(height: 16),
        Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.sessions,
                style: Theme.of(context).textTheme.titleSmall)),
        for (final se in _sessions!)
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
                    onPressed: () => _revoke(se), child: Text(l10n.revoke)),
          ),
      ],
      AnimatedBuilder(
        animation: Listenable.merge([app.themeCtl, app.localeCtl]),
        builder: (context, _) => Column(children: [
          DropdownButtonFormField<Locale?>(
            isExpanded: true,
            initialValue: app.appLocale,
            decoration: dec(l10n.language),
            items: [
              for (final e in langNames.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text(e.key == null ? l10n.langSystem : e.value)),
            ],
            onChanged: (v) {
              app.setLocale(v);
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
          const SizedBox(height: 16),
          if (tight)
            Align(alignment: Alignment.centerLeft, child: themeMenu(app, l10n))
          else
            DropdownButtonFormField<AppTheme>(
              isExpanded: true,
              initialValue: app.appTheme,
              decoration: dec(l10n.theme),
              items: [
                for (final (t, label) in [
                  (AppTheme.system, l10n.themeSystem),
                  (AppTheme.light, l10n.themeLight),
                  (AppTheme.dark, l10n.themeDark),
                  (AppTheme.oled, l10n.themeOled),
                ])
                  DropdownMenuItem(value: t, child: Text(label)),
              ],
              onChanged: (v) {
                if (v != null) app.setTheme(v);
                FocusManager.instance.primaryFocus?.unfocus();
              },
            ),
        ]),
      ),
      if (u.isOwner && _proxies != null) ...[
        const SizedBox(height: 24),
        Text(l10n.serverSection,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _proxiesCtl,
          decoration: dec(l10n.trustedProxies, l10n.trustedProxiesHint),
          onSubmitted: (_) => _saveProxies(),
        ),
        const SizedBox(height: 4),
        Text(l10n.trustedProxiesHelp,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _savingProxies ? null : _saveProxies,
            child: Text(l10n.save),
          ),
        ),
      ],
      const SizedBox(height: 24),
      ListTile(
        leading: const Icon(Icons.system_update_outlined),
        title: Text(l10n.checkUpdates),
        subtitle: Text(switch (_update) {
          UpdateResult.idle =>
            _version.isEmpty ? '' : l10n.versionLabel(_version),
          UpdateResult.checking => l10n.checking,
          UpdateResult.upToDate => l10n.upToDate(_version),
          UpdateResult.available =>
            l10n.updateAvailable(_latest?.version ?? ''),
          UpdateResult.failed => l10n.checkFailed,
        }),
        trailing: _update == UpdateResult.available && _latest != null
            ? TextButton(
                onPressed: () {
                  try {
                    openExternal(_latest!.url);
                  } catch (e) {
                    if (context.mounted) snack(context, e);
                  }
                },
                child: Text(l10n.viewRelease))
            : (_update == UpdateResult.checking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : null),
        onTap: _update == UpdateResult.checking ? null : _checkUpdates,
      ),
      ListTile(
        leading: const Icon(Icons.balance_outlined),
        title: Text(l10n.licenseAgpl),
        trailing: TextButton(
          onPressed: () {
            try {
              openExternal('https://gitlab.com/HttpAnimations/wfm');
            } catch (e) {
              if (context.mounted) snack(context, e);
            }
          },
          child: Text(l10n.viewOnGitlab),
        ),
        onTap: () async {
          final text = await rootBundle.loadString('LICENSE');
          if (!context.mounted) return;
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(ctx.l10n.license),
              content: SizedBox(
                width: 600,
                child: SingleChildScrollView(
                  child: SelectableText(text),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(ctx.l10n.done),
                ),
              ],
            ),
          );
        },
      ),
    ]);
  }
}

enum UpdateResult { idle, checking, upToDate, available, failed }

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog();
  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _cur = TextEditingController(), _next = TextEditingController();

  @override
  void dispose() {
    _cur.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.changePassword),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _cur,
              obscureText: true,
              decoration: dec(l10n.currentPassword),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          TextField(
              controller: _next,
              obscureText: true,
              decoration: dec(l10n.newPassword),
              onChanged: (_) => setState(() {})),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
            onPressed: _cur.text.isNotEmpty && validPassword(_next.text)
                ? () => Navigator.pop(context, (_cur.text, _next.text))
                : null,
            child: Text(l10n.save)),
      ],
    );
  }
}
