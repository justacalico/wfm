import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wfm/main.dart';
import 'package:wfm/shortcuts.dart';
import 'helpers.dart';

const catalog = [
  {
    'id': 'edit.undo',
    'label': 'Undo',
    'category': 'Edit',
    'menu': ['Edit'],
    'shortcuts': [
      {'keys': 'Cmd+Z', 'display': 'Ctrl+Z', 'panel': null}
    ]
  },
  {
    'id': 'edit.redo',
    'label': 'Redo',
    'category': 'Edit',
    'menu': ['Edit'],
    'shortcuts': [
      {'keys': 'Cmd+Shift+Z', 'display': 'Ctrl+Shift+Z', 'panel': null}
    ]
  },
  {
    'id': 'file.newBin',
    'label': 'Bin',
    'category': 'File',
    'menu': ['File', 'New'],
    'shortcuts': [
      {'keys': 'Cmd+B', 'display': 'Ctrl+B', 'panel': null},
      {'keys': 'Cmd+B', 'display': 'Ctrl+B', 'panel': 'Project'}
    ]
  },
  {
    'id': 'tool.razor',
    'label': 'Razor',
    'category': 'Tools',
    'menu': <String>[],
    'shortcuts': [
      {'keys': 'C', 'display': 'C', 'panel': null}
    ]
  },
  {
    'id': 'file.import',
    'label': 'Import',
    'category': 'File',
    'menu': ['File'],
    'shortcuts': <Map<String, String>>[]
  },
];

