import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'util.dart';

const _emojis = ['👍', '❤️', '😂', '🎉', '😮', '😢'];

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<Announcement>? _items;
  String _err = '';
  bool _more = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.announcements();
      setState(() {
        _items = v;
        _more = v.length >= 50;
        _err = '';
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _loadMore() async {
    final items = _items;
    if (items == null || items.isEmpty) return;
    try {
      final v = await Api.i.announcements(before: items.last.createdAt);
      setState(() {
        _items = [...items, ...v];
        _more = v.length >= 50;
      });
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _compose([Announcement? a]) async {
    final r = await showDialog<({String title, String body, bool comments, bool reactions})>(
        context: context,
        builder: (_) => _ComposeDialog(announcement: a));
    if (r == null || !mounted) return;
    try {
      if (a == null) {
        await Api.i.announcementCreate(r.title, r.body,
            comments: r.comments, reactions: r.reactions);
      } else {
        await Api.i.announcementUpdate(a.id,
            title: r.title,
            body: r.body,
            comments: r.comments,
            reactions: r.reactions);
      }
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _remove(Announcement a) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.deleteAnnouncement,
        l10n.deleteAnnouncementConfirm)) {
      return;
    }
    try {
      await Api.i.announcementDelete(a.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _react(Announcement a, String emoji) async {
    try {
      await Api.i.announcementReact(a.id, emoji);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Widget _reactions(AppLocalizations l10n, Announcement a) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final r in a.reactions)
        InkWell(
          onTap: a.reactionsEnabled ? () => _react(a, r.emoji) : null,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: r.mine ? scheme.secondaryContainer : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text('${r.emoji} ${r.count}'),
          ),
        ),
      if (a.reactionsEnabled)
        PopupMenuButton<String>(
          tooltip: l10n.addReaction,
          onSelected: (e) => _react(a, e),
          itemBuilder: (_) => [
            for (final e in _emojis)
              PopupMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 22)))
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_reaction_outlined, size: 18),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final items = _items;
    final tight = MediaQuery.sizeOf(context).width < 720;
    final me = Api.i.user;
    final canPost = me?.canAnnounce ?? false;
    return Scaffold(
      appBar: tight ? null : AppBar(title: Text(l10n.navAnnouncements)),
      floatingActionButton: canPost
          ? FloatingActionButton(
              onPressed: _compose,
              tooltip: l10n.newAnnouncement,
              child: const Icon(Icons.add))
          : null,
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(child: Text(l10n.noAnnouncements))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final a in items)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                    child: Text(a.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium)),
                                if (canPost || a.authorId == me?.id)
                                  PopupMenuButton<String>(
                                    iconSize: 20,
                                    onSelected: (v) => v == 'edit'
                                        ? _compose(a)
                                        : _remove(a),
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                          value: 'edit',
                                          child: Text(l10n.edit)),
                                      PopupMenuItem(
                                          value: 'delete',
                                          child: Text(l10n.delete)),
                                    ],
                                  ),
                              ]),
                              Text(
                                  '${a.authorName.isEmpty ? a.authorUsername : a.authorName}  ·  ${fmtAgo(l10n, a.createdAt)}${a.editedAt > 0 ? '  ·  ${l10n.editedMark}' : ''}',
                                  style:
                                      Theme.of(context).textTheme.bodySmall),
                              const SizedBox(height: 8),
                              MarkdownBody(
                                  data: a.body,
                                  onTapLink: (_, href, __) {
                                    if (href != null) launchUrl(Uri.parse(href));
                                  }),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(child: _reactions(l10n, a)),
                                TextButton.icon(
                                  onPressed: () =>
                                      _open(a),
                                  icon: const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 18),
                                  label: Text(a.commentsEnabled
                                      ? l10n.commentCount(a.commentCount)
                                      : l10n.commentsOff),
                                ),
                              ]),
                            ]),
                      ),
                    ),
                  if (_more)
                    Center(
                      child: TextButton(
                          onPressed: _loadMore, child: Text(l10n.loadMore)),
                    ),
                ]),
    );
  }

  void _open(Announcement a) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AnnouncementPage(announcementId: a.id)));
  }
}

