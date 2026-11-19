import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';

class InvitePage extends StatefulWidget {
  final String code;
  const InvitePage({super.key, required this.code});

  @override
  State<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends State<InvitePage> {
  Map<String, dynamic>? _inv;
  String _err = '';
  bool _busy = false;
  final _user = TextEditingController();
  final _name = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_user, _name, _pw, _pw2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.inviteGet(widget.code);
      setState(() => _inv = v);
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _redeem() async {
    final l10n = context.l10n;
    if (_pw.text != _pw2.text) {
      setState(() => _err = l10n.passwordsMismatch);
      return;
    }
    setState(() {
      _busy = true;
      _err = '';
    });
    try {
      await Api.i.inviteRedeem(
          widget.code, _user.text.trim(), _name.text.trim(), _pw.text);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Shell()), (_) => false);
    } catch (e) {
      setState(() {
        _busy = false;
        _err = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inv = _inv;
    return Scaffold(
      appBar: AppBar(title: const Text('WFM')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: _err.isNotEmpty && inv == null
              ? errorView(context, _err, _load)
              : inv == null
                  ? const CircularProgressIndicator()
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l10n.inviteSignup,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 16),
                              if ('${inv['username']}'.isEmpty)
                                TextField(
                                    controller: _user,
                                    decoration: InputDecoration(
                                        labelText: l10n.username))
                              else
                                ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.person),
                                    title: Text('${inv['username']}')),
                              const SizedBox(height: 8),
                              if ('${inv['name']}'.isEmpty)
                                TextField(
                                    controller: _name,
                                    decoration: InputDecoration(
                                        labelText: l10n.displayName))
                              else
                                ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.badge),
                                    title: Text('${inv['name']}')),
                              const SizedBox(height: 8),
                              TextField(
                                  controller: _pw,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                      labelText: l10n.password)),
                              const SizedBox(height: 8),
                              TextField(
                                  controller: _pw2,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                      labelText: l10n.confirmPassword),
                                  onSubmitted: (_) => _redeem()),
                              if (_err.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(_err,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error)),
                                ),
                              const SizedBox(height: 16),
                              FilledButton(
                                  onPressed: _busy ? null : _redeem,
                                  child: _busy
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : Text(l10n.signUp)),
                            ]),
                      ),
                    ),
        ),
      ),
    );
  }
}
