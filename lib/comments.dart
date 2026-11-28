import 'package:flutter/material.dart';
import 'api.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'util.dart';

class CommentsTab extends StatefulWidget {
  final Project project;
  const CommentsTab({super.key, required this.project});
  @override
  State<CommentsTab> createState() => _CommentsTabState();
}

class _CommentsTabState extends State<CommentsTab> {
  final _c = TextEditingController();
  List<ProjectComment>? _items;
  ProjectComment? _replyTo;
  String _err = '';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.comments(widget.project.id);
      setState(() {
        _items = v;
        _err = '';
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _post() async {
    final body = _c.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      await Api.i
          .addComment(widget.project.id, body, parentId: _replyTo?.id ?? '');
      _c.clear();
      if (mounted) {
        setState(() {
          _sending = false;
          _replyTo = null;
        });
      }
      _load();
    } catch (e) {
      if (mounted) {
        setState(() => _sending = false);
        snack(context, e);
      }
    }
  }

  Future<void> _edit(ProjectComment c) async {
    final body = await promptText(
        context, context.l10n.editComment, context.l10n.writeComment, c.body);
    if (body == null || body.trim().isEmpty || !mounted) return;
    try {
      await Api.i.editComment(widget.project.id, c.id, body);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete(ProjectComment c) async {
    if (!await confirm(context, context.l10n.delete, c.body)) return;
    try {
      await Api.i.deleteComment(widget.project.id, c.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Widget _comment(AppLocalizations l10n, ProjectComment c) {
    final own = c.userId == Api.i.user?.id;
    final canDel = own || widget.project.mine;
    return Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: c.avatar.isNotEmpty
                ? NetworkImage(Api.i.avatarUrl(c.userId, c.avatar),
                    headers: Api.i.imageHeaders)
                : null,
            onBackgroundImageError: c.avatar.isNotEmpty ? (_, __) {} : null,
            child:
                c.avatar.isNotEmpty ? null : const Icon(Icons.person_outline),
          ),
          title: Text(c.body),
          subtitle: Text(
              '${c.author}  ·  ${fmtAgo(l10n, c.createdAt)}${c.editedAt > 0 ? '  ·  ${l10n.edited}' : ''}'),
          trailing: (own || canDel)
              ? PopupMenuButton<String>(
                  onSelected: (v) => v == 'edit' ? _edit(c) : _delete(c),
                  itemBuilder: (_) => [
                    if (own)
                      PopupMenuItem(
                          value: 'edit', child: Text(l10n.editComment)),
                    PopupMenuItem(value: 'del', child: Text(l10n.delete)),
                  ],
                )
              : null,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 4),
          child: TextButton(
            onPressed: () => setState(() => _replyTo = c),
            child: Text(l10n.reply),
          ),
        ),
      ]),
    );
  }

  List<Widget> _thread(AppLocalizations l10n, List<ProjectComment> all,
      String parent, int depth) {
    return [
      for (final c in all.where((c) => c.parentId == parent)) ...[
        Padding(
          padding: EdgeInsets.only(left: depth > 6 ? 96.0 : depth * 16.0),
          child: _comment(l10n, c),
        ),
        ..._thread(l10n, all, c.id, depth + 1),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final items = _items;
    final replyTo = _replyTo;
    return Column(children: [
      Expanded(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? Center(child: Text(l10n.noComments))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: _thread(l10n, items, '', 0),
                  ),
      ),
      if (replyTo != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(children: [
            Expanded(
                child: Text(l10n.replyingTo(replyTo.author),
                    overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _replyTo = null),
            ),
          ]),
        ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                decoration: InputDecoration(
                    hintText:
                        replyTo == null ? l10n.writeComment : l10n.writeReply),
                onSubmitted: (_) => _post(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sending ? null : _post,
            ),
          ]),
        ),
      ),
    ]);
  }
}
