import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'l10n/app_localizations.dart';
import 'notifications.dart';
import 'projects.dart';
import 'shared.dart';
import 'invite.dart';
import 'link.dart';
import 'manage.dart';
import 'settings.dart';

void main() => runApp(const WfmApp());

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

enum AppTheme { system, light, dark, oled }

const appLocales = [
  Locale('en'),
  Locale('en', 'GB'),
  Locale('zh'),
  Locale('ru'),
  Locale('ga'),
];

ThemeData _makeTheme(Brightness b, {bool oled = false}) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8B5CF6),
        brightness: b,
      ).copyWith(surface: oled ? Colors.black : null),
      fontFamily: 'Noto Sans',
      scaffoldBackgroundColor: oled ? Colors.black : null,
    );

class WfmApp extends StatefulWidget {
  final Uri? uri;
  const WfmApp({super.key, this.uri});
  @override
  State<WfmApp> createState() => WfmAppState();
}

class WfmAppState extends State<WfmApp> {
  final themeCtl = ValueNotifier<AppTheme>(AppTheme.system);
  final localeCtl = ValueNotifier<Locale?>(null);
  final userCtl = ValueNotifier(0);
  final navKey = GlobalKey<NavigatorState>();

  AppTheme get appTheme => themeCtl.value;
  Locale? get appLocale => localeCtl.value;

  @override
  void initState() {
    super.initState();
    // A real sign-out (401 while logged in) returns to the gate from one
    // place instead of letting every Api.i.user! unwrap crash mid-build.
    Api.i.onSignedOut = () {
      navKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Gate()), (_) => false);
    };
    SharedPreferences.getInstance().then((p) {
      setState(() {
        themeCtl.value =
            AppTheme.values[p.getInt('theme') ?? AppTheme.system.index];
        final mb = p.getInt('chunkMb');
        if (mb != null) Api.i.chunkSize = mb * 1048576;
        final code = p.getString('locale');
        if (code != null && code.isNotEmpty) {
          final parts = code.split('_');
          localeCtl.value = Locale(parts[0],
              parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = appTheme == AppTheme.oled
        ? _makeTheme(Brightness.dark, oled: true)
        : _makeTheme(Brightness.dark);
    return MaterialApp(
      navigatorKey: navKey,
      title: 'WFM',
      theme: _makeTheme(Brightness.light),
      darkTheme: dark,
      themeMode: switch (appTheme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        _ => ThemeMode.dark,
      },
      locale: appLocale,
      supportedLocales: appLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Gate(uri: widget.uri),
      debugShowCheckedModeBanner: false,
    );
  }

  void setTheme(AppTheme t) {
    setState(() => themeCtl.value = t);
    SharedPreferences.getInstance().then((p) => p.setInt('theme', t.index));
  }

  void setLocale(Locale? l) {
    setState(() => localeCtl.value = l);
    SharedPreferences.getInstance().then((p) => l == null
        ? p.remove('locale')
        : p.setString(
            'locale',
            l.countryCode == null
                ? l.languageCode
                : '${l.languageCode}_${l.countryCode}'));
  }
}

InputDecoration dec(String label, [String? hint]) => InputDecoration(
    labelText: label, hintText: hint, border: const OutlineInputBorder());

final _toasts = <OverlayEntry>[];
final _toastGen = ValueNotifier(0);

void snack(BuildContext context, Object e, {bool good = false}) {
  if (!context.mounted) return;
  late OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
    _toasts.remove(entry);
    _toastGen.value++;
  }

  _toasts.removeWhere((t) => !t.mounted);
  entry = OverlayEntry(
      builder: (_) => ValueListenableBuilder<int>(
          valueListenable: _toastGen,
          builder: (_, __, ___) => Positioned(
              top: 12 + _toasts.indexOf(entry) * 64,
              left: 12,
              child: Notice('$e', good: good, onClose: dismiss))));
  _toasts.add(entry);
  Overlay.of(context).insert(entry);
}

Widget errorView(BuildContext context, Object err, VoidCallback onRetry) =>
    Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$err'),
        TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
      ]),
    );

class Notice extends StatefulWidget {
  final String message;
  final bool good;
  final VoidCallback onClose;
  const Notice(this.message,
      {super.key, this.good = false, required this.onClose});

  @override
  State<Notice> createState() => _NoticeState();
}

