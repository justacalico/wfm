// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Irish (`ga`).
class AppLocalizationsGa extends AppLocalizations {
  AppLocalizationsGa([String locale = 'ga']) : super(locale);

  @override
  String get appTitle => 'WFM';

  @override
  String get tagline =>
      'Tionscadail scannáin an ranga ar fad in aon áit amháin.';

  @override
  String get heroBody =>
      'Is bainisteoir meán féin-óstáilte é WFM do chláir scannánaíochta scoile. Uaslódálann daltaí físeán, gearrann siad in eagarthóir brabhsála, agus cuireann siad rindreálacha sa scuaine. Coinníonn múinteoirí cuntais, ceadanna agus gníomhaíocht faoi smacht.';

  @override
  String get openApp => 'Oscail an aip';

  @override
  String get featureEditTitle => 'Gearr sa bhrabhsálaí';

  @override
  String get featureEditBody =>
      'Eagarthóireacht amlíne cumhachtaithe ag FilmCraft, gan aon shuiteáil.';

  @override
  String get featureMediaTitle => 'Meáin eagraithe';

  @override
  String get featureMediaBody =>
      'Fillteáin Raw, Audio, Images agus Exports do gach tionscadal.';

  @override
  String get featureRenderTitle => 'Rindreálacha freastalaí';

  @override
  String get featureRenderBody =>
      'Cuir easpórtálacha sa scuaine ar an bhfreastalaí nó ar nóid cianda.';

  @override
  String get featureSchoolTitle => 'Déanta do scoileanna';

  @override
  String get featureSchoolBody =>
      'Róil dalta, modhnóir, múinteoir agus riarthóir le loga iniúchta.';

  @override
  String get downloadsTitle => 'Íoslódálacha';

  @override
  String get downloadsBody =>
      'Faigh an eisiúint is déanaí go díreach ó GitLab.';

  @override
  String get releasesError => 'Níorbh fhéidir eisiúintí a lódáil faoi láthair.';

  @override
  String get viewAllReleases => 'Gach eisiúint ar GitLab';

  @override
  String get licenseNote => 'Bogearraí saora agus foinsí oscailte (AGPL-3.0).';

  @override
  String get themeSystem => 'Córas';

  @override
  String get themeLight => 'Solas';

  @override
  String get themeDark => 'Dorcha';

  @override
  String get themeOled => 'OLED';

  @override
  String get language => 'Teanga';

  @override
  String get langSystem => 'Córas';

  @override
  String get showcaseTimeline => 'Gearr ar amlíne sa bhrabhsálaí';

  @override
  String get showcaseFiles =>
      'Faigheann gach tionscadal fillteáin bhainistithe';

  @override
  String get showcaseRenders =>
      'Féach ar easpórtálacha ag críochnú ar an bhfreastalaí';

  @override
  String get screenshotsTitle => 'Gabhálacha scáileáin';
}
