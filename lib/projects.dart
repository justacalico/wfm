import 'dart:async';
import 'package:flutter/material.dart';
import 'api.dart';
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
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await Api.i.projects();
      setState(() => _items = p);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final name = await promptText(context, 'New project', 'Project name');
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.createProject(name);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err.isNotEmpty) return Center(child: Text(_err));
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _create, icon: const Icon(Icons.add), label: const Text('New project')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No projects yet. Create one to get started.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 280, mainAxisExtent: 140, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: items.length,
                  itemBuilder: (c, i) {
                    final p = items[i];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => ProjectPage(project: p))),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.displayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis),
                            Text('Created ${fmtAgo(p.createdAt)}', style: Theme.of(c).textTheme.bodySmall),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                try {
                                  openExternal(Api.i.projectUrl(p.id));
                                } catch (e) {
                                  if (c.mounted) snack(c, e);
                                }
                              },
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open in Filmcraft'),
                            ),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
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
    final name = await promptText(context, 'Rename project', 'Display name', _p.displayName);
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.renameProject(_p.id, name);
      setState(() => _p = Project.fromJson({'id': _p.id, 'name': _p.name, 'displayName': name, 'createdAt': _p.createdAt}));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete project', 'Delete "${_p.displayName}" and all of its media? This cannot be undone.')) {
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
            label: const Text('Open in Filmcraft'),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'rename' ? _rename() : _delete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
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
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.folder_outlined), label: Text('Files')),
                  ButtonSegment(value: 1, icon: Icon(Icons.rocket_launch_outlined), label: Text('Renders')),
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
    if (picked.isEmpty) return;
    final folder = _path.isEmpty ? 'Raw/Other' : _path;
    setState(() => _uploading = true);
    try {
      for (final f in picked) {
        await Api.i.upload(widget.project.id, '$folder/${f.name}', f.bytes);
      }
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      setState(() => _uploading = false);
      _load();
    }
  }

  Future<void> _mkdir() async {
    final name = await promptText(context, 'New folder', 'Folder name');
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await Api.i.mkdir(widget.project.id, _path.isEmpty ? name : '$_path/$name');
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _rename(FileEntry e) async {
    final name = await promptText(context, 'Rename', 'New name', e.name);
    if (name == null || name.isEmpty || name == e.name || !mounted) return;
    final parent = e.path.contains('/') ? e.path.substring(0, e.path.lastIndexOf('/')) : '';
    try {
      await Api.i.move(widget.project.id, e.path, parent.isEmpty ? name : '$parent/$name');
      _load();
    } catch (err) {
      if (mounted) snack(context, err);
    }
  }

  Future<void> _delete(FileEntry e) async {
    if (!await confirm(context, 'Delete', 'Delete "${e.path}"?')) return;
    try {
      await Api.i.deleteFile(widget.project.id, e.path);
      _load();
    } catch (err) {
      if (mounted) snack(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crumbs = _path.isEmpty ? <String>[] : _path.split('/');
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          InkWell(onTap: () => _go(''), child: const Icon(Icons.home_outlined, size: 20)),
          for (var i = 0; i < crumbs.length; i++) ...[
            const Icon(Icons.chevron_right, size: 18),
            InkWell(
              onTap: () => _go(crumbs.sublist(0, i + 1).join('/')),
              child: Text(crumbs[i], style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
          const Spacer(),
          if (_uploading)
            const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
          IconButton(icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'New folder', onPressed: _mkdir),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _load),
          FilledButton.tonalIcon(
            onPressed: _uploading ? null : _upload,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Upload'),
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
                    ? const Center(child: Text('Empty folder'))
                    : ListView.builder(
                        itemCount: _items!.length,
                        itemBuilder: (c, i) {
                          final e = _items![i];
                          return ListTile(
                            leading: Icon(fileIcon(e)),
                            title: Text(e.name),
                            subtitle: e.isDir ? null : Text('${fmtBytes(e.size)}  ·  ${fmtAgo(e.modified)}'),
                            onTap: e.isDir ? () => _go(e.path) : null,
                            trailing: PopupMenuButton<String>(
                              onSelected: (v) {
                                switch (v) {
                                  case 'download':
                                    try {
                                      openExternal(Api.i.downloadUrl(widget.project.id, e.path, dl: true));
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
                                if (!e.isDir) const PopupMenuItem(value: 'download', child: Text('Download')),
                                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    final jobs = _jobs;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final queued = await showDialog<bool>(
              context: context, builder: (_) => RenderDialog(project: widget.project));
          if (queued == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('New render'),
      ),
      body: jobs == null
          ? const Center(child: CircularProgressIndicator())
          : jobs.isEmpty
              ? const Center(child: Text('No renders yet.'))
              : ListView.builder(
                  itemCount: jobs.length,
                  itemBuilder: (c, i) {
                    final j = jobs[i];
                    final name = j.outputName.toLowerCase().endsWith('.mp4') ? j.outputName : '${j.outputName}.mp4';
                    return ListTile(
                      leading: Icon(switch (j.status) {
                        'done' => Icons.check_circle_outline,
                        'failed' => Icons.error_outline,
                        'canceled' => Icons.cancel_outlined,
                        _ => Icons.timelapse,
                      }),
                      title: Text(name),
                      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${j.status}${j.worker.isNotEmpty ? ' on ${j.worker}' : ''}  ·  ${fmtAgo(j.createdAt)}'),
                        if (j.active)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: LinearProgressIndicator(value: j.status == 'running' ? j.progress : null),
                          ),
                        if (j.error.isNotEmpty) Text(j.error, style: TextStyle(color: Theme.of(c).colorScheme.error)),
                      ]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (j.status == 'done')
                          IconButton(
                            icon: const Icon(Icons.download),
                            tooltip: 'Download',
                            onPressed: () {
                              try {
                                openExternal(Api.i.downloadUrl(widget.project.id, 'Exports/$name', dl: true));
                              } catch (e) {
                                if (c.mounted) snack(c, e);
                              }
                            },
                          ),
                        if (j.active)
                          IconButton(icon: const Icon(Icons.stop), tooltip: 'Cancel', onPressed: () => _cancel(j)),
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
        'clips': [for (final p in _clips) {'path': p}],
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
    return AlertDialog(
      title: const Text('New render'),
      content: SizedBox(
        width: 560,
        height: 480,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Browse: $_folder', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
                  child: ListView(children: [
                    if (_folder.isNotEmpty)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.arrow_upward, size: 18),
                        title: const Text('..'),
                        onTap: () => _loadFolder(_folder.contains('/') ? _folder.substring(0, _folder.lastIndexOf('/')) : ''),
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
                                onPressed: () => setState(() => _clips.add(e.path)),
                              ),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
          const VerticalDivider(width: 24),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Clips (${_clips.length})', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              Expanded(
                child: _clips.isEmpty
                    ? const Center(child: Text('Add clips from the browser'))
                    : ReorderableListView(
                        onReorderItem: (a, b) => setState(() {
                          _clips.insert(b, _clips.removeAt(a));
                        }),
                        children: [
                          for (final p in _clips)
                            ListTile(
                              key: ValueKey(p),
                              dense: true,
                              title: Text(p, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                              trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() => _clips.remove(p))),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              TextField(controller: _out, decoration: dec('Output name')),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<(int, int)>(
                    initialValue: _res,
                    decoration: dec('Resolution'),
                    items: const [
                      DropdownMenuItem(value: (3840, 2160), child: Text('4K 2160p')),
                      DropdownMenuItem(value: (1920, 1080), child: Text('1080p')),
                      DropdownMenuItem(value: (1280, 720), child: Text('720p')),
                    ],
                    onChanged: (v) => setState(() => _res = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _fps,
                    decoration: dec('FPS'),
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
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy || _clips.isEmpty ? null : _submit,
          child: Text(_busy ? 'Queuing…' : 'Render'),
        ),
      ],
    );
  }
}
