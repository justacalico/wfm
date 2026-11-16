import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'api.dart';

void main() => runApp(const WfmApp());

class WfmApp extends StatefulWidget {
  const WfmApp({super.key});
  @override
  State<WfmApp> createState() => _WfmAppState();
}

class _WfmAppState extends State<WfmApp> {
  ThemeMode _theme = ThemeMode.system;
  Locale? _locale;

  static const locales = [
    Locale('en', 'GB'),
    Locale('zh', 'CN'),
    Locale('ru'),
    Locale('ga'),
  ];

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
      routes: {},
      builder: (context, child) => child ?? const SizedBox(),
      onGenerateTitle: (_) => 'WFM',
      debugShowCheckedModeBanner: false,
    );
  }

  void setTheme(ThemeMode m) => setState(() => _theme = m);
  void setLocale(Locale? l) => setState(() => _locale = l);
}

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
    if (await Api.i.needsSetup()) return const SetupPage();
    final u = await Api.i.me();
    return u == null ? const LoginPage() : const Shell();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Widget>(
        future: _route,
        builder: (context, s) => s.hasData
            ? s.data!
            : const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
}

InputDecoration _dec(String label) => InputDecoration(labelText: label, border: const OutlineInputBorder());

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
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
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
              TextField(controller: _name, decoration: _dec('Your name')),
              const SizedBox(height: 12),
              TextField(controller: _user, decoration: _dec('Username')),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: _dec('Password'), onSubmitted: (_) => _go()),
              if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err, style: TextStyle(color: Theme.of(context).colorScheme.error))),
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
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const Shell()));
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
              TextField(controller: _user, decoration: _dec('Username'), autofocus: true),
              const SizedBox(height: 12),
              TextField(controller: _pass, obscureText: true, decoration: _dec('Password'), onSubmitted: (_) => _go()),
              if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err, style: TextStyle(color: Theme.of(context).colorScheme.error))),
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

  @override
  Widget build(BuildContext context) {
    final u = Api.i.user!;
    final items = [
      (Icons.home_outlined, 'Home'),
      (Icons.movie_outlined, 'Projects'),
      if (u.canManage) (Icons.manage_accounts_outlined, 'Manage'),
      (Icons.settings_outlined, 'Settings'),
    ];
    final pages = <Widget>[
      const HomePage(),
      const ProjectsPage(),
      if (u.canManage) const ManagePage(),
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
        if (u.canManage) _card(context, Icons.group_outlined, 'Manage', 'Accounts and permissions'),
        _card(context, Icons.tune_outlined, 'Settings', 'Theme and language'),
      ]),
    ]);
  }

  Widget _card(BuildContext c, IconData i, String t, String sub) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(i, size: 28),
            const SizedBox(height: 12),
            Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(sub, style: Theme.of(c).textTheme.bodySmall),
          ]),
        ),
      );
}

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
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New project'),
        content: TextField(controller: c, decoration: _dec('Project name'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    try {
      await Api.i.createProject(name);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err.isNotEmpty) return Center(child: Text(_err));
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: const Text('New project')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? const Center(child: Text('No projects yet. Create one to get started.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 280, mainAxisExtent: 140, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: items.length,
                  itemBuilder: (c, i) {
                    final p = items[i];
                    return Card(
                      child: InkWell(
                        onTap: () => web.window.open(Api.i.projectUrl(p.id), '_blank'),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Spacer(),
                            const Text('Open in Filmcraft', style: TextStyle(fontSize: 12)),
                          ]),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});
  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  List<User>? _users;
  List<String> _roles = [];
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _roles = await Api.i.roles();
      _users = await Api.i.accounts();
      setState(() {});
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final name = TextEditingController(), user = TextEditingController(),
        pass = TextEditingController(), sid = TextEditingController(), note = TextEditingController();
    String role = _roles.contains('student') ? 'student' : _roles.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('New account'),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: _dec('Name')),
              const SizedBox(height: 8),
              TextField(controller: user, decoration: _dec('Username')),
              const SizedBox(height: 8),
              TextField(controller: pass, obscureText: true, decoration: _dec('Password')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: _dec('Role'),
                items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(r))],
                onChanged: (v) => ss(() => role = v!),
              ),
              const SizedBox(height: 8),
              TextField(controller: sid, decoration: _dec('Student ID (optional)')),
              const SizedBox(height: 8),
              TextField(controller: note, maxLength: 20, decoration: _dec('Note (max 20 chars)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await Api.i.createAccount({
        'username': user.text.trim(),
        'password': pass.text,
        'name': name.text.trim(),
        'role': role,
        'studentId': sid.text.trim(),
        'note': note.text.trim(),
      });
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reset(User u) async {
    final c = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset password: ${u.username}'),
        content: TextField(controller: c, obscureText: true, decoration: _dec('New password')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Reset')),
        ],
      ),
    );
    if (pw == null || pw.isEmpty) return;
    try {
      await Api.i.resetPassword(u.id, pw);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err.isNotEmpty) return Center(child: Text(_err));
    final users = _users;
    return Scaffold(
      appBar: AppBar(title: const Text('Manage accounts')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add), label: const Text('New account')),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (c, i) {
                final u = users[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(u.username.substring(0, 1).toUpperCase())),
                  title: Text('${u.name.isEmpty ? u.username : u.name}  ·  ${u.role}${u.disabled ? "  (disabled)" : ""}'),
                  subtitle: Text('@${u.username}${u.studentId.isNotEmpty ? " · ${u.studentId}" : ""}${u.note.isNotEmpty ? " · ${u.note}" : ""}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.key), tooltip: 'Reset password', onPressed: () => _reset(u)),
                    IconButton(
                      icon: Icon(u.disabled ? Icons.play_circle_outline : Icons.block),
                      tooltip: u.disabled ? 'Enable' : 'Disable',
                      onPressed: () async {
                        try {
                          await Api.i.setDisabled(u.id, !u.disabled);
                          _load();
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                        }
                      },
                    ),
                  ]),
                );
              },
            ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final app = context.findAncestorStateOfType<_WfmAppState>()!;
    final langs = <Locale?, String>{
      null: 'System default',
      const Locale('en', 'GB'): 'Traditional English',
      const Locale('zh', 'CN'): '简体中文',
      const Locale('ru'): 'Русский',
      const Locale('ga'): 'Gaeilge',
    };
    return ListView(padding: const EdgeInsets.all(24), children: [
      Text('Settings', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      DropdownButtonFormField<Locale?>(
        initialValue: app._locale,
        decoration: _dec('Language'),
        items: [for (final e in langs.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => app.setLocale(v),
      ),
      const SizedBox(height: 16),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('System')),
          ButtonSegment(value: ThemeMode.light, label: Text('Light')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
        ],
        selected: {app._theme},
        onSelectionChanged: (s) => app.setTheme(s.first),
      ),
    ]);
  }
}
