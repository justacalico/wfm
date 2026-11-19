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
      await Api.i.addComment(widget.project.id, body);
      _c.clear();
      if (mounted) setState(() => _sending = false);
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
    final canDel = own || widget.project.mine || (Api.i.user?.isOwner ?? false);
    return Card(
      child: ListTile(
        title: Text(c.body),
        subtitle: Text(
            '${c.author}  ·  ${fmtTime(l10n, c.createdAt)}${c.editedAt > 0 ? '  ·  ${l10n.edited}' : ''}'),
        trailing: (own || canDel)
            ? PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? _edit(c) : _delete(c),
                itemBuilder: (_) => [
                  if (own)
                    PopupMenuItem(value: 'edit', child: Text(l10n.editComment)),
                  PopupMenuItem(value: 'del', child: Text(l10n.delete)),
                ],
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final items = _items;
    return Column(children: [
      Expanded(
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
                ? Center(child: Text(l10n.noComments))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [for (final c in items) _comment(l10n, c)],
                  ),
      ),
      SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                decoration: InputDecoration(hintText: l10n.writeComment),
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
