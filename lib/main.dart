import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'projects.dart';
import 'manage.dart';
import 'settings.dart';

void main() => runApp(const WfmApp());

class WfmApp extends StatefulWidget {
  const WfmApp({super.key});
  @override
  State<WfmApp> createState() => WfmAppState();
}

class WfmAppState extends State<WfmApp> {
  ThemeMode _theme = ThemeMode.system;
  Locale? _locale;

  ThemeMode get themeMode => _theme;
  Locale? get appLocale => _locale;

  static const locales = [
    Locale('en', 'GB'),
    Locale('zh', 'CN'),
    Locale('ru'),
    Locale('ga'),
  ];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _theme = ThemeMode.values[p.getInt('theme') ?? 0];
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
    return MaterialApp(
      title: 'WFM',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF8B5CF6), brightness: Brightness.light),
      darkTheme: ThemeData(colorSchemeSeed: const Color(0xFF8B5CF6), brightness: Brightness.dark),
      themeMode: _theme,
      locale: _locale,
      supportedLocales: locales,
      home: const Gate(),
      debugShowCheckedModeBanner: false,
    );
  }

  void setTheme(ThemeMode m) {
    setState(() => _theme = m);
    SharedPreferences.getInstance().then((p) => p.setInt('theme', m.index));
  }

  void setLocale(Locale? l) {
    setState(() => _locale = l);
    SharedPreferences.getInstance().then((p) =>
        l == null ? p.remove('locale') : p.setString('locale', '${l.languageCode}_${l.countryCode ?? ''}'));
  }
}

InputDecoration dec(String label, [String? hint]) =>
    InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder());

void snack(BuildContext context, Object e) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }
}

Future<String?> promptText(BuildContext context, String title, String label, [String initial = '']) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, decoration: dec(label), autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v.trim())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('OK')),
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
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
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
  final _user = TextEditingController(), _pass = TextEditingController(), _name = TextEditingController();
  String _err = '';
  bool _busy = false;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await Api.i.setupOwner(_user.text.trim(), _pass.text, _name.text.trim());
      await Api.i.roles().catchError((_) => Api.i.caps);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
      }
    } catch (e) {
      setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              Text('Welcome to WFM', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Create the owner account to get started.'),
              const SizedBox(height: 20),
              TextField(controller: _name, decoration: dec('Your name')),
              const SizedBox(height: 12),
              TextField(controller: _user, decoration: dec('Username')),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: dec('Password'), onSubmitted: (_) => _go()),
              if (_err.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'Creating…' : 'Create owner')),
            ]),
          ),
        ),
      );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController(), _pass = TextEditingController();
  String _err = '';
  bool _busy = false;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await Api.i.login(_user.text.trim(), _pass.text);
      await Api.i.roles().catchError((_) => Api.i.caps);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
      }
    } catch (e) {
      setState(() => _err = 'Sign in failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(24), children: [
              Text('WFM', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              TextField(controller: _user, decoration: dec('Username'), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: dec('Password'), onSubmitted: (_) => _go()),
              if (_err.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err, style: TextStyle(color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 20),
              FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'Signing in…' : 'Sign in')),
            ]),
          ),
        ),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _page = 0;

  void go(int i) => setState(() => _page = i);

  @override
  Widget build(BuildContext context) {
    final u = Api.i.user!;
    final showManage = Api.i.caps.manage || Api.i.caps.audit;
    final items = [
      (Icons.home_outlined, 'Home'),
      (Icons.movie_outlined, 'Projects'),
      if (showManage) (Icons.manage_accounts_outlined, 'Manage'),
      (Icons.settings_outlined, 'Settings'),
    ];
    final pages = <Widget>[
      const HomePage(),
      const ProjectsPage(),
      if (showManage) const ManagePage(),
      const SettingsPage(),
    ];
    if (_page >= pages.length) _page = 0;
    final initials = u.name.trim().isEmpty
        ? u.username.substring(0, 1).toUpperCase()
        : (u.name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase());
    return Scaffold(
      body: Row(children: [
        NavigationRail(
          selectedIndex: _page,
          onDestinationSelected: (i) => setState(() => _page = i),
          labelType: NavigationRailLabelType.all,
          destinations: [for (final it in items) NavigationRailDestination(icon: Icon(it.$1), label: Text(it.$2))],
          trailing: Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(child: Text(initials)),
                  const SizedBox(height: 4),
                  Text(u.name.isEmpty ? u.username : u.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  Text(u.role, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  IconButton(
                    icon: const Icon(Icons.logout, size: 18),
                    tooltip: 'Log out',
                    onPressed: () async {
                      await Api.i.logout();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Gate()));
                      }
                    },
                  ),
                ]),
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: pages[_page]),
      ]),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final u = Api.i.user!;
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Hi, ${u.name.isEmpty ? u.username : u.name}', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 12, children: [
        _card(context, Icons.movie_outlined, 'Projects', 'Open your film projects'),
        if (Api.i.caps.manage || Api.i.caps.audit) _card(context, Icons.group_outlined, 'Manage', 'Accounts and permissions'),
        _card(context, Icons.tune_outlined, 'Settings', 'Theme and language'),
      ]),
    ]);
  }

  Widget _card(BuildContext c, IconData i, String t, String sub) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => c.findAncestorStateOfType<_ShellState>()?.go(t == 'Projects' ? 1 : (t == 'Manage' ? 2 : 3)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, size: 28),
              const SizedBox(height: 12),
              Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(sub, style: Theme.of(c).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
