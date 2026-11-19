import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api.dart';
import 'main.dart';

class _Row {
  final ShortcutAction action;
  final String? panel;
  _Row(this.action, this.panel);
  String get key => panel == null ? action.id : '${action.id}@$panel';
}

final _keyNames = {
  LogicalKeyboardKey.backspace: 'Backspace',
  LogicalKeyboardKey.delete: 'Delete',
  LogicalKeyboardKey.enter: 'Enter',
  LogicalKeyboardKey.numpadEnter: 'Enter',
  LogicalKeyboardKey.space: 'Space',
  LogicalKeyboardKey.escape: 'Escape',
  LogicalKeyboardKey.tab: 'Tab',
  LogicalKeyboardKey.arrowLeft: 'Left',
  LogicalKeyboardKey.arrowRight: 'Right',
  LogicalKeyboardKey.arrowUp: 'Up',
  LogicalKeyboardKey.arrowDown: 'Down',
  LogicalKeyboardKey.home: 'Home',
  LogicalKeyboardKey.end: 'End',
  LogicalKeyboardKey.pageUp: 'PageUp',
  LogicalKeyboardKey.pageDown: 'PageDown',
  LogicalKeyboardKey.comma: ',',
  LogicalKeyboardKey.period: '.',
  LogicalKeyboardKey.slash: '/',
  LogicalKeyboardKey.backslash: '\\',
  LogicalKeyboardKey.semicolon: ';',
  LogicalKeyboardKey.equal: '=',
  LogicalKeyboardKey.minus: '-',
  LogicalKeyboardKey.quote: "'",
  LogicalKeyboardKey.bracketLeft: '[',
  LogicalKeyboardKey.bracketRight: ']',
  LogicalKeyboardKey.backquote: '`',
};

String? keyName(LogicalKeyboardKey k) {
  if (_keyNames.containsKey(k)) return _keyNames[k];
  final label = k.keyLabel;
  if (label.length == 1) {
    final c = label.toUpperCase();
    if (RegExp(r'^[A-Z0-9]$').hasMatch(c)) return c;
  }
  if (label.startsWith('F') && int.tryParse(label.substring(1)) != null) {
    return label;
  }
  return null;
}

String? keyToken(KeyDownEvent e) {
  final name = keyName(e.logicalKey);
  if (name == null) return null;
  final hw = HardwareKeyboard.instance;
  final mac = defaultTargetPlatform == TargetPlatform.macOS;
  return [
    if ((mac && hw.isMetaPressed) || (!mac && hw.isControlPressed)) 'Cmd',
    if (mac && hw.isControlPressed) 'Ctrl',
    if (hw.isAltPressed) 'Alt',
    if (hw.isShiftPressed) 'Shift',
    name,
  ].join('+');
}

String displayKeys(String keys) {
  final mac = defaultTargetPlatform == TargetPlatform.macOS;
  return keys
      .split('+')
      .map((t) => t == 'Cmd'
          ? mac
              ? '⌘'
              : 'Ctrl'
          : t)
      .join('+');
}

class ShortcutsPage extends StatefulWidget {
  const ShortcutsPage({super.key});
  @override
  State<ShortcutsPage> createState() => _ShortcutsPageState();
}

