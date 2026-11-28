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
  String get fileExists => 'Tá comhad leis an ainm sin ann cheana.';

  @override
  String get extensionLocked =>
      'Bhrisfeadh athrú ar an iarmhír an comhad, mar sin tá an gníomh seo blocáilte.';

  @override
  String get renameFailed => 'Níorbh fhéidir an comhad a athainmniú.';

  @override
  String get download => 'Íoslódáil';

  @override
  String get close => 'Dún';

  @override
  String get playInBrowser => 'Seinm sa bhrabhsálaí';

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
  String get projects => 'Tionscadail';

  @override
  String get newProject => 'Tionscadal nua';

  @override
  String get projectName => 'Ainm an tionscadail';

  @override
  String get noProjects =>
      'Níl aon tionscadal ann fós. Cruthaigh ceann chun tosú.';

  @override
  String editedAgo(Object when) {
    return 'Curtha in eagar $when';
  }

  @override
  String get editInFilmcraft => 'Cuir in eagar';

  @override
  String get openScript => 'Scríobh script';

  @override
  String get openBoards => 'Pleanáil an scéalchláir';

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
  String get back => 'Ar ais';

  @override
  String get addToFolder => 'Cuir le fillteán';

  @override
  String get noFolder => 'Gan fhillteán';

  @override
  String get renameFolder => 'Athainmnigh an fillteán';

  @override
  String deleteFolderBody(Object name) {
    return 'Scrios an fillteán \"$name\"? Coinnítear na tionscadail agus bogtar iad amach.';
  }

  @override
  String get noMatchingProjects =>
      'Níl aon tionscadal a mheaitseálann an cuardach.';

  @override
  String get files => 'Comhaid';

  @override
  String get renders => 'Rindreálacha';

  @override
  String get emptyFolder => 'Fillteán folamh';

  @override
  String get emptyFolderUpload =>
      'Fillteán folamh. Brúigh Uaslódáil chun comhaid a chur leis.';

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
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get renderAlreadyActive =>
      'Tá rindreáil ar siúl don tionscadal seo cheana féin.';

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
  String get classes => 'Ranganna';

  @override
  String get schoolClass => 'Rang';

  @override
  String get newClass => 'Rang nua';

  @override
  String get className => 'Ainm an ranga';

  @override
  String get renameClass => 'Athainmnigh an rang';

  @override
  String get noClasses => 'Níl aon rang fós';

  @override
  String get unmanagedClass => 'Gan bhainistiú';

  @override
  String memberCount(Object count) {
    return '$count ball';
  }

  @override
  String get moveToClass => 'Bog go rang';

  @override
  String deleteClassBody(Object name) {
    return 'Scrios an rang \"$name\"? Bogfar a bhaill go Gan bhainistiú.';
  }

  @override
  String get add => 'Cuir leis';

  @override
  String get remove => 'Bain';

  @override
  String get coTeachers => 'Comh-mhúinteoirí';

  @override
  String coTeacherCount(Object count) {
    return '$count chomh-mhúinteoir';
  }

  @override
  String get addCoTeacher => 'Cuir comh-mhúinteoir leis';

  @override
  String get coTeacherNew => 'Cruthaigh cuntas nua';

  @override
  String removeCoTeacherBody(Object name) {
    return 'Bain $name mar chomh-mhúinteoir? Fanann a gcuntas ann.';
  }

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
  String get enforceHttps => 'Éiligh HTTPS';

  @override
  String get enforceHttpsHint =>
      'Atreoraítear gach trácht HTTP chuig HTTPS. Má tá sé taobh thiar de sheachfhreastalaí, cuir leis na seachfhreastalaithe iontaofa ar dtús.';

  @override
  String get enforceHttpsLocked =>
      'Faoi ghlas ag cumraíocht an fhreastalaí (WFM_ENFORCE_HTTPS).';

  @override
  String get backupLimit =>
      'Uaslíon cúltacaí do gach tionscadal (5 de réir réamhshocraithe)';

  @override
  String get createBackup => 'Cruthaigh cúltaca';

  @override
  String get backupCreated => 'Cúltaca cruthaithe';

  @override
  String get backupNothingToSave => 'Níl aon rud le cúltaca fós.';

  @override
  String backupLimitReached(Object limit) {
    return 'Sroicheadh teorainn na gcúltacaí ($limit). Forás an cúltaca is sine?';
  }

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
  String weeksAgo(Object count) {
    return '$count seacht. ó shin';
  }

  @override
  String monthsAgo(Object count) {
    return '$count mhí ó shin';
  }

  @override
  String yearsAgo(Object count) {
    return '$count bl. ó shin';
  }

  @override
  String get renderMode => 'Rindreáil ar';

  @override
  String get renderOnDevice => 'An gléas seo';

  @override
  String get renderOnServer => 'Freastalaí';

  @override
  String get renderNameTaken => 'Tá an t-ainm in úsáid cheana';

  @override
  String renderNameTakenBody(Object name) {
    return 'Tá rindreáil darb ainm \"$name\" ann cheana. Scriosfaidh forscríobh an rindreáil shean.';
  }

  @override
  String get overwrite => 'Forscríobh';

  @override
  String useOtherName(Object name) {
    return 'Úsáid \"$name\"';
  }

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

  @override
  String get mcp => 'Cúntóir AI';

  @override
  String get mcpSubtitle => 'Lig do ghníomhaire WFM a rith ar do shon';

  @override
  String get mcpHint =>
      'Dírigh gníomhaire AI ar an bhfreastalaí seo agus is féidir leis tionscadail a chruthú, físeáin a uaslódáil agus amlínte a chur in eagar ar do shon. Ní shuiteáiltear aon rud ar do ghléas; nascann an gníomhaire thar an líonra le comhartha a chruthaíonn tú anseo.';

  @override
  String get mcpUrl => 'URL an fhreastalaí';

  @override
  String get mcpTokens => 'Comharthaí gníomhaire';

  @override
  String get mcpTokensHint =>
      'Oibríonn gach comhartha mar phasfhocal do ghníomhaire amháin. Is féidir é a chúlghairm am ar bith.';

  @override
  String get mcpEmpty =>
      'Níl aon chomhartha go fóill. Cruthaigh ceann chun gníomhaire a ligean isteach.';

  @override
  String get mcpNew => 'Comhartha nua';

  @override
  String get mcpName => 'Ainm an chomhartha';

  @override
  String get mcpNameHint => 'm.sh. Claude deisce';

  @override
  String get mcpReady => 'Comhartha réidh';

  @override
  String get mcpOnce =>
      'Ní thaispeánfar an comhartha ach uair amháin. Cóipeáil an leid nó an cumraíocht thíos isteach i do ghníomhaire.';

  @override
  String get mcpPrompt => 'Leid le greamú';

  @override
  String get mcpConfig => 'Cumraíocht le greamú';

  @override
  String get mcpRevokeBody =>
      'Caillfidh an gníomhaire a úsáideann an comhartha seo rochtain láithreach. Cúlghairm?';

  @override
  String get readOnly => 'Léamh amháin';

  @override
  String get takeOver => 'Tóg úinéireacht';

  @override
  String takeOverBody(Object name) {
    return 'Tóg úinéireacht $name?';
  }

  @override
  String ownedBy(Object name) {
    return 'le $name';
  }

  @override
  String userProjects(Object name) {
    return 'Tionscadail $name';
  }

  @override
  String get userProjectsEmpty => 'Níl aon tionscadal ann fós.';

  @override
  String get selectFiles => 'Roghnaigh';

  @override
  String get selectAll => 'Roghnaigh go léir';

  @override
  String get moveSelected => 'Bog na roghnaithe';

  @override
  String get deleteSelected => 'Scrios na roghnaithe';

  @override
  String get downloadZip => 'Íoslódáil zip';

  @override
  String get destFolder => 'Fillteán sprice';

  @override
  String selectedCount(Object n) {
    return '$n roghnaithe';
  }

  @override
  String get changePhoto => 'Athraigh grianghraf';

  @override
  String get action => 'Gníomh';

  @override
  String get actor => 'Aisteoir';

  @override
  String get from => 'Ó';

  @override
  String get to => 'Go dtí';

  @override
  String get applyFilters => 'Cuir scagairí i bhfeidhm';

  @override
  String get clearFilters => 'Glan na scagairí';

  @override
  String get chunkSize => 'Méid smutáin uaslódála';

  @override
  String get account => 'Cuntas';

  @override
  String get invite => 'Cuireadh';

  @override
  String get newInvite => 'Cuireadh nua';

  @override
  String get inviteReady => 'Cuireadh réidh';

  @override
  String get inviteUrl => 'Nasc cuiridh';

  @override
  String get inviteCode => 'Cód cuiridh';

  @override
  String get inviteEmail => 'Corp ríomhphoist';

  @override
  String inviteEmailBody(Object url) {
    return 'Tugadh cuireadh duit chuig WFM. Cláraigh anseo: $url';
  }

  @override
  String get copy => 'Cóipeáil';

  @override
  String get copied => 'Cóipeáilte';

  @override
  String get invites => 'Cuirí';

  @override
  String get used => 'Úsáidte';

  @override
  String get expired => 'Imithe in éag';

  @override
  String get pending => 'Ar feitheamh';

  @override
  String get usernameOptional => 'Ainm úsáideora (roghnach)';

  @override
  String get nameOptional => 'Ainm (roghnach)';

  @override
  String get inviteSignup => 'Cruthaigh do chuntas';

  @override
  String get signUp => 'Cláraigh';

  @override
  String get confirmPassword => 'Deimhnigh an pasfhocal';

  @override
  String get passwordsMismatch => 'Ní mheaitseálann na pasfhocail';

  @override
  String get revoked => 'Cúlghlactha';

  @override
  String get share => 'Comhroinn';

  @override
  String get shareProject => 'Comhroinn tionscadal';

  @override
  String get send => 'Seol';

  @override
  String get canView => 'Amharc';

  @override
  String get canEdit => 'Eagarthóireacht';

  @override
  String get accepted => 'Glactha';

  @override
  String get declined => 'Diúltaithe';

  @override
  String get accept => 'Glac';

  @override
  String get decline => 'Diúltaigh';

  @override
  String shareInviteFrom(Object level, Object user) {
    return 'Cuireadh ó $user · $level';
  }

  @override
  String get navShared => 'Roinnte liom';

  @override
  String get pendingInvites => 'Cuirí ar feitheamh';

  @override
  String get sharedProjects => 'Tionscadail roinnte';

  @override
  String get noShares =>
      'Níl aon rud roinnte leat fós. Beidh tionscadail a roinnfidh daoine eile leat le feiceáil anseo.';

  @override
  String get autoShares => 'Uath-roinnt';

  @override
  String get autoSharesHint =>
      'Tugtar cuireadh do na daoine seo chuig gach tionscadal nua a chruthaíonn do mhic léinn.';

  @override
  String get autoShareAdd => 'Cuir uath-roinnt leis';

  @override
  String get quotaMb => 'Cuóta stórála (MB)';

  @override
  String get quotaMbHint => 'Fág folamh le haghaidh gan teorainn';

  @override
  String storageUsed(Object used, Object quota) {
    return '$used as $quota in úsáid';
  }

  @override
  String get navNotifications => 'Fógraí';

  @override
  String get noNotifications => 'Níl aon fhógra go fóil';

  @override
  String get markAllRead => 'Marcáil gach ceann mar léite';

  @override
  String notifShareInvite(Object from, Object project) {
    return 'Thug $from cuireadh duit chuig $project';
  }

  @override
  String notifShareAuto(Object from, Object project) {
    return 'Roinn $from $project leat';
  }

  @override
  String notifShareAccepted(Object from, Object project) {
    return 'Ghlac $from le do chuireadh chuig $project';
  }

  @override
  String notifShareDeclined(Object from, Object project) {
    return 'Dhiúltaigh $from do chuireadh chuig $project';
  }

  @override
  String notifRenderDone(Object name, Object project) {
    return 'Críochnaíodh an rindreáil: $name i $project';
  }

  @override
  String notifRenderFailed(Object name, Object project) {
    return 'Theip ar an rindreáil: $name i $project';
  }

  @override
  String notifNodeOffline(Object name) {
    return 'Chuaigh an nód rindreála $name as líne';
  }

  @override
  String get shareLinks => 'Naisc roinnte';

  @override
  String get createLink => 'Cruthaigh nasc';

  @override
  String get scopeProject => 'An tionscadal ar fad';

  @override
  String get scopeRenders => 'Rindreálacha amháin';

  @override
  String get expiryNever => 'Gan dáta éaga';

  @override
  String get expiryDay => '1 lá';

  @override
  String get expiryWeek => '7 lá';

  @override
  String get expiryMonth => '30 lá';

  @override
  String linkExpires(Object when) {
    return 'Éagann $when';
  }

  @override
  String get linkEmpty => 'Tada le taispeáint';

  @override
  String get linkRendersOnly => 'Rindreálacha amháin';

  @override
  String get duplicate => 'Dúbail';

  @override
  String get saveCopy => 'Sábháil cóip';

  @override
  String get useTemplate => 'Úsáid teimpléad';

  @override
  String get template => 'Teimpléad';

  @override
  String get markTemplate => 'Marcáil mar theimpléad';

  @override
  String get unmarkTemplate => 'Bain an marc teimpléid';

  @override
  String get projectDuplicated => 'Cóip cruthaithe';

  @override
  String get projectGone => 'Níl an tionscadal seo ann a thuilleadh.';

  @override
  String get comments => 'Nótaí tráchta';

  @override
  String get noComments => 'Níl aon nóta tráchta fós';

  @override
  String get writeComment => 'Scríobh nóta tráchta';

  @override
  String get editComment => 'Cuir nóta tráchta in eagar';

  @override
  String get edited => 'curtha in eagar';

  @override
  String get submitForReview => 'Cuir isteach le haghaidh athbhreithnithe';

  @override
  String get withdrawSubmission => 'Tarraing siar an t-aighneacht';

  @override
  String get markReviewed => 'Marcáil mar athbhreithnithe';

  @override
  String get returnToDraft => 'Fill ar dhreacht';

  @override
  String get statusSubmitted => 'Curtha isteach';

  @override
  String get statusReviewed => 'Athbhreithnithe';

  @override
  String notifCoTeacher(Object from, Object name) {
    return 'Chuir $from tú mar chomh-mhúinteoir ar $name';
  }

  @override
  String notifComment(Object from, Object project) {
    return 'Rinne $from tráchtaireacht ar $project';
  }

  @override
  String notifSubmitted(Object from, Object project) {
    return 'Chuir $from $project isteach le haghaidh athbhreithnithe';
  }

  @override
  String notifReviewed(Object from, Object project) {
    return 'Mharcáil $from $project mar athbhreithnithe';
  }

  @override
  String notifReturned(Object from, Object project) {
    return 'Thug $from $project ar ais go dreacht';
  }

  @override
  String get editors => 'Eagarthóirí';

  @override
  String get filmcraftShortcuts => 'Aicearraí FilmCraft';

  @override
  String get scriptcraftShortcuts => 'Aicearraí ScriptCraft';

  @override
  String get deckcraftShortcuts => 'Aicearraí DeckCraft';

  @override
  String get searchShortcuts => 'Cuardaigh gníomhartha';

  @override
  String get pressShortcut => 'Brúigh an aicearra nua';

  @override
  String shortcutConflict(Object action) {
    return 'In úsáid cheana ag $action';
  }

  @override
  String get clearShortcut => 'Glan';

  @override
  String get unbound => 'Gan cheangal';

  @override
  String get resetToDefault => 'Athshocraigh go réamhshocraithe';

  @override
  String get resetAllShortcuts => 'Athshocraigh gach aicearra';

  @override
  String get resetAllShortcutsBody =>
      'Gach aicearra a chur ar ais go dtí a réamhshocrú?';

  @override
  String unsupportedUploadType(Object names) {
    return 'Cineál comhaid nach dtacaítear leis: $names';
  }

  @override
  String get assign => 'Sanntaigh';

  @override
  String get assignProject => 'Sanntaigh do dhaltaí';

  @override
  String get assignment => 'Tasc';

  @override
  String get dueDate => 'Dáta dílis';

  @override
  String get noDueDate => 'Gan dháta dílis';

  @override
  String get allowWithdraw => 'Ceadaigh ais-tharraingt';

  @override
  String get maxSubmissions => 'Uaslíon iarrachtaí (0 = gan teorainn)';

  @override
  String get hiddenFromStudents => 'I bhfolach ar dhaltaí';

  @override
  String get lockedForStudents => 'Faoi ghlas';

  @override
  String get submissions => 'Aighneachtaí';

  @override
  String attemptsUsed(Object max, Object used) {
    return '$used as $max iarracht';
  }

  @override
  String get overdue => 'Thar téarma';

  @override
  String get unassign => 'Bain an tasc';

  @override
  String get unassignBody =>
      'Bain an tasc seo? Fanfaidh cóipeanna na ndaltaí mar ghnáththionscadail.';

  @override
  String get noStudents => 'Níl daltaí le sannadh';

  @override
  String get lateSubmission => 'déanach';

  @override
  String get assignedToYou => 'Sannta duit';

  @override
  String get dueNow => 'dlite anois';

  @override
  String inMinutes(Object count) {
    return 'in $count nóiméad';
  }

  @override
  String inHours(Object count) {
    return 'in $count uair';
  }

  @override
  String inDays(Object count) {
    return 'in $count lá';
  }

  @override
  String get notStarted => 'Gan tosú';

  @override
  String get inProgress => 'Ar siúl';

  @override
  String inviteUsedBy(Object name) {
    return 'Úsáidte ag $name';
  }

  @override
  String get wipeAudit => 'Glan na logaí';

  @override
  String get wipeAuditBody =>
      'Scrios gach iontráil sa loga gníomhaíochta seo? Ní féidir é seo a chur ar ais.';

  @override
  String get nodeSetupHint =>
      'Suiteáil WFM ar mheaisín eile, cruthaigh nód anseo, agus rith an t-ordú a thaispeántar. Déanann an nód ainmniú ar an bhfreastalaí seo le haghaidh jabanna rindreála.';

  @override
  String get nodeGuide => 'Treoir shuiteála';

  @override
  String get storage => 'Stóráil';

  @override
  String get storageMedia => 'Stóráil meán';

  @override
  String get storageDatabase => 'Bunachar sonraí';

  @override
  String get storageNoUsers => 'Níl aon duine ag úsáid stórála go fóil.';

  @override
  String get storageResync => 'Athshioncrónaigh nóid';

  @override
  String storageResyncDone(Object checked, Object copied) {
    return 'Rinneadh $checked réad a sheiceáil, $copied a chóipeáil.';
  }

  @override
  String get openSubmissions => 'Oscail aighneachtaí';

  @override
  String get closeSubmissions => 'Dún aighneachtaí';

  @override
  String submitConfirmBody(Object name) {
    return 'Cuir $name isteach le hathbhreithniú?';
  }

  @override
  String get reply => 'Freagair';

  @override
  String replyingTo(Object name) {
    return 'Ag freagairt do $name';
  }

  @override
  String get writeReply => 'Scríobh freagra';

  @override
  String notifReply(Object from, Object project) {
    return 'D\'fhreagair $from thú i $project';
  }

  @override
  String get recentProjects => 'Tionscadail le déanaí';

  @override
  String get latestActivity => 'Gníomhaíocht is déanaí';

  @override
  String get connect => 'Ceangail';

  @override
  String get connecting => 'Ag ceangal…';

  @override
  String get connectSubtitle =>
      'Cuir isteach seoladh fhreastalaí WFM do scoile.';

  @override
  String get serverAddress => 'Seoladh an fhreastalaí';

  @override
  String get notAWfmServer =>
      'Níorbh fhéidir freastalaí WFM a bhaint amach ag an seoladh sin.';

  @override
  String get updateRequired => 'Nuashonrú ag teastáil';

  @override
  String updateRequiredBody(Object server, Object app) {
    return 'Tá WFM $server ar an bhfreastalaí ach tá $app ar an aip seo. Nuashonraigh an aip chun leanúint ar aghaidh.';
  }

  @override
  String get downloadUpdate => 'Íoslódáil an nuashonrú';

  @override
  String get checkAgain => 'Seiceáil arís';

  @override
  String get updateStillRequired =>
      'Ní mheaitseálann leagan na haipe leagan an fhreastalaí go fóil.';

  @override
  String get changeServer => 'Athraigh freastalaí';

  @override
  String get editorsInBrowser => 'Oscail eagarthóirí sa bhrabhsálaí';

  @override
  String get editorsInBrowserHint =>
      'Oscail ScriptCraft agus DeckCraft i do bhrabhsálaí réamhshocraithe in ionad fuinneog na haipe.';

  @override
  String get editPreparing => 'Tionscadal á ullmhú…';

  @override
  String editPulling(Object done, Object total) {
    return 'Comhaid an tionscadail á n-íoslódáil ($done as $total)';
  }

  @override
  String get editLockTitle => 'Tá an tionscadal á chur in eagar';

  @override
  String editLockHeld(Object holder) {
    return 'Tá $holder ag cur an tionscadail seo in eagar faoi láthair. Gabháil ceannas ar an eagarthóireacht?';
  }

  @override
  String get editLockLost =>
      'Cailleadh an glas eagarthóireachta. Athoscail an tionscadal chun leanúint leis an sioncronú.';

  @override
  String get editAlreadyOpen =>
      'Tá an tionscadal sin oscailte san eagarthóir cheana.';

  @override
  String get editDeclined => 'Tá an tionscadal faoi ghlas ag eagarthóir eile.';

  @override
  String get editMissing =>
      'Níl an t-eagarthóir dúchais suiteáilte leis an aip seo.';

  @override
  String get autoShareInvites => 'Cuireadh comhroinnte uathoibríoch';

  @override
  String autoShareInviteFrom(Object who, Object level) {
    return 'Ba mhaith le $who a chuid tionscadal nua a chomhroinnt go huathoibríoch leat ($level)';
  }

  @override
  String get activeAutoShares => 'Liostaí comhroinnte uathoibríoch';

  @override
  String autoShareActiveHint(Object who, Object level) {
    return 'Roinntear tionscadail nua le $who agus a gcuid daltaí leat ($level)';
  }

  @override
  String get leaveAutoShare => 'Imigh';

  @override
  String get leaveAutoShareConfirm =>
      'Imigh as an liosta comhroinnte uathoibríoch seo? Stopfar tionscadail nua a roinnt leat.';

  @override
  String get leaveShare => 'Imigh';

  @override
  String get leaveShareConfirm =>
      'Bain an tionscadal comhroinnte seo de do liosta? Cuirfear an t-úinéir ar an eolas.';

  @override
  String get autoSharePending => 'Ar feitheamh';

  @override
  String get autoShareAccepted => 'Glactha';

  @override
  String get autoShareDeclined => 'Diúltaithe';

  @override
  String notifAutoShareInvite(Object from) {
    return 'Ba mhaith le $from a chuid tionscadal a chomhroinnt go huathoibríoch leat';
  }

  @override
  String notifAutoShareAccepted(Object from) {
    return 'Ghlac $from le do chuireadh comhroinnte uathoibríoch';
  }

  @override
  String notifAutoShareDeclined(Object from) {
    return 'Dhiúltaigh $from do chuireadh comhroinnte uathoibríoch';
  }

  @override
  String notifShareLeft(Object from, Object project) {
    return 'D\'fhág $from $project';
  }

  @override
  String get navAnnouncements => 'Fógraí';

  @override
  String get newAnnouncement => 'Fógra nua';

  @override
  String get editAnnouncement => 'Cuir an fógra in eagar';

  @override
  String get deleteAnnouncement => 'Scrios an fógra';

  @override
  String get deleteAnnouncementConfirm =>
      'Scrios an fógra seo agus a chuid tuairimí go léir?';

  @override
  String get announcementTitle => 'Teideal';

  @override
  String get announcementBody => 'Corp an fhógra';

  @override
  String get markdownHint => 'Tacaítear le formáidiú Markdown.';

  @override
  String get allowComments => 'Ceadaigh tuairimí';

  @override
  String get allowReactions => 'Ceadaigh frithghníomhartha';

  @override
  String get noAnnouncements => 'Níl aon fhógra fós.';

  @override
  String get addReaction => 'Cuir frithghníomh leis';

  @override
  String commentCount(Object count) {
    return 'Tuairimí: $count';
  }

  @override
  String get commentsOff => 'Tá tuairimí múchta';

  @override
  String get editedMark => 'curtha in eagar';

  @override
  String get deleteComment => 'Scrios an tuairim';

  @override
  String get deleteCommentConfirm => 'Scrios an tuairim seo?';

  @override
  String get edit => 'Cuir in eagar';

  @override
  String get post => 'Postáil';

  @override
  String notifAnnouncement(Object from, Object name) {
    return 'D\'fhoilsigh $from fógra: $name';
  }

  @override
  String notifAnnComment(Object from, Object name) {
    return 'Rinne $from trácht ar $name';
  }
}
