import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'main.dart';
import 'mcp.dart';
import 'platform.dart';
import 'sessions.dart';
import 'shortcuts.dart';
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
  ServerSettings? _server;
  final _proxiesCtl = TextEditingController();
  bool _savingProxies = false;
  UpdateResult _update = UpdateResult.idle;
  AppUpdate? _latest;
  String _version = '';
  bool _editorsExternal = false;
  List<AutoShare>? _autoShares;

  @override
  void initState() {
    super.initState();
    if (Api.i.user?.isOwner ?? false) {
      Api.i.serverSettings().then((v) {
        if (mounted) {
          setState(() {
            _server = v;
            _proxiesCtl.text = v.trustedProxies;
          });
        }
      }).catchError((_) {});
    }
    Api.i.serverVersion().then((v) {
      if (mounted) setState(() => _version = v);
    }).catchError((_) {});
    if (isNativeApp) {
      SharedPreferences.getInstance().then((p) {
        if (mounted) {
          setState(
              () => _editorsExternal = p.getBool('editorsExternal') ?? false);
        }
      });
    }
    if (Api.i.caps.creatable.isNotEmpty) _loadAutoShares();
  }

  void _loadAutoShares() {
    Api.i.autoShares().then((v) {
      if (mounted) setState(() => _autoShares = v);
    }).catchError((_) {});
  }

  Future<void> _addAutoShare() async {
    final r = await showDialog<(String, String)>(
        context: context, builder: (_) => const _AutoShareDialog());
    if (r == null || !mounted) return;
    try {
      await Api.i.autoShareAdd(r.$1, r.$2);
      _loadAutoShares();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _removeAutoShare(AutoShare a) async {
    try {
      await Api.i.autoShareDelete(a.id);
      if (mounted) {
        setState(() => _autoShares!.removeWhere((x) => x.id == a.id));
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
    setState(() => _savingProxies = true);
    try {
      await Api.i.saveSettings(_proxiesCtl.text);
      if (mounted) snack(context, context.l10n.settingsSaved, good: true);
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      if (mounted) setState(() => _savingProxies = false);
    }
  }

  Future<void> _saveEnforceHttps(bool v) async {
    try {
      await Api.i.saveEnforceHttps(v);
      if (mounted) setState(() => _server!.enforceHttps = v);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _checkUpdates() async {
    if (_update == UpdateResult.checking) return;
    setState(() => _update = UpdateResult.checking);
    try {
      final checker =
          UpdateChecker.factoryForTesting?.call() ?? UpdateChecker(Api.i);
      final u = await checker.check();
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

  Future<void> _changeAvatar() async {
    try {
      final files =
          await pickFiles(exts: const ['png', 'jpg', 'jpeg', 'gif', 'webp']);
      if (files.isEmpty || !mounted) return;
      await uploadAvatarPicked(Api.i, files.first);
      await Api.i.me();
      if (!mounted) return;
      context.findAncestorStateOfType<WfmAppState>()?.userCtl.value++;
      setState(() {});
    } catch (e) {
      if (mounted) snack(context, e);
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
        leading: Tooltip(
          message: l10n.changePhoto,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _changeAvatar,
            child: CircleAvatar(
              radius: 20,
              backgroundImage: u.hasAvatar
                  ? NetworkImage(Api.i.avatarUrl(u.id, u.avatar),
                      headers: Api.i.imageHeaders)
                  : null,
              onBackgroundImageError: u.hasAvatar ? (_, __) {} : null,
              child: u.hasAvatar ? null : const Icon(Icons.person_outline),
            ),
          ),
        ),
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
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.devices_outlined, size: 18),
        title: Text(l10n.sessions),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SessionsPage())),
      ),
      const SizedBox(height: 16),
      Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.editors,
              style: Theme.of(context).textTheme.titleSmall)),
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.keyboard_outlined, size: 18),
        title: Text(l10n.filmcraftShortcuts),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ShortcutsPage())),
      ),
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.keyboard_outlined, size: 18),
        title: Text(l10n.scriptcraftShortcuts),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ShortcutsPage(app: 'scriptcraft'))),
      ),
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.keyboard_outlined, size: 18),
        title: Text(l10n.deckcraftShortcuts),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ShortcutsPage(app: 'deckcraft'))),
      ),
      if (Api.i.caps.creatable.isNotEmpty) ...[
        const SizedBox(height: 16),
        Align(
            alignment: Alignment.centerLeft,
            child: Text(l10n.autoShares,
                style: Theme.of(context).textTheme.titleSmall)),
        Text(l10n.autoSharesHint, style: Theme.of(context).textTheme.bodySmall),
        for (final a in _autoShares ?? [])
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_add_outlined, size: 18),
            title:
                Text(a.inviteeName.isEmpty ? a.inviteeUsername : a.inviteeName),
            subtitle: Text(a.level == 'edit' ? l10n.canEdit : l10n.canView),
            trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => _removeAutoShare(a)),
          ),
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
                onPressed: _addAutoShare,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.autoShareAdd))),
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
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: Api.i.chunkSize ~/ 1048576,
            decoration: dec(l10n.chunkSize),
            items: [
              for (final m in [8, 16, 32, 64, 80, 128, 256, 512])
                DropdownMenuItem(value: m, child: Text('$m MB')),
            ],
            onChanged: (v) {
              if (v == null) return;
              Api.i.chunkSize = v * 1048576;
              SharedPreferences.getInstance()
                  .then((p) => p.setInt('chunkMb', v));
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
        ]),
      ),
      if (isNativeApp)
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.open_in_browser_outlined, size: 18),
          title: Text(l10n.editorsInBrowser),
          subtitle: Text(l10n.editorsInBrowserHint),
          value: _editorsExternal,
          onChanged: (v) {
            setState(() => _editorsExternal = v);
            SharedPreferences.getInstance()
                .then((p) => p.setBool('editorsExternal', v));
          },
        ),
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.smart_toy_outlined, size: 18),
        title: Text(l10n.mcp),
        subtitle: Text(l10n.mcpSubtitle),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const McpPage())),
      ),
      if (u.isOwner && _server != null) ...[
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
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.https_outlined, size: 18),
          title: Text(l10n.enforceHttps),
          subtitle: Text(_server!.enforceHttpsLocked
              ? l10n.enforceHttpsLocked
              : l10n.enforceHttpsHint),
          value: _server!.enforceHttps,
          onChanged: _server!.enforceHttpsLocked ? null : _saveEnforceHttps,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: '${_server!.backupCount}',
          decoration: dec(l10n.backupLimit),
          items: [
            for (final n in [1, 3, 5, 6, 10, 15, 20])
              DropdownMenuItem(value: '$n', child: Text('$n')),
          ],
          onChanged: (value) async {
            final n = int.tryParse(value ?? '');
            if (n == null) return;
            try {
              await Api.i.saveBackupCount(n);
            } catch (e) {
              if (!context.mounted) return;
              snack(context, e);
            }
          },
        ),
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
                onPressed: () async {
                  try {
                    await openExternal(_latest!.url);
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
          onPressed: () async {
            try {
              await openExternal('https://gitlab.com/HttpAnimations/wfm');
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

class _AutoShareDialog extends StatefulWidget {
  const _AutoShareDialog();
  @override
  State<_AutoShareDialog> createState() => _AutoShareDialogState();
}

class _AutoShareDialogState extends State<_AutoShareDialog> {
  final _name = TextEditingController();
  String _level = 'view';

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    void submit() {
      if (_name.text.trim().isNotEmpty) {
        Navigator.pop(context, (_name.text.trim(), _level));
      }
    }

    return AlertDialog(
      title: Text(l10n.autoShareAdd),
      content: SizedBox(
        width: 320,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: dec(l10n.username),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => submit()),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _level,
            decoration: dec(l10n.share),
            items: [
              DropdownMenuItem(value: 'view', child: Text(l10n.canView)),
              DropdownMenuItem(value: 'edit', child: Text(l10n.canEdit)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _level = v);
            },
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
            onPressed: _name.text.trim().isNotEmpty ? submit : null,
            child: Text(l10n.send)),
      ],
    );
  }
}