class _ShortcutsPageState extends State<ShortcutsPage> {
  List<_Row>? _rows;
  Map<String, String> _over = {};
  String _q = '', _err = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await Api.i.shortcutCatalog();
      final over = await Api.i.shortcuts();
      if (mounted) {
        setState(() {
          _over = over;
          _rows = [
            for (final a in catalog)
              for (final p in a.contexts) _Row(a, p)
          ];
          _err = '';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  String keysFor(_Row r) =>
      _over.containsKey(r.key) ? _over[r.key]! : r.action.defaultKeys(r.panel);

  String? _conflict(_Row self, String keys) {
    for (final o in _rows ?? <_Row>[]) {
      if (o.key != self.key && o.panel == self.panel && keysFor(o) == keys) {
        return o.action.label;
      }
    }
    return null;
  }

  Future<void> _apply(Map<String, String> next) async {
    if (_saving) return;
    _saving = true;
    try {
      await Api.i.saveShortcuts(next);
      if (mounted) setState(() => _over = next);
    } catch (e) {
      if (mounted) snack(context, e);
    }
    _saving = false;
  }

  Future<void> _edit(_Row r) async {
    final res = await showDialog<String>(
        context: context,
        builder: (_) => _CaptureDialog(
            title: r.action.label,
            panel: r.panel,
            conflictOf: (keys) => _conflict(r, keys)));
    if (res == null || !mounted) return;
    final next = Map<String, String>.of(_over);
    if (res.isEmpty) {
      if (r.action.defaultKeys(r.panel).isEmpty) {
        next.remove(r.key);
      } else {
        next[r.key] = '';
      }
    } else {
      for (final o in _rows ?? <_Row>[]) {
        if (o.panel == r.panel && o.key != r.key && keysFor(o) == res) {
          next[o.key] = '';
        }
      }
      if (res == r.action.defaultKeys(r.panel)) {
        next.remove(r.key);
      } else {
        next[r.key] = res;
      }
    }
    await _apply(next);
  }

  Future<void> _resetAll() async {
    if (!await confirm(context, context.l10n.resetAllShortcuts,
        context.l10n.resetAllShortcutsBody)) {
      return;
    }
    await _apply({});
  }

  void _resetOne(_Row r) {
    final next = Map<String, String>.of(_over)..remove(r.key);
    _apply(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.filmcraftShortcuts), actions: [
        IconButton(
            tooltip: l10n.resetAllShortcuts,
            icon: const Icon(Icons.restore),
            onPressed: _resetAll),
      ]),
      body: _err.isNotEmpty
          ? errorView(context, _err, _load)
          : _rows == null
              ? const Center(child: CircularProgressIndicator())
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: l10n.searchShortcuts,
                          border: const OutlineInputBorder()),
                      onChanged: (v) => setState(() => _q = v),
                    ),
                  ),
                  Expanded(
                    child: ListView(children: [
                      for (final r in _rows!.where((r) =>
                          _q.isEmpty ||
                          '${r.action.label} ${r.action.id} ${keysFor(r)} ${r.panel ?? ''}'
                              .toLowerCase()
                              .contains(_q.toLowerCase())))
                        ListTile(
                          dense: true,
                          onTap: () => _edit(r),
                          title: Text(r.action.label),
                          subtitle: Text(r.panel ??
                              [r.action.category, ...r.action.menu]
                                  .where((s) => s.isNotEmpty)
                                  .join(' / ')),
                          trailing:
                              Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(
                                keysFor(r).isEmpty
                                    ? l10n.unbound
                                    : displayKeys(keysFor(r)),
                                style: TextStyle(
                                    color: keysFor(r).isEmpty
                                        ? Theme.of(context).hintColor
                                        : null)),
                            if (_over.containsKey(r.key))
                              IconButton(
                                  tooltip: l10n.resetToDefault,
                                  icon: const Icon(Icons.undo, size: 18),
                                  onPressed: () => _resetOne(r)),
                          ]),
                        ),
                    ]),
                  ),
                ]),
    );
  }
}

class _CaptureDialog extends StatefulWidget {
  final String title;
  final String? panel;
  final String? Function(String keys) conflictOf;
  const _CaptureDialog(
      {required this.title, required this.panel, required this.conflictOf});
  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  String _keys = '', _conflict = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.panel == null
          ? widget.title
          : '${widget.title} (${widget.panel})'),
      content: Focus(
        autofocus: true,
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          final t = keyToken(e);
          if (t == null) return KeyEventResult.handled;
          setState(() {
            _keys = t;
            _conflict = widget.conflictOf(t) ?? '';
          });
          return KeyEventResult.handled;
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l10n.pressShortcut),
          const SizedBox(height: 12),
          Text(_keys.isEmpty ? '—' : displayKeys(_keys),
              style: Theme.of(context).textTheme.headlineSmall),
          if (_conflict.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.shortcutConflict(_conflict),
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(''),
            child: Text(l10n.clearShortcut)),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel)),
        FilledButton(
            onPressed:
                _keys.isEmpty ? null : () => Navigator.of(context).pop(_keys),
            child: Text(l10n.save)),
      ],
    );
  }
}
