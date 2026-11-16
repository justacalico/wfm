import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'util.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _changePassword(BuildContext context) async {
    final cur = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: cur, obscureText: true, decoration: dec('Current password')),
            const SizedBox(height: 8),
            TextField(controller: next, obscureText: true, decoration: dec('New password')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Change')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await Api.i.changePassword(cur.text, next.text);
      if (context.mounted) snack(context, 'Password changed');
    } catch (e) {
      if (context.mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorStateOfType<WfmAppState>()!;
    final u = Api.i.user!;
    final langs = <Locale?, String>{
      null: 'System default',
      const Locale('en', 'GB'): 'English',
      const Locale('zh', 'CN'): '简体中文',
      const Locale('ru'): 'Русский',
      const Locale('ga'): 'Gaeilge',
    };
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(u.name.isEmpty ? u.username : u.name),
        subtitle: Text('@${u.username}  ·  ${u.role}${u.studentId.isNotEmpty ? '  ·  ${u.studentId}' : ''}  ·  last login ${fmtAgo(u.lastLogin)}'),
        trailing: TextButton.icon(
          onPressed: () => _changePassword(context),
          icon: const Icon(Icons.key, size: 16),
          label: const Text('Change password'),
        ),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<Locale?>(
        initialValue: app.appLocale,
        decoration: dec('Language'),
        items: [for (final e in langs.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => app.setLocale(v),
      ),
      const SizedBox(height: 16),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {app.themeMode},
        onSelectionChanged: (s) => app.setTheme(s.first),
      ),
    ]);
  }
}
