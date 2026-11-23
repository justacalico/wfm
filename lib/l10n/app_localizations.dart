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

  /// No description provided for @fileExists.
  ///
  /// In en, this message translates to:
  /// **'A file with that name already exists.'**
  String get fileExists;

  /// No description provided for @extensionLocked.
  ///
  /// In en, this message translates to:
  /// **'Changing the file extension would break the file, so this action is blocked.'**
  String get extensionLocked;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename the file.'**
  String get renameFailed;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @playInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Play in browser'**
  String get playInBrowser;

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

  /// No description provided for @editedAgo.
  ///
  /// In en, this message translates to:
  /// **'Edited {when}'**
  String editedAgo(Object when);

  /// No description provided for @editInFilmcraft.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editInFilmcraft;

  /// No description provided for @openScript.
  ///
  /// In en, this message translates to:
  /// **'Write script'**
  String get openScript;

  /// No description provided for @openBoards.
  ///
  /// In en, this message translates to:
  /// **'Plan storyboard'**
  String get openBoards;

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

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @addToFolder.
  ///
  /// In en, this message translates to:
  /// **'Add to folder'**
  String get addToFolder;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// No description provided for @renameFolder.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get renameFolder;

  /// No description provided for @deleteFolderBody.
  ///
  /// In en, this message translates to:
  /// **'Delete folder \"{name}\"? Its projects are kept and moved out.'**
  String deleteFolderBody(Object name);

  /// No description provided for @noMatchingProjects.
  ///
  /// In en, this message translates to:
  /// **'No projects match your search.'**
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

  /// No description provided for @emptyFolderUpload.
  ///
  /// In en, this message translates to:
  /// **'Empty folder. Tap Upload to add files.'**
  String get emptyFolderUpload;

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

  /// No description provided for @renderStatus.
  ///
  /// In en, this message translates to:
  /// **'{status}  ·  {when}'**
  String renderStatus(Object status, Object when);

  /// No description provided for @renderAlreadyActive.
  ///
  /// In en, this message translates to:
  /// **'A render is already in progress for this project.'**
  String get renderAlreadyActive;

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

  /// No description provided for @classes.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get classes;

  /// No description provided for @schoolClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get schoolClass;

  /// No description provided for @newClass.
  ///
  /// In en, this message translates to:
  /// **'New class'**
  String get newClass;

  /// No description provided for @className.
  ///
  /// In en, this message translates to:
  /// **'Class name'**
  String get className;

  /// No description provided for @renameClass.
  ///
  /// In en, this message translates to:
  /// **'Rename class'**
  String get renameClass;

  /// No description provided for @noClasses.
  ///
  /// In en, this message translates to:
  /// **'No classes yet'**
  String get noClasses;

  /// No description provided for @unmanagedClass.
  ///
  /// In en, this message translates to:
  /// **'Unmanaged'**
  String get unmanagedClass;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'{count} members'**
  String memberCount(Object count);

  /// No description provided for @moveToClass.
  ///
  /// In en, this message translates to:
  /// **'Move to class'**
  String get moveToClass;

  /// No description provided for @deleteClassBody.
  ///
  /// In en, this message translates to:
  /// **'Delete class \"{name}\"? Its members move to Unmanaged.'**
  String deleteClassBody(Object name);

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @coTeachers.
  ///
  /// In en, this message translates to:
  /// **'Co-teachers'**
  String get coTeachers;

  /// No description provided for @coTeacherCount.
  ///
  /// In en, this message translates to:
  /// **'{count} co-teachers'**
  String coTeacherCount(Object count);

  /// No description provided for @addCoTeacher.
  ///
  /// In en, this message translates to:
  /// **'Add co-teacher'**
  String get addCoTeacher;

  /// No description provided for @coTeacherNew.
  ///
  /// In en, this message translates to:
  /// **'Create a new account'**
  String get coTeacherNew;

  /// No description provided for @removeCoTeacherBody.
  ///
  /// In en, this message translates to:
  /// **'Remove {name} as a co-teacher? Their account stays.'**
  String removeCoTeacherBody(Object name);

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

  /// No description provided for @weeksAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}w ago'**
  String weeksAgo(Object count);

  /// No description provided for @monthsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}mo ago'**
  String monthsAgo(Object count);

  /// No description provided for @yearsAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}y ago'**
  String yearsAgo(Object count);

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

  /// No description provided for @renderNameTaken.
  ///
  /// In en, this message translates to:
  /// **'Name already in use'**
  String get renderNameTaken;

  /// No description provided for @renderNameTakenBody.
  ///
  /// In en, this message translates to:
  /// **'A render named \"{name}\" already exists. Overwriting it will wipe the old render.'**
  String renderNameTakenBody(Object name);

  /// No description provided for @overwrite.
  ///
  /// In en, this message translates to:
  /// **'Overwrite'**
  String get overwrite;

  /// No description provided for @useOtherName.
  ///
  /// In en, this message translates to:
  /// **'Use \"{name}\"'**
  String useOtherName(Object name);

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

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @finishSetupInBrowser.
  ///
  /// In en, this message translates to:
  /// **'This server has no admin account yet. Finish setup in a browser at {url}.'**
  String finishSetupInBrowser(String url);

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

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @currentSession.
  ///
  /// In en, this message translates to:
  /// **'This session'**
  String get currentSession;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @revokeSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Sign out this session?'**
  String get revokeSessionBody;

  /// No description provided for @sessionLastSeen.
  ///
  /// In en, this message translates to:
  /// **'Last seen {time}'**
  String sessionLastSeen(Object time);

  /// No description provided for @mcp.
  ///
  /// In en, this message translates to:
  /// **'AI assistant'**
  String get mcp;

  /// No description provided for @mcpSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Let an agent run WFM for you'**
  String get mcpSubtitle;

  /// No description provided for @mcpHint.
  ///
  /// In en, this message translates to:
  /// **'Point an AI agent at this server and it can create projects, upload footage and edit timelines on your behalf. Nothing installs on your device; the agent connects over the network with a token you create here.'**
  String get mcpHint;

  /// No description provided for @mcpUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get mcpUrl;

  /// No description provided for @mcpTokens.
  ///
  /// In en, this message translates to:
  /// **'Agent tokens'**
  String get mcpTokens;

  /// No description provided for @mcpTokensHint.
  ///
  /// In en, this message translates to:
  /// **'Each token works like a password for one agent. Revoke it at any time.'**
  String get mcpTokensHint;

  /// No description provided for @mcpEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tokens yet. Create one to let an agent in.'**
  String get mcpEmpty;

  /// No description provided for @mcpNew.
  ///
  /// In en, this message translates to:
  /// **'New token'**
  String get mcpNew;

  /// No description provided for @mcpName.
  ///
  /// In en, this message translates to:
  /// **'Token name'**
  String get mcpName;

  /// No description provided for @mcpNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Claude desktop'**
  String get mcpNameHint;

  /// No description provided for @mcpReady.
  ///
  /// In en, this message translates to:
  /// **'Token ready'**
  String get mcpReady;

  /// No description provided for @mcpOnce.
  ///
  /// In en, this message translates to:
  /// **'The token is only shown this once. Copy the prompt or the config below into your agent.'**
  String get mcpOnce;

  /// No description provided for @mcpPrompt.
  ///
  /// In en, this message translates to:
  /// **'Prompt to paste'**
  String get mcpPrompt;

  /// No description provided for @mcpConfig.
  ///
  /// In en, this message translates to:
  /// **'Config to paste'**
  String get mcpConfig;

  /// No description provided for @mcpRevokeBody.
  ///
  /// In en, this message translates to:
  /// **'The agent using this token loses access immediately. Revoke it?'**
  String get mcpRevokeBody;

  /// No description provided for @readOnly.
  ///
  /// In en, this message translates to:
  /// **'Read only'**
  String get readOnly;

  /// No description provided for @takeOver.
  ///
  /// In en, this message translates to:
  /// **'Take ownership'**
  String get takeOver;

  /// No description provided for @takeOverBody.
  ///
  /// In en, this message translates to:
  /// **'Take ownership of {name}?'**
  String takeOverBody(Object name);

  /// No description provided for @ownedBy.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String ownedBy(Object name);

  /// No description provided for @userProjects.
  ///
  /// In en, this message translates to:
  /// **'{name}\'s projects'**
  String userProjects(Object name);

  /// No description provided for @userProjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet.'**
  String get userProjectsEmpty;

  /// No description provided for @selectFiles.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectFiles;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @moveSelected.
  ///
  /// In en, this message translates to:
  /// **'Move selected'**
  String get moveSelected;

  /// No description provided for @deleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Delete selected'**
  String get deleteSelected;

  /// No description provided for @downloadZip.
  ///
  /// In en, this message translates to:
  /// **'Download zip'**
  String get downloadZip;

  /// No description provided for @destFolder.
  ///
  /// In en, this message translates to:
  /// **'Destination folder'**
  String get destFolder;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{n} selected'**
  String selectedCount(Object n);

  /// No description provided for @changePhoto.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get changePhoto;

  /// No description provided for @action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get action;

  /// No description provided for @actor.
  ///
  /// In en, this message translates to:
  /// **'Actor'**
  String get actor;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @chunkSize.
  ///
  /// In en, this message translates to:
  /// **'Upload chunk size'**
  String get chunkSize;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// No description provided for @newInvite.
  ///
  /// In en, this message translates to:
  /// **'New invite'**
  String get newInvite;

  /// No description provided for @inviteReady.
  ///
  /// In en, this message translates to:
  /// **'Invite ready'**
  String get inviteReady;

  /// No description provided for @inviteUrl.
  ///
  /// In en, this message translates to:
  /// **'Invite link'**
  String get inviteUrl;

  /// No description provided for @inviteCode.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get inviteCode;

  /// No description provided for @inviteEmail.
  ///
  /// In en, this message translates to:
  /// **'Email body'**
  String get inviteEmail;

  /// No description provided for @inviteEmailBody.
  ///
  /// In en, this message translates to:
  /// **'You have been invited to WFM. Sign up here: {url}'**
  String inviteEmailBody(Object url);

  /// No description provided for @copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get copied;

  /// No description provided for @invites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get invites;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'Used'**
  String get used;

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @usernameOptional.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get usernameOptional;

  /// No description provided for @nameOptional.
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get nameOptional;

  /// No description provided for @inviteSignup.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get inviteSignup;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @passwordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsMismatch;

  /// No description provided for @revoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get revoked;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareProject.
  ///
  /// In en, this message translates to:
  /// **'Share project'**
  String get shareProject;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @canView.
  ///
  /// In en, this message translates to:
  /// **'Can view'**
  String get canView;

  /// No description provided for @canEdit.
  ///
  /// In en, this message translates to:
  /// **'Can edit'**
  String get canEdit;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @shareInviteFrom.
  ///
  /// In en, this message translates to:
  /// **'Invited by {user} · {level}'**
  String shareInviteFrom(Object level, Object user);

  /// No description provided for @navShared.
  ///
  /// In en, this message translates to:
  /// **'Shared with me'**
  String get navShared;

  /// No description provided for @pendingInvites.
  ///
  /// In en, this message translates to:
  /// **'Pending invites'**
  String get pendingInvites;

  /// No description provided for @sharedProjects.
  ///
  /// In en, this message translates to:
  /// **'Shared projects'**
  String get sharedProjects;

  /// No description provided for @noShares.
  ///
  /// In en, this message translates to:
  /// **'Nothing shared with you yet. Projects others share with you appear here.'**
  String get noShares;

  /// No description provided for @autoShares.
  ///
  /// In en, this message translates to:
  /// **'Auto-share'**
  String get autoShares;

  /// No description provided for @autoSharesHint.
  ///
  /// In en, this message translates to:
  /// **'These people are invited to every new project your students create.'**
  String get autoSharesHint;

  /// No description provided for @autoShareAdd.
  ///
  /// In en, this message translates to:
  /// **'Add auto-share'**
  String get autoShareAdd;

  /// No description provided for @quotaMb.
  ///
  /// In en, this message translates to:
  /// **'Storage quota (MB)'**
  String get quotaMb;

  /// No description provided for @quotaMbHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty for unlimited'**
  String get quotaMbHint;

  /// No description provided for @storageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {quota} used'**
  String storageUsed(Object used, Object quota);

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @notifShareInvite.
  ///
  /// In en, this message translates to:
  /// **'{from} invited you to {project}'**
  String notifShareInvite(Object from, Object project);

  /// No description provided for @notifShareAuto.
  ///
  /// In en, this message translates to:
  /// **'{from} shared {project} with you'**
  String notifShareAuto(Object from, Object project);

  /// No description provided for @notifShareAccepted.
  ///
  /// In en, this message translates to:
  /// **'{from} accepted your invite to {project}'**
  String notifShareAccepted(Object from, Object project);

  /// No description provided for @notifShareDeclined.
  ///
  /// In en, this message translates to:
  /// **'{from} declined your invite to {project}'**
  String notifShareDeclined(Object from, Object project);

  /// No description provided for @notifRenderDone.
  ///
  /// In en, this message translates to:
  /// **'Render finished: {name} in {project}'**
  String notifRenderDone(Object name, Object project);

  /// No description provided for @notifRenderFailed.
  ///
  /// In en, this message translates to:
  /// **'Render failed: {name} in {project}'**
  String notifRenderFailed(Object name, Object project);

  /// No description provided for @notifNodeOffline.
  ///
  /// In en, this message translates to:
  /// **'Render node {name} went offline'**
  String notifNodeOffline(Object name);

  /// No description provided for @shareLinks.
  ///
  /// In en, this message translates to:
  /// **'Share links'**
  String get shareLinks;

  /// No description provided for @createLink.
  ///
  /// In en, this message translates to:
  /// **'Create link'**
  String get createLink;

  /// No description provided for @scopeProject.
  ///
  /// In en, this message translates to:
  /// **'Whole project'**
  String get scopeProject;

  /// No description provided for @scopeRenders.
  ///
  /// In en, this message translates to:
  /// **'Renders only'**
  String get scopeRenders;

  /// No description provided for @expiryNever.
  ///
  /// In en, this message translates to:
  /// **'Never expires'**
  String get expiryNever;

  /// No description provided for @expiryDay.
  ///
  /// In en, this message translates to:
  /// **'1 day'**
  String get expiryDay;

  /// No description provided for @expiryWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get expiryWeek;

  /// No description provided for @expiryMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get expiryMonth;

  /// No description provided for @linkExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {when}'**
  String linkExpires(Object when);

  /// No description provided for @linkEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show'**
  String get linkEmpty;

  /// No description provided for @linkRendersOnly.
  ///
  /// In en, this message translates to:
  /// **'Renders only'**
  String get linkRendersOnly;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @saveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save a copy'**
  String get saveCopy;

  /// No description provided for @useTemplate.
  ///
  /// In en, this message translates to:
  /// **'Use template'**
  String get useTemplate;

  /// No description provided for @template.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get template;

  /// No description provided for @markTemplate.
  ///
  /// In en, this message translates to:
  /// **'Mark as template'**
  String get markTemplate;

  /// No description provided for @unmarkTemplate.
  ///
  /// In en, this message translates to:
  /// **'Unmark template'**
  String get unmarkTemplate;

  /// No description provided for @projectDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Copy created'**
  String get projectDuplicated;

  /// No description provided for @projectGone.
  ///
  /// In en, this message translates to:
  /// **'This project no longer exists.'**
  String get projectGone;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @noComments.
  ///
  /// In en, this message translates to:
  /// **'No comments yet'**
  String get noComments;

  /// No description provided for @writeComment.
  ///
  /// In en, this message translates to:
  /// **'Write a comment'**
  String get writeComment;

  /// No description provided for @editComment.
  ///
  /// In en, this message translates to:
  /// **'Edit comment'**
  String get editComment;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitForReview;

  /// No description provided for @withdrawSubmission.
  ///
  /// In en, this message translates to:
  /// **'Withdraw submission'**
  String get withdrawSubmission;

  /// No description provided for @markReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark reviewed'**
  String get markReviewed;

  /// No description provided for @returnToDraft.
  ///
  /// In en, this message translates to:
  /// **'Return to draft'**
  String get returnToDraft;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// No description provided for @statusReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get statusReviewed;

  /// No description provided for @notifCoTeacher.
  ///
  /// In en, this message translates to:
  /// **'{from} added you as a co-teacher of {name}'**
  String notifCoTeacher(Object from, Object name);

  /// No description provided for @notifComment.
  ///
  /// In en, this message translates to:
  /// **'{from} commented on {project}'**
  String notifComment(Object from, Object project);

  /// No description provided for @notifSubmitted.
  ///
  /// In en, this message translates to:
  /// **'{from} submitted {project} for review'**
  String notifSubmitted(Object from, Object project);

  /// No description provided for @notifReviewed.
  ///
  /// In en, this message translates to:
  /// **'{from} marked {project} reviewed'**
  String notifReviewed(Object from, Object project);

  /// No description provided for @notifReturned.
  ///
  /// In en, this message translates to:
  /// **'{from} returned {project} to draft'**
  String notifReturned(Object from, Object project);

  /// No description provided for @editors.
  ///
  /// In en, this message translates to:
  /// **'Editors'**
  String get editors;

  /// No description provided for @filmcraftShortcuts.
  ///
  /// In en, this message translates to:
  /// **'FilmCraft shortcuts'**
  String get filmcraftShortcuts;

  /// No description provided for @scriptcraftShortcuts.
  ///
  /// In en, this message translates to:
  /// **'ScriptCraft shortcuts'**
  String get scriptcraftShortcuts;

  /// No description provided for @deckcraftShortcuts.
  ///
  /// In en, this message translates to:
  /// **'DeckCraft shortcuts'**
  String get deckcraftShortcuts;

  /// No description provided for @searchShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Search actions'**
  String get searchShortcuts;

  /// No description provided for @pressShortcut.
  ///
  /// In en, this message translates to:
  /// **'Press the new shortcut'**
  String get pressShortcut;

  /// No description provided for @shortcutConflict.
  ///
  /// In en, this message translates to:
  /// **'Already used by {action}'**
  String shortcutConflict(Object action);

  /// No description provided for @clearShortcut.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearShortcut;

  /// No description provided for @unbound.
  ///
  /// In en, this message translates to:
  /// **'Unbound'**
  String get unbound;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get resetToDefault;

  /// No description provided for @resetAllShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Reset all shortcuts'**
  String get resetAllShortcuts;

  /// No description provided for @resetAllShortcutsBody.
  ///
  /// In en, this message translates to:
  /// **'Restore every shortcut to its default?'**
  String get resetAllShortcutsBody;

  /// No description provided for @unsupportedUploadType.
  ///
  /// In en, this message translates to:
  /// **'File type isn\'t allowed: {names}'**
  String unsupportedUploadType(Object names);

  /// No description provided for @assign.
  ///
  /// In en, this message translates to:
  /// **'Assign'**
  String get assign;

  /// No description provided for @assignProject.
  ///
  /// In en, this message translates to:
  /// **'Assign to students'**
  String get assignProject;

  /// No description provided for @assignment.
  ///
  /// In en, this message translates to:
  /// **'Assignment'**
  String get assignment;

  /// No description provided for @dueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get dueDate;

  /// No description provided for @noDueDate.
  ///
  /// In en, this message translates to:
  /// **'No due date'**
  String get noDueDate;

  /// No description provided for @allowWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Allow unsubmission'**
  String get allowWithdraw;

  /// No description provided for @maxSubmissions.
  ///
  /// In en, this message translates to:
  /// **'Max submissions (0 = unlimited)'**
  String get maxSubmissions;

  /// No description provided for @hiddenFromStudents.
  ///
  /// In en, this message translates to:
  /// **'Hidden from students'**
  String get hiddenFromStudents;

  /// No description provided for @lockedForStudents.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockedForStudents;

  /// No description provided for @submissions.
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get submissions;

  /// No description provided for @attemptsUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {max} attempts'**
  String attemptsUsed(Object max, Object used);

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @unassign.
  ///
  /// In en, this message translates to:
  /// **'Remove assignment'**
  String get unassign;

  /// No description provided for @unassignBody.
  ///
  /// In en, this message translates to:
  /// **'Remove this assignment? Student copies stay as ordinary projects.'**
  String get unassignBody;

  /// No description provided for @noStudents.
  ///
  /// In en, this message translates to:
  /// **'No students to assign'**
  String get noStudents;

  /// No description provided for @lateSubmission.
  ///
  /// In en, this message translates to:
  /// **'late'**
  String get lateSubmission;

  /// No description provided for @assignedToYou.
  ///
  /// In en, this message translates to:
  /// **'Assigned to you'**
  String get assignedToYou;

  /// No description provided for @dueNow.
  ///
  /// In en, this message translates to:
  /// **'due now'**
  String get dueNow;

  /// No description provided for @inMinutes.
  ///
  /// In en, this message translates to:
  /// **'in {count}m'**
  String inMinutes(Object count);

  /// No description provided for @inHours.
  ///
  /// In en, this message translates to:
  /// **'in {count}h'**
  String inHours(Object count);

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'in {count}d'**
  String inDays(Object count);

  /// No description provided for @notStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get notStarted;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get inProgress;

  /// No description provided for @editorMode.
  ///
  /// In en, this message translates to:
  /// **'Editor mode'**
  String get editorMode;

  /// No description provided for @editorModeWeb.
  ///
  /// In en, this message translates to:
  /// **'Web'**
  String get editorModeWeb;

  /// No description provided for @editorModeNative.
  ///
  /// In en, this message translates to:
  /// **'Native'**
  String get editorModeNative;

  /// No description provided for @craftCheckoutDir.
  ///
  /// In en, this message translates to:
  /// **'Project checkout folder'**
  String get craftCheckoutDir;

  /// No description provided for @craftCheckoutDirBody.
  ///
  /// In en, this message translates to:
  /// **'Native editors keep a local copy of each open project here.'**
  String get craftCheckoutDirBody;

  /// No description provided for @craftAlreadyOpen.
  ///
  /// In en, this message translates to:
  /// **'{craft} already has this project open.'**
  String craftAlreadyOpen(Object craft);

  /// No description provided for @craftMissing.
  ///
  /// In en, this message translates to:
  /// **'The native {craft} editor is not bundled in this build.'**
  String craftMissing(Object craft);

  /// No description provided for @craftLocked.
  ///
  /// In en, this message translates to:
  /// **'{craft} is open elsewhere and could not be taken over.'**
  String craftLocked(Object craft);

  /// No description provided for @craftTakeOverBody.
  ///
  /// In en, this message translates to:
  /// **'{craft} already has this project open elsewhere. Take over and close the other session?'**
  String craftTakeOverBody(Object craft);

  /// No description provided for @syncPulling.
  ///
  /// In en, this message translates to:
  /// **'Downloading project files…'**
  String get syncPulling;

  /// No description provided for @syncPushing.
  ///
  /// In en, this message translates to:
  /// **'Uploading changes…'**
  String get syncPushing;

  /// No description provided for @syncLockLost.
  ///
  /// In en, this message translates to:
  /// **'This project was taken over elsewhere. The editor was closed to keep your work safe.'**
  String get syncLockLost;

  /// No description provided for @importStorage.
  ///
  /// In en, this message translates to:
  /// **'Import storage'**
  String get importStorage;

  /// No description provided for @importMixed.
  ///
  /// In en, this message translates to:
  /// **'Local copy + upload'**
  String get importMixed;

  /// No description provided for @importServer.
  ///
  /// In en, this message translates to:
  /// **'Server only'**
  String get importServer;
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