void main() {
  setUp(
      () => SharedPreferences.setMockInitialValues({'server': 'http://test'}));

  Future<void> pump(WidgetTester t, Widget w) async {
    await t.pumpWidget(testApp(w));
    await settle(t);
  }

  Map<String, dynamic Function(http.Request)> stubs(
          {Map<String, dynamic> bindings = const {}, Object? catalog}) =>
      {
        'GET /api/shortcuts/catalog': (_) => catalog ?? [],
        'GET /api/shortcuts': (_) => {'bindings': bindings},
      };

  testWidgets('lists rows, panels and filters by search', (t) async {
    installApi(
        extra: stubs(bindings: {'edit.undo': 'Alt+Q'}, catalog: catalog));
    await pump(t, const ShortcutsPage());
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('Alt+Q'), findsOneWidget);
    expect(find.text('Ctrl+Shift+Z'), findsOneWidget);
    expect(find.text('Bin'), findsNWidgets(2));
    expect(find.text('Project'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Unbound'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'razor');
    await settle(t);
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Razor'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'zzz');
    await settle(t);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('remap captures keys, warns on conflict, saves', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.text('Undo'));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(t);
    expect(find.textContaining('Already used by'), findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(saved, contains('"edit.undo":"C"'));
    expect(saved, contains('"tool.razor":""'));
    expect(find.text('Unbound'), findsWidgets);

    await t.tap(find.text('Razor'));
    await settle(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await settle(t);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('Ctrl+Shift+J')),
        findsOneWidget);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(saved, contains('"tool.razor":"Cmd+Shift+J"'));
    expect(find.text('Ctrl+Shift+J'), findsOneWidget);

    await t.tap(find.text('Razor'));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(saved, isNot(contains('tool.razor')));
  });

  testWidgets('modifier-only and unknown keys are ignored', (t) async {
    installApi(extra: stubs(catalog: catalog));
    await pump(t, const ShortcutsPage());
    await t.tap(find.text('Razor'));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.f2);
    await t.sendKeyEvent(LogicalKeyboardKey.numpadComma);
    await settle(t);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('F2')),
        findsOneWidget);
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(t);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('clear binding and reset to default', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(bindings: {'edit.undo': 'Alt+Q'}, catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.text('Import'));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'Clear'));
    await settle(t);
    expect(saved, isNot(contains('file.import')));

    await t.tap(find.byIcon(Icons.undo));
    await settle(t);
    expect(saved, isNot(contains('edit.undo')));
    expect(find.text('Ctrl+Z'), findsOneWidget);

    await t.tap(find.text('Bin').first);
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'Clear'));
    await settle(t);
    expect(saved, contains('"file.newBin":""'));
  });

  testWidgets('clear keeps explicit unbind for defaults', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.text('Bin').last);
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'Clear'));
    await settle(t);
    expect(saved, contains('"file.newBin@Project":""'));
  });

  testWidgets('reset all confirms and clears overrides', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(bindings: {'edit.undo': 'Alt+Q'}, catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.byIcon(Icons.restore));
    await settle(t);
    await t.tap(find.widgetWithText(TextButton, 'Cancel'));
    await settle(t);
    expect(saved, isEmpty);
    await t.tap(find.byIcon(Icons.restore));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(saved, contains('"bindings":{}'));
    expect(find.text('Ctrl+Z'), findsOneWidget);
  });

  testWidgets('save error shows snack', (t) async {
    installApi(extra: {
      ...stubs(catalog: catalog),
      'PUT /api/shortcuts': (_) => http.Response('{"error":"nope"}', 500),
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.text('Razor'));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(find.textContaining('nope'), findsOneWidget);
  });

  testWidgets('load error retries', (t) async {
    var calls = 0;
    installApi(extra: {
      'GET /api/shortcuts/catalog': (_) =>
          calls++ == 0 ? http.Response('{"error":"x"}', 500) : catalog,
      'GET /api/shortcuts': (_) => {'bindings': <String, String>{}},
    });
    await pump(t, const ShortcutsPage());
    expect(find.text('Retry'), findsOneWidget);
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('mac display shows the command glyph', (t) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    installApi(extra: stubs(catalog: catalog));
    await pump(t, const ShortcutsPage());
    expect(find.text('⌘+Z'), findsOneWidget);
    await t.tap(find.text('Razor'));
    await settle(t);
    await t.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyK);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await settle(t);
    expect(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.text('⌘+Ctrl+K')),
        findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('settings tile opens the shortcuts page', (t) async {
    installApi(extra: stubs(catalog: catalog));
    await t.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
    await t.tap(find.byIcon(Icons.keyboard_outlined).first);
    await settle(t);
    expect(find.byType(ShortcutsPage), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('scriptcraft page loads its catalog and sc-namespaced bindings',
      (t) async {
    var app = '';
    var saved = '';
    installApi(extra: {
      'GET /api/shortcuts/catalog': (req) {
        app = req.url.queryParameters['app'] ?? '';
        return catalog;
      },
      'GET /api/shortcuts': (_) => {
            'bindings': {'sc.edit.undo': 'Alt+Q', 'edit.undo': 'Cmd+K'}
          },
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage(app: 'scriptcraft'));
    expect(app, 'scriptcraft');
    expect(find.text('ScriptCraft shortcuts'), findsOneWidget);
    expect(find.text('Alt+Q'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(saved, contains('"sc.edit.undo":"C"'));
    expect(saved, contains('"edit.undo":"Cmd+K"'));
    expect(saved, contains('"sc.tool.razor":""'));
    expect(find.text('Unbound'), findsWidgets);
  });

  testWidgets('scriptcraft reset all keeps filmcraft bindings', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(
          bindings: {'sc.edit.undo': 'Alt+Q', 'edit.undo': 'Cmd+K'},
          catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage(app: 'scriptcraft'));
    await t.tap(find.byIcon(Icons.restore));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(saved, contains('"edit.undo":"Cmd+K"'));
    expect(saved, isNot(contains('sc.edit.undo')));
  });

  testWidgets('filmcraft reset all keeps scriptcraft bindings', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(
          bindings: {'sc.edit.undo': 'Alt+Q', 'edit.undo': 'Cmd+K'},
          catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.byIcon(Icons.restore));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(saved, contains('"sc.edit.undo":"Alt+Q"'));
    expect(saved, isNot(contains('"edit.undo"')));
  });

  testWidgets('deckcraft page loads its catalog and dc-namespaced bindings',
      (t) async {
    var app = '';
    var saved = '';
    installApi(extra: {
      'GET /api/shortcuts/catalog': (req) {
        app = req.url.queryParameters['app'] ?? '';
        return catalog;
      },
      'GET /api/shortcuts': (_) => {
            'bindings': {'dc.edit.undo': 'Alt+Q', 'edit.undo': 'Cmd+K'}
          },
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage(app: 'deckcraft'));
    expect(app, 'deckcraft');
    expect(find.text('DeckCraft shortcuts'), findsOneWidget);
    expect(find.text('Alt+Q'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await settle(t);
    await t.sendKeyEvent(LogicalKeyboardKey.keyC);
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(t);
    expect(saved, contains('"dc.edit.undo":"C"'));
    expect(saved, contains('"edit.undo":"Cmd+K"'));
  });

  testWidgets('deckcraft reset all keeps other app bindings', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(bindings: {
        'dc.edit.undo': 'Alt+Q',
        'sc.edit.undo': 'Alt+W',
        'edit.undo': 'Cmd+K'
      }, catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage(app: 'deckcraft'));
    await t.tap(find.byIcon(Icons.restore));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(saved, contains('"sc.edit.undo":"Alt+W"'));
    expect(saved, contains('"edit.undo":"Cmd+K"'));
    expect(saved, isNot(contains('dc.edit.undo')));
  });

  testWidgets('filmcraft reset all keeps deckcraft bindings', (t) async {
    var saved = '';
    installApi(extra: {
      ...stubs(
          bindings: {'dc.edit.undo': 'Alt+Q', 'edit.undo': 'Cmd+K'},
          catalog: catalog),
      'PUT /api/shortcuts': (req) {
        saved = req.body;
        return {'ok': true};
      },
    });
    await pump(t, const ShortcutsPage());
    await t.tap(find.byIcon(Icons.restore));
    await settle(t);
    await t.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await settle(t);
    expect(saved, contains('"dc.edit.undo":"Alt+Q"'));
    expect(saved, isNot(contains('"edit.undo"')));
  });

  testWidgets('deckcraft settings tile opens the dc shortcuts page', (t) async {
    var app = '';
    installApi(extra: {
      'GET /api/shortcuts/catalog': (req) {
        app = req.url.queryParameters['app'] ?? '';
        return catalog;
      },
      'GET /api/shortcuts': (_) => {'bindings': <String, String>{}},
    });
    await t.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
    await t.tap(find.text('DeckCraft shortcuts'));
    await settle(t);
    expect(find.byType(ShortcutsPage), findsOneWidget);
    expect(app, 'deckcraft');
    expect(find.text('DeckCraft shortcuts'), findsNWidgets(2));
  });

  testWidgets('scriptcraft settings tile opens the sc shortcuts page',
      (t) async {
    var app = '';
    installApi(extra: {
      'GET /api/shortcuts/catalog': (req) {
        app = req.url.queryParameters['app'] ?? '';
        return catalog;
      },
      'GET /api/shortcuts': (_) => {'bindings': <String, String>{}},
    });
    await t.binding.setSurfaceSize(const Size(1280, 2400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(const WfmApp());
    await settle(t);
    await t.tap(find.widgetWithText(ListTile, 'Settings').first);
    await settle(t);
    await t.tap(find.text('ScriptCraft shortcuts'));
    await settle(t);
    expect(find.byType(ShortcutsPage), findsOneWidget);
    expect(app, 'scriptcraft');
    expect(find.text('ScriptCraft shortcuts'), findsNWidgets(2));
  });
}
