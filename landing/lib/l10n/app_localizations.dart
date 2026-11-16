// coverage:ignore-file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('en', 'GB')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WFM'**
  String get appTitle;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Film projects for a whole class, in one place.'**
  String get tagline;

  /// No description provided for @heroBody.
  ///
  /// In en, this message translates to:
  /// **'WFM is a self-hosted media manager for school film programs. Students upload footage, cut in a browser editor, and queue renders. Teachers keep accounts, permissions and activity under control.'**
  String get heroBody;

  /// No description provided for @openApp.
  ///
  /// In en, this message translates to:
  /// **'Open the app'**
  String get openApp;

  /// No description provided for @featureEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit in the browser'**
  String get featureEditTitle;

  /// No description provided for @featureEditBody.
  ///
  /// In en, this message translates to:
  /// **'Timeline editing powered by FilmCraft, no installs needed.'**
  String get featureEditBody;

  /// No description provided for @featureMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Organized media'**
  String get featureMediaTitle;

  /// No description provided for @featureMediaBody.
  ///
  /// In en, this message translates to:
  /// **'Raw, Audio, Images and Exports folders for every project.'**
  String get featureMediaBody;

  /// No description provided for @featureRenderTitle.
  ///
  /// In en, this message translates to:
  /// **'Server renders'**
  String get featureRenderTitle;

  /// No description provided for @featureRenderBody.
  ///
  /// In en, this message translates to:
  /// **'Queue exports on the server or on remote render nodes.'**
  String get featureRenderBody;

  /// No description provided for @featureSchoolTitle.
  ///
  /// In en, this message translates to:
  /// **'Made for schools'**
  String get featureSchoolTitle;

  /// No description provided for @featureSchoolBody.
  ///
  /// In en, this message translates to:
  /// **'Student, mod, teacher and admin roles with an audit log.'**
  String get featureSchoolBody;

  /// No description provided for @downloadsTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get downloadsTitle;

  /// No description provided for @downloadsBody.
  ///
  /// In en, this message translates to:
  /// **'Grab the latest release straight from GitLab.'**
  String get downloadsBody;

  /// No description provided for @releasesError.
  ///
  /// In en, this message translates to:
  /// **'Could not load releases right now.'**
  String get releasesError;

  /// No description provided for @viewAllReleases.
  ///
  /// In en, this message translates to:
  /// **'All releases on GitLab'**
  String get viewAllReleases;

  /// No description provided for @licenseNote.
  ///
  /// In en, this message translates to:
  /// **'Free and open source (AGPL-3.0).'**
  String get licenseNote;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeOled.
  ///
  /// In en, this message translates to:
  /// **'OLED'**
  String get themeOled;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @showcaseTimeline.
  ///
  /// In en, this message translates to:
  /// **'Cut on a timeline in the browser'**
  String get showcaseTimeline;

  /// No description provided for @showcaseFiles.
  ///
  /// In en, this message translates to:
  /// **'Every project gets managed folders'**
  String get showcaseFiles;

  /// No description provided for @showcaseRenders.
  ///
  /// In en, this message translates to:
  /// **'Watch exports finish on the server'**
  String get showcaseRenders;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'en':
      {
        switch (locale.countryCode) {
          case 'GB':
            return AppLocalizationsEnGb();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
