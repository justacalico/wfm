import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'l10n/app_localizations.dart';
import 'projects.dart';
import 'manage.dart';
import 'settings.dart';

void main() => runApp(const WfmApp());

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

enum AppTheme { system, light, dark, oled }

const appLocales = [
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
  const WfmApp({super.key});
  @override
  State<WfmApp> createState() => WfmAppState();
}

class WfmAppState extends State<WfmApp> {
  AppTheme _theme = AppTheme.system;
  Locale? _locale;

  AppTheme get appTheme => _theme;
  Locale? get appLocale => _locale;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _theme = AppTheme.values[p.getInt('theme') ?? AppTheme.light.index];
        final code = p.getString('locale');
        if (code != null && code.isNotEmpty) {
          final parts = code.split('_');
          _locale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = _theme == AppTheme.oled
        ? _makeTheme(Brightness.dark, oled: true)
        : _makeTheme(Brightness.dark);
    return MaterialApp(
      title: 'WFM',
      theme: _makeTheme(Brightness.light),
      darkTheme: dark,
      themeMode: switch (_theme) {
        AppTheme.system => ThemeMode.system,
        AppTheme.light => ThemeMode.light,
        _ => ThemeMode.dark,
      },
      locale: _locale,
      supportedLocales: appLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const Gate(),
      debugShowCheckedModeBanner: false,
    );
  }

  void setTheme(AppTheme t) {
    setState(() => _theme = t);
    SharedPreferences.getInstance().then((p) => p.setInt('theme', t.index));
  }

  void setLocale(Locale? l) {
    setState(() => _locale = l);
    SharedPreferences.getInstance().then((p) => l == null
        ? p.remove('locale')
        : p.setString('locale', '${l.languageCode}_${l.countryCode ?? ''}'));
  }
}

InputDecoration dec(String label, [String? hint]) => InputDecoration(
    labelText: label, hintText: hint, border: const OutlineInputBorder());

final _toasts = <OverlayEntry>[];

void snack(BuildContext context, Object e, {bool good = false}) {
  if (!context.mounted) return;
  late OverlayEntry entry;
  void dismiss() {
    if (entry.mounted) entry.remove();
    _toasts.remove(entry);
  }

  _toasts.removeWhere((t) => !t.mounted);
  entry = OverlayEntry(
      builder: (_) => Positioned(
          top: 16 + _toasts.length * 64,
          left: 16,
          child: Notice('$e', good: good, onClose: dismiss)));
  _toasts.add(entry);
  Overlay.of(context).insert(entry);
}

class Notice extends StatefulWidget {
  final String message;
  final bool good;
  final VoidCallback onClose;
  const Notice(this.message,
      {super.key, this.good = false, required this.onClose});

  @override
  State<Notice> createState() => _NoticeState();
}

class _NoticeState extends State<Notice> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), widget.onClose);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(widget.good ? Icons.check_circle_outline : Icons.error_outline,
                size: 18, color: widget.good ? cs.primary : cs.error),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.message)),
            IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 16),
                onPressed: widget.onClose),
          ]),
        ),
      ),
    );
  }
}

class AuthPickers extends StatelessWidget {
  const AuthPickers({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorStateOfType<WfmAppState>()!;
    final l10n = context.l10n;
    return Row(mainAxisSize: MainAxisSize.min, children: [
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
          onChanged: app.setLocale,
        ),
      ),
      const SizedBox(width: 8),
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
        onSelectionChanged: (s) => app.setTheme(s.first),
      ),
    ]);
  }
}

Future<String?> promptText(BuildContext context, String title, String label,
    [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
          controller: c,
          decoration: dec(label),
          autofocus: true,
          onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(ctx.l10n.ok)),
      ],
    ),
  );
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
  const Gate({super.key});
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
      if (await Api.i.needsSetup()) return const SetupPage();
      final u = await Api.i.me();
      if (u == null) return const LoginPage();
      await Api.i.roles().catchError((_) => Api.i.caps);
      return const Shell();
    } catch (_) {
      return const LoginPage();
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

  Future<void> _go() async {
    setState(() => _busy = true);
    try {
      await Api.i
          .setupOwner(_user.text.trim(), _pass.text, _name.text.trim());
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
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 8), child: AuthPickers()),
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
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 8), child: AuthPickers()),
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

  void go(int i) => setState(() => _page = i);

  List<(IconData, String)> _items(AppLocalizations l10n, bool showManage) => [
        (Icons.home_outlined, l10n.navHome),
        (Icons.movie_outlined, l10n.navProjects),
        if (showManage) (Icons.manage_accounts_outlined, l10n.navManage),
        (Icons.settings_outlined, l10n.navSettings),
      ];

  List<Widget> _pages(bool showManage) => [
        const HomePage(),
        const ProjectsPage(),
        if (showManage) const ManagePage(),
        const SettingsPage(),
      ];

  Widget _navColumn(AppLocalizations l10n, {VoidCallback? onTap}) {
    final u = Api.i.user!;
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
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(l10n.appTitle,
              style: Theme.of(context).textTheme.titleLarge),
        ),
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
                      title: Text(items[i].$2),
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
        leading: CircleAvatar(
            radius: 16,
            child: Text(initials, style: const TextStyle(fontSize: 12))),
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
          appBar: AppBar(title: Text(_items(l10n, showManage)[_page].$2)),
          drawer: Drawer(
              child: SafeArea(
                  child: _navColumn(l10n,
                      onTap: () => Navigator.of(context).pop()))),
          body: pages[_page],
        );
      }
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 240, child: SafeArea(child: _navColumn(l10n))),
          const VerticalDivider(width: 1),
          Expanded(child: pages[_page]),
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
    final u = Api.i.user!;
    final showManage = Api.i.caps.manage || Api.i.caps.audit;
    final cards = <(IconData, String, String, int)>[
      (Icons.movie_outlined, l10n.cardProjects, l10n.cardProjectsSub, 1),
      if (showManage)
        (Icons.group_outlined, l10n.cardManage, l10n.cardManageSub, 2),
      (
        Icons.tune_outlined,
        l10n.cardSettings,
        l10n.cardSettingsSub,
        showManage ? 3 : 2
      ),
    ];
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text(l10n.greeting(u.name.isEmpty ? u.username : u.name),
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final c in cards)
          Card(
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
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(c.$3, style: Theme.of(context).textTheme.bodySmall),
                    ]),
              ),
            ),
          ),
      ]),
    ]);
  }
}
