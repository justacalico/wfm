import 'package:flutter/material.dart';
import 'api.dart';
import 'main.dart';
import 'platform.dart';
import 'util.dart';

class LinkPage extends StatefulWidget {
  final String token;
  const LinkPage({super.key, required this.token});

  @override
  State<LinkPage> createState() => _LinkPageState();
}

class _LinkPageState extends State<LinkPage> {
  Map<String, dynamic>? _data;
  String _err = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await Api.i.linkResolve(widget.token);
      setState(() {
        _data = v;
        _err = '';
      });
    } catch (e) {
      setState(() => _err = '$e');
    }
  }

  Future<void> _open(String path) async {
    try {
      await openExternal(Api.i.linkFileUrl(widget.token, path));
    } catch (e) {
      if (mounted) snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_err.isNotEmpty) return errorView(context, _err, _load);
    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final files = (data['files'] as List? ?? []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text('${data['name'] ?? ''}')),
      body: files.isEmpty
          ? Center(child: Text(l10n.linkEmpty))
          : ListView(padding: const EdgeInsets.all(16), children: [
              if (data['scope'] == 'renders')
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(l10n.linkRendersOnly,
                      style: Theme.of(context).textTheme.labelMedium),
                ),
              for (final f in files)
                Card(
                  child: ListTile(
                    leading: Icon(playableMedia('${f['path'] ?? ''}')
                        ? Icons.play_circle_outline
                        : Icons.insert_drive_file_outlined),
                    title: Text('${f['path'] ?? ''}'),
                    subtitle: Text(fmtBytes((f['size'] as num?)?.toInt() ?? 0)),
                    onTap: () => _open('${f['path'] ?? ''}'),
                  ),
                ),
            ]),
    );
  }
}
