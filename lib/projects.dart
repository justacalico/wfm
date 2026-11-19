import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'comments.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'media_preview.dart';
import 'platform.dart';
import 'uploads.dart';
import 'util.dart';

String? _theme(BuildContext c) =>
    c.findAncestorStateOfType<WfmAppState>()?.appTheme.name;

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  List<Project>? _items;
  List<ProjectGroup> _groups = [];
  String _err = '';
  String? _tagFilter;
  int _view = 0;
  int _sort = 0;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((p) {
      final v = p.getInt('projectsView');
      final s = p.getInt('projectsSort');
      if (mounted) {
        setState(() {
          if (v != null) _view = v;
          if (s != null) _sort = s;
        });
      }
    });
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _setView(int v) {
    setState(() => _view = v);
    SharedPreferences.getInstance().then((p) => p.setInt('projectsView', v));
  }

  void _setSort(int v) {
    setState(() => _sort = v);
    SharedPreferences.getInstance().then((p) => p.setInt('projectsSort', v));
  }

  Future<void> _load() async {
    try {
      final res = await Future.wait([Api.i.projects(), Api.i.groups()]);
      setState(() {
        _items = res[0] as List<Project>;
        _groups = res[1] as List<ProjectGroup>;
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final name = await promptText(
        context, context.l10n.newProject, context.l10n.projectName);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.createProject(name);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _newGroup() async {
    final name = await promptText(
        context, context.l10n.newGroup, context.l10n.groupName);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.createGroup(name);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _renameGroup(ProjectGroup g) async {
    final name = await promptText(
        context, context.l10n.renameGroup, context.l10n.groupName, g.name);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.renameGroup(g.id, name);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _deleteGroup(ProjectGroup g) async {
    if (!await confirm(
        context, context.l10n.delete, context.l10n.deleteGroupBody(g.name))) {
      return;
    }
    try {
      await Api.i.deleteGroup(g.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _moveToGroup(Project p) async {
    final l10n = context.l10n;
    final gid = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.moveToGroup),
        children: [
          SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text(l10n.noGroup)),
          for (final g in _groups)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, g.id), child: Text(g.name)),
        ],
      ),
    );
    if (gid == null || gid == p.groupId || !mounted) return;
    try {
      await Api.i.updateProject(p.id, groupId: gid);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _editTags(Project p) async {
    final v = await promptText(context, context.l10n.editTags,
        context.l10n.tagsHint, p.tags.join(', '));
    if (v == null || !mounted) return;
    try {
      await Api.i
          .updateProject(p.id, tags: [for (final t in v.split(',')) t.trim()]);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _togglePin(Project p) async {
    try {
      await Api.i.updateProject(p.id, pinned: !p.pinned);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
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

  Future<void> _duplicate(Project p) async {
    try {
      await Api.i.duplicateProject(p.id);
      if (mounted) snack(context, context.l10n.projectDuplicated);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Widget _menu(BuildContext c, AppLocalizations l10n, Project p) => SizedBox(
        width: 28,
        height: 28,
        child: PopupMenuButton<String>(
          iconSize: 18,
          padding: EdgeInsets.zero,
          onSelected: (v) => switch (v) {
            'share' =>
              showDialog(context: c, builder: (_) => _ShareDialog(project: p)),
            'render' =>
              showDialog(context: c, builder: (_) => RenderDialog(project: p)),
            'pin' => _togglePin(p),
            'tags' => _editTags(p),
            'take' => _takeOver(p),
            'dup' => _duplicate(p),
            _ => _moveToGroup(p),
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'share', child: Text(l10n.share)),
            if (p.editable)
              PopupMenuItem(value: 'render', child: Text(l10n.render)),
            if (!p.editable)
              PopupMenuItem(value: 'take', child: Text(l10n.takeOver))
            else ...[
              PopupMenuItem(
                  value: 'pin',
                  child: Text(p.pinned ? l10n.unpinProject : l10n.pinProject)),
              PopupMenuItem(value: 'tags', child: Text(l10n.editTags)),
              PopupMenuItem(value: 'group', child: Text(l10n.moveToGroup)),
            ],
            PopupMenuItem(value: 'dup', child: Text(l10n.duplicate)),
          ],
        ),
      );

  Widget _openAction(BuildContext c, IconData icon, String label, String url) =>
      TextButton.icon(
        onPressed: () async {
          try {
            await openEditor(c, Api.i, url);
          } catch (e) {
            if (c.mounted) snack(c, e);
          }
        },
        icon: Icon(icon, size: 16),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
      );

  Widget _actions(BuildContext c, AppLocalizations l10n, Project p,
      {bool expand = false}) {
    if (!p.editable) {
      return Text(l10n.readOnly, style: Theme.of(c).textTheme.labelSmall);
    }
    final theme = _theme(c);
    final buttons = [
      _openAction(c, Icons.edit_note, l10n.openScript,
          Api.i.scriptUrl(p.id, theme: theme)),
      _openAction(c, Icons.view_carousel_outlined, l10n.openBoards,
          Api.i.deckUrl(p.id, theme: theme)),
      _openAction(c, Icons.edit_outlined, l10n.editInFilmcraft,
          Api.i.projectUrl(p.id, theme: theme)),
    ];
    if (!expand) return Row(mainAxisSize: MainAxisSize.min, children: buttons);
    return Row(children: [for (final b in buttons) Expanded(child: b)]);
  }

  Widget _card(BuildContext c, AppLocalizations l10n, Project p, double w) {
    return SizedBox(
      width: w,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final shell = c.findAncestorStateOfType<ShellState>();
            if (shell != null) {
              shell.openProject(p);
            } else {
              Navigator.of(c).push(
                  MaterialPageRoute(builder: (_) => ProjectPage(project: p)));
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis),
                ),
                _menu(c, l10n, p),
              ]),
              Text(
                  [
                    l10n.createdAgo(fmtAgo(l10n, p.createdAt)),
                    if (p.ownerName.isNotEmpty) l10n.ownedBy(p.ownerName),
                  ].join('  ·  '),
                  style: Theme.of(c).textTheme.bodySmall),
              if (p.status != 'draft')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: tagChip(
                      c,
                      p.status == 'reviewed'
                          ? l10n.statusReviewed
                          : l10n.statusSubmitted),
                ),
              if (p.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in p.tags) tagChip(context, t),
                  ]),
                ),
              const SizedBox(height: 4),
              _actions(c, l10n, p, expand: true),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext c, AppLocalizations l10n, Project p) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final shell = c.findAncestorStateOfType<ShellState>();
          if (shell != null) {
            shell.openProject(p);
          } else {
            Navigator.of(c).push(
                MaterialPageRoute(builder: (_) => ProjectPage(project: p)));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.displayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis),
                    Text(l10n.createdAgo(fmtAgo(l10n, p.createdAt)),
                        style: Theme.of(c).textTheme.bodySmall),
                    if (p.status != 'draft')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: tagChip(
                            c,
                            p.status == 'reviewed'
                                ? l10n.statusReviewed
                                : l10n.statusSubmitted),
                      ),
                    if (p.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final t in p.tags) tagChip(context, t),
                        ]),
                      ),
                  ]),
            ),
            _menu(c, l10n, p),
            Flexible(
                child: FittedBox(
                    fit: BoxFit.scaleDown, child: _actions(c, l10n, p))),
          ]),
        ),
      ),
    );
  }

  Widget _cards(List<Project> ps, AppLocalizations l10n, bool tight) {
    if (_view == 1) {
      return Column(children: [
        for (final p in ps) _row(context, l10n, p),
      ]);
    }
    return LayoutBuilder(builder: (c, cons) {
      final cols = tight ? 1 : (cons.maxWidth / 300).floor();
      final w = (cons.maxWidth - 12 * (cols - 1)) / cols;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final p in ps) _card(c, l10n, p, w),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final items = _items;
    final tight = MediaQuery.sizeOf(context).width < 720;
    final q = _query.text.trim().toLowerCase();
    final filtered = [
      for (final p in items ?? <Project>[])
        if ((_tagFilter == null || p.tags.contains(_tagFilter)) &&
            (q.isEmpty ||
                p.name.toLowerCase().contains(q) ||
                p.displayName.toLowerCase().contains(q)))
          p,
    ]..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return switch (_sort) {
          1 => b.createdAt.compareTo(a.createdAt),
          2 => b.lastActivity.compareTo(a.lastActivity),
          _ =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        };
      });
    final allTags = {
      for (final p in items ?? <Project>[]) ...p.tags,
    }.toList()
      ..sort();
    final byGroup = <String, List<Project>>{};
    for (final p in filtered) {
      byGroup.putIfAbsent(p.groupId, () => []).add(p);
    }
    final orphans = [
      for (final e in byGroup.entries)
        if (e.key.isNotEmpty && !_groups.any((g) => g.id == e.key)) ...e.value,
    ];
    final ungrouped = [...?byGroup[''], ...orphans];
    return Scaffold(
      appBar: tight ? null : AppBar(title: Text(l10n.projects)),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: Text(l10n.newProject)),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: l10n.searchProjects,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                PopupMenuButton<int>(
                  icon: const Icon(Icons.sort),
                  tooltip: l10n.sortProjects,
                  initialValue: _sort,
                  onSelected: _setSort,
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 0, child: Text(l10n.name)),
                    PopupMenuItem(value: 1, child: Text(l10n.sortCreated)),
                    PopupMenuItem(value: 2, child: Text(l10n.sortActivity)),
                  ],
                ),
                IconButton(
                  icon: Icon(_view == 0 ? Icons.view_list : Icons.grid_view),
                  tooltip: _view == 0 ? l10n.listView : l10n.gridView,
                  onPressed: () => _setView(_view == 0 ? 1 : 0),
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                if (allTags.isNotEmpty)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final t in allTags)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(t),
                              selected: _tagFilter == t,
                              onSelected: (v) =>
                                  setState(() => _tagFilter = v ? t : null),
                            ),
                          ),
                      ]),
                    ),
                  )
                else
                  const Spacer(),
                TextButton.icon(
                  onPressed: _newGroup,
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: Text(l10n.newGroup),
                ),
              ]),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: Text(l10n.noProjects)),
                )
              else if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: Text(l10n.noMatchingProjects)),
                )
              else ...[
                for (final g in _groups) ...[
                  _groupHeader(l10n, g),
                  _cards(byGroup[g.id] ?? <Project>[], l10n, tight),
                ],
                if (_groups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(l10n.ungrouped,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                _cards(ungrouped, l10n, tight),
              ],
            ]),
    );
  }

  Widget _groupHeader(AppLocalizations l10n, ProjectGroup g) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(children: [
        const Icon(Icons.folder_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
            child: Text(g.name, style: Theme.of(context).textTheme.titleSmall)),
        SizedBox(
          width: 28,
          height: 28,
          child: PopupMenuButton<String>(
            iconSize: 18,
            padding: EdgeInsets.zero,
            onSelected: (v) =>
                v == 'rename' ? _renameGroup(g) : _deleteGroup(g),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
          ),
        ),
      ]),
    );
  }
}

