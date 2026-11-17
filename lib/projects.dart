import 'dart:async';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
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

  Widget _card(BuildContext c, AppLocalizations l10n, Project p, bool tight) {
    return SizedBox(
      width: tight ? double.infinity : 290,
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
                SizedBox(
                  width: 28,
                  height: 28,
                  child: PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    onSelected: (v) =>
                        v == 'tags' ? _editTags(p) : _moveToGroup(p),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'tags', child: Text(l10n.editTags)),
                      PopupMenuItem(
                          value: 'group', child: Text(l10n.moveToGroup)),
                    ],
                  ),
                ),
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
            ]),
          ),
        ),
      ),
    );
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
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    for (final p in byGroup[g.id] ?? <Project>[])
                      _card(context, l10n, p, tight),
                  ]),
                ],
                if (_groups.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(l10n.ungrouped,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final p in ungrouped) _card(context, l10n, p, tight),
                ]),
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
    final ups = [for (final f in picked) _Upload(f.name, f.bytes.length)];
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
                        child: LinearProgressIndicator(
                            value: done / ups.length)),
                    const SizedBox(width: 12),
                    Text('$done/${ups.length}'),
                  ]),
                  const SizedBox(height: 10),
                  for (final u in ups)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(
                            child: Text(
                                '${u.name}  ·  ${fmtBytes(u.size)}',
                                overflow: TextOverflow.ellipsis)),
                        const SizedBox(width: 10),
                        switch (u.state) {
                          2 => const Icon(Icons.check_circle_outline,
                              size: 18),
                          3 => const Icon(Icons.error_outline, size: 18),
                          1 => const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
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
        await Api.i
            .upload(widget.project.id, '$folder/${picked[i].name}', picked[i].bytes);
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
                    final name = j.outputName.toLowerCase().endsWith('.mp4')
                        ? j.outputName
                        : '${j.outputName}.mp4';
                    return ListTile(
                      leading: Icon(switch (j.status) {
                        'done' => Icons.check_circle_outline,
                        'failed' => Icons.error_outline,
                        'canceled' => Icons.cancel_outlined,
                        _ => Icons.timelapse,
                      }),
                      title: Text(name),
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
                            onPressed: () {
                              try {
                                openExternal(Api.i.downloadUrl(
                                    widget.project.id, 'Exports/$name',
                                    dl: true));
                              } catch (e) {
                                if (c.mounted) snack(c, e);
                              }
                            },
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
  String _folder = 'Raw/A-Roll';
  List<FileEntry> _folderItems = [];
  final List<String> _clips = [];
  final _out = TextEditingController(text: 'export');
  (int, int) _res = (1920, 1080);
  int _fps = 30;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadFolder(_folder);
  }

  Future<void> _loadFolder(String path) async {
    try {
      final f = await Api.i.files(widget.project.id, path);
      setState(() {
        _folder = path;
        _folderItems = f;
      });
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _submit() async {
    if (_clips.isEmpty) return;
    setState(() => _busy = true);
    try {
      await Api.i.createRender(widget.project.id, {
        'width': _res.$1,
        'height': _res.$2,
        'fps': _fps,
        'clips': [
          for (final p in _clips) {'path': p}
        ],
        'output': _out.text.trim().isEmpty ? 'export' : _out.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        if (context.mounted) snack(context, e);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.newRender),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.browseFolder(_folder),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      border:
                          Border.all(color: Theme.of(context).dividerColor)),
                  child: ListView(children: [
                    if (_folder.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.arrow_upward, size: 18),
                        title: const Text('..'),
                        onTap: () => _loadFolder(_folder.contains('/')
                            ? _folder.substring(0, _folder.lastIndexOf('/'))
                            : ''),
                      ),
                    for (final e in _folderItems)
                      ListTile(
                        dense: true,
                        leading: Icon(fileIcon(e), size: 18),
                        title: Text(e.name, overflow: TextOverflow.ellipsis),
                        onTap: e.isDir ? () => _loadFolder(e.path) : null,
                        trailing: e.isDir || _clips.contains(e.path)
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.add, size: 18),
                                onPressed: () =>
                                    setState(() => _clips.add(e.path)),
                              ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          const VerticalDivider(width: 24),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.clipsCount(_clips.length),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Expanded(
                child: _clips.isEmpty
                    ? Center(child: Text(l10n.addClips))
                    : ReorderableListView(
                        onReorderItem: (a, b) => setState(() {
                          _clips.insert(b, _clips.removeAt(a));
                        }),
                        children: [
                          for (final p in _clips)
                            ListTile(
                              key: ValueKey(p),
                              dense: true,
                              title: Text(p,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () =>
                                      setState(() => _clips.remove(p))),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              TextField(controller: _out, decoration: dec(l10n.outputName)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<(int, int)>(
                    isExpanded: true,
                    initialValue: _res,
                    decoration: dec(l10n.resolution),
                    items: const [
                      DropdownMenuItem(
                          value: (3840, 2160), child: Text('4K 2160p')),
                      DropdownMenuItem(
                          value: (1920, 1080), child: Text('1080p')),
                      DropdownMenuItem(value: (1280, 720), child: Text('720p')),
                    ],
                    onChanged: (v) => setState(() => _res = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _fps,
                    decoration: dec(l10n.frameRate),
                    items: const [
                      DropdownMenuItem(value: 24, child: Text('24')),
                      DropdownMenuItem(value: 25, child: Text('25')),
                      DropdownMenuItem(value: 30, child: Text('30')),
                      DropdownMenuItem(value: 60, child: Text('60')),
                    ],
                    onChanged: (v) => setState(() => _fps = v!),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel)),
        FilledButton(
          onPressed: _busy || _clips.isEmpty ? null : _submit,
          child: Text(_busy ? l10n.queuing : l10n.render),
        ),
      ],
    );
  }
}