class _NoticeState extends State<Notice> with SingleTickerProviderStateMixin {
  Timer? _timer;
  bool _closing = false;
  late final AnimationController _anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 250))
    ..forward();

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), dismiss);
  }

  void dismiss() {
    if (_closing) return;
    _closing = true;
    _anim.reverse().then((_) {
      if (mounted) widget.onClose();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position:
            curved.drive(Tween(begin: const Offset(-1, 0), end: Offset.zero)),
        child: Stack(children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Card(
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 10, 10, 10),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                      widget.good
                          ? Icons.check_circle_outline
                          : Icons.error_outline,
                      size: 18,
                      color: widget.good ? cs.primary : cs.error),
                  const SizedBox(width: 8),
                  Flexible(child: Text(widget.message)),
                ]),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 22, height: 22),
              iconSize: 13,
              icon: const Icon(Icons.close),
              onPressed: dismiss,
            ),
          ),
        ]),
      ),
    );
  }
}

IconData themeIcon(AppTheme t) => switch (t) {
      AppTheme.system => Icons.brightness_auto,
      AppTheme.light => Icons.light_mode,
      AppTheme.dark => Icons.dark_mode,
      AppTheme.oled => Icons.brightness_2,
    };

Widget themeMenu(WfmAppState app, AppLocalizations l10n) =>
    PopupMenuButton<AppTheme>(
      icon: Icon(themeIcon(app.appTheme)),
      initialValue: app.appTheme,
      onSelected: (t) {
        app.setTheme(t);
        FocusManager.instance.primaryFocus?.unfocus();
      },
      itemBuilder: (context) => [
        for (final (t, label) in [
          (AppTheme.system, l10n.themeSystem),
          (AppTheme.light, l10n.themeLight),
          (AppTheme.dark, l10n.themeDark),
          (AppTheme.oled, l10n.themeOled),
        ])
          PopupMenuItem(
              value: t,
              child: Row(children: [
                Icon(themeIcon(t), size: 16),
                const SizedBox(width: 8),
                Text(label),
              ])),
      ],
    );

class AuthPickers extends StatelessWidget {
  const AuthPickers({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorStateOfType<WfmAppState>()!;
    final l10n = context.l10n;
    final tight = MediaQuery.sizeOf(context).width < 480;
    return AnimatedBuilder(
      animation: Listenable.merge([app.themeCtl, app.localeCtl]),
      builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<Locale?>(
            value: app.appLocale,
            icon: const Icon(Icons.language),
            items: [
              for (final e in langNames.entries)
                DropdownMenuItem(
                    value: e.key,
                    child: Text(e.key == null ? l10n.langSystem : e.value)),
            ],
            onChanged: (v) {
              app.setLocale(v);
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
        ),
        const SizedBox(width: 8),
        if (tight)
          themeMenu(app, l10n)
        else
          SegmentedButton<AppTheme>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              ButtonSegment(
                  value: AppTheme.system,
                  icon: const Icon(Icons.brightness_auto, size: 16),
                  tooltip: l10n.themeSystem),
              ButtonSegment(
                  value: AppTheme.light,
                  icon: const Icon(Icons.light_mode, size: 16),
                  tooltip: l10n.themeLight),
              ButtonSegment(
                  value: AppTheme.dark,
                  icon: const Icon(Icons.dark_mode, size: 16),
                  tooltip: l10n.themeDark),
              ButtonSegment(
                  value: AppTheme.oled,
                  icon: const Icon(Icons.brightness_2, size: 16),
                  tooltip: l10n.themeOled),
            ],
            selected: {app.appTheme},
            onSelectionChanged: (s) {
              app.setTheme(s.first);
              FocusManager.instance.primaryFocus?.unfocus();
            },
          ),
      ]),
    );
  }
}

Future<String?> promptText(BuildContext context, String title, String label,
        [String initial = '', bool Function(String)? valid]) =>
    showDialog<String>(
        context: context,
        builder: (_) => _PromptDialog(title, label, initial, valid));

class _PromptDialog extends StatefulWidget {
  final String title, label, initial;
  final bool Function(String)? valid;
  const _PromptDialog(this.title, this.label, this.initial, this.valid);
  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
          controller: _c,
          decoration: dec(widget.label),
          autofocus: true,
          onChanged: (_) => setState(() {}),
          onSubmitted: (v) {
            if (widget.valid == null || widget.valid!(v.trim())) {
              Navigator.pop(context, v.trim());
            }
          }),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.cancel)),
        FilledButton(
            onPressed: widget.valid == null || widget.valid!(_c.text.trim())
                ? () => Navigator.pop(context, _c.text.trim())
                : null,
            child: Text(context.l10n.ok)),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String body) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.l10n.confirm)),
        ],
      ),
    ) ==
    true;

class Gate extends StatefulWidget {
  final Uri? uri;
  const Gate({super.key, this.uri});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  Future<Widget>? _route;

  @override
  void initState() {
    super.initState();
    _route = _decide();
  }