Widget tagChip(BuildContext context, String t) {
  final c = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: c.secondaryContainer, borderRadius: BorderRadius.circular(12)),
    child:
        Text(t, style: TextStyle(fontSize: 11, color: c.onSecondaryContainer)),
  );
}

class ProjectPage extends StatefulWidget {
  final Project project;
  final VoidCallback? onBack;
  const ProjectPage({super.key, required this.project, this.onBack});
  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  int _tab = 0;
  String _filesPath = '';
  late Project _p = widget.project;

  @override
  void didUpdateWidget(ProjectPage old) {
    super.didUpdateWidget(old);
    if (!identical(old.project, widget.project)) {
      _p = widget.project;
      _tab = 0;
      _filesPath = '';
    }
  }

  Future<void> _share() async {
    await showDialog(
        context: context, builder: (_) => _ShareDialog(project: _p));
  }

  Future<void> _rename() async {
    final name = await promptText(context, context.l10n.renameProject,
        context.l10n.displayName, _p.displayName);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.updateProject(_p.id, displayName: name);
      setState(() => _p = _p.copyWith(displayName: name));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _duplicate() async {
    try {
      await Api.i.duplicateProject(_p.id);
      if (mounted) snack(context, context.l10n.projectDuplicated);
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _toggleTemplate() async {
    try {
      await Api.i.updateProject(_p.id, template: !_p.template);
      setState(() => _p = _p.copyWith(template: !_p.template));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _submit() async {
    try {
      final st = await Api.i.submitProject(_p.id);
      setState(() => _p = _p.copyWith(status: st));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _review(String status) async {
    try {
      final st = await Api.i.reviewProject(_p.id, status);
      setState(() => _p = _p.copyWith(status: st));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  void _close() {
    if (widget.onBack != null) {
      widget.onBack!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, context.l10n.deleteProject,
        context.l10n.deleteProjectBody(_p.displayName))) {
      return;
    }
    try {
      await Api.i.deleteProject(_p.id);
      if (mounted) _close();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        leading:
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _close),
        title: Row(children: [
          Flexible(
              child: Text(_p.displayName, overflow: TextOverflow.ellipsis)),
          if (_p.template) ...[
            const SizedBox(width: 8),
            tagChip(context, l10n.template),
          ],
          if (_p.status != 'draft') ...[
            const SizedBox(width: 8),
            tagChip(
                context,
                _p.status == 'reviewed'
                    ? l10n.statusReviewed
                    : l10n.statusSubmitted),
          ],
        ]),
        actions: [
          if (!_p.editable)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                  child: Text(l10n.readOnly,
                      style: Theme.of(context).textTheme.labelSmall)),
            ),
          if (_p.editable) ...[
            FilledButton.tonalIcon(
              onPressed: () async {
                try {
                  await openEditor(context, Api.i,
                      Api.i.projectUrl(_p.id, theme: _theme(context)));
                } catch (e) {
                  if (context.mounted) snack(context, e);
                }
              },
              icon: const Icon(Icons.movie_edit, size: 18),
              label: Text(l10n.editInFilmcraft),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                try {
                  await openEditor(context, Api.i,
                      Api.i.scriptUrl(_p.id, theme: _theme(context)));
                } catch (e) {
                  if (context.mounted) snack(context, e);
                }
              },
              icon: const Icon(Icons.edit_note, size: 20),
              tooltip: l10n.openScript,
            ),
            IconButton(
              onPressed: () async {
                try {
                  await openEditor(context, Api.i,
                      Api.i.deckUrl(_p.id, theme: _theme(context)));
                } catch (e) {
                  if (context.mounted) snack(context, e);
                }
              },
              icon: const Icon(Icons.view_carousel_outlined, size: 20),
              tooltip: l10n.openBoards,
            ),
          ],
          if (_p.mine && _p.status != 'reviewed')
            IconButton(
              icon: Icon(
                  _p.status == 'submitted'
                      ? Icons.undo_outlined
                      : Icons.send_outlined,
                  size: 20),
              tooltip: _p.status == 'submitted'
                  ? l10n.withdrawSubmission
                  : l10n.submitForReview,
              onPressed: _submit,
            ),
          if (!_p.mine &&
              _p.status == 'submitted' &&
              (Api.i.user?.isStaff ?? false)) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              tooltip: l10n.markReviewed,
              onPressed: () => _review('reviewed'),
            ),
            IconButton(
              icon: const Icon(Icons.undo_outlined, size: 20),
              tooltip: l10n.returnToDraft,
              onPressed: () => _review('draft'),
            ),
          ],
          if (_p.mine) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined, size: 20),
              tooltip: l10n.share,
              onPressed: _share,
            ),
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'rename' => _rename(),
                'dup' => _duplicate(),
                'tpl' => _toggleTemplate(),
                _ => _delete(),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
                PopupMenuItem(value: 'dup', child: Text(l10n.duplicate)),
                PopupMenuItem(
                    value: 'tpl',
                    child: Text(
                        _p.template ? l10n.unmarkTemplate : l10n.markTemplate)),
                PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
              ],
            ),
          ] else ...[
            if (_p.template)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton.tonalIcon(
                  onPressed: _duplicate,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: Text(l10n.useTemplate),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 20),
                tooltip: l10n.saveCopy,
                onPressed: _duplicate,
              ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                      value: 0,
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(l10n.files)),
                  ButtonSegment(
                      value: 1,
                      icon: const Icon(Icons.rocket_launch_outlined),
                      label: Text(l10n.renders)),
                  ButtonSegment(
                      value: 2,
                      icon: const Icon(Icons.comment_outlined),
                      label: Text(l10n.comments)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
        ),
      ),
      body: _tab == 0
          ? FilesTab(
              project: _p, path: _filesPath, onPath: (p) => _filesPath = p)
          : _tab == 1
              ? RendersTab(project: _p)
              : CommentsTab(project: _p),
    );
  }
}

