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
  String get cancel => 'Отмена';

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get done => 'Готово';

  @override
  String get save => 'Сохранить';

  @override
  String get delete => 'Удалить';

  @override
  String get rename => 'Переименовать';

  @override
  String get download => 'Скачать';

  @override
  String get create => 'Создать';

  @override
  String get refresh => 'Обновить';

  @override
  String get upload => 'Загрузить';

  @override
  String get enable => 'Включить';

  @override
  String get disable => 'Отключить';

  @override
  String get logout => 'Выйти';

  @override
  String get welcomeTitle => 'Добро пожаловать в WFM';

  @override
  String get setupSubtitle =>
      'Создайте учётную запись владельца, чтобы начать.';

  @override
  String get yourName => 'Ваше имя';

  @override
  String get username => 'Имя пользователя';

  @override
  String get password => 'Пароль';

  @override
  String get creating => 'Создание…';

  @override
  String get createOwner => 'Создать владельца';

  @override
  String get signIn => 'Войти';

  @override
  String get signingIn => 'Вход…';

  @override
  String signInFailed(Object error) {
    return 'Ошибка входа: $error';
  }

  @override
  String get behindProxy => 'Сервер находится за обратным прокси';

  @override
  String get trustedProxies => 'Доверенные прокси';

  @override
  String get trustedProxiesHint =>
      'IP-адреса или CIDR через запятую, например 10.0.0.1, 172.16.0.0/12';

  @override
  String get navHome => 'Главная';

  @override
  String get navProjects => 'Проекты';

  @override
  String get navManage => 'Управление';

  @override
  String get navSettings => 'Настройки';

  @override
  String greeting(Object name) {
    return 'Привет, $name';
  }

  @override
  String get cardProjects => 'Проекты';

  @override
  String get cardProjectsSub => 'Открыть ваши фильмы';

  @override
  String get cardManage => 'Управление';

  @override
  String get cardManageSub => 'Учётные записи и права';

  @override
  String get cardSettings => 'Настройки';

  @override
  String get cardSettingsSub => 'Тема и язык';

  @override
  String get projects => 'Проекты';

  @override
  String get newProject => 'Новый проект';

  @override
  String get projectName => 'Название проекта';

  @override
  String get noProjects => 'Проектов пока нет. Создайте первый.';

  @override
  String createdAgo(Object when) {
    return 'Создан $when';
  }

  @override
  String get openInFilmcraft => 'Открыть в Filmcraft';

  @override
  String get renameProject => 'Переименовать проект';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get deleteProject => 'Удалить проект';

  @override
  String deleteProjectBody(Object name) {
    return 'Удалить «$name» со всеми медиафайлами? Это действие нельзя отменить.';
  }

  @override
  String get files => 'Файлы';

  @override
  String get renders => 'Рендеры';

  @override
  String get emptyFolder => 'Пустая папка';

  @override
  String get newFolder => 'Новая папка';

  @override
  String get folderName => 'Имя папки';

  @override
  String get newName => 'Новое имя';

  @override
  String deleteFileBody(Object path) {
    return 'Удалить «$path»?';
  }

  @override
  String get noRenders => 'Рендеров пока нет.';

  @override
  String get newRender => 'Новый рендер';

  @override
  String get render => 'Рендер';

  @override
  String get queuing => 'В очередь…';

  @override
  String renderStatusWorker(Object status, Object worker, Object when) {
    return '$status на $worker  ·  $when';
  }

  @override
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get outputName => 'Имя файла';

  @override
  String get resolution => 'Разрешение';

  @override
  String get frameRate => 'FPS';

  @override
  String get addClips => 'Добавьте клипы из списка файлов';

  @override
  String clipsCount(Object count) {
    return 'Клипы ($count)';
  }

  @override
  String browseFolder(Object folder) {
    return 'Папка: $folder';
  }

  @override
  String get manage => 'Управление';

  @override
  String get nothingToManage => 'Нечего управлять.';

  @override
  String get accounts => 'Учётные записи';

  @override
  String get activity => 'Активность';

  @override
  String get renderNodes => 'Узлы рендера';

  @override
  String get newAccount => 'Новая учётная запись';

  @override
  String get name => 'Имя';

  @override
  String get role => 'Роль';

  @override
  String get studentIdOptional => 'ID студента (необязательно)';

  @override
  String get noteOptional => 'Заметка (до 20 символов)';

  @override
  String get resetPassword => 'Сбросить пароль';

  @override
  String resetPasswordTitle(Object username) {
    return 'Сброс пароля: $username';
  }

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get passwordReset => 'Пароль сброшен';

  @override
  String get disabledSuffix => '  (отключён)';

  @override
  String userLine(Object username, Object when) {
    return '@$username  ·  последний вход $when';
  }

  @override
  String get nothingRecorded => 'Записей пока нет.';

  @override
  String get newNode => 'Новый узел';

  @override
  String get nodeName => 'Имя узла';

  @override
  String nodeCreatedTitle(Object name) {
    return 'Узел «$name» создан';
  }

  @override
  String get nodeTokenNote =>
      'Сохраните этот токен, он показывается один раз. Запустите узел командой:';

  @override
  String get noNodes =>
      'Узлов рендера нет. Локальные воркеры на сервере продолжат работу.';

  @override
  String lastSeen(Object when) {
    return 'был в сети $when';
  }

  @override
  String get deleteNode => 'Удалить узел';

  @override
  String deleteNodeBody(Object name) {
    return 'Удалить узел «$name»?';
  }

  @override
  String get settings => 'Настройки';

  @override
  String get language => 'Язык';

  @override
  String get langSystem => 'Системный';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get themeOled => 'OLED';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get serverSection => 'Сервер';

  @override
  String get trustedProxiesHelp =>
      'X-Forwarded-For принимается только с этих адресов. Оставьте пустым, если сервер не за обратным прокси.';

  @override
  String get settingsSaved => 'Настройки сохранены';

  @override
  String get checkUpdates => 'Проверить обновления';

  @override
  String get checking => 'Проверка…';

  @override
  String upToDate(Object version) {
    return 'WFM последней версии (v$version)';
  }

  @override
  String updateAvailable(Object version) {
    return 'Доступно обновление: $version';
  }

  @override
  String get checkFailed => 'Не удалось проверить обновления';

  @override
  String get viewRelease => 'Открыть релиз';

  @override
  String versionLabel(Object version) {
    return 'Версия $version';
  }

  @override
  String get never => 'никогда';

  @override
  String get justNow => 'только что';

  @override
  String minutesAgo(Object count) {
    return '$count мин. назад';
  }

  @override
  String hoursAgo(Object count) {
    return '$count ч. назад';
  }

  @override
  String daysAgo(Object count) {
    return '$count дн. назад';
  }
}
