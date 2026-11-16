// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'WFM';

  @override
  String get tagline => 'Все фильмы класса в одном месте.';

  @override
  String get heroBody =>
      'WFM — это самостоятельно размещаемый менеджер медиа для школьных кинопрограмм. Ученики загружают отснятое, монтируют в браузерном редакторе и ставят рендеры в очередь. Учителя управляют аккаунтами, правами и активностью.';

  @override
  String get openApp => 'Открыть приложение';

  @override
  String get featureEditTitle => 'Монтаж в браузере';

  @override
  String get featureEditBody =>
      'Таймлайн-монтаж на базе FilmCraft, без установки.';

  @override
  String get featureMediaTitle => 'Порядок в медиа';

  @override
  String get featureMediaBody =>
      'Папки Raw, Audio, Images и Exports для каждого проекта.';

  @override
  String get featureRenderTitle => 'Рендер на сервере';

  @override
  String get featureRenderBody =>
      'Очередь экспортов на сервере или удалённых узлах.';

  @override
  String get featureSchoolTitle => 'Для школ';

  @override
  String get featureSchoolBody =>
      'Роли ученик, модератор, учитель и админ с журналом аудита.';

  @override
  String get downloadsTitle => 'Загрузки';

  @override
  String get downloadsBody => 'Скачайте последний релиз прямо с GitLab.';

  @override
  String get releasesError => 'Не удалось загрузить список релизов.';

  @override
  String get viewAllReleases => 'Все релизы на GitLab';

  @override
  String get licenseNote => 'Свободное ПО с открытым кодом (AGPL-3.0).';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeOled => 'OLED';

  @override
  String get language => 'Язык';

  @override
  String get langSystem => 'Системный';

  @override
  String get showcaseTimeline => 'Монтаж на таймлайне в браузере';

  @override
  String get showcaseFiles => 'У каждого проекта свои папки';

  @override
  String get showcaseRenders => 'Экспорты завершаются на сервере';

  @override
  String get screenshotsTitle => 'Скриншоты';
}
