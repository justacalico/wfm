// coverage:ignore-file
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ga.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_zh.dart';

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
    Locale('en', 'GB'),
    Locale('ga'),
    Locale('ru'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WFM'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @uploadingFiles.
  ///
  /// In en, this message translates to:
  /// **'Uploading files'**
  String get uploadingFiles;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enable;

  /// No description provided for @disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disable;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to WFM'**
  String get welcomeTitle;

  /// No description provided for @setupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create the owner account to get started.'**
  String get setupSubtitle;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @creating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get creating;

  /// No description provided for @createOwner.
  ///
  /// In en, this message translates to:
  /// **'Create owner'**
  String get createOwner;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed: {error}'**
  String signInFailed(Object error);

  /// No description provided for @trustedProxies.
  ///
  /// In en, this message translates to:
  /// **'Trusted proxies'**
  String get trustedProxies;

  /// No description provided for @trustedProxiesHint.
  ///
  /// In en, this message translates to:
  /// **'Comma-separated IPs or CIDR ranges, e.g. 10.0.0.1, 172.16.0.0/12'**
  String get trustedProxiesHint;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get navManage;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String greeting(Object name);

  /// No description provided for @cardProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get cardProjects;

  /// No description provided for @cardProjectsSub.
  ///
  /// In en, this message translates to:
  /// **'Open your film projects'**
  String get cardProjectsSub;

  /// No description provided for @cardManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get cardManage;

  /// No description provided for @cardManageSub.
  ///
  /// In en, this message translates to:
  /// **'Accounts and permissions'**
  String get cardManageSub;

  /// No description provided for @cardSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get cardSettings;

  /// No description provided for @cardSettingsSub.
  ///
  /// In en, this message translates to:
  /// **'Theme and language'**
  String get cardSettingsSub;

  /// No description provided for @projects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projects;

  /// No description provided for @newProject.
  ///
  /// In en, this message translates to:
  /// **'New project'**
  String get newProject;

  /// No description provided for @projectName.
  ///
  /// In en, this message translates to:
  /// **'Project name'**
  String get projectName;

  /// No description provided for @noProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects yet. Create one to get started.'**
  String get noProjects;

  /// No description provided for @createdAgo.
  ///
  /// In en, this message translates to:
  /// **'Created {when}'**
  String createdAgo(Object when);

  /// No description provided for @openInFilmcraft.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get openInFilmcraft;

  /// No description provided for @renameProject.
  ///
  /// In en, this message translates to:
  /// **'Rename project'**
  String get renameProject;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @deleteProject.
  ///
  /// In en, this message translates to:
  /// **'Delete project'**
  String get deleteProject;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteAccountBody(Object name);

  /// No description provided for @deleteProjectBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\" and all of its media? This cannot be undone.'**
  String deleteProjectBody(Object name);

  /// No description provided for @newGroup.
  ///
  /// In en, this message translates to:
  /// **'New group'**
  String get newGroup;

  /// No description provided for @groupName.
  ///
  /// In en, this message translates to:
  /// **'Group name'**
  String get groupName;

  /// No description provided for @ungrouped.
  ///
  /// In en, this message translates to:
  /// **'Ungrouped'**
  String get ungrouped;

  /// No description provided for @noGroup.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get noGroup;

  /// No description provided for @moveToGroup.
  ///
  /// In en, this message translates to:
  /// **'Move to group'**
  String get moveToGroup;

  /// No description provided for @renameGroup.
  ///
  /// In en, this message translates to:
  /// **'Rename group'**
  String get renameGroup;

  /// No description provided for @deleteGroupBody.
  ///
  /// In en, this message translates to:
  /// **'Delete group \"{name}\"? Its projects are kept and become ungrouped.'**
  String deleteGroupBody(Object name);

  /// No description provided for @editTags.
  ///
  /// In en, this message translates to:
  /// **'Edit tags'**
  String get editTags;

  /// No description provided for @tagsHint.
  ///
  /// In en, this message translates to:
  /// **'Tags, comma separated'**
  String get tagsHint;

  /// No description provided for @noMatchingProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects match this tag.'**
  String get noMatchingProjects;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @renders.
  ///
  /// In en, this message translates to:
  /// **'Renders'**
  String get renders;

  /// No description provided for @emptyFolder.
  ///
  /// In en, this message translates to:
  /// **'Empty folder'**
  String get emptyFolder;

  /// No description provided for @newFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get newFolder;

  /// No description provided for @folderName.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderName;

  /// No description provided for @newName.
  ///
  /// In en, this message translates to:
  /// **'New name'**
  String get newName;

  /// No description provided for @deleteFileBody.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{path}\"?'**
  String deleteFileBody(Object path);

  /// No description provided for @noRenders.
  ///
  /// In en, this message translates to:
  /// **'No renders yet.'**
  String get noRenders;

  /// No description provided for @newRender.
  ///
  /// In en, this message translates to:
  /// **'New render'**
  String get newRender;

  /// No description provided for @render.
  ///
  /// In en, this message translates to:
  /// **'Render'**
  String get render;

  /// No description provided for @queuing.
  ///
  /// In en, this message translates to:
  /// **'Queuing…'**
  String get queuing;

  /// No description provided for @renderStatusWorker.
  ///
  /// In en, this message translates to:
  /// **'{status} on {worker}  ·  {when}'**
  String renderStatusWorker(Object status, Object worker, Object when);

  /// No description provided for @renderStatus.
  ///
  /// In en, this message translates to:
  /// **'{status}  ·  {when}'**
  String renderStatus(Object status, Object when);

  /// No description provided for @outputName.
  ///
  /// In en, this message translates to:
  /// **'Output name'**
  String get outputName;

  /// No description provided for @resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get resolution;

  /// No description provided for @addClips.
  ///
  /// In en, this message translates to:
  /// **'Add clips from the browser'**
  String get addClips;

  /// No description provided for @clipsCount.
  ///
  /// In en, this message translates to:
  /// **'Clips ({count})'**
  String clipsCount(Object count);

  /// No description provided for @browseFolder.
  ///
  /// In en, this message translates to:
  /// **'Browse: {folder}'**
  String browseFolder(Object folder);

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @nothingToManage.
  ///
  /// In en, this message translates to:
  /// **'Nothing to manage.'**
  String get nothingToManage;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @renderNodes.
  ///
  /// In en, this message translates to:
  /// **'Render nodes'**
  String get renderNodes;

  /// No description provided for @newAccount.
  ///
  /// In en, this message translates to:
  /// **'New account'**
  String get newAccount;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit account'**
  String get editAccount;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @studentIdOptional.
  ///
  /// In en, this message translates to:
  /// **'Student ID (optional)'**
  String get studentIdOptional;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (max 20 chars)'**
  String get noteOptional;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPassword;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password: {username}'**
  String resetPasswordTitle(Object username);

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordReset.
  ///
  /// In en, this message translates to:
  /// **'Password reset'**
  String get passwordReset;

  /// No description provided for @disabledSuffix.
  ///
  /// In en, this message translates to:
  /// **'  (disabled)'**
  String get disabledSuffix;

  /// No description provided for @userLine.
  ///
  /// In en, this message translates to:
  /// **'@{username}  ·  last login {when}'**
  String userLine(Object username, Object when);

  /// No description provided for @gridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get gridView;

  /// No description provided for @searchProjects.
  ///
  /// In en, this message translates to:
  /// **'Search projects'**
  String get searchProjects;

  /// No description provided for @sortProjects.
  ///
  /// In en, this message translates to:
  /// **'Sort projects'**
  String get sortProjects;

  /// No description provided for @sortCreated.
  ///
  /// In en, this message translates to:
  /// **'Created date'**
  String get sortCreated;

  /// No description provided for @sortActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity'**
  String get sortActivity;

  /// No description provided for @pinProject.
  ///
  /// In en, this message translates to:
  /// **'Pin project'**
  String get pinProject;

  /// No description provided for @unpinProject.
  ///
  /// In en, this message translates to:
  /// **'Unpin project'**
  String get unpinProject;

  /// No description provided for @listView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listView;

  /// No description provided for @noAccounts.
  ///
  /// In en, this message translates to:
  /// **'No accounts'**
  String get noAccounts;

  /// No description provided for @nothingRecorded.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded yet.'**
  String get nothingRecorded;

  /// No description provided for @newNode.
  ///
  /// In en, this message translates to:
  /// **'New node'**
  String get newNode;

  /// No description provided for @nodeName.
  ///
  /// In en, this message translates to:
  /// **'Node name'**
  String get nodeName;

  /// No description provided for @nodeCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Node \"{name}\" created'**
  String nodeCreatedTitle(Object name);

  /// No description provided for @nodeTokenNote.
  ///
  /// In en, this message translates to:
  /// **'Save this token, it is shown once. Start the node with:'**
  String get nodeTokenNote;

  /// No description provided for @noNodes.
  ///
  /// In en, this message translates to:
  /// **'No render nodes. Local workers on the server still run.'**
  String get noNodes;

  /// No description provided for @lastSeen.
  ///
  /// In en, this message translates to:
  /// **'last seen {when}'**
  String lastSeen(Object when);

  /// No description provided for @deleteNode.
  ///
  /// In en, this message translates to:
  /// **'Delete node'**
  String get deleteNode;

  /// No description provided for @deleteNodeBody.
  ///
  /// In en, this message translates to:
  /// **'Delete node \"{name}\"?'**
  String deleteNodeBody(Object name);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

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

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

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

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @serverSection.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get serverSection;

  /// No description provided for @trustedProxiesHelp.
  ///
  /// In en, this message translates to:
  /// **'X-Forwarded-For is only trusted from these addresses. Leave empty unless the server sits behind a reverse proxy.'**
  String get trustedProxiesHelp;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @checking.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checking;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'WFM is up to date (v{version})'**
  String upToDate(Object version);

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'Update available: {version}'**
  String updateAvailable(Object version);

  /// No description provided for @checkFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed'**
  String get checkFailed;

  /// No description provided for @viewRelease.
  ///
  /// In en, this message translates to:
  /// **'View release'**
  String get viewRelease;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(Object version);

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get never;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String minutesAgo(Object count);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String hoursAgo(Object count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String daysAgo(Object count);

  /// No description provided for @renderMode.
  ///
  /// In en, this message translates to:
  /// **'Render on'**
  String get renderMode;

  /// No description provided for @renderOnDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get renderOnDevice;

  /// No description provided for @renderOnServer.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get renderOnServer;

  /// No description provided for @sequence.
  ///
  /// In en, this message translates to:
  /// **'Sequence'**
  String get sequence;

  /// No description provided for @matchSource.
  ///
  /// In en, this message translates to:
  /// **'Match source'**
  String get matchSource;

  /// No description provided for @outputFormat.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get outputFormat;

  /// No description provided for @exportRange.
  ///
  /// In en, this message translates to:
  /// **'Range'**
  String get exportRange;

  /// No description provided for @rangeEntire.
  ///
  /// In en, this message translates to:
  /// **'Entire sequence'**
  String get rangeEntire;

  /// No description provided for @rangeInOut.
  ///
  /// In en, this message translates to:
  /// **'In/out'**
  String get rangeInOut;

  /// No description provided for @rangeWorkArea.
  ///
  /// In en, this message translates to:
  /// **'Work area'**
  String get rangeWorkArea;

  /// No description provided for @rangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get rangeCustom;

  /// No description provided for @rangeStart.
  ///
  /// In en, this message translates to:
  /// **'Start (seconds)'**
  String get rangeStart;

  /// No description provided for @rangeEnd.
  ///
  /// In en, this message translates to:
  /// **'End (seconds)'**
  String get rangeEnd;

  /// No description provided for @rangeNeedTimes.
  ///
  /// In en, this message translates to:
  /// **'Enter the range start and end in seconds'**
  String get rangeNeedTimes;

  /// No description provided for @renderAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get renderAudio;

  /// No description provided for @preset.
  ///
  /// In en, this message translates to:
  /// **'Preset (optional)'**
  String get preset;

  /// No description provided for @advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced options'**
  String get advancedOptions;

  /// No description provided for @openInFilmcraftFirst.
  ///
  /// In en, this message translates to:
  /// **'Open this project in FilmCraft once so it can be rendered.'**
  String get openInFilmcraftFirst;

  /// No description provided for @noSequences.
  ///
  /// In en, this message translates to:
  /// **'This project has no sequences to export.'**
  String get noSequences;

  /// No description provided for @quality.
  ///
  /// In en, this message translates to:
  /// **'Quality (0-100)'**
  String get quality;

  /// No description provided for @bitrateKbps.
  ///
  /// In en, this message translates to:
  /// **'Bitrate (kbps)'**
  String get bitrateKbps;

  /// No description provided for @crf.
  ///
  /// In en, this message translates to:
  /// **'CRF'**
  String get crf;

  /// No description provided for @bitrateMode.
  ///
  /// In en, this message translates to:
  /// **'Bitrate mode'**
  String get bitrateMode;

  /// No description provided for @audioCodec.
  ///
  /// In en, this message translates to:
  /// **'Audio codec'**
  String get audioCodec;

  /// No description provided for @flacLevel.
  ///
  /// In en, this message translates to:
  /// **'FLAC level'**
  String get flacLevel;

  /// No description provided for @hardwareEncoding.
  ///
  /// In en, this message translates to:
  /// **'Hardware encoding'**
  String get hardwareEncoding;

  /// No description provided for @renderScale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get renderScale;

  /// No description provided for @loudnessLufs.
  ///
  /// In en, this message translates to:
  /// **'Loudness (LUFS)'**
  String get loudnessLufs;

  /// No description provided for @h264Profile.
  ///
  /// In en, this message translates to:
  /// **'H.264 profile'**
  String get h264Profile;

  /// No description provided for @h264IntraOnly.
  ///
  /// In en, this message translates to:
  /// **'H.264 intra-only'**
  String get h264IntraOnly;

  /// No description provided for @proresProfile.
  ///
  /// In en, this message translates to:
  /// **'ProRes profile'**
  String get proresProfile;

  /// No description provided for @dnxProfile.
  ///
  /// In en, this message translates to:
  /// **'DNx profile'**
  String get dnxProfile;

  /// No description provided for @apvProfile.
  ///
  /// In en, this message translates to:
  /// **'APV profile'**
  String get apvProfile;

  /// No description provided for @mxfVideoCodec.
  ///
  /// In en, this message translates to:
  /// **'MXF video codec'**
  String get mxfVideoCodec;

  /// No description provided for @burnCaptions.
  ///
  /// In en, this message translates to:
  /// **'Burn captions'**
  String get burnCaptions;

  /// No description provided for @alphaChannel.
  ///
  /// In en, this message translates to:
  /// **'Alpha channel'**
  String get alphaChannel;

  /// No description provided for @exrCompression.
  ///
  /// In en, this message translates to:
  /// **'EXR compression'**
  String get exrCompression;

  /// No description provided for @captionSidecar.
  ///
  /// In en, this message translates to:
  /// **'Caption sidecar'**
  String get captionSidecar;

  /// No description provided for @extraParams.
  ///
  /// In en, this message translates to:
  /// **'Extra export params (JSON)'**
  String get extraParams;

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON'**
  String get invalidJson;

  /// No description provided for @defaultOption.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultOption;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server: {error}'**
  String serverUnreachable(Object error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @licenseAgpl.
  ///
  /// In en, this message translates to:
  /// **'Licensed under AGPL-3.0'**
  String get licenseAgpl;

  /// No description provided for @viewOnGitlab.
  ///
  /// In en, this message translates to:
  /// **'View on GitLab'**
  String get viewOnGitlab;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @deleteRenderBody.
  ///
  /// In en, this message translates to:
  /// **'Delete the \"{name}\" render? Its exported files stay in the project.'**
  String deleteRenderBody(Object name);
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
      <String>['en', 'ga', 'ru', 'zh'].contains(locale.languageCode);

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
    case 'ga':
      return AppLocalizationsGa();
    case 'ru':
      return AppLocalizationsRu();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