IconData fileIcon(FileEntry e) {
  if (e.isDir) return Icons.folder_outlined;
  switch (extOf(e.name)) {
    case 'mp4' ||
          'mov' ||
          'mkv' ||
          'webm' ||
          'avi' ||
          'm4v' ||
          'mts' ||
          'm2ts' ||
          'mxf':
      return Icons.movie_outlined;
    case 'mp3' || 'wav' || 'aac' || 'flac' || 'ogg' || 'oga' || 'm4a' || 'opus':
      return Icons.audio_file_outlined;
    case 'png' ||
          'jpg' ||
          'jpeg' ||
          'gif' ||
          'webp' ||
          'bmp' ||
          'tif' ||
          'tiff' ||
          'dng' ||
          'exr' ||
          'hdr':
      return Icons.image_outlined;
    case 'srt' || 'vtt':
      return Icons.subtitles_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

class FilesTab extends StatefulWidget {
  final Project project;
  final String path;
  final ValueChanged<String>? onPath;
  const FilesTab(
      {super.key, required this.project, this.path = '', this.onPath});
  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  String _path = '';
  List<FileEntry>? _items;
  String _err = '';
  int _view = 0;
  bool _sel = false;
  int _usage = -1;
  final _selPaths = <String>{};

  @override
  void initState() {
    super.initState();
    _path = widget.path;
    SharedPreferences.getInstance().then((p) {
      final v = p.getInt('filesView');
      if (v != null && mounted) setState(() => _view = v);
    });
    _load();
    _loadUsage();
    installDropHandler(_enqueue);
  }

  @override
  void didUpdateWidget(FilesTab old) {
    super.didUpdateWidget(old);
    if (widget.path != _path) {
      _path = widget.path;
      _items = null;
      _load();
    }
  }

  void _setView(int v) {
    setState(() => _view = v);
    SharedPreferences.getInstance().then((p) => p.setInt('filesView', v));
  }

  Future<void> _load() async {
    setState(() => _err = '');
    try {
      final f = await Api.i.files(widget.project.id, _path);
      setState(() => _items = f);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  void _loadUsage() {
    Api.i.projectUsage(widget.project.id).then((v) {
      if (mounted) setState(() => _usage = v);
    }).catchError((_) {});
  }

  void _toggleSel(FileEntry e) {
    setState(() {
      _selPaths.contains(e.path)
          ? _selPaths.remove(e.path)
          : _selPaths.add(e.path);
    });
  }

  void _exitSel() {
    setState(() {
      _sel = false;
      _selPaths.clear();
    });
  }

  Future<void> _bulkDelete() async {
    final l10n = context.l10n;
    if (!await confirm(
        context, l10n.deleteSelected, l10n.selectedCount(_selPaths.length))) {
      return;
    }
    for (final p in _selPaths.toList()) {
      try {
        await Api.i.deleteFile(widget.project.id, p);
      } catch (e) {
        if (mounted) snack(context, e);
        break;
      }
    }
    if (mounted) {
      _exitSel();
      _load();
    }
  }

  Future<void> _bulkMove() async {
    final dest = await promptText(context, context.l10n.moveSelected,
        context.l10n.destFolder, _path.isEmpty ? 'Raw' : _path);
    if (dest == null || dest.isEmpty || !mounted) return;
    for (final p in _selPaths.toList()) {
      final name = p.contains('/') ? p.split('/').last : p;
      try {
        await Api.i.move(widget.project.id, p, '$dest/$name');
      } catch (e) {
        if (mounted) snack(context, e);
        break;
      }
    }
    if (mounted) {
      _exitSel();
      _load();
    }
  }

  void _zipSel() async {
    try {
      await openExternal(Api.i.zipUrl(widget.project.id, _selPaths.toList()));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  void _go(String path) {
    _path = path;
    widget.onPath?.call(path);
    _items = null;
    _load();
  }

  Future<void> _upload() async {
    List<PickedFile> picked;
    try {
      picked = await pickFiles();
    } catch (e) {
      if (mounted) snack(context, e);
      return;
    }
    _enqueue(picked);
  }

  void _enqueue(List<PickedFile> picked) {
    if (picked.isEmpty || !mounted) return;
    final folder = _path.isEmpty ? 'Raw/Other' : _path;
    unawaited(Api.i.uploads.enqueue([
      for (final f in picked)
        UploadJob(
            widget.project.id,
            f.name,
            f.size,
            (onProgress) => uploadPicked(
                Api.i, widget.project.id, '$folder/${f.name}', f, onProgress)),
    ]).then((_) {
      if (mounted) _load();
    }));
  }

  Widget _progress() => AnimatedBuilder(
        animation: Api.i.uploads,
        builder: (c, _) {
          final jobs = Api.i.uploads.jobs
              .where((j) => j.pid == widget.project.id)
              .toList();
          if (jobs.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(children: [
              for (final j in jobs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    switch (j.state) {
                      2 => const Icon(Icons.check_circle_outline, size: 16),
                      3 => const Icon(Icons.error_outline, size: 16),
                      _ => const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    },
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(j.name, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    if (j.state == 1)
                      Text(
                          '${fmtBytes(j.sent)} / ${j.total > 0 ? fmtBytes(j.total) : '?'}',
                          style: Theme.of(c).textTheme.labelSmall),
                    if (j.state == 3) ...[
                      Text(j.error?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(c).colorScheme.error)),
                      const SizedBox(width: 4),
                      InkWell(
                          onTap: () => Api.i.uploads.dismiss(j),
                          child: const Icon(Icons.close, size: 16)),
                    ],
                    if (j.state == 1)
                      SizedBox(
                          width: 120,
                          child: LinearProgressIndicator(
                              value: j.total > 0 ? j.sent / j.total : null)),
                  ]),
                ),
            ]),
          );
        },
      );

  Future<void> _mkdir() async {
    final name = await promptText(
        context, context.l10n.newFolder, context.l10n.folderName);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i
          .mkdir(widget.project.id, _path.isEmpty ? name : '$_path/$name');
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _rename(FileEntry e) async {
    final name = await promptText(
        context, context.l10n.rename, context.l10n.newName, e.name);
    if (name == null || name.isEmpty || name == e.name || !mounted) return;
    final parent = e.path.contains('/')
        ? e.path.substring(0, e.path.lastIndexOf('/'))
        : '';
    try {
      await Api.i.move(
          widget.project.id, e.path, parent.isEmpty ? name : '$parent/$name');
      _load();
    } catch (err) {
      if (mounted) snack(context, err);
    }
  }

  Future<void> _delete(FileEntry e) async {
    if (!await confirm(
        context, context.l10n.delete, context.l10n.deleteFileBody(e.path)))
      return;
    try {
      await Api.i.deleteFile(widget.project.id, e.path);
      _load();
    } catch (err) {
      if (mounted) snack(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final crumbs = _path.isEmpty ? <String>[] : _path.split('/');
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: _sel
            ? Row(children: [
                IconButton(
                    icon: const Icon(Icons.select_all),
                    tooltip: l10n.selectAll,
                    onPressed: () => setState(() {
                          for (final e in _items ?? []) {
                            _selPaths.add(e.path);
                          }
                        })),
                Text(l10n.selectedCount(_selPaths.length)),
                const Spacer(),
                IconButton(
                    icon: const Icon(Icons.download),
                    tooltip: l10n.downloadZip,
                    onPressed: _selPaths.isEmpty ? null : _zipSel),
                if (widget.project.editable) ...[
                  IconButton(
                      icon: const Icon(Icons.drive_file_move_outline),
                      tooltip: l10n.moveSelected,
                      onPressed: _selPaths.isEmpty ? null : _bulkMove),
                  IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.deleteSelected,
                      onPressed: _selPaths.isEmpty ? null : _bulkDelete),
                ],
                IconButton(icon: const Icon(Icons.close), onPressed: _exitSel),
              ])
            : Row(children: [
                InkWell(
                    onTap: () => _go(''),
                    child: const Icon(Icons.home_outlined, size: 20)),
                for (var i = 0; i < crumbs.length; i++) ...[
                  const Icon(Icons.chevron_right, size: 18),
                  InkWell(
                    onTap: () => _go(crumbs.sublist(0, i + 1).join('/')),
                    child: Text(crumbs[i],
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
                const Spacer(),
                if (_usage >= 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                        Api.i.user?.quotaBytes != null &&
                                Api.i.user!.quotaBytes > 0
                            ? l10n.storageUsed(fmtBytes(_usage),
                                fmtBytes(Api.i.user!.quotaBytes))
                            : fmtBytes(_usage),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: l10n.selectFiles,
                    onPressed: () => setState(() => _sel = true)),
                IconButton(
                    icon: Icon(_view == 0 ? Icons.grid_view : Icons.view_list),
                    tooltip: _view == 0 ? l10n.gridView : l10n.listView,
                    onPressed: () => _setView(_view == 0 ? 1 : 0)),
                if (widget.project.editable)
                  IconButton(
                      icon: const Icon(Icons.create_new_folder_outlined),
                      tooltip: l10n.newFolder,
                      onPressed: _mkdir),
                IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.refresh,
                    onPressed: _load),
                if (widget.project.editable)
                  FilledButton.tonalIcon(
                    onPressed: _upload,
                    icon: const Icon(Icons.upload_file, size: 18),
                    label: Text(l10n.upload),
                  ),
              ]),
      ),
      _progress(),
      const Divider(height: 1),
      Expanded(
        child: _err.isNotEmpty
            ? errorView(context, _err, _load)
            : _items == null
                ? const Center(child: CircularProgressIndicator())
                : _items!.isEmpty
                    ? Center(child: Text(l10n.emptyFolder))
                    : _view == 1
                        ? GridView.extent(
                            key: PageStorageKey(
                                'files-grid-${widget.project.id}-$_path'),
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 1.5,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            padding: const EdgeInsets.all(12),
                            children: [
                              for (final e in _items!) _cell(context, l10n, e)
                            ],
                          )
                        : ListView.builder(
                            key: PageStorageKey(
                                'files-list-${widget.project.id}-$_path'),
                            itemCount: _items!.length,
                            itemBuilder: (c, i) => _tile(c, l10n, _items![i]),
                          ),
      ),
    ]);
  }

  Widget _thumb(FileEntry e, {double? h, double? w}) => Image.network(
        Api.i.thumbUrl(widget.project.id, e.path),
        height: h,
        width: w,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(fileIcon(e), size: h == null ? 40 : 20),
      );

  void _preview(FileEntry e) =>
      MediaPreview.show(context, widget.project.id, e);

  Widget _menu(BuildContext c, AppLocalizations l10n, FileEntry e) =>
      PopupMenuButton<String>(
        onSelected: (v) async {
          switch (v) {
            case 'zip':
              try {
                await openExternal(Api.i.zipUrl(widget.project.id, [e.path]));
              } catch (err) {
                if (c.mounted) snack(c, err);
              }
            case 'download':
              try {
                await openExternal(
                    Api.i.downloadUrl(widget.project.id, e.path, dl: true));
              } catch (err) {
                if (c.mounted) snack(c, err);
              }
            case 'rename':
              _rename(e);
            case 'delete':
              _delete(e);
          }
        },
        itemBuilder: (_) => [
          if (e.isDir)
            PopupMenuItem(value: 'zip', child: Text(l10n.downloadZip))
          else
            PopupMenuItem(value: 'download', child: Text(l10n.download)),
          if (widget.project.editable) ...[
            PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
          ],
        ],
      );

  Widget _tile(BuildContext c, AppLocalizations l10n, FileEntry e) => ListTile(
        leading: _sel
            ? Checkbox(
                value: _selPaths.contains(e.path),
                onChanged: (_) => _toggleSel(e))
            : SizedBox(
                width: 40,
                height: 40,
                child: e.isDir || !thumbable(e.name)
                    ? Icon(fileIcon(e))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _thumb(e, h: 40, w: 40))),
        title: Text(e.name),
        subtitle: e.isDir
            ? null
            : Text('${fmtBytes(e.size)}  ·  ${fmtAgo(l10n, e.modified)}'),
        onTap: _sel
            ? () => _toggleSel(e)
            : e.isDir
                ? () => _go(e.path)
                : (thumbable(e.name) || playableMedia(e.name))
                    ? () => _preview(e)
                    : null,
        trailing: _sel || (e.isDir && !widget.project.editable)
            ? null
            : _menu(c, l10n, e),
      );

  Widget _cell(BuildContext c, AppLocalizations l10n, FileEntry e) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _sel
              ? () => _toggleSel(e)
              : e.isDir
                  ? () => _go(e.path)
                  : (thumbable(e.name) || playableMedia(e.name))
                      ? () => _preview(e)
                      : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(fileIcon(e)),
                const Spacer(),
                if (_sel)
                  SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                          value: _selPaths.contains(e.path),
                          onChanged: (_) => _toggleSel(e)))
                else if (!e.isDir || widget.project.editable)
                  _menu(c, l10n, e),
              ]),
              if (!e.isDir && thumbable(e.name))
                Expanded(
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _thumb(e, w: double.infinity)))
              else
                const Spacer(),
              Text(e.name, overflow: TextOverflow.ellipsis),
              if (!e.isDir)
                Text('${fmtBytes(e.size)}  ·  ${fmtAgo(l10n, e.modified)}',
                    style: Theme.of(c).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      );
}

