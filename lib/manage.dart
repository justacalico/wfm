import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'main.dart';
import 'projects.dart';
import 'util.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tight = MediaQuery.sizeOf(context).width < 720;
    final tabs = <(String, Widget)>[
      if (Api.i.caps.manage) (l10n.accounts, const AccountsTab()),
      if (Api.i.user?.isStaff ?? false) (l10n.classes, const ClassesTab()),
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

/// The managed-users subtree as `(user, depth)` rows: direct children of `meId`
/// at depth 0, their children nested under them while `expanded` holds the
/// parent's id. Accounts whose creator left the tree surface at the top level.
List<(User, int)> accountTree(
    List<User> users, String meId, Set<String> expanded) {
  final byParent = <String, List<User>>{};
  final ids = <String>{};
  for (final u in users) {
    byParent.putIfAbsent(u.createdBy, () => []).add(u);
    ids.add(u.id);
  }
  final out = <(User, int)>[];
  final seen = <String>{};
  void walk(String parent, int depth) {
    for (final u in byParent[parent] ?? const <User>[]) {
      if (!seen.add(u.id)) continue;
      out.add((u, depth));
      if (expanded.contains(u.id)) walk(u.id, depth + 1);
    }
  }

  walk(meId, 0);
  for (final u in users) {
    if (seen.contains(u.id) || ids.contains(u.createdBy)) continue;
    seen.add(u.id);
    out.add((u, 0));
    if (expanded.contains(u.id)) walk(u.id, 1);
  }
  return out;
}

class _AccountsTabState extends State<AccountsTab> {
  List<User>? _users;
  String _err = '';
  List<Invite> _invites = [];
  final _expanded = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _users = await Api.i.accounts();
      _invites = await Api.i.invites().catchError((_) => <Invite>[]);
      setState(() {});
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final fields = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => const _AccountDialog());
    if (fields == null || !mounted) return;
    try {
      if (fields['invite'] == '1') {
        final code = await Api.i.inviteCreate(fields['role']!,
            username: fields['username'] ?? '', name: fields['name'] ?? '');
        if (mounted) {
          await showDialog(
              context: context, builder: (_) => _InviteDoneDialog(code));
        }
      } else {
        await Api.i.createAccount(fields);
      }
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _revoke(Invite i) async {
    try {
      await Api.i.inviteRevoke(i.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _edit(User u) async {
    final fields = await showDialog<Map<String, dynamic>>(
        context: context, builder: (_) => _AccountDialog(existing: u));
    if (fields == null || !mounted) return;
    final q = int.tryParse('${fields.remove('quotaMb')}'.trim());
    if (q != null) fields['quotaBytes'] = q * 1048576;
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
    final tight = MediaQuery.sizeOf(context).width < 720;
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
              : Builder(builder: (c) {
                  final rows =
                      accountTree(users, Api.i.user?.id ?? '', _expanded);
                  final kids = <String, int>{};
                  for (final u in users) {
                    kids[u.createdBy] = (kids[u.createdBy] ?? 0) + 1;
                  }
                  return ListView.builder(
                    itemCount: rows.length +
                        (_invites.isEmpty ? 0 : _invites.length + 1),
                    itemBuilder: (c, i) {
                      if (i >= rows.length) {
                        final j = i - rows.length;
                        if (j == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(l10n.invites,
                                style: Theme.of(context).textTheme.titleSmall),
                          );
                        }
                        final inv = _invites[j - 1];
                        final now =
                            DateTime.now().millisecondsSinceEpoch ~/ 1000;
                        final status = inv.revoked
                            ? l10n.revoked
                            : inv.usedBy.isNotEmpty
                                ? l10n.used
                                : inv.expired(now)
                                    ? l10n.expired
                                    : l10n.pending;
                        return ListTile(
                          leading: const Icon(Icons.link),
                          title: Text(
                              '${inv.role}${inv.presetUsername.isNotEmpty ? "  ·  ${inv.presetUsername}" : ""}'),
                          subtitle: Text(
                              '$status  ·  ${fmtTime(l10n, inv.expiresAt)}'),
                          trailing: inv.pending(now)
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: l10n.revoke,
                                  onPressed: () => _revoke(inv))
                              : null,
                        );
                      }
                      final (u, depth) = rows[i];
                      final nk = kids[u.id] ?? 0;
                      final actions =
                          Row(mainAxisSize: MainAxisSize.min, children: [
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
                      ]);
                      return ListTile(
                        contentPadding:
                            EdgeInsets.only(left: 16.0 + depth * 28, right: 8),
                        leading: Row(mainAxisSize: MainAxisSize.min, children: [
                          SizedBox(
                            width: 28,
                            child: nk == 0
                                ? null
                                : IconButton(
                                    iconSize: 20,
                                    padding: EdgeInsets.zero,
                                    icon: Icon(_expanded.contains(u.id)
                                        ? Icons.expand_more
                                        : Icons.chevron_right),
                                    onPressed: () => setState(() =>
                                        _expanded.contains(u.id)
                                            ? _expanded.remove(u.id)
                                            : _expanded.add(u.id))),
                          ),
                          CircleAvatar(
                              child: Text(
                                  u.username.substring(0, 1).toUpperCase())),
                        ]),
                        title: Text(
                            '${u.name.isEmpty ? u.username : u.name}  ·  ${u.role}${u.disabled ? l10n.disabledSuffix : ""}'),
                        subtitle: tight
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(l10n.userLine(
                                        '${u.username}${u.studentId.isNotEmpty ? " · ${u.studentId}" : ""}${u.note.isNotEmpty ? " · ${u.note}" : ""}',
                                        fmtAgo(l10n, u.lastLogin))),
                                    actions,
                                  ])
                            : Text(l10n.userLine(
                                '${u.username}${u.studentId.isNotEmpty ? " · ${u.studentId}" : ""}${u.note.isNotEmpty ? " · ${u.note}" : ""}',
                                fmtAgo(l10n, u.lastLogin))),
                        trailing: tight ? null : actions,
                        onTap: () => Navigator.of(c).push(MaterialPageRoute(
                            builder: (_) => UserProjectsPage(user: u))),
                      );
                    },
                  );
                }),
    );
  }
}

