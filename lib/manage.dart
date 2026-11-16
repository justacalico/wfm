import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'util.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final tabs = <(String, Widget)>[
      if (Api.i.caps.manage) ('Accounts', const AccountsTab()),
      if (Api.i.caps.audit) ('Activity', const AuditTab()),
      if (Api.i.user?.isAdmin ?? false) ('Render nodes', const NodesTab()),
    ];
    if (tabs.isEmpty) return const Center(child: Text('Nothing to manage.'));
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage'),
          bottom: TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        ),
        body: TabBarView(children: [for (final t in tabs) t.$2]),
      ),
    );
  }
}

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});
  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  List<User>? _users;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _users = await Api.i.accounts();
      setState(() {});
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final name = TextEditingController(), user = TextEditingController(),
        pass = TextEditingController(), sid = TextEditingController(), note = TextEditingController();
    String role = Api.i.caps.creatable.contains('student') ? 'student' : Api.i.caps.creatable.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('New account'),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: dec('Name')),
              const SizedBox(height: 8),
              TextField(controller: user, decoration: dec('Username')),
              const SizedBox(height: 8),
              TextField(controller: pass, obscureText: true, decoration: dec('Password')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: dec('Role'),
                items: [for (final r in Api.i.caps.creatable) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => ss(() => role = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: sid, decoration: dec('Student ID (optional)')),
              const SizedBox(height: 8),
              TextField(controller: note, maxLength: 20, decoration: dec('Note (max 20 chars)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.i.createAccount({
        'username': user.text.trim(),
        'password': pass.text,
        'name': name.text.trim(),
        'role': role,
        'studentId': sid.text.trim(),
        'note': note.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _reset(User u) async {
    final pw = await promptText(context, 'Reset password: ${u.username}', 'New password');
    if (pw == null || pw.isEmpty || !mounted) return;
    try {
      await Api.i.resetPassword(u.id, pw);
      if (mounted) snack(context, 'Password reset');
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err.isNotEmpty) return Center(child: Text(_err));
    final users = _users;
    return Scaffold(
      floatingActionButton: Api.i.caps.creatable.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _create, icon: const Icon(Icons.person_add), label: const Text('New account')),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (c, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(u.username.substring(0, 1).toUpperCase())),
                  title: Text('${u.name.isEmpty ? u.username : u.name}  ·  ${u.role}${u.disabled ? "  (disabled)" : ""}'),
                  subtitle: Text('@${u.username}${u.studentId.isNotEmpty ? " · ${u.studentId}" : ""}${u.note.isNotEmpty ? " · ${u.note}" : ""}  ·  last login ${fmtAgo(u.lastLogin)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.key), tooltip: 'Reset password', onPressed: () => _reset(u)),
                    IconButton(
                      icon: Icon(u.disabled ? Icons.play_circle_outline : Icons.block),
                      tooltip: u.disabled ? 'Enable' : 'Disable',
                      onPressed: () async {
                        try {
                          await Api.i.setDisabled(u.id, !u.disabled);
                          _load();
                        } catch (e) {
                          if (context.mounted) snack(context, e);
                        }
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class AuditTab extends StatefulWidget {
  const AuditTab({super.key});
  @override
  State<AuditTab> createState() => _AuditTabState();
}

class _AuditTabState extends State<AuditTab> {
  List<AuditEntry>? _items;
  String _scope = 'account';
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.audit(scope: _scope);
      setState(() => _items = v);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          SegmentedButton<String>(
            segments: [
              const ButtonSegment(value: 'account', label: Text('Accounts')),
              if (Api.i.user?.isOwner ?? false) const ButtonSegment(value: 'project', label: Text('Projects')),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              _scope = s.first;
              _items = null;
              _load();
            },
          ),
          const Spacer(),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _err.isNotEmpty
            ? Center(child: Text(_err))
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const Center(child: Text('Nothing recorded yet.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (c, i) {
                          final e = items[i];
                          return ListTile(
                            dense: true,
                            title: Text('${e.actor}  ·  ${e.action}${e.target.isNotEmpty ? '  ·  ${e.target}' : ''}'),
                            subtitle: e.detail.isEmpty ? null : Text(e.detail),
                            trailing: Text(fmtTime(e.ts), style: Theme.of(c).textTheme.bodySmall),
                          );
                        },
                      ),
      ),
    ]);
  }
}

class NodesTab extends StatefulWidget {
  const NodesTab({super.key});
  @override
  State<NodesTab> createState() => _NodesTabState();
}

class _NodesTabState extends State<NodesTab> {
  List<RenderNode>? _nodes;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final n = await Api.i.nodes();
      setState(() => _nodes = n);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final name = await promptText(context, 'New render node', 'Node name');
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final n = await Api.i.createNode(name);
      _load();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Node "${n['name']}" created'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Save this token, it is shown once. Start the node with:'),
            const SizedBox(height: 8),
            SelectableText('wfm --worker <server-url> ${n['token']} ${n['name']}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
        ),
      );
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err.isNotEmpty) return Center(child: Text(_err));
    final nodes = _nodes;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _create, icon: const Icon(Icons.add), label: const Text('New node')),
      body: nodes == null
          ? const Center(child: CircularProgressIndicator())
          : nodes.isEmpty
              ? const Center(child: Text('No render nodes. Local workers on the server still run.'))
              : ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (c, i) {
                    final n = nodes[i];
                    final stale = DateTime.now().millisecondsSinceEpoch ~/ 1000 - n.lastSeen > 120;
                    return ListTile(
                      leading: Icon(Icons.dns_outlined,
                          color: n.disabled ? Colors.grey : (stale ? Colors.orange : Colors.green)),
                      title: Text('${n.name}${n.disabled ? "  (disabled)" : ""}'),
                      subtitle: Text('last seen ${fmtAgo(n.lastSeen)}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: Icon(n.disabled ? Icons.play_circle_outline : Icons.pause_circle_outline),
                          tooltip: n.disabled ? 'Enable' : 'Disable',
                          onPressed: () async {
                            try {
                              await Api.i.setNodeDisabled(n.id, !n.disabled);
                              _load();
                            } catch (e) {
                              if (context.mounted) snack(context, e);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Delete',
                          onPressed: () async {
                            if (!await confirm(context, 'Delete node', 'Delete node "${n.name}"?')) return;
                            try {
                              await Api.i.deleteNode(n.id);
                              _load();
                            } catch (e) {
                              if (context.mounted) snack(context, e);
                            }
                          },
                        ),
                      ]),
                    );
                  },
                ),
    );
  }
}