class AnnouncementPage extends StatefulWidget {
  final String announcementId;
  const AnnouncementPage({super.key, required this.announcementId});
  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage> {
  final _c = TextEditingController();
  Announcement? _a;
  List<AnnComment>? _comments;
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
      final l = await Api.i.announcements(limit: 100);
      Announcement? a;
      for (final x in l) {
        if (x.id == widget.announcementId) a = x;
      }
      final cs = await Api.i.annComments(widget.announcementId);
      setState(() {
        _a = a;
        _comments = cs;
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
      await Api.i.annCommentAdd(widget.announcementId, body);
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

  Future<void> _edit(AnnComment c) async {
    final body = await promptText(
        context, context.l10n.editComment, context.l10n.writeComment, c.body);
    if (body == null || body.trim().isEmpty || !mounted) return;
    try {
      await Api.i.annCommentEdit(widget.announcementId, c.id, body);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _delete(AnnComment c) async {
    final l10n = context.l10n;
    if (!await confirm(context, l10n.deleteComment, l10n.deleteCommentConfirm)) {
      return;
    }
    try {
      await Api.i.annCommentDelete(widget.announcementId, c.id);
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) {
      return Scaffold(
          appBar: AppBar(), body: errorView(context, _err, _load));
    }
    final a = _a;
    final comments = _comments;
    final me = Api.i.user;
    final mod = me?.canAnnounce ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(a?.title ?? '')),
      body: a == null || comments == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text('${a.authorName.isEmpty ? a.authorUsername : a.authorName}  ·  ${fmtAgo(l10n, a.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              MarkdownBody(
                  data: a.body,
                  onTapLink: (_, href, __) {
                    if (href != null) launchUrl(Uri.parse(href));
                  }),
              const SizedBox(height: 16),
              Text(l10n.commentCount(a.commentCount),
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final c in comments)
                Card(
                  child: ListTile(
                    title: Text(c.body),
                    subtitle: Text(
                        '${c.authorName.isEmpty ? c.authorUsername : c.authorName}  ·  ${fmtAgo(l10n, c.createdAt)}${c.editedAt > 0 ? '  ·  ${l10n.editedMark}' : ''}'),
                    trailing: (c.authorId == me?.id ||
                            a.authorId == me?.id ||
                            mod)
                        ? PopupMenuButton<String>(
                            iconSize: 20,
                            onSelected: (v) =>
                                v == 'edit' ? _edit(c) : _delete(c),
                            itemBuilder: (_) => [
                              if (c.authorId == me?.id)
                                PopupMenuItem(
                                    value: 'edit', child: Text(l10n.edit)),
                              PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l10n.delete)),
                            ],
                          )
                        : null,
                  ),
                ),
              if (a.commentsEnabled)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                      controller: _c,
                      minLines: 1,
                      maxLines: 4,
                      decoration:
                          InputDecoration(hintText: l10n.writeComment),
                      onSubmitted: (_) => _post(),
                    )),
                    const SizedBox(width: 8),
                    IconButton.filled(
                        onPressed: _sending ? null : _post,
                        icon: const Icon(Icons.send, size: 18)),
                  ]),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(l10n.commentsOff,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
            ]),
    );
  }
}

class _ComposeDialog extends StatefulWidget {
  final Announcement? announcement;
  const _ComposeDialog({this.announcement});
  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late bool _comments;
  late bool _reactions;

  @override
  void initState() {
    super.initState();
    final a = widget.announcement;
    _title = TextEditingController(text: a?.title ?? '');
    _body = TextEditingController(text: a?.body ?? '');
    _comments = a?.commentsEnabled ?? true;
    _reactions = a?.reactionsEnabled ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.announcement == null
          ? l10n.newAnnouncement
          : l10n.editAnnouncement),
      content: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _title,
              decoration: InputDecoration(labelText: l10n.announcementTitle)),
          const SizedBox(height: 12),
          TextField(
              controller: _body,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                  labelText: l10n.announcementBody,
                  helperText: l10n.markdownHint)),
          SwitchListTile(
              dense: true,
              title: Text(l10n.allowComments),
              value: _comments,
              onChanged: (v) => setState(() => _comments = v)),
          SwitchListTile(
              dense: true,
              title: Text(l10n.allowReactions),
              value: _reactions,
              onChanged: (v) => setState(() => _reactions = v)),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel)),
        FilledButton(
            onPressed: () {
              final title = _title.text.trim();
              final body = _body.text.trim();
              if (title.isEmpty || body.isEmpty) return;
              Navigator.pop(context,
                  (title: title, body: body, comments: _comments, reactions: _reactions));
            },
            child: Text(widget.announcement == null ? l10n.post : l10n.save)),
      ],
    );
  }
}
