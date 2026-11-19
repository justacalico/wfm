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
  String get cancel => 'Cealaigh';

  @override
  String get ok => 'Ceart go leor';

  @override
  String get confirm => 'Deimhnigh';

  @override
  String get done => 'Déanta';

  @override
  String get save => 'Sábháil';

  @override
  String get delete => 'Scrios';

  @override
  String get rename => 'Athainmnigh';

  @override
  String get download => 'Íoslódáil';

  @override
  String get create => 'Cruthaigh';

  @override
  String get refresh => 'Athnuaigh';

  @override
  String get uploadingFiles => 'Comhaid á n-uaslódáil';

  @override
  String get upload => 'Uaslódáil';

  @override
  String get enable => 'Cumasaigh';

  @override
  String get disable => 'Díchumasaigh';

  @override
  String get logout => 'Logáil amach';

  @override
  String get welcomeTitle => 'Fáilte go WFM';

  @override
  String get setupSubtitle => 'Cruthaigh an cuntas úinéara chun tosú.';

  @override
  String get yourName => 'D\'ainm';

  @override
  String get username => 'Ainm úsáideora';

  @override
  String get password => 'Pasfhocal';

  @override
  String get creating => 'Á chruthú…';

  @override
  String get createOwner => 'Cruthaigh úinéir';

  @override
  String get signIn => 'Logáil isteach';

  @override
  String get signingIn => 'Ag logáil isteach…';

  @override
  String signInFailed(Object error) {
    return 'Theip ar an logáil isteach: $error';
  }

  @override
  String get trustedProxies => 'Seachfhreastalaithe iontaofa';

  @override
  String get trustedProxiesHint =>
      'Seoltaí IP nó raonta CIDR scartha le camóg, m.sh. 10.0.0.1, 172.16.0.0/12';

  @override
  String get navHome => 'Baile';

  @override
  String get navProjects => 'Tionscadail';

  @override
  String get navManage => 'Bainistigh';

  @override
  String get navSettings => 'Socruithe';

  @override
  String greeting(Object name) {
    return 'Dia dhuit, $name';
  }

  @override
  String get cardProjects => 'Tionscadail';

  @override
  String get cardProjectsSub => 'Oscail do thionscadail scannáin';

  @override
  String get cardManage => 'Bainistigh';

  @override
  String get cardManageSub => 'Cuntais agus ceadanna';

  @override
  String get cardSettings => 'Socruithe';

  @override
  String get cardSettingsSub => 'Téama agus teanga';

  @override
  String get projects => 'Tionscadail';

  @override
  String get newProject => 'Tionscadal nua';

  @override
  String get projectName => 'Ainm an tionscadail';

  @override
  String get noProjects =>
      'Níl aon tionscadal ann fós. Cruthaigh ceann chun tosú.';

  @override
  String createdAgo(Object when) {
    return 'Cruthaithe $when';
  }

  @override
  String get openInFilmcraft => 'Oscail';

  @override
  String get renameProject => 'Athainmnigh tionscadal';

  @override
  String get displayName => 'Ainm taispeána';

  @override
  String get deleteProject => 'Scrios tionscadal';

  @override
  String deleteAccountBody(Object name) {
    return 'Scrios \"$name\"? Ní féidir é seo a chealú.';
  }

  @override
  String deleteProjectBody(Object name) {
    return 'Scrios \"$name\" agus a mheáin go léir? Ní féidir é seo a chealú.';
  }

  @override
  String get newGroup => 'Grúpa nua';

  @override
  String get groupName => 'Ainm an ghrúpa';

  @override
  String get ungrouped => 'Gan ghrúpa';

  @override
  String get noGroup => 'Gan ghrúpa';

  @override
  String get moveToGroup => 'Bog go grúpa';

  @override
  String get renameGroup => 'Athainmnigh an grúpa';

  @override
  String deleteGroupBody(Object name) {
    return 'Scrios an grúpa \"$name\"? Coinnítear na tionscadail gan ghrúpa.';
  }

  @override
  String get editTags => 'Cuir clibeanna in eagar';

  @override
  String get tagsHint => 'Clibeanna, scartha le camóga';

  @override
  String get noMatchingProjects => 'Níl aon tionscadal leis an gclib seo.';

  @override
  String get files => 'Comhaid';

  @override
  String get renders => 'Rindreálacha';

  @override
  String get emptyFolder => 'Fillteán folamh';

  @override
  String get newFolder => 'Fillteán nua';

  @override
  String get folderName => 'Ainm an fhillteáin';

  @override
  String get newName => 'Ainm nua';

  @override
  String deleteFileBody(Object path) {
    return 'Scrios \"$path\"?';
  }

  @override
  String get noRenders => 'Níl aon rindreáil ann fós.';

  @override
  String get newRender => 'Rindreáil nua';

  @override
  String get render => 'Rindreáil';

  @override
  String get queuing => 'Á chur sa scuaine…';

  @override
  String renderStatusWorker(Object status, Object worker, Object when) {
    return '$status ar $worker  ·  $when';
  }

  @override
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get outputName => 'Ainm aschuir';

  @override
  String get resolution => 'Taifeach';

  @override
  String get addClips => 'Cuir gearrthóga leis ón mbrabhsálaí';

  @override
  String clipsCount(Object count) {
    return 'Gearrthóga ($count)';
  }

  @override
  String browseFolder(Object folder) {
    return 'Brabhsáil: $folder';
  }

  @override
  String get manage => 'Bainistigh';

  @override
  String get nothingToManage => 'Níl aon rud le bainistiú.';

  @override
  String get accounts => 'Cuntais';

  @override
  String get activity => 'Gníomhaíocht';

  @override
  String get renderNodes => 'Nóid rindreála';

  @override
  String get newAccount => 'Cuntas nua';

  @override
  String get editAccount => 'Cuir an cuntas in eagar';

  @override
  String get name => 'Ainm';

  @override
  String get role => 'Ról';

  @override
  String get studentIdOptional => 'ID mac léinn (roghnach)';

  @override
  String get noteOptional => 'Nóta (20 carachtar ar a mhéad)';

  @override
  String get resetPassword => 'Athshocraigh pasfhocal';

  @override
  String resetPasswordTitle(Object username) {
    return 'Athshocraigh pasfhocal: $username';
  }

  @override
  String get newPassword => 'Pasfhocal nua';

  @override
  String get passwordReset => 'Pasfhocal athshocraithe';

  @override
  String get disabledSuffix => '  (díchumasaithe)';

  @override
  String userLine(Object username, Object when) {
    return '@$username  ·  logáil isteach dheireanach $when';
  }

  @override
  String get gridView => 'Amharc eangaí';

  @override
  String get searchProjects => 'Cuardaigh tionscadail';

  @override
  String get sortProjects => 'Sórtáil tionscadail';

  @override
  String get sortCreated => 'Dáta cruthaithe';

  @override
  String get sortActivity => 'Gníomhaíocht dheireanach';

  @override
  String get pinProject => 'Greamaigh tionscadal';

  @override
  String get unpinProject => 'Díghreamaigh tionscadal';

  @override
  String get listView => 'Amharc liosta';

  @override
  String get noAccounts => 'Níl aon chuntas ann fós.';

  @override
  String get nothingRecorded => 'Níl aon taifead ann fós.';

  @override
  String get newNode => 'Nód nua';

  @override
  String get nodeName => 'Ainm an nóid';

  @override
  String nodeCreatedTitle(Object name) {
    return 'Cruthaíodh an nód \"$name\"';
  }

  @override
  String get nodeTokenNote =>
      'Sábháil an tóchamharc seo, ní thaispeánfar é ach uair amháin. Toscaigh an nód le:';

  @override
  String get noNodes =>
      'Níl aon nód rindreála ann. Rithfidh oibrithe áitiúla ar an bhfreastalaí i gcónaí.';

  @override
  String lastSeen(Object when) {
    return 'feicthe $when ó shin';
  }

  @override
  String get deleteNode => 'Scrios nód';

  @override
  String deleteNodeBody(Object name) {
    return 'Scrios an nód \"$name\"?';
  }

  @override
  String get settings => 'Socruithe';

  @override
  String get language => 'Teanga';

  @override
  String get langSystem => 'Córas';

  @override
  String get theme => 'Téama';

  @override
  String get themeSystem => 'Córas';

  @override
  String get themeLight => 'Solas';

  @override
  String get themeDark => 'Dorcha';

  @override
  String get themeOled => 'OLED';

  @override
  String get changePassword => 'Athraigh pasfhocal';

  @override
  String get currentPassword => 'Pasfhocal reatha';

  @override
  String get passwordChanged => 'Athraíodh an pasfhocal';

  @override
  String get serverSection => 'Freastalaí';

  @override
  String get trustedProxiesHelp =>
      'Ní chuirtear muinín in X-Forwarded-For ach ó na seoltaí seo. Fág folamh é mura bhfuil an freastalaí taobh thiar de sheachfhreastalaí.';

  @override
  String get settingsSaved => 'Socruithe sábháilte';

  @override
  String get checkUpdates => 'Seiceáil le haghaidh nuashonruithe';

  @override
  String get checking => 'Ag seiceáil…';

  @override
  String upToDate(Object version) {
    return 'Tá WFM cothrom le dáta (v$version)';
  }

  @override
  String updateAvailable(Object version) {
    return 'Nuashonrú ar fáil: $version';
  }

  @override
  String get checkFailed => 'Theip ar an seiceáil nuashonrúcháin';

  @override
  String get viewRelease => 'Amharc ar an eisiúint';

  @override
  String versionLabel(Object version) {
    return 'Leagan $version';
  }

  @override
  String get never => 'riamh';

  @override
  String get justNow => 'anois díreach';

  @override
  String minutesAgo(Object count) {
    return '$count nóiméad ó shin';
  }

  @override
  String hoursAgo(Object count) {
    return '$count uair ó shin';
  }

  @override
  String daysAgo(Object count) {
    return '$count lá ó shin';
  }

  @override
  String get renderMode => 'Rindreáil ar';

  @override
  String get renderOnDevice => 'An gléas seo';

  @override
  String get renderOnServer => 'Freastalaí';

  @override
  String get sequence => 'Seicheamh';

  @override
  String get matchSource => 'Meaitseáil leis an bhfoinse';

  @override
  String get outputFormat => 'Formáid';

  @override
  String get exportRange => 'Raon';

  @override
  String get rangeEntire => 'An seicheamh ar fad';

  @override
  String get rangeInOut => 'Pointí isteach/amach';

  @override
  String get rangeWorkArea => 'Limistéar oibre';

  @override
  String get rangeCustom => 'Saincheaptha';

  @override
  String get rangeStart => 'Tús (soicindí)';

  @override
  String get rangeEnd => 'Deireadh (soicindí)';

  @override
  String get rangeNeedTimes =>
      'Cuir tús agus deireadh an raoin i soicindí isteach';

  @override
  String get renderAudio => 'Fuaim';

  @override
  String get preset => 'Réamhshocrú (roghnach)';

  @override
  String get advancedOptions => 'Roghanna casta';

  @override
  String get openInFilmcraftFirst =>
      'Oscail an tionscadal in FilmCraft uair amháin sular féidir é a rindreáil.';

  @override
  String get noSequences =>
      'Níl aon seicheamh le heaspórtáil sa tionscadal seo.';

  @override
  String get quality => 'Cáilíocht (0-100)';

  @override
  String get bitrateKbps => 'Bítráta (kbps)';

  @override
  String get crf => 'CRF';

  @override
  String get bitrateMode => 'Mód bítráta';

  @override
  String get audioCodec => 'Codec fuaime';

  @override
  String get flacLevel => 'Leibhéal FLAC';

  @override
  String get hardwareEncoding => 'Ionchódú crua-earraí';

  @override
  String get renderScale => 'Scála';

  @override
  String get loudnessLufs => 'Airde fuaime (LUFS)';

  @override
  String get h264Profile => 'Próifíl H.264';

  @override
  String get h264IntraOnly => 'H.264 intra amháin';

  @override
  String get proresProfile => 'Próifíl ProRes';

  @override
  String get dnxProfile => 'Próifíl DNx';

  @override
  String get apvProfile => 'Próifíl APV';

  @override
  String get mxfVideoCodec => 'Codec físe MXF';

  @override
  String get burnCaptions => 'Dóigh fotheideail';

  @override
  String get alphaChannel => 'Cainéal alfa';

  @override
  String get exrCompression => 'Comhbhrú EXR';

  @override
  String get captionSidecar => 'Comhad fotheideal ar leith';

  @override
  String get extraParams => 'Paraiméadair bhreise easpórtála (JSON)';

  @override
  String get invalidJson => 'JSON neamhbhailí';

  @override
  String get defaultOption => 'Réamhshocrú';

  @override
  String serverUnreachable(Object error) {
    return 'Ní féidir teagmháil a dhéanamh leis an bhfreastalaí: $error';
  }

  @override
  String get retry => 'Bain triail eile as';

  @override
  String get license => 'Ceadúnas';

  @override
  String get licenseAgpl => 'Faoi cheadúnas AGPL-3.0';

  @override
  String get viewOnGitlab => 'Féach ar GitLab';

  @override
  String get loadMore => 'Lódáil níos mó';

  @override
  String deleteRenderBody(Object name) {
    return 'Scrios taifead rindreála “$name”? Fanfaidh na comhaid easpórtáilte sa tionscadal.';
  }

  @override
  String get sessions => 'Seisiúin';

  @override
  String get currentSession => 'An seisiún seo';

  @override
  String get revoke => 'Cúlghairm';

  @override
  String get revokeSessionBody => 'Logáil amach an seisiún seo?';

  @override
  String sessionLastSeen(Object time) {
    return 'Feicthe go déanaí $time';
  }
}