  Future<Widget> _decide() async {
    try {
      const m = '/invite/';
      final p = widget.uri?.path ?? Uri.base.path;
      var i = p.indexOf(m);
      if (i >= 0 && i + m.length < p.length) {
        return InvitePage(code: p.substring(i + m.length));
      }
      const l = '/link/';
      i = p.indexOf(l);
      if (i >= 0 && i + l.length < p.length) {
        return LinkPage(token: p.substring(i + l.length));
      }
      if (await Api.i.needsSetup()) return const SetupPage();
      final u = await Api.i.me();
      if (u == null) return const LoginPage();
      await Api.i.roles().catchError((_) => Api.i.caps);
      return const Shell();
    } catch (e) {
      return GateError(e);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: _route,
        builder: (context, s) => s.hasData
            ? s.data!
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}

/// Shown when the gate can't reach the server (or gets a non-auth error):
/// a real error state with retry instead of a misleading login form.
class GateError extends StatelessWidget {
  final Object error;
  const GateError(this.error, {super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(l10n.serverUnreachable('$error'), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const Gate())),
              child: Text(l10n.retry),
            ),
          ]),
        ),
      ),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _user = TextEditingController(),
      _pass = TextEditingController(),
      _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      await Api.i.setupOwner(_user.text.trim(), _pass.text, _name.text.trim());
      await Api.i.roles().catchError((_) => Api.i.caps);
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
      }
    } catch (e) {
      if (mounted) snack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, actions: const [
        Padding(padding: EdgeInsets.only(right: 8), child: AuthPickers()),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Row(children: [
                  Image.asset('assets/icon.png', width: 32, height: 32),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(l10n.welcomeTitle,
                          style: Theme.of(context).textTheme.headlineSmall)),
                ]),
                const SizedBox(height: 8),
                Text(l10n.setupSubtitle),
                const SizedBox(height: 20),
                TextField(controller: _name, decoration: dec(l10n.yourName)),
                const SizedBox(height: 12),
                TextField(controller: _user, decoration: dec(l10n.username)),
                const SizedBox(height: 12),
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: dec(l10n.password),
                    onSubmitted: (_) => _go()),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _go,
                    child: Text(_busy ? l10n.creating : l10n.createOwner)),
              ]),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController(), _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      await Api.i.login(_user.text.trim(), _pass.text);
      await Api.i.roles().catchError((_) => Api.i.caps);
      if (mounted) {
        Navigator.of(context)
            .pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
      }
    } catch (e) {
      if (mounted) snack(context, context.l10n.signInFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, actions: const [
        Padding(padding: EdgeInsets.only(right: 8), child: AuthPickers()),
      ]),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Image.asset('assets/icon.png', width: 36, height: 36),
                  const SizedBox(width: 10),
                  Text(l10n.appTitle,
                      style: Theme.of(context).textTheme.headlineMedium),
                ]),
                const SizedBox(height: 24),
                TextField(
                    controller: _user,
                    decoration: dec(l10n.username),
                    autofocus: true),
                const SizedBox(height: 12),
                TextField(
                    controller: _pass,
                    obscureText: true,
                    decoration: dec(l10n.password),
                    onSubmitted: (_) => _go()),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _go,
                    child: Text(_busy ? l10n.signingIn : l10n.signIn)),
              ]),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _page = 0;
  Project? _open;
  int _pending = 0;
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    refreshShared();
    refreshNotifs();
  }

  Future<void> refreshShared() async {
    final v = await Api.i.shares().catchError((_) => <Share>[]);
    final n = v.where((s) => s.status == 'pending').length;
    if (mounted && n != _pending) setState(() => _pending = n);
  }

  Future<void> refreshNotifs() async {
    final n = await Api.i.notificationsUnread().catchError((_) => _unread);
    if (mounted && n != _unread) setState(() => _unread = n);
  }

  void go(int i) => setState(() {
        _page = i;
        _open = null;
      });

  void openProject(Project p) => setState(() => _open = p);

  void closeProject() => setState(() => _open = null);

  List<(IconData, String)> _items(AppLocalizations l10n, bool showManage) => [
        (Icons.home_outlined, l10n.navHome),
        (Icons.movie_outlined, l10n.navProjects),
        (Icons.folder_shared_outlined, l10n.navShared),
        (Icons.notifications_outlined, l10n.navNotifications),
        if (showManage) (Icons.manage_accounts_outlined, l10n.navManage),
        (Icons.settings_outlined, l10n.navSettings),
      ];

  List<Widget> _pages(bool showManage) => [
        const HomePage(),
        const ProjectsPage(),
        const SharedPage(),
        const NotificationsPage(),
        if (showManage) const ManagePage(),
        const SettingsPage(),
      ];

  Widget _navColumn(AppLocalizations l10n, {VoidCallback? onTap}) {
    final u = Api.i.user;
    if (u == null) return const SizedBox.shrink();
    final items = _items(l10n, Api.i.caps.manage || Api.i.caps.audit);
    final initials = u.name.trim().isEmpty
        ? u.username.substring(0, 1).toUpperCase()
        : (u.name
            .trim()
            .split(RegExp(r'\s+'))
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase());
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(children: [
          Image.asset('assets/icon.png', width: 36, height: 36),
          const SizedBox(width: 12),
          Text(l10n.appTitle, style: Theme.of(context).textTheme.titleLarge),
        ]),
      ),
      Expanded(
        child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Material(
                    color: i == _page
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      dense: true,
                      leading: Icon(items[i].$1, size: 20),
                      title: Row(children: [
                        Flexible(
                            child: Text(items[i].$2,
                                overflow: TextOverflow.ellipsis)),
                        if (items[i].$1 == Icons.folder_shared_outlined &&
                            _pending > 0) ...[
                          const SizedBox(width: 6),
                          Badge(label: Text('$_pending')),
                        ],
                        if (items[i].$1 == Icons.notifications_outlined &&
                            _unread > 0) ...[
                          const SizedBox(width: 6),
                          Badge(label: Text('$_unread')),
                        ],
                      ]),
                      shape: const StadiumBorder(),
                      onTap: () {
                        go(i);
                        onTap?.call();
                      },
                    ),
                  ),
                ),
            ]),
      ),
      const Divider(height: 1),
      ListTile(
        leading: ValueListenableBuilder(
            valueListenable:
                context.findAncestorStateOfType<WfmAppState>()!.userCtl,
            builder: (c, v, w) {
              final me = Api.i.user;
              return CircleAvatar(
                  radius: 16,
                  backgroundImage: me != null && me.hasAvatar
                      ? NetworkImage(Api.i.avatarUrl(me.id, me.avatar))
                      : null,
                  onBackgroundImageError:
                      me != null && me.hasAvatar ? (_, __) {} : null,
                  child: me != null && me.hasAvatar
                      ? null
                      : Text(initials, style: const TextStyle(fontSize: 12)));
            }),
        title: Text(u.name.isEmpty ? u.username : u.name,
            overflow: TextOverflow.ellipsis),
        subtitle: Text(u.role, style: const TextStyle(fontSize: 11)),
        trailing: IconButton(
          icon: const Icon(Icons.logout, size: 18),
          tooltip: l10n.logout,
          onPressed: () async {
            await Api.i.logout();
            if (mounted) {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const Gate()));
            }
          },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showManage = Api.i.caps.manage || Api.i.caps.audit;
    final pages = _pages(showManage);
    if (_page >= pages.length) _page = 0;
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 720) {
        return Scaffold(
          appBar: _open == null
              ? AppBar(title: Text(_items(l10n, showManage)[_page].$2))
              : null,
          drawer: Drawer(
              child: SafeArea(
                  child: _navColumn(l10n,
                      onTap: () => Navigator.of(context).pop()))),
          body: _open != null
              ? ProjectPage(project: _open!, onBack: closeProject)
              : pages[_page],
        );
      }
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 240, child: SafeArea(child: _navColumn(l10n))),
          const VerticalDivider(width: 1),
          Expanded(
              child: _open != null
                  ? ProjectPage(project: _open!, onBack: closeProject)
                  : pages[_page]),
        ]),
      );
    });
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final u = Api.i.user;
    if (u == null) return const SizedBox.shrink();
    final showManage = Api.i.caps.manage || Api.i.caps.audit;
    final cards = <(IconData, String, String, int)>[
      (Icons.movie_outlined, l10n.cardProjects, l10n.cardProjectsSub, 1),
      if (showManage)
        (Icons.group_outlined, l10n.cardManage, l10n.cardManageSub, 4),
      (
        Icons.tune_outlined,
        l10n.cardSettings,
        l10n.cardSettingsSub,
        showManage ? 5 : 4
      ),
    ];
    final tight = MediaQuery.sizeOf(context).width < 720;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(l10n.greeting(u.name.isEmpty ? u.username : u.name),
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final c in cards)
          SizedBox(
            width: tight ? double.infinity : null,
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    context.findAncestorStateOfType<ShellState>()?.go(c.$4),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(c.$1, size: 28),
                        const SizedBox(height: 12),
                        Text(c.$2,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(c.$3,
                            style: Theme.of(context).textTheme.bodySmall),
                      ]),
                ),
              ),
            ),
          ),
      ]),
    ]);
  }
}