/// A teacher's classes: create, rename, delete, and move members between them.
/// Deleting a class drops its members back into the unmanaged class.
class ClassesTab extends StatefulWidget {
  const ClassesTab({super.key});
  @override
  State<ClassesTab> createState() => _ClassesTabState();
}

class _ClassesTabState extends State<ClassesTab> {
  List<SchoolClass>? _classes;
  List<User> _users = const [];
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await Api.i.classes();
      final u = await Api.i.accounts();
      setState(() {
        _classes = c;
        _users = u;
        _err = '';
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  String _name(SchoolClass c) =>
      c.unmanaged ? context.l10n.unmanagedClass : c.name;

  bool _canManage(SchoolClass c) =>
      c.ownerId == Api.i.user?.id || (Api.i.user?.isAdmin ?? false);

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptText(
        context, l10n.newClass, l10n.className, '', (v) => v.trim().isNotEmpty);
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await Api.i.classCreate(name.trim());
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _rename(SchoolClass c) async {
    final l10n = context.l10n;
    final name = await promptText(context, l10n.renameClass, l10n.className,
        c.name, (v) => v.trim().isNotEmpty);
    if (name == null ||
        name.trim().isEmpty ||
        name.trim() == c.name ||
        !mounted) {
      return;
    }
    try {
      await Api.i.classRename(c.id, name.trim());
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete(SchoolClass c) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.delete, l10n.deleteClassBody(_name(c)))) {
      return;
    }
    try {
      await Api.i.classDelete(c.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _move(User u, SchoolClass to) async {
    try {
      await Api.i.updateAccount(u.id, {'classId': to.id});
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final classes = _classes;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.group_add),
          label: Text(l10n.newClass)),
      body: classes == null
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? Center(child: Text(l10n.noClasses))
              : ListView(children: [
                  for (final c in classes)
                    ExpansionTile(
                      leading: Icon(c.unmanaged
                          ? Icons.group_outlined
                          : Icons.class_outlined),
                      title: Text(_name(c)),
                      subtitle: Text(l10n.memberCount(c.members)),
                      children: [
                        if (_canManage(c) && !c.unmanaged)
                          OverflowBar(children: [
                            TextButton.icon(
                                onPressed: () => _rename(c),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: Text(l10n.rename)),
                            TextButton.icon(
                                onPressed: () => _delete(c),
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                label: Text(l10n.delete)),
                          ]),
                        for (final u in _users)
                          if (u.classId == c.id)
                            ListTile(
                              dense: true,
                              title: Text(u.name.isEmpty ? u.username : u.name),
                              subtitle: Text('${u.username} · ${u.role}'),
                              trailing: _canManage(c)
                                  ? PopupMenuButton<String>(
                                      icon: const Icon(
                                          Icons.drive_file_move_outline,
                                          size: 20),
                                      tooltip: l10n.moveToClass,
                                      onSelected: (v) => _move(u,
                                          classes.firstWhere((x) => x.id == v)),
                                      itemBuilder: (_) => [
                                        for (final oc in classes)
                                          if (oc.id != c.id)
                                            PopupMenuItem(
                                                value: oc.id,
                                                child: Text(_name(oc))),
                                      ],
                                    )
                                  : null,
                            ),
                      ],
                    ),
                ]),
    );
  }
}

/// Read-only view of a managed account's projects; taking over is the only
/// action offered since everything else stays under the owner's control.
class UserProjectsPage extends StatefulWidget {
  final User user;
  const UserProjectsPage({super.key, required this.user});
  @override
  State<UserProjectsPage> createState() => _UserProjectsPageState();
}

class _UserProjectsPageState extends State<UserProjectsPage> {
  List<Project>? _items;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.accountProjects(widget.user.id);
      setState(() {
        _items = v;
        _err = '';
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _takeOver(Project p) async {
    if (!await confirm(context, context.l10n.takeOver,
        context.l10n.takeOverBody(p.displayName))) {
      return;
    }
    try {
      await Api.i.takeOverProject(p.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = widget.user;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.userProjects(u.name.isEmpty ? u.username : u.name))),
      body: _err.isNotEmpty
          ? errorView(context, _err, _load)
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : items.isEmpty
                  ? Center(child: Text(l10n.userProjectsEmpty))
                  : ListView(padding: const EdgeInsets.all(16), children: [
                      for (final p in items)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            title: Text(p.displayName),
                            subtitle: Text([
                              l10n.createdAgo(fmtAgo(l10n, p.createdAt)),
                              if (p.status == 'submitted')
                                l10n.statusSubmitted
                              else if (p.status == 'reviewed')
                                l10n.statusReviewed,
                            ].join('  ·  ')),
                            trailing: p.canTakeOver
                                ? PopupMenuButton<String>(
                                    iconSize: 18,
                                    onSelected: (_) => _takeOver(p),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                          value: 'take',
                                          child: Text(l10n.takeOver)),
                                    ],
                                  )
                                : null,
                            onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) => ProjectPage(project: p))),
                          ),
                        ),
                    ]),
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
  late final _quota = TextEditingController(
      text: widget.existing == null || widget.existing!.quotaBytes <= 0
          ? ''
          : '${widget.existing!.quotaBytes ~/ 1048576}');
  int _usage = -1;
  final _pass = TextEditingController();
  bool _invite = false;
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
  List<SchoolClass> _classes = const [];
  late String _classId = widget.existing?.classId ?? '';

  @override
  void initState() {
    super.initState();
    Api.i.classes().then((v) {
      if (mounted) setState(() => _classes = v);
    }).catchError((_) {});
    final u = widget.existing;
    if (u != null) {
      Api.i.accountUsage(u.id).then((v) {
        if (mounted) setState(() => _usage = v);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _user, _sid, _note, _pass, _quota]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editing = widget.existing != null;
    final valid = _invite
        ? (_user.text.trim().isEmpty || validUsername(_user.text.trim())) &&
            (_name.text.isEmpty || validDisplayName(_name.text))
        : validDisplayName(_name.text) &&
            validUsername(_user.text.trim()) &&
            (editing || validPassword(_pass.text));
    return AlertDialog(
      scrollable: true,
      title: Text(editing
          ? l10n.editAccount
          : _invite
              ? l10n.newInvite
              : l10n.newAccount),
      content: SizedBox(
        width: 340,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (!editing) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l10n.account)),
                ButtonSegment(value: true, label: Text(l10n.invite)),
              ],
              selected: {_invite},
              onSelectionChanged: (v) => setState(() => _invite = v.first),
            ),
            const SizedBox(height: 8),
          ],
          TextField(
              controller: _name,
              decoration: dec(_invite ? l10n.nameOptional : l10n.name),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          TextField(
              controller: _user,
              decoration: dec(_invite ? l10n.usernameOptional : l10n.username),
              onChanged: (_) => setState(() {})),
          if (!editing && !_invite) ...[
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
          if (_role == 'student' && _classes.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _classId.isNotEmpty
                  ? _classId
                  : _classes
                      .firstWhere((c) => c.unmanaged,
                          orElse: () => _classes.first)
                      .id,
              decoration: dec(l10n.schoolClass),
              items: [
                for (final c in _classes)
                  DropdownMenuItem(
                      value: c.id,
                      child: Text(c.unmanaged ? l10n.unmanagedClass : c.name)),
                if (_classId.isNotEmpty &&
                    !_classes.any((c) => c.id == _classId))
                  DropdownMenuItem(value: _classId, child: Text(_classId)),
              ],
              onChanged: (v) => setState(() => _classId = v!),
            ),
          ],
          if (!_invite) ...[
            const SizedBox(height: 8),
            TextField(
                controller: _sid, decoration: dec(l10n.studentIdOptional)),
            const SizedBox(height: 8),
            TextField(
                controller: _note,
                maxLength: 20,
                decoration: dec(l10n.noteOptional)),
          ],
          if (editing) ...[
            const SizedBox(height: 8),
            TextField(
                controller: _quota,
                keyboardType: TextInputType.number,
                decoration: dec(l10n.quotaMb, l10n.quotaMbHint)),
            if (_usage >= 0)
              Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l10n.storageUsed(
                      fmtBytes(_usage),
                      _quota.text.trim().isEmpty
                          ? '∞'
                          : '${_quota.text.trim()} MB'))),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
            onPressed: valid
                ? () => Navigator.pop(context, <String, dynamic>{
                      if (_invite) 'invite': '1',
                      'username': _user.text.trim(),
                      'name': _name.text.trim(),
                      'role': _role,
                      'studentId': _sid.text.trim(),
                      'note': _note.text.trim(),
                      'quotaMb': _quota.text.trim(),
                      if (_role == 'student' && _classId.isNotEmpty)
                        'classId': _classId,
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

class _InviteDoneDialog extends StatelessWidget {
  final String code;
  const _InviteDoneDialog(this.code);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url =
        '${Uri.base.scheme.startsWith('http') ? '${Uri.base.origin}/' : ''}app/invite/$code';
    Widget row(String label, String value) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Row(children: [
                Expanded(child: SelectableText(value)),
                IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: l10n.copy,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      snack(context, l10n.copied, good: true);
                    }),
              ]),
            ]);
    return AlertDialog(
      title: Text(l10n.inviteReady),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          row(l10n.inviteUrl, url),
          const SizedBox(height: 8),
          row(l10n.inviteCode, code),
          const SizedBox(height: 8),
          row(l10n.inviteEmail, l10n.inviteEmailBody(url)),
        ]),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
      ],
    );
  }
}
