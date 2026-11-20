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
  String get fileExists => 'Файл с таким именем уже существует.';

  @override
  String get extensionLocked =>
      'Изменение расширения повредит файл, поэтому действие заблокировано.';

  @override
  String get renameFailed => 'Не удалось переименовать файл.';

  @override
  String get download => 'Скачать';

  @override
  String get close => 'Закрыть';

  @override
  String get playInBrowser => 'Открыть в браузере';

  @override
  String get create => 'Создать';

  @override
  String get refresh => 'Обновить';

  @override
  String get uploadingFiles => 'Загрузка файлов';

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
  String get editInFilmcraft => 'Редактировать';

  @override
  String get openScript => 'Писать сценарий';

  @override
  String get openBoards => 'Планировать раскадровку';

  @override
  String get renameProject => 'Переименовать проект';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String get deleteProject => 'Удалить проект';

  @override
  String deleteAccountBody(Object name) {
    return 'Удалить «$name»? Это действие нельзя отменить.';
  }

  @override
  String deleteProjectBody(Object name) {
    return 'Удалить «$name» со всеми медиафайлами? Это действие нельзя отменить.';
  }

  @override
  String get newGroup => 'Новая группа';

  @override
  String get groupName => 'Название группы';

  @override
  String get ungrouped => 'Без группы';

  @override
  String get noGroup => 'Без группы';

  @override
  String get moveToGroup => 'Переместить в группу';

  @override
  String get renameGroup => 'Переименовать группу';

  @override
  String deleteGroupBody(Object name) {
    return 'Удалить группу «$name»? Проекты сохранятся без группы.';
  }

  @override
  String get editTags => 'Изменить теги';

  @override
  String get tagsHint => 'Теги через запятую';

  @override
  String get noMatchingProjects => 'Нет проектов с этим тегом.';

  @override
  String get files => 'Файлы';

  @override
  String get renders => 'Рендеры';

  @override
  String get emptyFolder => 'Пустая папка';

  @override
  String get emptyFolderUpload =>
      'Пустая папка. Нажмите «Загрузить», чтобы добавить файлы.';

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
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get renderAlreadyActive => 'Для этого проекта уже идёт рендер.';

  @override
  String get outputName => 'Имя файла';

  @override
  String get resolution => 'Разрешение';

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
  String get classes => 'Классы';

  @override
  String get schoolClass => 'Класс';

  @override
  String get newClass => 'Новый класс';

  @override
  String get className => 'Название класса';

  @override
  String get renameClass => 'Переименовать класс';

  @override
  String get noClasses => 'Классов пока нет';

  @override
  String get unmanagedClass => 'Без класса';

  @override
  String memberCount(Object count) {
    return '$count участников';
  }

  @override
  String get moveToClass => 'Переместить в класс';

  @override
  String deleteClassBody(Object name) {
    return 'Удалить класс \"$name\"? Участники перейдут в \"Без класса\".';
  }

  @override
  String get activity => 'Активность';

  @override
  String get renderNodes => 'Узлы рендера';

  @override
  String get newAccount => 'Новая учётная запись';

  @override
  String get editAccount => 'Изменить учётную запись';

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
  String get gridView => 'Сетка';

  @override
  String get searchProjects => 'Поиск проектов';

  @override
  String get sortProjects => 'Сортировка проектов';

  @override
  String get sortCreated => 'Дата создания';

  @override
  String get sortActivity => 'Последняя активность';

  @override
  String get pinProject => 'Закрепить проект';

  @override
  String get unpinProject => 'Открепить проект';

  @override
  String get listView => 'Список';

  @override
  String get noAccounts => 'Аккаунтов пока нет.';

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

  @override
  String weeksAgo(Object count) {
    return '$count нед. назад';
  }

  @override
  String monthsAgo(Object count) {
    return '$count мес. назад';
  }

  @override
  String yearsAgo(Object count) {
    return '$count г. назад';
  }

  @override
  String get renderMode => 'Где рендерить';

  @override
  String get renderOnDevice => 'Это устройство';

  @override
  String get renderOnServer => 'Сервер';

  @override
  String get sequence => 'Секвенция';

  @override
  String get matchSource => 'Как в исходнике';

  @override
  String get outputFormat => 'Формат';

  @override
  String get exportRange => 'Диапазон';

  @override
  String get rangeEntire => 'Вся секвенция';

  @override
  String get rangeInOut => 'Точки входа/выхода';

  @override
  String get rangeWorkArea => 'Рабочая область';

  @override
  String get rangeCustom => 'Свой диапазон';

  @override
  String get rangeStart => 'Начало (сек)';

  @override
  String get rangeEnd => 'Конец (сек)';

  @override
  String get rangeNeedTimes => 'Укажите начало и конец диапазона в секундах';

  @override
  String get renderAudio => 'Аудио';

  @override
  String get preset => 'Пресет (необязательно)';

  @override
  String get advancedOptions => 'Расширенные настройки';

  @override
  String get openInFilmcraftFirst =>
      'Откройте проект в FilmCraft хотя бы раз, чтобы его можно было отрендерить.';

  @override
  String get noSequences => 'В проекте нет секвенций для экспорта.';

  @override
  String get quality => 'Качество (0-100)';

  @override
  String get bitrateKbps => 'Битрейт (кбит/с)';

  @override
  String get crf => 'CRF';

  @override
  String get bitrateMode => 'Режим битрейта';

  @override
  String get audioCodec => 'Аудиокодек';

  @override
  String get flacLevel => 'Уровень FLAC';

  @override
  String get hardwareEncoding => 'Аппаратное кодирование';

  @override
  String get renderScale => 'Масштаб';

  @override
  String get loudnessLufs => 'Громкость (LUFS)';

  @override
  String get h264Profile => 'Профиль H.264';

  @override
  String get h264IntraOnly => 'H.264 только intra';

  @override
  String get proresProfile => 'Профиль ProRes';

  @override
  String get dnxProfile => 'Профиль DNx';

  @override
  String get apvProfile => 'Профиль APV';

  @override
  String get mxfVideoCodec => 'Видеокодек MXF';

  @override
  String get burnCaptions => 'Вжечь субтитры';

  @override
  String get alphaChannel => 'Альфа-канал';

  @override
  String get exrCompression => 'Сжатие EXR';

  @override
  String get captionSidecar => 'Файл субтитров';

  @override
  String get extraParams => 'Доп. параметры экспорта (JSON)';

  @override
  String get invalidJson => 'Неверный JSON';

  @override
  String get defaultOption => 'По умолчанию';

  @override
  String get serverUrl => ' ';

  @override
  String get connect => '';

  @override
  String get connecting => '…';

  @override
  String finishSetupInBrowser(String url) {
    return '    .    : $url.';
  }

  @override
  String serverUnreachable(Object error) {
    return 'Не удаётся связаться с сервером: $error';
  }

  @override
  String get retry => 'Повторить';

  @override
  String get license => '';

  @override
  String get licenseAgpl => ' AGPL-3.0';

  @override
  String get viewOnGitlab => '  GitLab';

  @override
  String get loadMore => 'Загрузить ещё';

  @override
  String deleteRenderBody(Object name) {
    return 'Удалить запись рендера «$name»? Экспортированные файлы останутся в проекте.';
  }

  @override
  String get sessions => 'Сеансы';

  @override
  String get currentSession => 'Этот сеанс';

  @override
  String get revoke => 'Отозвать';

  @override
  String get revokeSessionBody => 'Завершить этот сеанс?';

  @override
  String sessionLastSeen(Object time) {
    return 'Активность $time';
  }

  @override
  String get readOnly => 'Только чтение';

  @override
  String get takeOver => 'Стать владельцем';

  @override
  String takeOverBody(Object name) {
    return 'Стать владельцем $name?';
  }

  @override
  String ownedBy(Object name) {
    return 'владелец $name';
  }

  @override
  String userProjects(Object name) {
    return 'Проекты: $name';
  }

  @override
  String get userProjectsEmpty => 'Проектов пока нет.';

  @override
  String get selectFiles => 'Выбрать';

  @override
  String get selectAll => 'Выбрать все';

  @override
  String get moveSelected => 'Переместить выбранное';

  @override
  String get deleteSelected => 'Удалить выбранное';

  @override
  String get downloadZip => 'Скачать zip';

  @override
  String get destFolder => 'Папка назначения';

  @override
  String selectedCount(Object n) {
    return 'Выбрано: $n';
  }

  @override
  String get changePhoto => 'Изменить фото';

  @override
  String get action => 'Действие';

  @override
  String get actor => 'Автор';

  @override
  String get from => 'От';

  @override
  String get to => 'До';

  @override
  String get applyFilters => 'Применить фильтры';

  @override
  String get clearFilters => 'Сбросить фильтры';

  @override
  String get chunkSize => 'Размер части загрузки';

  @override
  String get account => 'Аккаунт';

  @override
  String get invite => 'Приглашение';

  @override
  String get newInvite => 'Новое приглашение';

  @override
  String get inviteReady => 'Приглашение создано';

  @override
  String get inviteUrl => 'Ссылка-приглашение';

  @override
  String get inviteCode => 'Код приглашения';

  @override
  String get inviteEmail => 'Текст письма';

  @override
  String inviteEmailBody(Object url) {
    return 'Вас пригласили в WFM. Зарегистрируйтесь: $url';
  }

  @override
  String get copy => 'Копировать';

  @override
  String get copied => 'Скопировано';

  @override
  String get invites => 'Приглашения';

  @override
  String get used => 'Использовано';

  @override
  String get expired => 'Истекло';

  @override
  String get pending => 'Ожидает';

  @override
  String get usernameOptional => 'Имя пользователя (необязательно)';

  @override
  String get nameOptional => 'Имя (необязательно)';

  @override
  String get inviteSignup => 'Создайте свой аккаунт';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get passwordsMismatch => 'Пароли не совпадают';

  @override
  String get revoked => 'Отозвано';

  @override
  String get share => 'Поделиться';

  @override
  String get shareProject => 'Поделиться проектом';

  @override
  String get send => 'Отправить';

  @override
  String get canView => 'Просмотр';

  @override
  String get canEdit => 'Редактирование';

  @override
  String get accepted => 'Принято';

  @override
  String get declined => 'Отклонено';

  @override
  String get accept => 'Принять';

  @override
  String get decline => 'Отклонить';

  @override
  String shareInviteFrom(Object level, Object user) {
    return 'Приглашение от $user · $level';
  }

  @override
  String get navShared => 'Мне открыли доступ';

  @override
  String get pendingInvites => 'Ожидающие приглашения';

  @override
  String get sharedProjects => 'Общие проекты';

  @override
  String get noShares =>
      'С вами пока ничем не поделились. Проекты, которыми с вами поделятся, появятся здесь.';

  @override
  String get autoShares => 'Автодоступ';

  @override
  String get autoSharesHint =>
      'Эти люди автоматически приглашаются в каждый новый проект ваших учеников.';

  @override
  String get autoShareAdd => 'Добавить';

  @override
  String get quotaMb => 'Квота хранилища (МБ)';

  @override
  String get quotaMbHint => 'Оставьте пустым для безлимита';

  @override
  String storageUsed(Object used, Object quota) {
    return 'Использовано $used из $quota';
  }

  @override
  String get navNotifications => 'Уведомления';

  @override
  String get noNotifications => 'Пока нет уведомлений';

  @override
  String get markAllRead => 'Отметить все прочитанными';

  @override
  String notifShareInvite(Object from, Object project) {
    return '$from пригласил(а) вас в $project';
  }

  @override
  String notifShareAuto(Object from, Object project) {
    return '$from поделился(ась) с вами проектом $project';
  }

  @override
  String notifShareAccepted(Object from, Object project) {
    return '$from принял(а) ваше приглашение в $project';
  }

  @override
  String notifShareDeclined(Object from, Object project) {
    return '$from отклонил(а) ваше приглашение в $project';
  }

  @override
  String notifRenderDone(Object name, Object project) {
    return 'Рендер завершён: $name в $project';
  }

  @override
  String notifRenderFailed(Object name, Object project) {
    return 'Рендер не удался: $name в $project';
  }

  @override
  String notifNodeOffline(Object name) {
    return 'Рендер-узел $name отключился';
  }

  @override
  String get shareLinks => 'Ссылки для просмотра';

  @override
  String get createLink => 'Создать ссылку';

  @override
  String get scopeProject => 'Весь проект';

  @override
  String get scopeRenders => 'Только рендеры';

  @override
  String get expiryNever => 'Без срока';

  @override
  String get expiryDay => '1 день';

  @override
  String get expiryWeek => '7 дней';

  @override
  String get expiryMonth => '30 дней';

  @override
  String linkExpires(Object when) {
    return 'Истекает $when';
  }

  @override
  String get linkEmpty => 'Нечего показать';

  @override
  String get linkRendersOnly => 'Только рендеры';

  @override
  String get duplicate => 'Дублировать';

  @override
  String get saveCopy => 'Сохранить копию';

  @override
  String get useTemplate => 'Использовать шаблон';

  @override
  String get template => 'Шаблон';

  @override
  String get markTemplate => 'Сделать шаблоном';

  @override
  String get unmarkTemplate => 'Убрать шаблон';

  @override
  String get projectDuplicated => 'Копия создана';

  @override
  String get comments => 'Комментарии';

  @override
  String get noComments => 'Пока нет комментариев';

  @override
  String get writeComment => 'Написать комментарий';

  @override
  String get editComment => 'Изменить комментарий';

  @override
  String get edited => 'изменено';

  @override
  String get submitForReview => 'Отправить на проверку';

  @override
  String get withdrawSubmission => 'Отозвать отправку';

  @override
  String get markReviewed => 'Отметить проверенным';

  @override
  String get returnToDraft => 'Вернуть в черновик';

  @override
  String get statusSubmitted => 'Отправлено';

  @override
  String get statusReviewed => 'Проверено';

  @override
  String notifComment(Object from, Object project) {
    return '$from прокомментировал $project';
  }

  @override
  String notifSubmitted(Object from, Object project) {
    return '$from отправил $project на проверку';
  }

  @override
  String notifReviewed(Object from, Object project) {
    return '$from отметил $project проверенным';
  }

  @override
  String notifReturned(Object from, Object project) {
    return '$from вернул $project в черновик';
  }

  @override
  String get editors => 'Редакторы';

  @override
  String get filmcraftShortcuts => 'Горячие клавиши FilmCraft';

  @override
  String get scriptcraftShortcuts => 'Горячие клавиши ScriptCraft';

  @override
  String get searchShortcuts => 'Поиск действий';

  @override
  String get pressShortcut => 'Нажмите новое сочетание';

  @override
  String shortcutConflict(Object action) {
    return 'Уже используется: $action';
  }

  @override
  String get clearShortcut => 'Очистить';

  @override
  String get unbound => 'Не назначено';

  @override
  String get resetToDefault => 'Сбросить на умолчание';

  @override
  String get resetAllShortcuts => 'Сбросить все сочетания';

  @override
  String get resetAllShortcutsBody =>
      'Вернуть все сочетания к значениям по умолчанию?';

  @override
  String unsupportedUploadType(Object names) {
    return 'Тип файла не поддерживается: $names';
  }

  @override
  String get assign => '';

  @override
  String get assignProject => ' ';

  @override
  String get assignment => '';

  @override
  String get dueDate => ' ';

  @override
  String get noDueDate => ' ';

  @override
  String get allowWithdraw => '  ';

  @override
  String get maxSubmissions => '.  (0 =  )';

  @override
  String get hiddenFromStudents => '  ';

  @override
  String get lockedForStudents => '';

  @override
  String get submissions => ' ';

  @override
  String attemptsUsed(Object max, Object used) {
    return '$used  $max ';
  }

  @override
  String get overdue => '';

  @override
  String get unassign => ' ';

  @override
  String get unassignBody => '  ?     .';

  @override
  String get noStudents => '   ';

  @override
  String get lateSubmission => ' ';

  @override
  String get assignedToYou => 'Назначено вам';

  @override
  String get dueNow => 'срок вышел';

  @override
  String inMinutes(Object count) {
    return 'через $count мин.';
  }

  @override
  String inHours(Object count) {
    return 'через $count ч.';
  }

  @override
  String inDays(Object count) {
    return 'через $count дн.';
  }

  @override
  String get notStarted => 'Не начато';

  @override
  String get inProgress => 'В работе';
}
