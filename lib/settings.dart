import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api.dart';
import 'main.dart';
import 'platform.dart';
import 'util.dart';
import 'version_check.dart';

final langNames = <Locale?, String>{
  null: '',
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
  bool _savingProxies = false;
  UpdateResult _update = UpdateResult.idle;
  AppUpdate? _latest;
  String _version = '';

  @override
  void initState() {
    super.initState();
    if (Api.i.user?.isOwner ?? false) {
      Api.i.serverSettings().then((v) {
        if (mounted) setState(() => _proxies = v);
      }).catchError((_) {});
    }
    Api.i.serverVersion().then((v) {
      if (mounted) setState(() => _version = v);
    }).catchError((_) {});
  }

  Future<void> _saveProxies(String value) async {
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
    final l10n = context.l10n;
    final cur = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.changePassword),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: cur,
                obscureText: true,
                decoration: dec(l10n.currentPassword)),
            const SizedBox(height: 8),
            TextField(
                controller: next,
                obscureText: true,
                decoration: dec(l10n.newPassword)),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.save)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.changePassword(cur.text, next.text);
      if (mounted) snack(context, context.l10n.passwordChanged, good: true);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final app = context.findAncestorStateOfType<WfmAppState>()!;
    final u = Api.i.user!;
    final proxies = TextEditingController(text: _proxies);
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(l10n.settings, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(u.name.isEmpty ? u.username : u.name),
        subtitle: Text(l10n.userLine(
            '${u.username}${u.studentId.isNotEmpty ? '  ·  ${u.studentId}' : ''}  ·  ${u.role}',
            fmtAgo(l10n, u.lastLogin))),
        trailing: TextButton.icon(
          onPressed: _changePassword,
          icon: const Icon(Icons.key, size: 16),
          label: Text(l10n.changePassword),
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<Locale?>(
        initialValue: app.appLocale,
        decoration: dec(l10n.language),
        items: [
          for (final e in langNames.entries)
            DropdownMenuItem(
                value: e.key,
                child: Text(e.key == null ? l10n.langSystem : e.value)),
        ],
        onChanged: (v) => app.setLocale(v),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<AppTheme>(
          segments: [
            ButtonSegment(
                value: AppTheme.system, label: Text(l10n.themeSystem)),
            ButtonSegment(value: AppTheme.light, label: Text(l10n.themeLight)),
            ButtonSegment(value: AppTheme.dark, label: Text(l10n.themeDark)),
            ButtonSegment(value: AppTheme.oled, label: Text(l10n.themeOled)),
          ],
          selected: {app.appTheme},
          onSelectionChanged: (s) => app.setTheme(s.first),
        ),
      ),
      if (u.isOwner && _proxies != null) ...[
        const SizedBox(height: 24),
        Text(l10n.serverSection,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: proxies,
          decoration: dec(l10n.trustedProxies, l10n.trustedProxiesHint),
          onSubmitted: _saveProxies,
        ),
        const SizedBox(height: 4),
        Text(l10n.trustedProxiesHelp,
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            onPressed: _savingProxies ? null : () => _saveProxies(proxies.text),
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
    ]);
  }
}

enum UpdateResult { idle, checking, upToDate, available, failed }
