// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WFM';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get confirm => 'Confirm';

  @override
  String get done => 'Done';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get download => 'Download';

  @override
  String get create => 'Create';

  @override
  String get refresh => 'Refresh';

  @override
  String get upload => 'Upload';

  @override
  String get enable => 'Enable';

  @override
  String get disable => 'Disable';

  @override
  String get logout => 'Log out';

  @override
  String get welcomeTitle => 'Welcome to WFM';

  @override
  String get setupSubtitle => 'Create the owner account to get started.';

  @override
  String get yourName => 'Your name';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get creating => 'Creating…';

  @override
  String get createOwner => 'Create owner';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String signInFailed(Object error) {
    return 'Sign in failed: $error';
  }

  @override
  String get trustedProxies => 'Trusted proxies';

  @override
  String get trustedProxiesHint =>
      'Comma-separated IPs or CIDR ranges, e.g. 10.0.0.1, 172.16.0.0/12';

  @override
  String get navHome => 'Home';

  @override
  String get navProjects => 'Projects';

  @override
  String get navManage => 'Manage';

  @override
  String get navSettings => 'Settings';

  @override
  String greeting(Object name) {
    return 'Hi, $name';
  }

  @override
  String get cardProjects => 'Projects';

  @override
  String get cardProjectsSub => 'Open your film projects';

  @override
  String get cardManage => 'Manage';

  @override
  String get cardManageSub => 'Accounts and permissions';

  @override
  String get cardSettings => 'Settings';

  @override
  String get cardSettingsSub => 'Theme and language';

  @override
  String get projects => 'Projects';

  @override
  String get newProject => 'New project';

  @override
  String get projectName => 'Project name';

  @override
  String get noProjects => 'No projects yet. Create one to get started.';

  @override
  String createdAgo(Object when) {
    return 'Created $when';
  }

  @override
  String get openInFilmcraft => 'Open';

  @override
  String get renameProject => 'Rename project';

  @override
  String get displayName => 'Display name';

  @override
  String get deleteProject => 'Delete project';

  @override
  String deleteProjectBody(Object name) {
    return 'Delete \"$name\" and all of its media? This cannot be undone.';
  }

  @override
  String get newGroup => 'New group';

  @override
  String get groupName => 'Group name';

  @override
  String get ungrouped => 'Ungrouped';

  @override
  String get noGroup => 'No group';

  @override
  String get moveToGroup => 'Move to group';

  @override
  String get renameGroup => 'Rename group';

  @override
  String deleteGroupBody(Object name) {
    return 'Delete group \"$name\"? Its projects are kept and become ungrouped.';
  }

  @override
  String get editTags => 'Edit tags';

  @override
  String get tagsHint => 'Tags, comma separated';

  @override
  String get noMatchingProjects => 'No projects match this tag.';

  @override
  String get files => 'Files';

  @override
  String get renders => 'Renders';

  @override
  String get emptyFolder => 'Empty folder';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get newName => 'New name';

  @override
  String deleteFileBody(Object path) {
    return 'Delete \"$path\"?';
  }

  @override
  String get noRenders => 'No renders yet.';

  @override
  String get newRender => 'New render';

  @override
  String get render => 'Render';

  @override
  String get queuing => 'Queuing…';

  @override
  String renderStatusWorker(Object status, Object worker, Object when) {
    return '$status on $worker  ·  $when';
  }

  @override
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get outputName => 'Output name';

  @override
  String get resolution => 'Resolution';

  @override
  String get frameRate => 'FPS';

  @override
  String get addClips => 'Add clips from the browser';

  @override
  String clipsCount(Object count) {
    return 'Clips ($count)';
  }

  @override
  String browseFolder(Object folder) {
    return 'Browse: $folder';
  }

  @override
  String get manage => 'Manage';

  @override
  String get nothingToManage => 'Nothing to manage.';

  @override
  String get accounts => 'Accounts';

  @override
  String get activity => 'Activity';

  @override
  String get renderNodes => 'Render nodes';

  @override
  String get newAccount => 'New account';

  @override
  String get name => 'Name';

  @override
  String get role => 'Role';

  @override
  String get studentIdOptional => 'Student ID (optional)';

  @override
  String get noteOptional => 'Note (max 20 chars)';

  @override
  String get resetPassword => 'Reset password';

  @override
  String resetPasswordTitle(Object username) {
    return 'Reset password: $username';
  }

  @override
  String get newPassword => 'New password';

  @override
  String get passwordReset => 'Password reset';

  @override
  String get disabledSuffix => '  (disabled)';

  @override
  String userLine(Object username, Object when) {
    return '@$username  ·  last login $when';
  }

  @override
  String get nothingRecorded => 'Nothing recorded yet.';

  @override
  String get newNode => 'New node';

  @override
  String get nodeName => 'Node name';

  @override
  String nodeCreatedTitle(Object name) {
    return 'Node \"$name\" created';
  }

  @override
  String get nodeTokenNote =>
      'Save this token, it is shown once. Start the node with:';

  @override
  String get noNodes =>
      'No render nodes. Local workers on the server still run.';

  @override
  String lastSeen(Object when) {
    return 'last seen $when';
  }

  @override
  String get deleteNode => 'Delete node';

  @override
  String deleteNodeBody(Object name) {
    return 'Delete node \"$name\"?';
  }

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeOled => 'OLED';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get serverSection => 'Server';

  @override
  String get trustedProxiesHelp =>
      'X-Forwarded-For is only trusted from these addresses. Leave empty unless the server sits behind a reverse proxy.';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get checkUpdates => 'Check for updates';

  @override
  String get checking => 'Checking…';

  @override
  String upToDate(Object version) {
    return 'WFM is up to date (v$version)';
  }

  @override
  String updateAvailable(Object version) {
    return 'Update available: $version';
  }

  @override
  String get checkFailed => 'Update check failed';

  @override
  String get viewRelease => 'View release';

  @override
  String versionLabel(Object version) {
    return 'Version $version';
  }

  @override
  String get never => 'never';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(Object count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(Object count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(Object count) {
    return '${count}d ago';
  }
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');
}
