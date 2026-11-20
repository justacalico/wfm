// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WFM';

  @override
  String get tagline => 'Film projects for a whole class, in one place.';

  @override
  String get heroBody =>
      'WFM is a self-hosted media manager for school film programs. Students upload footage, write scripts, plan storyboards, cut in a browser editor and queue renders. Teachers keep accounts, assignments and activity under control.';

  @override
  String get openApp => 'Open the app';

  @override
  String get featureEditTitle => 'Write, board and cut';

  @override
  String get featureEditBody =>
      'ScriptCraft screenplays, DeckCraft storyboards and FilmCraft timelines, all in the browser.';

  @override
  String get featureMediaTitle => 'Organized media';

  @override
  String get featureMediaBody =>
      'Managed folders for footage, audio, images, scripts, boards and exports.';

  @override
  String get featureRenderTitle => 'Server renders';

  @override
  String get featureRenderBody =>
      'Queue exports on the server or on remote render nodes.';

  @override
  String get featureSchoolTitle => 'Made for schools';

  @override
  String get featureSchoolBody =>
      'Student, mod, teacher and admin roles, assignments and an audit log.';

  @override
  String get downloadsTitle => 'Downloads';

  @override
  String get downloadsBody => 'Grab the latest release straight from GitLab.';

  @override
  String get releasesError => 'Could not load releases right now.';

  @override
  String get viewAllReleases => 'All releases on GitLab';

  @override
  String get licenseNote => 'Free and open source (AGPL-3.0).';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeOled => 'OLED';

  @override
  String get language => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get showcaseScript => 'Draft the script before the shoot';

  @override
  String get showcaseTimeline => 'Cut on a timeline in the browser';

  @override
  String get showcaseFiles => 'Every project gets managed folders';

  @override
  String get showcaseRenders => 'Watch exports finish on the server';

  @override
  String get screenshotsTitle => 'Screenshots';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String get featureMediaTitle => 'Organised media';

  @override
  String get screenshotsTitle => 'Screenshots';
}
