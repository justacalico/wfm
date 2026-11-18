import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'platform.dart';
import 'util.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
    SharedPreferences.getInstance().then((p) {
      final v = p.getInt('projectsView');
      if (v != null && mounted) setState(() => _view = v);
    });
  }

  void _setView(int v) {
    setState(() => _view = v);
    SharedPreferences.getInstance().then((p) => p.setInt('projectsView', v));
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

  Widget _menu(AppLocalizations l10n, Project p) => SizedBox(
        width: 28,
        height: 28,
        child: PopupMenuButton<String>(
          iconSize: 18,
          padding: EdgeInsets.zero,
          onSelected: (v) => v == 'tags' ? _editTags(p) : _moveToGroup(p),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'tags', child: Text(l10n.editTags)),
            PopupMenuItem(value: 'group', child: Text(l10n.moveToGroup)),
          ],
        ),
      );

  Widget _actions(BuildContext c, AppLocalizations l10n, Project p) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton.icon(
          onPressed: () =>
              showDialog(context: c, builder: (_) => RenderDialog(project: p)),
          icon: const Icon(Icons.movie_creation_outlined, size: 16),
          label: Text(l10n.render),
        ),
        TextButton.icon(
          onPressed: () {
            try {
              openExternal(Api.i.projectUrl(p.id));
            } catch (e) {
              if (c.mounted) snack(c, e);
            }
          },
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(l10n.openInFilmcraft),
        ),
      ]);

  Widget _card(BuildContext c, AppLocalizations l10n, Project p, double w) {
    return SizedBox(
      width: w,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(c)
              .push(MaterialPageRoute(builder: (_) => ProjectPage(project: p))),
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
                _menu(l10n, p),
              ]),
              Text(l10n.createdAgo(fmtAgo(l10n, p.createdAt)),
                  style: Theme.of(c).textTheme.bodySmall),
              if (p.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in p.tags) tagChip(context, t),
                  ]),
                ),
              Align(
                  alignment: Alignment.centerRight,
                  child: _actions(c, l10n, p)),
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
        onTap: () => Navigator.of(c)
            .push(MaterialPageRoute(builder: (_) => ProjectPage(project: p))),
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
                    if (p.tags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final t in p.tags) tagChip(context, t),
                        ]),
                      ),
                  ]),
            ),
            _menu(l10n, p),
            _actions(c, l10n, p),
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
    if (_err.isNotEmpty) return Center(child: Text(_err));
    final items = _items;
    final tight = MediaQuery.sizeOf(context).width < 720;
    final filtered = [
      for (final p in items ?? <Project>[])
        if (_tagFilter == null || p.tags.contains(_tagFilter)) p,
    ];
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
                IconButton(
                  icon: Icon(_view == 0 ? Icons.view_list : Icons.grid_view),
                  tooltip: _view == 0 ? l10n.listView : l10n.gridView,
                  onPressed: () => _setView(_view == 0 ? 1 : 0),
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
  const ProjectPage({super.key, required this.project});
  @override
  State<ProjectPage> createState() => _ProjectPageState();
}

class _ProjectPageState extends State<ProjectPage> {
  int _tab = 0;
  late Project _p = widget.project;

  Future<void> _rename() async {
    final name = await promptText(context, context.l10n.renameProject,
        context.l10n.displayName, _p.displayName);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.updateProject(_p.id, displayName: name);
      setState(() => _p = Project.fromJson({
            'id': _p.id,
            'name': _p.name,
            'displayName': name,
            'groupId': _p.groupId,
            'tags': _p.tags,
            'createdAt': _p.createdAt
          }));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, context.l10n.deleteProject,
        context.l10n.deleteProjectBody(_p.displayName))) {
      return;
    }
    try {
      await Api.i.deleteProject(_p.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_p.displayName),
        actions: [
          FilledButton.tonalIcon(
            onPressed: () {
              try {
                openExternal(Api.i.projectUrl(_p.id));
              } catch (e) {
                if (context.mounted) snack(context, e);
              }
            },
            icon: const Icon(Icons.movie_edit, size: 18),
            label: Text(l10n.openInFilmcraft),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'rename' ? _rename() : _delete(),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(l10n.rename)),
              PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
            ],
          ),
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
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
        ),
      ),
      body: _tab == 0 ? FilesTab(project: _p) : RendersTab(project: _p),
    );
  }
}

