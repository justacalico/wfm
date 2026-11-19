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
  String get openScript => 'Script';

  @override
  String get openBoards => 'Scéalchlár';

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
  String get serverUrl => 'URL an fhreastalaí';

  @override
  String get connect => 'Ceangail';

  @override
  String get connecting => 'Ag ceangal…';

  @override
  String finishSetupInBrowser(String url) {
    return 'Níl cuntas riarthóra ar an bhfreastalaí seo fós. Críochnaigh an tsocrú sa bhrabhsálaí ag $url.';
  }

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
  String get readOnly => 'Léamh amháin';

  @override
  String get takeOver => 'Tóg seilbh';

  @override
  String takeOverBody(Object name) {
    return 'Tóg úinéireacht $name?';
  }

  @override
  String ownedBy(Object name) {
    return 'le $name';
  }

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
  String get noShares => 'Níl aon rud roinnte leat fós';

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
  String get keyboardShortcuts => 'Aicearraí méarchláir';

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
}
