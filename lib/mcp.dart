import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'main.dart';
import 'util.dart';

class McpPage extends StatefulWidget {
  const McpPage({super.key});
  @override
  State<McpPage> createState() => _McpPageState();
}

class _McpPageState extends State<McpPage> {
  List<McpToken>? _tokens;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.mcpTokens();
      if (mounted) {
        setState(() {
          _tokens = v;
          _err = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
        context: context, builder: (_) => const _McpNameDialog());
    if (name == null || !mounted) return;
    try {
      final t = await Api.i.mcpTokenCreate(name);
      if (!mounted) return;
      _load();
      await showDialog<void>(
          context: context, builder: (_) => _McpTokenDialog(t));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  Future<void> _revoke(McpToken t) async {
    if (!await confirm(
        context, context.l10n.revoke, context.l10n.mcpRevokeBody)) {
      return;
    }
    try {
      await Api.i.mcpTokenDelete(t.id);
      if (mounted) {
        setState(() => _tokens!.removeWhere((x) => x.id == t.id));
      }
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = _tokens;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.mcp)),
      body: _err.isNotEmpty
          ? errorView(context, _err, _load)
          : tokens == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(24), children: [
                  Text(l10n.mcpHint,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.link, size: 18),
                    title: Text(l10n.mcpUrl),
                    subtitle: Text(Api.i.mcpUrl),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_outlined, size: 18),
                      tooltip: l10n.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: Api.i.mcpUrl));
                        snack(context, l10n.copied, good: true);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(l10n.mcpTokens,
                        style: Theme.of(context).textTheme.titleSmall),
                  ),
                  Text(l10n.mcpTokensHint,
                      style: Theme.of(context).textTheme.bodySmall),
                  if (tokens.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l10n.mcpEmpty,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  for (final t in tokens)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.smart_toy_outlined, size: 18),
                      title: Text(t.name.isEmpty ? '—' : t.name),
                      subtitle: t.lastSeen > 0
                          ? Text(l10n.sessionLastSeen(fmtAgo(l10n, t.lastSeen)))
                          : null,
                      trailing: TextButton(
                          onPressed: () => _revoke(t),
                          child: Text(l10n.revoke)),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: _create,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(l10n.mcpNew),
                    ),
                  ),
                ]),
    );
  }
}

class _McpNameDialog extends StatefulWidget {
  const _McpNameDialog();
  @override
  State<_McpNameDialog> createState() => _McpNameDialogState();
}

class _McpNameDialogState extends State<_McpNameDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.mcpNew),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _name,
          autofocus: true,
          decoration: dec(l10n.mcpName, l10n.mcpNameHint),
          onSubmitted: (_) => Navigator.pop(context, _name.text.trim()),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _name.text.trim()),
            child: Text(l10n.save)),
      ],
    );
  }
}

class _McpTokenDialog extends StatelessWidget {
  final McpToken token;
  const _McpTokenDialog(this.token);

  static String prompt(String url, String token) =>
      'Add my WFM film manager as an MCP server so you can manage my '
      'projects, upload footage and edit timelines:\n\n'
      'URL: $url\n'
      'Authorization: Bearer $token';

  static String config(String url, String token) =>
      const JsonEncoder.withIndent('  ').convert({
        'mcpServers': {
          'wfm': {
            'type': 'http',
            'url': url,
            'headers': {'Authorization': 'Bearer $token'},
          }
        }
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final url = Api.i.mcpUrl;
    Widget block(String label, String text) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                  child: Text(label,
                      style: Theme.of(context).textTheme.labelLarge)),
              IconButton(
                icon: const Icon(Icons.copy_outlined, size: 18),
                tooltip: l10n.copy,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  snack(context, l10n.copied, good: true);
                },
              ),
            ]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(text,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            const SizedBox(height: 12),
          ],
        );
    return AlertDialog(
      title: Text(l10n.mcpReady),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(l10n.mcpOnce, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            block(l10n.mcpPrompt, prompt(url, token.token)),
            block(l10n.mcpConfig, config(url, token.token)),
          ]),
        ),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(context), child: Text(l10n.done)),
      ],
    );
  }
}
