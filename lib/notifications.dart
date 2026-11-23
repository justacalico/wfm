import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'projects.dart';
import 'l10n/app_localizations.dart';
import 'shared.dart';
import 'util.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<AppNotification>? _list;
  int _unread = 0;
  String _err = '';
  bool _more = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (v, unread) = await Api.i.notifications();
      setState(() {
        _list = v;
        _unread = unread;
        _err = '';
        _more = v.length >= 50;
      });
      if (mounted) {
        context.findAncestorStateOfType<ShellState>()?.refreshNotifs();
      }
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _loadMore() async {
    final list = _list;
    if (list == null || list.isEmpty) return;
    try {
      final (v, unread) =
          await Api.i.notifications(before: list.last.createdAt);
      setState(() {
        _list = [...list, ...v];
        _unread = unread;
        _more = v.length >= 50;
      });
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _readAll() async {
    try {
      await Api.i.notificationsReadAll();
      _load();
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  String _text(AppLocalizations l10n, AppNotification n) => notifText(l10n, n);

  IconData _icon(AppNotification n) => switch (n.kind) {
        'share_invite' || 'share_auto' => Icons.folder_shared_outlined,
        'share_accepted' => Icons.check_circle_outline,
        'share_declined' => Icons.cancel_outlined,
        'render_done' => Icons.movie_creation_outlined,
        'render_failed' => Icons.error_outline,
        'node_offline' => Icons.dns_outlined,
        'co_teacher' => Icons.co_present_outlined,
        'comment' => Icons.comment_outlined,
        'submit' => Icons.send_outlined,
        'review' => Icons.fact_check_outlined,
        _ => Icons.notifications_outlined,
      };

  Future<void> _tap(AppNotification n) async {
    if (n.readAt == 0) {
      try {
        await Api.i.notificationRead(n.id);
        setState(() {
          n.readAt = 1;
          _unread = _unread > 0 ? _unread - 1 : 0;
        });
        if (mounted) {
          context.findAncestorStateOfType<ShellState>()?.refreshNotifs();
        }
      } catch (e) {
        if (mounted) snack(context, e);
      }
    }
    if (!mounted) return;
    final shell = context.findAncestorStateOfType<ShellState>();
    final pid = '${n.payload['project'] ?? ''}';
    switch (n.kind) {
      case 'share_invite' || 'share_auto':
        if (shell != null) {
          shell.go(2);
        } else {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const SharedPage()));
        }
      case 'render_done' ||
            'render_failed' ||
            'comment' ||
            'submit' ||
            'review':
        if (pid.isEmpty) return;
        final tab =
            n.kind == 'render_done' || n.kind == 'render_failed' ? 1 : 0;
        final Project p;
        try {
          p = await Api.i.project(pid);
        } catch (e) {
          if (mounted) {
            snack(
                context,
                e is ApiException && e.status == 404
                    ? context.l10n.projectGone
                    : e);
          }
          return;
        }
        if (!mounted) return;
        if (shell != null) {
          shell.openProject(p, tab: tab);
        } else {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ProjectPage(project: p, initialTab: tab)));
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final list = _list;
    final tight = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(
        title: tight ? null : Text(l10n.navNotifications),
        actions: [
          if (_unread > 0)
            TextButton.icon(
              onPressed: _readAll,
              icon: const Icon(Icons.done_all, size: 18),
              label: Text(l10n.markAllRead),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? Center(child: Text(l10n.noNotifications))
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final n in list)
                    Card(
                      child: ListTile(
                        leading: Icon(_icon(n)),
                        title: Text(_text(l10n, n)),
                        subtitle: Text(fmtAgo(l10n, n.createdAt)),
                        trailing: n.readAt == 0
                            ? const Icon(Icons.circle,
                                size: 10, color: Colors.redAccent)
                            : null,
                        onTap: () => _tap(n),
                      ),
                    ),
                  if (_more)
                    Center(
                      child: TextButton(
                        onPressed: _loadMore,
                        child: Text(l10n.loadMore),
                      ),
                    ),
                ]),
    );
  }
}

String notifText(AppLocalizations l10n, AppNotification n) {
  final p = n.payload;
  final from = '${p['from'] ?? ''}';
  final project = '${p['projectName'] ?? ''}';
  final name = '${p['name'] ?? ''}';
  switch (n.kind) {
    case 'share_invite':
      return l10n.notifShareInvite(from, project);
    case 'share_auto':
      return l10n.notifShareAuto(from, project);
    case 'share_accepted':
      return l10n.notifShareAccepted(from, project);
    case 'share_declined':
      return l10n.notifShareDeclined(from, project);
    case 'render_done':
      return l10n.notifRenderDone(name, project);
    case 'render_failed':
      return l10n.notifRenderFailed(name, project);
    case 'node_offline':
      return l10n.notifNodeOffline(name);
    case 'co_teacher':
      return l10n.notifCoTeacher(from, '${p['className'] ?? ''}');
    case 'comment':
      return l10n.notifComment(from, project);
    case 'reply':
      return l10n.notifReply(from, project);
    case 'submit':
      return l10n.notifSubmitted(from, project);
    case 'review':
      return '${p['status']}' == 'draft'
          ? l10n.notifReturned(from, project)
          : l10n.notifReviewed(from, project);
    default:
      return n.kind;
  }
}