IconData fileIcon(FileEntry e) {
  if (e.isDir) return Icons.folder_outlined;
  switch (extOf(e.name)) {
    case 'mp4' || 'mov' || 'mkv' || 'webm' || 'avi' || 'm4v':
      return Icons.movie_outlined;
    case 'mp3' || 'wav' || 'aac' || 'flac' || 'ogg' || 'm4a':
      return Icons.audio_file_outlined;
    case 'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'bmp':
      return Icons.image_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

class _Upload {
  final String name;
  final int size;
  int state = 0;
  _Upload(this.name, this.size);
}

class FilesTab extends StatefulWidget {
  final Project project;
  const FilesTab({super.key, required this.project});
  @override
  State<FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends State<FilesTab> {
  String _path = '';
  List<FileEntry>? _items;
  String _err = '';
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
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

  void _go(String path) {
    _path = path;
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
    if (picked.isEmpty || !mounted) return;
    final folder = _path.isEmpty ? 'Raw/Other' : _path;
    final ups = [for (final f in picked) _Upload(f.name, f.size)];
    final tick = ValueNotifier(0);
    final l10n = context.l10n;
    setState(() => _uploading = true);
    unawaited(showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: ValueListenableBuilder<int>(
          valueListenable: tick,
          builder: (ctx, _, __) {
            final done = ups.where((u) => u.state == 2).length;
            return AlertDialog(
              title: Text(l10n.uploadingFiles),
              content: SizedBox(
                width: 360,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                    Expanded(
                        child:
                            LinearProgressIndicator(value: done / ups.length)),
                    const SizedBox(width: 12),
                    Text('$done/${ups.length}'),
                  ]),
                  const SizedBox(height: 10),
                  for (final u in ups)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(
                            child: Text('${u.name}  ·  ${fmtBytes(u.size)}',
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        switch (u.state) {
                          2 => const Icon(Icons.check_circle_outline, size: 18),
                          3 => const Icon(Icons.error_outline, size: 18),
                          1 => const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2)),
                          _ => const Icon(Icons.schedule, size: 16),
                        },
                      ]),
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    ));
    Object? error;
    for (var i = 0; i < picked.length; i++) {
      ups[i].state = 1;
      tick.value++;
      try {
        await uploadPicked(
            Api.i, widget.project.id, '$folder/${picked[i].name}', picked[i]);
        ups[i].state = 2;
      } catch (e) {
        ups[i].state = 3;
        error = e;
        break;
      }
      tick.value++;
    }
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    tick.dispose();
    setState(() => _uploading = false);
    if (error != null && mounted) snack(context, error);
    _load();
  }

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
        child: Row(children: [
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
          if (_uploading)
            const Padding(
                padding: EdgeInsets.only(right: 12),
                child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(
              icon: const Icon(Icons.create_new_folder_outlined),
              tooltip: l10n.newFolder,
              onPressed: _mkdir),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.refresh,
              onPressed: _load),
          FilledButton.tonalIcon(
            onPressed: _uploading ? null : _upload,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(l10n.upload),
          ),
        ]),
      ),
      const Divider(height: 1),
      Expanded(
        child: _err.isNotEmpty
            ? Center(child: Text(_err))
            : _items == null
                ? const Center(child: CircularProgressIndicator())
                : _items!.isEmpty
                    ? Center(child: Text(l10n.emptyFolder))
                    : ListView.builder(
                        itemCount: _items!.length,
                        itemBuilder: (c, i) {
                          final e = _items![i];
                          return ListTile(
                            leading: Icon(fileIcon(e)),
                            title: Text(e.name),
                            subtitle: e.isDir
                                ? null
                                : Text(
                                    '${fmtBytes(e.size)}  ·  ${fmtAgo(l10n, e.modified)}'),
                            onTap: e.isDir ? () => _go(e.path) : null,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'download':
                                    try {
                                      openExternal(Api.i.downloadUrl(
                                          widget.project.id, e.path,
                                          dl: true));
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
                                if (!e.isDir)
                                  PopupMenuItem(
                                      value: 'download',
                                      child: Text(l10n.download)),
                                PopupMenuItem(
                                    value: 'rename', child: Text(l10n.rename)),
                                PopupMenuItem(
                                    value: 'delete', child: Text(l10n.delete)),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    ]);
  }
}

class RendersTab extends StatefulWidget {
  final Project project;
  const RendersTab({super.key, required this.project});
  @override
  State<RendersTab> createState() => _RendersTabState();
}

class _RendersTabState extends State<RendersTab> {
  List<RenderJob>? _jobs;
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
      final j = await Api.i.renders(widget.project.id);
      if (mounted) setState(() => _jobs = j);
    } catch (_) {}
  }

  Future<void> _cancel(RenderJob j) async {
    try {
      await Api.i.cancelRender(j.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _download(RenderJob j) async {
    try {
      final files = await Api.i.files(widget.project.id, 'Exports');
      final f = files.where((e) =>
          !e.isDir &&
          (e.name == j.outputName || e.name.startsWith('${j.outputName}.')));
      if (f.isEmpty) throw StateError('not found');
      openExternal(Api.i
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final queued = await showDialog<bool>(
              context: context,
              builder: (_) => RenderDialog(project: widget.project));
          if (queued == true) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.newRender),
      ),
      body: jobs == null
          ? const Center(child: CircularProgressIndicator())
          : jobs.isEmpty
              ? Center(child: Text(l10n.noRenders))
              : ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (c, i) {
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
                            Text(j.worker.isNotEmpty
                                ? l10n.renderStatusWorker(j.status, j.worker,
                                    fmtAgo(l10n, j.createdAt))
                                : l10n.renderStatus(
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
                        if (j.active)
                          IconButton(
                              icon: const Icon(Icons.stop),
                              tooltip: l10n.cancel,
                              onPressed: () => _cancel(j)),
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
          _mode = i.serverRender ? 'server' : 'device';
        });
      }
    }).catchError((e) {
      if (mounted) setState(() => _infoError = '$e');
    });
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
    try {
      final job = await Api.i.createRender(widget.project.id, {
        'mode': _mode,
        'sequence': _seq,
        'output': _out.text.trim().isEmpty ? 'export' : _out.text.trim(),
        'params': params,
      });
      if (_mode == 'device') {
        openExternal(Api.i.renderUrl(widget.project.id, job.id));
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
                                  const SizedBox(height: 8),
                                  _field(l10n.extraParams, _extra),
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
