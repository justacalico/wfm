import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'nav.dart';
import 'releases.dart';
import 'showcase.dart';

void main() => runApp(const LandingApp());

extension L10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

enum LandingTheme { system, light, dark, oled }

const landingLocales = [
  Locale('en', 'GB'),
  Locale('zh'),
  Locale('ru'),
  Locale('ga'),
];

final landingLangs = <Locale?, String>{
  null: '',
  const Locale('en', 'GB'): 'Traditional English',
  const Locale('zh'): '简体中文',
  const Locale('ru'): 'Русский',
  const Locale('ga'): 'Gaeilge',
};

ThemeData _landingTheme(Brightness b, {bool oled = false}) => ThemeData(
      colorScheme:
          ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6), brightness: b)
              .copyWith(surface: oled ? Colors.black : null),
      fontFamily: 'Noto Sans',
      scaffoldBackgroundColor: oled ? Colors.black : null,
    );

class LandingApp extends StatefulWidget {
  const LandingApp({super.key});
  @override
  State<LandingApp> createState() => LandingAppState();
}

class LandingAppState extends State<LandingApp> {
  LandingTheme _theme = LandingTheme.system;
  Locale? _locale;

  LandingTheme get landingTheme => _theme;
  Locale? get appLocale => _locale;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      setState(() {
        _theme = LandingTheme.values[p.getInt('theme') ?? 0];
        final code = p.getString('locale');
        if (code != null && code.isNotEmpty) {
          final parts = code.split('_');
          _locale = Locale(parts[0], parts.length > 1 ? parts[1] : null);
        }
      });
    });
  }

  void setTheme(LandingTheme t) {
    setState(() => _theme = t);
    SharedPreferences.getInstance().then((p) => p.setInt('theme', t.index));
  }

  void setLocale(Locale? l) {
    setState(() => _locale = l);
    SharedPreferences.getInstance().then((p) =>
        l == null ? p.remove('locale') : p.setString('locale', '${l.languageCode}_${l.countryCode ?? ''}'));
  }

  @override
  Widget build(BuildContext context) {
    final dark = _theme == LandingTheme.oled
        ? _landingTheme(Brightness.dark, oled: true)
        : _landingTheme(Brightness.dark);
    return MaterialApp(
      title: 'WFM',
      debugShowCheckedModeBanner: false,
      theme: _landingTheme(Brightness.light),
      darkTheme: dark,
      themeMode: switch (_theme) {
        LandingTheme.system => ThemeMode.system,
        LandingTheme.light => ThemeMode.light,
        _ => ThemeMode.dark,
      },
      locale: _locale,
      supportedLocales: landingLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});
  static ReleaseFetcher Function()? releaseFactoryForTesting;
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Future<List<Release>>? _releases;

  @override
  void initState() {
    super.initState();
    _releases = (LandingPage.releaseFactoryForTesting?.call() ??
            ReleaseFetcher(http.Client()))
        .fetch();
  }

  void _open(String url) {
    try {
      openExternal(url);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final app = context.findAncestorStateOfType<LandingAppState>()!;
    final wide = MediaQuery.of(context).size.width > 720;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            children: [
              Row(children: [
                const Spacer(),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<Locale?>(
                    initialValue: app.appLocale,
                    isDense: true,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: l10n.language,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      for (final e in landingLangs.entries)
                        DropdownMenuItem(
                            value: e.key,
                            child: Text(e.key == null ? l10n.langSystem : e.value,
                                style: const TextStyle(fontSize: 13))),
                    ],
                    onChanged: (v) => app.setLocale(v),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<LandingTheme>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: LandingTheme.system,
                        icon: const Icon(Icons.brightness_auto, size: 16),
                        tooltip: l10n.themeSystem),
                    ButtonSegment(
                        value: LandingTheme.light,
                        icon: const Icon(Icons.light_mode, size: 16),
                        tooltip: l10n.themeLight),
                    ButtonSegment(
                        value: LandingTheme.dark,
                        icon: const Icon(Icons.dark_mode, size: 16),
                        tooltip: l10n.themeDark),
                    ButtonSegment(
                        value: LandingTheme.oled,
                        icon: const Icon(Icons.brightness_2, size: 16),
                        tooltip: l10n.themeOled),
                  ],
                  selected: {app.landingTheme},
                  onSelectionChanged: (s) => app.setTheme(s.first),
                ),
              ]),
              const SizedBox(height: 32),
              Text(l10n.appTitle,
                  style: TextStyle(
                      fontSize: wide ? 64 : 44,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                      height: 1)),
              const SizedBox(height: 16),
              Text(l10n.tagline,
                  style: TextStyle(fontSize: wide ? 28 : 20, fontWeight: FontWeight.w600, height: 1.3)),
              const SizedBox(height: 16),
              Text(l10n.heroBody,
                  style: TextStyle(fontSize: 15, height: 1.6, color: cs.onSurfaceVariant)),
              const SizedBox(height: 32),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _Feature(Icons.movie_outlined, l10n.featureEditTitle, l10n.featureEditBody),
                _Feature(Icons.folder_outlined, l10n.featureMediaTitle, l10n.featureMediaBody),
                _Feature(Icons.rocket_launch_outlined, l10n.featureRenderTitle, l10n.featureRenderBody),
                _Feature(Icons.group_outlined, l10n.featureSchoolTitle, l10n.featureSchoolBody),
              ]),
              const SizedBox(height: 40),
              Wrap(spacing: 16, runSpacing: 16, children: [
                SizedBox(
                  width: 290,
                  child: ShowcaseCard(title: l10n.showcaseTimeline, child: const TimelineMock()),
                ),
                SizedBox(
                  width: 290,
                  child: ShowcaseCard(title: l10n.showcaseFiles, child: const FoldersMock()),
                ),
                SizedBox(
                  width: 290,
                  child: ShowcaseCard(title: l10n.showcaseRenders, child: const RendersMock()),
                ),
              ]),
              const SizedBox(height: 40),
              Text(l10n.downloadsTitle, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(l10n.downloadsBody, style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 16),
              FutureBuilder<List<Release>>(
                future: _releases,
                builder: (context, s) {
                  if (s.hasError) {
                    return Text(l10n.releasesError, style: TextStyle(color: cs.error));
                  }
                  if (!s.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final releases = s.data!;
                  if (releases.isEmpty) {
                    return TextButton(
                        onPressed: () => _open(ReleaseFetcher.pageUrl),
                        child: Text(l10n.viewAllReleases));
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final r in releases)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.download_outlined),
                          title: Text('${r.name}  ·  ${r.tag}'),
                          subtitle: r.assets.isEmpty
                              ? null
                              : Wrap(spacing: 6, runSpacing: 4, children: [
                                  for (final a in r.assets)
                                    ActionChip(
                                      label: Text(a.name, style: const TextStyle(fontSize: 12)),
                                      onPressed: () => _open(a.url),
                                    ),
                                ]),
                          onTap: () => _open(r.url),
                        ),
                      ),
                    TextButton(
                        onPressed: () => _open(ReleaseFetcher.pageUrl),
                        child: Text(l10n.viewAllReleases)),
                  ]);
                },
              ),
              const SizedBox(height: 40),
              Wrap(spacing: 12, children: [
                FilledButton.icon(
                  onPressed: goApp,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.openApp),
                ),
              ]),
              const SizedBox(height: 16),
              Text(l10n.licenseNote, style: TextStyle(fontSize: 12, color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _Feature(this.icon, this.title, this.body);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 300,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 22, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant, height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}
