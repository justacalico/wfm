import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'util.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tight = MediaQuery.sizeOf(context).width < 720;
    final tabs = <(String, Widget)>[
      if (Api.i.caps.manage) (l10n.accounts, const AccountsTab()),
      if (Api.i.caps.audit) (l10n.activity, const AuditTab()),
      if (Api.i.user?.isAdmin ?? false) (l10n.renderNodes, const NodesTab()),
    ];
    if (tabs.isEmpty) return Center(child: Text(l10n.nothingToManage));
    final tabBar = TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]);
    final PreferredSizeWidget appBar =
        tight ? tabBar : AppBar(title: Text(l10n.manage), bottom: tabBar);
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: appBar,
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
    final fields = await showDialog<Map<String, String>>(
        context: context, builder: (_) => const _AccountDialog());
    if (fields == null || !mounted) return;
    try {
      await Api.i.createAccount(fields);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _edit(User u) async {
    final fields = await showDialog<Map<String, String>>(
        context: context, builder: (_) => _AccountDialog(existing: u));
    if (fields == null || !mounted) return;
    try {
      await Api.i.updateAccount(u.id, fields);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _reset(User u) async {
    final pw = await promptText(
        context,
        context.l10n.resetPasswordTitle(u.username),
        context.l10n.newPassword,
        '',
        validPassword);
    if (pw == null || pw.isEmpty || !mounted) return;
    try {
      await Api.i.resetPassword(u.id, pw);
      if (mounted) snack(context, context.l10n.passwordReset, good: true);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete(User u) async {
    if (!await confirm(
        context, context.l10n.delete, context.l10n.deleteAccountBody(u.name))) {
      return;
    }
    try {
      await Api.i.deleteAccount(u.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final users = _users;
    return Scaffold(
      floatingActionButton: Api.i.caps.creatable.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.person_add),
              label: Text(l10n.newAccount)),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? Center(child: Text(l10n.noAccounts))
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (c, i) {
                    final u = users[i];
                    return ListTile(
                      leading: CircleAvatar(
                          child:
                              Text(u.username.substring(0, 1).toUpperCase())),
                      title: Text(
                          '${u.name.isEmpty ? u.username : u.name}  ·  ${u.role}${u.disabled ? l10n.disabledSuffix : ""}'),
                      subtitle: Text(l10n.userLine(
                          '${u.username}${u.studentId.isNotEmpty ? " · ${u.studentId}" : ""}${u.note.isNotEmpty ? " · ${u.note}" : ""}',
                          fmtAgo(l10n, u.lastLogin))),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: l10n.editAccount,
                            onPressed: () => _edit(u)),
                        IconButton(
                            icon: const Icon(Icons.key),
                            tooltip: l10n.resetPassword,
                            onPressed: () => _reset(u)),
                        IconButton(
                          icon: Icon(u.disabled
                              ? Icons.play_circle_outline
                              : Icons.block),
                          tooltip: u.disabled ? l10n.enable : l10n.disable,
                          onPressed: () async {
                            try {
                              await Api.i.setDisabled(u.id, !u.disabled);
                              _load();
                            } catch (e) {
                              if (context.mounted) snack(context, e);
                            }
                          },
                        ),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: l10n.delete,
                            onPressed: () => _delete(u)),
                      ]),
                    );
                  },
                ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  final User? existing;
  const _AccountDialog({this.existing});
  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _user =
      TextEditingController(text: widget.existing?.username ?? '');
  late final _sid =
      TextEditingController(text: widget.existing?.studentId ?? '');
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  final _pass = TextEditingController();
  late String _role = widget.existing?.role ??
      (Api.i.caps.creatable.contains('student')
          ? 'student'
          : Api.i.caps.creatable.first);
  late final List<String> _roles = [
    ...Api.i.caps.creatable,
    if (widget.existing != null &&
        !Api.i.caps.creatable.contains(widget.existing!.role))
      widget.existing!.role,
  ];

  @override
  void dispose() {
    for (final c in [_name, _user, _sid, _note, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.existing != null;
    final valid = validDisplayName(_name.text) &&
        validUsername(_user.text.trim()) &&
        (editing || validPassword(_pass.text));
    return AlertDialog(
      scrollable: true,
      title: Text(editing ? l10n.editAccount : l10n.newAccount),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: dec(l10n.name),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          TextField(
              controller: _user,
              decoration: dec(l10n.username),
              onChanged: (_) => setState(() {})),
          if (!editing) ...[
            const SizedBox(height: 8),
            TextField(
                controller: _pass,
                obscureText: true,
                decoration: dec(l10n.password),
                onChanged: (_) => setState(() {})),
          ],
          if (!editing || _roles.length > 1) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: dec(l10n.role),
              items: [
                for (final r in _roles)
                  DropdownMenuItem(value: r, child: Text(r))
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),
          ],
          const SizedBox(height: 8),
          TextField(controller: _sid, decoration: dec(l10n.studentIdOptional)),
          const SizedBox(height: 8),
          TextField(
              controller: _note,
              maxLength: 20,
              decoration: dec(l10n.noteOptional)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
            onPressed: valid
                ? () => Navigator.pop(context, {
                      'username': _user.text.trim(),
                      'name': _name.text.trim(),
                      'role': _role,
                      'studentId': _sid.text.trim(),
                      'note': _note.text.trim(),
                      if (!editing) 'password': _pass.text,
                    })
                : null,
            child: Text(editing ? l10n.save : l10n.create)),
      ],
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
  bool _hasMore = false;
  int _from = 0, _to = 0;
  final _action = TextEditingController();
  final _actor = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _action.dispose();
    _actor.dispose();
    super.dispose();
  }

  Future<void> _load([int offset = 0]) async {
    try {
      final v = await Api.i.audit(
          scope: _scope,
          offset: offset,
          action: _action.text,
          actor: _actor.text,
          from: _from,
          to: _to);
      setState(() {
        _items = offset == 0 ? v : [...?_items, ...v];
        _hasMore = v.length == 200;
        _err = '';
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  void _apply() {
    setState(() => _items = null);
    _load();
  }

  void _clearFilters() {
    _action.clear();
    _actor.clear();
    _from = _to = 0;
    _apply();
  }

  Future<void> _pick(bool isFrom) async {
    final now = DateTime.now();
    final d = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(2020),
        lastDate: now.add(const Duration(days: 366)));
    if (d == null || !mounted) return;
    var t = d.millisecondsSinceEpoch ~/ 1000;
    if (!isFrom) t += 86399;
    setState(() => isFrom ? _from = t : _to = t);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = _items;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'account', label: Text(l10n.accounts)),
              if (Api.i.user?.isOwner ?? false)
                ButtonSegment(value: 'project', label: Text(l10n.projects)),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              _scope = s.first;
              _items = null;
              _load();
            },
          ),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refresh,
              onPressed: _load),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                  width: 140,
                  child: TextField(
                      controller: _action,
                      decoration: InputDecoration(
                          labelText: l10n.action, isDense: true),
                      onSubmitted: (_) => _apply())),
              SizedBox(
                  width: 140,
                  child: TextField(
                      controller: _actor,
                      decoration:
                          InputDecoration(labelText: l10n.actor, isDense: true),
                      onSubmitted: (_) => _apply())),
              ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_from == 0
                      ? l10n.from
                      : '${l10n.from} ${fmtTime(l10n, _from)}'),
                  onPressed: () => _pick(true)),
              ActionChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                      _to == 0 ? l10n.to : '${l10n.to} ${fmtTime(l10n, _to)}'),
                  onPressed: () => _pick(false)),
              IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: l10n.applyFilters,
                  onPressed: _apply),
              IconButton(
                  icon: const Icon(Icons.filter_alt_off),
                  tooltip: l10n.clearFilters,
                  onPressed: _clearFilters),
            ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _err.isNotEmpty
            ? errorView(context, _err, () => _load())
            : items == null
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? Center(child: Text(l10n.nothingRecorded))
                    : ListView.builder(
                        itemCount: items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (c, i) {
                          if (i == items.length) {
                            return Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: TextButton(
                                        onPressed: () => _load(items.length),
                                        child: Text(l10n.loadMore))));
                          }
                          final e = items[i];
                          return ListTile(
                            dense: true,
                            title: Text(
                                '${e.actor}  ·  ${e.action}${e.target.isNotEmpty ? '  ·  ${e.target}' : ''}'),
                            subtitle: e.detail.isEmpty ? null : Text(e.detail),
                            trailing: Text(fmtTime(l10n, e.ts),
                                style: Theme.of(c).textTheme.bodySmall),
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
    final name =
        await promptText(context, context.l10n.newNode, context.l10n.nodeName);
    if (name == null || name.isEmpty || !mounted) return;
    final l10n = context.l10n;
    try {
      final n = await Api.i.createNode(name);
      _load();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.nodeCreatedTitle(n['name'])),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.nodeTokenNote),
                const SizedBox(height: 8),
                SelectableText(
                    'wfm --worker <server-url> ${n['token']} ${n['name']}',
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ]),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: Text(l10n.done))
          ],
        ),
      );
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final nodes = _nodes;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: Text(l10n.newNode)),
      body: nodes == null
          ? const Center(child: CircularProgressIndicator())
          : nodes.isEmpty
              ? Center(child: Text(l10n.noNodes))
              : ListView.builder(
                  itemCount: nodes.length,
                  itemBuilder: (c, i) {
                    final n = nodes[i];
                    final stale =
                        DateTime.now().millisecondsSinceEpoch ~/ 1000 -
                                n.lastSeen >
                            120;
                    return ListTile(
                      leading: Icon(Icons.dns_outlined,
                          color: n.disabled
                              ? Colors.grey
                              : (stale ? Colors.orange : Colors.green)),
                      title: Text(
                          '${n.name}${n.disabled ? l10n.disabledSuffix : ""}'),
                      subtitle: Text(l10n.lastSeen(fmtAgo(l10n, n.lastSeen))),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: Icon(n.disabled
                              ? Icons.play_circle_outline
                              : Icons.pause_circle_outline),
                          tooltip: n.disabled ? l10n.enable : l10n.disable,
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
                          tooltip: l10n.delete,
                          onPressed: () async {
                            if (!await confirm(context, l10n.deleteNode,
                                l10n.deleteNodeBody(n.name))) return;
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