class RendersTab extends StatefulWidget {
  final Project project;
  const RendersTab({super.key, required this.project});
  @override
  State<RendersTab> createState() => _RendersTabState();
}

class _RendersTabState extends State<RendersTab> {
  static const _page = 50;
  List<RenderJob>? _jobs;
  bool _more = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_jobs?.any((j) => j.active) ?? false) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shown = _jobs?.length ?? _page;
      final j = await Api.i
          .renders(widget.project.id, limit: shown < _page ? _page : shown);
      if (mounted) {
        setState(() {
          _jobs = j;
          _more = j.length >= (shown < _page ? _page : shown);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMore() async {
    try {
      final j = await Api.i.renders(widget.project.id, offset: _jobs!.length);
      if (mounted) {
        setState(() {
          _jobs = [...?_jobs, ...j];
          _more = j.length >= _page;
        });
      }
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _cancel(RenderJob j) async {
    try {
      await Api.i.cancelRender(j.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _retry(RenderJob j) async {
    final theme = _theme(context);
    try {
      final next = await Api.i.retryRender(j.id);
      if (next.mode == 'device' && mounted) {
        await openEditor(context, Api.i,
            Api.i.renderUrl(widget.project.id, next.id, theme: theme));
      }
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete(RenderJob j) async {
    if (!await confirm(context, context.l10n.delete,
        context.l10n.deleteRenderBody(j.outputName))) {
      return;
    }
    try {
      await Api.i.deleteRender(j.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _download(RenderJob j) async {
    try {
      final files = await Api.i.files(widget.project.id, 'Exports');
      final f = files
          .where((e) =>
              !e.isDir &&
              (e.name == j.outputName || e.name.startsWith('${j.outputName}.')))
          .toList();
      if (f.isEmpty) throw StateError('not found');
      f.sort((a, b) => b.size.compareTo(a.size));
      await openExternal(Api.i
          .downloadUrl(widget.project.id, 'Exports/${f.first.name}', dl: true));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final jobs = _jobs;
    return Scaffold(
      floatingActionButton: widget.project.editable
          ? FloatingActionButton.extended(
              onPressed: () async {
                final queued = await showDialog<bool>(
                    context: context,
                    builder: (_) => RenderDialog(project: widget.project));
                if (queued == true) _load();
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.newRender),
            )
          : null,
      body: jobs == null
          ? const Center(child: CircularProgressIndicator())
          : jobs.isEmpty
              ? Center(child: Text(l10n.noRenders))
              : ListView.builder(
                  itemCount: jobs.length + (_more ? 1 : 0),
                  itemBuilder: (c, i) {
                    if (i >= jobs.length) {
                      return Center(
                        child: TextButton(
                          onPressed: _loadMore,
                          child: Text(l10n.loadMore),
                        ),
                      );
                    }
                    final j = jobs[i];
                    return ListTile(
                      leading: Icon(switch (j.status) {
                        'done' => Icons.check_circle_outline,
                        'failed' => Icons.error_outline,
                        'canceled' => Icons.cancel_outlined,
                        _ => Icons.timelapse,
                      }),
                      title: Text(j.outputName),
                      subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.renderStatus(
                                j.status, fmtAgo(l10n, j.createdAt))),
                            if (j.active)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: LinearProgressIndicator(
                                    value: j.status == 'running'
                                        ? j.progress
                                        : null),
                              ),
                            if (j.error.isNotEmpty)
                              Text(j.error,
                                  style: TextStyle(
                                      color: Theme.of(c).colorScheme.error)),
                          ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (j.status == 'done')
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: l10n.download,
                            onPressed: () => _download(j),
                          ),
                        if (j.active && widget.project.editable)
                          IconButton(
                              icon: const Icon(Icons.stop),
                              tooltip: l10n.cancel,
                              onPressed: () => _cancel(j)),
                        if (!j.active && widget.project.editable) ...[
                          IconButton(
                              icon: const Icon(Icons.refresh),
                              tooltip: l10n.retry,
                              onPressed: () => _retry(j)),
                          IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: l10n.delete,
                              onPressed: () => _delete(j)),
                        ],
                      ]),
                    );
                  },
                ),
    );
  }
}

class RenderDialog extends StatefulWidget {
  final Project project;
  const RenderDialog({super.key, required this.project});
  @override
  State<RenderDialog> createState() => _RenderDialogState();
}

class _RenderDialogState extends State<RenderDialog> {
  static const _formats = {
    'h264': 'H.264 (MP4)',
    'hevc': 'HEVC (MP4)',
    'prores': 'ProRes',
    'dnxhr': 'DNxHR',
    'apv': 'APV',
    'mjpeg': 'MJPEG',
    'mxf-op1a': 'MXF OP1a',
    'mxf-opatom': 'MXF OP-Atom',
    'png': 'PNG sequence',
    'tiff': 'TIFF sequence',
    'bmp': 'BMP sequence',
    'jpg': 'JPEG sequence',
    'tga': 'TGA sequence',
    'dpx': 'DPX sequence',
    'exr': 'EXR sequence',
    'gif': 'GIF',
    'wav': 'WAV',
    'aiff': 'AIFF',
    'aac': 'AAC',
    'mp3': 'MP3',
    'flac': 'FLAC',
  };

  RenderInfo? _info;
  String? _infoError;
  int _seq = 0;
  String _mode = 'device';
  final _out = TextEditingController(text: 'export');
  String _format = 'h264';
  (int, int)? _res;
  String _range = 'entire';
  final _rangeStart = TextEditingController();
  final _rangeEnd = TextEditingController();
  bool _audio = true;
  final _preset = TextEditingController();
  bool _busy = false;
  final _quality = TextEditingController();
  final _bitrate = TextEditingController();
  final _crf = TextEditingController();
  final _flacLevel = TextEditingController();
  final _scale = TextEditingController();
  final _loudness = TextEditingController();
  final _extra = TextEditingController();
  String? _bitrateMode, _audioCodec, _hardware;
  String? _h264Profile, _proresProfile, _dnxProfile, _apvProfile, _mxfCodec;
  String? _exrCompression, _captionSidecar;
  bool _h264Intra = false, _burnCaptions = false, _alpha = false;

  @override
  void initState() {
    super.initState();
    Api.i.renderInfo(widget.project.id).then((i) {
      if (mounted) {
        setState(() {
          _info = i;
          _seq = i.activeSequence ??
              (i.sequences.isEmpty ? 0 : i.sequences.first.id);
        });
      }
    }).catchError((e) {
      if (mounted) setState(() => _infoError = '$e');
    });
  }

  @override
  void dispose() {
    for (final c in [
      _out,
      _rangeStart,
      _rangeEnd,
      _preset,
      _quality,
      _bitrate,
      _crf,
      _flacLevel,
      _scale,
      _loudness,
      _extra,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? _params() {
    final l10n = context.l10n;
    final p = <String, dynamic>{'format': _format};
    if (_res != null) {
      p['width'] = _res!.$1;
      p['height'] = _res!.$2;
    }
    if (_range != 'entire') p['range'] = _range;
    if (_range == 'custom') {
      final s = double.tryParse(_rangeStart.text.trim());
      final e = double.tryParse(_rangeEnd.text.trim());
      if (s == null || e == null) {
        snack(context, l10n.rangeNeedTimes);
        return null;
      }
      p['startSeconds'] = s;
      p['endSeconds'] = e;
    }
    if (!_audio) p['audio'] = false;
    if (_preset.text.trim().isNotEmpty) p['preset'] = _preset.text.trim();
    void num(String key, TextEditingController c, {bool dbl = false}) {
      final v =
          dbl ? double.tryParse(c.text.trim()) : int.tryParse(c.text.trim());
      if (v != null) p[key] = v;
    }

    num('quality', _quality);
    num('bitrateKbps', _bitrate);
    num('crf', _crf);
    num('flacLevel', _flacLevel);
    num('scale', _scale, dbl: true);
    num('loudnessLufs', _loudness, dbl: true);
    if (_bitrateMode != null) p['bitrateMode'] = _bitrateMode;
    if (_audioCodec != null) p['audioCodec'] = _audioCodec;
    if (_hardware != null) p['hardwareEncoding'] = _hardware;
    if (_h264Profile != null) p['h264Profile'] = _h264Profile;
    if (_proresProfile != null) p['proresProfile'] = _proresProfile;
    if (_dnxProfile != null) p['dnxProfile'] = _dnxProfile;
    if (_apvProfile != null) p['apvProfile'] = _apvProfile;
    if (_mxfCodec != null) p['mxfVideoCodec'] = _mxfCodec;
    if (_exrCompression != null) p['exrCompression'] = _exrCompression;
    if (_captionSidecar != null) p['captionSidecar'] = _captionSidecar;
    if (_h264Intra) p['h264IntraOnly'] = true;
    if (_burnCaptions) p['burnCaptions'] = true;
    if (_alpha) p['alpha'] = true;
    if (_extra.text.trim().isNotEmpty) {
      final Object? v;
      try {
        v = jsonDecode(_extra.text.trim());
      } on FormatException {
        snack(context, l10n.invalidJson);
        return null;
      }
      if (v is! Map) {
        snack(context, l10n.invalidJson);
        return null;
      }
      p.addAll(Map<String, dynamic>.from(v));
    }
    return p;
  }

  Future<void> _submit() async {
    final params = _params();
    if (params == null) return;
    setState(() => _busy = true);
    final theme = _theme(context);
    try {
      final job = await Api.i.createRender(widget.project.id, {
        'mode': _mode,
        'sequence': _seq,
        'output': _out.text.trim().isEmpty ? 'export' : _out.text.trim(),
        'params': params,
      });
      if (_mode == 'device' && mounted) {
        await openEditor(context, Api.i,
            Api.i.renderUrl(widget.project.id, job.id, theme: theme));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        if (context.mounted) snack(context, e);
        setState(() => _busy = false);
      }
    }
  }

  Widget _drop<T>(String label, T? value, List<(T?, String)> items,
          void Function(T?) set) =>
      DropdownButtonFormField<T>(
        isExpanded: true,
        initialValue: value,
        decoration: dec(label),
        items: [
          for (final (v, label) in items)
            DropdownMenuItem<T>(value: v, child: Text(label)),
        ],
        onChanged: set,
      );

  Widget _field(String label, TextEditingController c) =>
      TextField(controller: c, decoration: dec(label));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = _info;
    final canSubmit = !_busy &&
        info != null &&
        info.project &&
        (info.sequences.isNotEmpty || _seq > 0);
    return AlertDialog(
      title: Text(l10n.newRender),
      content: SizedBox(
        width: 620,
        height: 560,
        child: _infoError != null
            ? Center(child: Text(_infoError!))
            : info == null
                ? const Center(child: CircularProgressIndicator())
                : !info.project
                    ? Center(child: Text(l10n.openInFilmcraftFirst))
                    : SingleChildScrollView(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (info.sequences.isEmpty)
                                Text(l10n.noSequences)
                              else
                                _drop<int>(
                                    l10n.sequence,
                                    _seq,
                                    [
                                      for (final s in info.sequences)
                                        (s.id, s.name)
                                    ],
                                    (v) => setState(() => _seq = v ?? 0)),
                              const SizedBox(height: 8),
                              _drop<String>(
                                  l10n.renderMode,
                                  _mode,
                                  [
                                    ('device', l10n.renderOnDevice),
                                    if (info.serverRender)
                                      ('server', l10n.renderOnServer),
                                  ],
                                  (v) => setState(() => _mode = v ?? 'device')),
                              const SizedBox(height: 8),
                              _field(l10n.outputName, _out),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: _drop<String>(
                                      l10n.outputFormat,
                                      _format,
                                      [
                                        for (final e in _formats.entries)
                                          (e.key, e.value)
                                      ],
                                      (v) => setState(
                                          () => _format = v ?? 'h264')),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _drop<(int, int)>(
                                      l10n.resolution,
                                      _res,
                                      [
                                        (null, l10n.matchSource),
                                        ((3840, 2160), '2160p'),
                                        ((1920, 1080), '1080p'),
                                        ((1280, 720), '720p'),
                                        ((854, 480), '480p'),
                                      ],
                                      (v) => setState(() => _res = v)),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                  child: _drop<String>(
                                      l10n.exportRange,
                                      _range,
                                      [
                                        ('entire', l10n.rangeEntire),
                                        ('inOut', l10n.rangeInOut),
                                        ('workArea', l10n.rangeWorkArea),
                                        ('custom', l10n.rangeCustom),
                                      ],
                                      (v) => setState(
                                          () => _range = v ?? 'entire')),
                                ),
                                if (_range == 'custom') ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child:
                                          _field(l10n.rangeStart, _rangeStart)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: _field(l10n.rangeEnd, _rangeEnd)),
                                ],
                              ]),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(l10n.renderAudio),
                                value: _audio,
                                onChanged: (v) => setState(() => _audio = v),
                              ),
                              _field(l10n.preset, _preset),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(l10n.advancedOptions),
                                children: [
                                  Row(children: [
                                    Expanded(
                                        child: _field(l10n.quality, _quality)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child:
                                            _field(l10n.bitrateKbps, _bitrate)),
                                    const SizedBox(width: 8),
                                    Expanded(child: _field(l10n.crf, _crf)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.bitrateMode,
                                          _bitrateMode,
                                          [
                                            (null, l10n.defaultOption),
                                            ('cbr', 'CBR'),
                                            ('vbr1Pass', 'VBR 1-pass'),
                                            ('vbr2Pass', 'VBR 2-pass'),
                                            ('crf', 'CRF'),
                                          ],
                                          (v) =>
                                              setState(() => _bitrateMode = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.audioCodec,
                                          _audioCodec,
                                          [
                                            (null, l10n.defaultOption),
                                            ('auto', 'Auto'),
                                            ('aac', 'AAC'),
                                            ('pcm', 'PCM'),
                                            ('flac', 'FLAC'),
                                          ],
                                          (v) =>
                                              setState(() => _audioCodec = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child:
                                            _field(l10n.flacLevel, _flacLevel)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.hardwareEncoding,
                                          _hardware,
                                          [
                                            (null, l10n.defaultOption),
                                            ('auto', 'Auto'),
                                            ('off', 'Off'),
                                          ],
                                          (v) => setState(() => _hardware = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child:
                                            _field(l10n.renderScale, _scale)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: _field(
                                            l10n.loudnessLufs, _loudness)),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.h264Profile,
                                          _h264Profile,
                                          [
                                            (null, l10n.defaultOption),
                                            ('baseline', 'Baseline'),
                                            ('main', 'Main'),
                                            ('high', 'High'),
                                            ('high10', 'High 10'),
                                          ],
                                          (v) =>
                                              setState(() => _h264Profile = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.proresProfile,
                                          _proresProfile,
                                          [
                                            (null, l10n.defaultOption),
                                            ('proxy', 'Proxy'),
                                            ('lt', 'LT'),
                                            ('standard', 'Standard'),
                                            ('hq', 'HQ'),
                                            ('4444', '4444'),
                                            ('4444xq', '4444 XQ'),
                                          ],
                                          (v) => setState(
                                              () => _proresProfile = v)),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.dnxProfile,
                                          _dnxProfile,
                                          [
                                            (null, l10n.defaultOption),
                                            ('lb', 'LB'),
                                            ('sq', 'SQ'),
                                            ('hq', 'HQ'),
                                            ('hqx', 'HQX'),
                                          ],
                                          (v) =>
                                              setState(() => _dnxProfile = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.apvProfile,
                                          _apvProfile,
                                          [
                                            (null, l10n.defaultOption),
                                            ('422-10', '422-10'),
                                            ('422-12', '422-12'),
                                            ('444-10', '444-10'),
                                            ('444-12', '444-12'),
                                            ('4444-10', '4444-10'),
                                            ('4444-12', '4444-12'),
                                            ('400-10', '400-10'),
                                          ],
                                          (v) =>
                                              setState(() => _apvProfile = v)),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.mxfVideoCodec,
                                          _mxfCodec,
                                          [
                                            (null, l10n.defaultOption),
                                            ('dnxhr', 'DNxHR'),
                                            ('proRes', 'ProRes'),
                                            ('h264', 'H.264'),
                                          ],
                                          (v) => setState(() => _mxfCodec = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.exrCompression,
                                          _exrCompression,
                                          [
                                            (null, l10n.defaultOption),
                                            ('none', 'None'),
                                            ('rle', 'RLE'),
                                            ('zips', 'ZIPS'),
                                            ('zip', 'ZIP'),
                                          ],
                                          (v) => setState(
                                              () => _exrCompression = v)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _drop<String>(
                                          l10n.captionSidecar,
                                          _captionSidecar,
                                          [
                                            (null, l10n.defaultOption),
                                            ('srt', 'SRT'),
                                            ('vtt', 'VTT'),
                                          ],
                                          (v) => setState(
                                              () => _captionSidecar = v)),
                                    ),
                                  ]),
                                  _field(l10n.extraParams, _extra),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 8, children: [
                                    FilterChip(
                                        label: Text(l10n.h264IntraOnly),
                                        selected: _h264Intra,
                                        onSelected: (v) =>
                                            setState(() => _h264Intra = v)),
                                    FilterChip(
                                        label: Text(l10n.burnCaptions),
                                        selected: _burnCaptions,
                                        onSelected: (v) =>
                                            setState(() => _burnCaptions = v)),
                                    FilterChip(
                                        label: Text(l10n.alphaChannel),
                                        selected: _alpha,
                                        onSelected: (v) =>
                                            setState(() => _alpha = v)),
                                  ]),
                                ],
                              ),
                            ]),
                      ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: Text(_busy ? l10n.queuing : l10n.render),
        ),
      ],
    );
  }
}

class _ShareDialog extends StatefulWidget {
  final Project project;
  const _ShareDialog({required this.project});
  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  List<Share>? _shares;
  List<ShareLink>? _links;
  final _tokens = <String, String>{};
  final _user = TextEditingController();
  String _level = 'view';
  String _scope = 'renders';
  int _days = 7;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _user.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.projectShares(widget.project.id);
      setState(() => _shares = v);
    } catch (e) {
      setState(() => _shares = []);
      if (mounted) snack(context, e);
    }
    try {
      final l = await Api.i.projectLinks(widget.project.id);
      setState(() => _links = l);
    } catch (e) {
      setState(() => _links = []);
      if (mounted) snack(context, e);
    }
  }

  Future<void> _createLink() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await Api.i.linkCreate(widget.project.id, _scope,
          expiresAt: _days > 0
              ? DateTime.now().millisecondsSinceEpoch ~/ 1000 + _days * 86400
              : 0);
      _tokens['${r['id']}'] = '${r['token']}';
      await _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  String _linkUrl(ShareLink l) =>
      '${Uri.base.scheme.startsWith('http') ? '${Uri.base.origin}/' : ''}app/link/${_tokens[l.id]}';

  Future<void> _send() async {
    final username = _user.text.trim();
    if (username.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await Api.i.shareProject(widget.project.id, username, _level);
      _user.clear();
      await _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shares = _shares;
    return AlertDialog(
      title: Text(l10n.shareProject),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _user,
                  decoration:
                      InputDecoration(labelText: l10n.username, isDense: true),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _level,
                items: [
                  DropdownMenuItem(value: 'view', child: Text(l10n.canView)),
                  DropdownMenuItem(value: 'edit', child: Text(l10n.canEdit)),
                ],
                onChanged: (v) => setState(() => _level = v!),
              ),
              IconButton(
                  icon: const Icon(Icons.send),
                  tooltip: l10n.send,
                  onPressed: _busy ? null : _send),
            ]),
            const SizedBox(height: 8),
            if (shares == null)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())
            else
              for (final sh in shares)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.person_outline),
                  title: Text(sh.inviteeName.isEmpty
                      ? sh.inviteeUsername
                      : sh.inviteeName),
                  subtitle: Text(
                      '${sh.level == 'edit' ? l10n.canEdit : l10n.canView}  ·  ${sh.status == 'pending' ? l10n.pending : sh.status == 'accepted' ? l10n.accepted : l10n.declined}'),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (v) async {
                      try {
                        if (v == 'revoke') {
                          await Api.i.shareRevoke(widget.project.id, sh.id);
                        } else {
                          await Api.i.shareLevel(widget.project.id, sh.id, v);
                        }
                        _load();
                      } catch (e) {
                        if (context.mounted) snack(context, e);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'view', child: Text(l10n.canView)),
                      PopupMenuItem(value: 'edit', child: Text(l10n.canEdit)),
                      PopupMenuItem(value: 'revoke', child: Text(l10n.revoke)),
                    ],
                  ),
                ),
            const Divider(height: 24),
            Row(children: [
              Text(l10n.shareLinks,
                  style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              IconButton(
                  icon: const Icon(Icons.add_link),
                  tooltip: l10n.createLink,
                  onPressed: _busy ? null : _createLink),
            ]),
            Row(children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _scope,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                        value: 'renders', child: Text(l10n.scopeRenders)),
                    DropdownMenuItem(
                        value: 'project', child: Text(l10n.scopeProject)),
                  ],
                  onChanged: (v) => setState(() => _scope = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<int>(
                  value: _days,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l10n.expiryNever)),
                    DropdownMenuItem(value: 1, child: Text(l10n.expiryDay)),
                    DropdownMenuItem(value: 7, child: Text(l10n.expiryWeek)),
                    DropdownMenuItem(value: 30, child: Text(l10n.expiryMonth)),
                  ],
                  onChanged: (v) => setState(() => _days = v!),
                ),
              ),
            ]),
            if (_links != null)
              for (final l in _links!)
                if (!l.revoked)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.link, size: 20),
                    title: Text(l.scope == 'renders'
                        ? l10n.scopeRenders
                        : l10n.scopeProject),
                    subtitle: Text(l.expiresAt > 0
                        ? l10n.linkExpires(fmtTime(l10n, l.expiresAt))
                        : l10n.expiryNever),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (_tokens.containsKey(l.id))
                        IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: l10n.copy,
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _linkUrl(l)));
                              snack(context, l10n.copied, good: true);
                            }),
                      IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: l10n.revoke,
                          onPressed: () async {
                            try {
                              await Api.i.linkRevoke(widget.project.id, l.id);
                              _load();
                            } catch (e) {
                              if (context.mounted) snack(context, e);
                            }
                          }),
                    ]),
                  ),
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.ok)),
      ],
    );
  }
}
