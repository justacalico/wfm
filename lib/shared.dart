import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'projects.dart';
import 'util.dart';

class SharedPage extends StatefulWidget {
  const SharedPage({super.key});
  @override
  State<SharedPage> createState() => _SharedPageState();
}

class _SharedPageState extends State<SharedPage> {
  List<Share>? _shares;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.shares();
      setState(() {
        _shares = v;
        _err = '';
      });
      if (mounted) {
        context.findAncestorStateOfType<ShellState>()?.refreshShared();
      }
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _respond(Share sh, bool accept) async {
    try {
      await Api.i.shareRespond(sh.id, accept);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _copy(Share sh) async {
    try {
      await Api.i.duplicateProject(sh.projectId);
      if (mounted) snack(context, context.l10n.projectDuplicated);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  void _open(Share sh) {
    final p = Project.fromJson({
      'id': sh.projectId,
      'name': sh.projectName,
      'access': sh.template ? 'view' : sh.level,
      'ownerId': 'x',
      'ownerName': sh.inviterUsername,
      'template': sh.template,
    });
    final shell = context.findAncestorStateOfType<ShellState>();
    if (shell != null) {
      shell.openProject(p);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ProjectPage(project: p)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final shares = _shares;
    final tight = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: tight ? null : AppBar(title: Text(l10n.navShared)),
      body: shares == null
          ? const Center(child: CircularProgressIndicator())
          : shares.isEmpty
              ? Center(child: Text(l10n.noShares))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  if (shares.any((s) => s.status == 'pending')) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(l10n.pendingInvites,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final sh in shares.where((s) => s.status == 'pending'))
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.mail_outline),
                          title: Text(sh.projectName.isEmpty
                              ? sh.projectId
                              : sh.projectName),
                          subtitle: Text(l10n.shareInviteFrom(
                              sh.level == 'edit' ? l10n.canEdit : l10n.canView,
                              sh.inviterUsername)),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(
                                onPressed: () => _respond(sh, true),
                                child: Text(l10n.accept)),
                            TextButton(
                                onPressed: () => _respond(sh, false),
                                child: Text(l10n.decline)),
                          ]),
                        ),
                      ),
                  ],
                  if (shares.any((s) => s.status == 'accepted')) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(l10n.sharedProjects,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    for (final sh
                        in shares.where((s) => s.status == 'accepted'))
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.folder_shared),
                          title: Text(sh.projectName.isEmpty
                              ? sh.projectId
                              : sh.projectName),
                          subtitle: Text(
                              '${sh.level == 'edit' && !sh.template ? l10n.canEdit : l10n.canView}${sh.template ? '  ·  ${l10n.template}' : ''}  ·  ${sh.inviterUsername}  ·  ${fmtTime(l10n, sh.createdAt)}'),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            if (sh.template)
                              TextButton(
                                  onPressed: () => _copy(sh),
                                  child: Text(l10n.useTemplate))
                            else
                              IconButton(
                                  icon:
                                      const Icon(Icons.copy_outlined, size: 20),
                                  tooltip: l10n.saveCopy,
                                  onPressed: () => _copy(sh)),
                            const Icon(Icons.chevron_right),
                          ]),
                          onTap: () => _open(sh),
                        ),
                      ),
                  ],
                ]),
    );
  }
}
