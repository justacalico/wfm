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
  String get fileExists => 'A file with that name already exists.';

  @override
  String get extensionLocked =>
      'Changing the file extension would break the file, so this action is blocked.';

  @override
  String get renameFailed => 'Couldn\'t rename the file.';

  @override
  String get download => 'Download';

  @override
  String get close => 'Close';

  @override
  String get playInBrowser => 'Play in browser';

  @override
  String get create => 'Create';

  @override
  String get refresh => 'Refresh';

  @override
  String get uploadingFiles => 'Uploading files';

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
  String get editInFilmcraft => 'Edit';

  @override
  String get openScript => 'Script';

  @override
  String get openBoards => 'Storyboard';

  @override
  String get renameProject => 'Rename project';

  @override
  String get displayName => 'Display name';

  @override
  String get deleteProject => 'Delete project';

  @override
  String deleteAccountBody(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

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
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get renderAlreadyActive =>
      'A render is already in progress for this project.';

  @override
  String get outputName => 'Output name';

  @override
  String get resolution => 'Resolution';

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
  String get editAccount => 'Edit account';

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
  String get gridView => 'Grid view';

  @override
  String get searchProjects => 'Search projects';

  @override
  String get sortProjects => 'Sort projects';

  @override
  String get sortCreated => 'Created date';

  @override
  String get sortActivity => 'Last activity';

  @override
  String get pinProject => 'Pin project';

  @override
  String get unpinProject => 'Unpin project';

  @override
  String get listView => 'List view';

  @override
  String get noAccounts => 'No accounts';

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

  @override
  String weeksAgo(Object count) {
    return '${count}w ago';
  }

  @override
  String monthsAgo(Object count) {
    return '${count}mo ago';
  }

  @override
  String yearsAgo(Object count) {
    return '${count}y ago';
  }

  @override
  String get renderMode => 'Render on';

  @override
  String get renderOnDevice => 'This device';

  @override
  String get renderOnServer => 'Server';

  @override
  String get sequence => 'Sequence';

  @override
  String get matchSource => 'Match source';

  @override
  String get outputFormat => 'Format';

  @override
  String get exportRange => 'Range';

  @override
  String get rangeEntire => 'Entire sequence';

  @override
  String get rangeInOut => 'In/out';

  @override
  String get rangeWorkArea => 'Work area';

  @override
  String get rangeCustom => 'Custom';

  @override
  String get rangeStart => 'Start (seconds)';

  @override
  String get rangeEnd => 'End (seconds)';

  @override
  String get rangeNeedTimes => 'Enter the range start and end in seconds';

  @override
  String get renderAudio => 'Audio';

  @override
  String get preset => 'Preset (optional)';

  @override
  String get advancedOptions => 'Advanced options';

  @override
  String get openInFilmcraftFirst =>
      'Open this project in FilmCraft once so it can be rendered.';

  @override
  String get noSequences => 'This project has no sequences to export.';

  @override
  String get quality => 'Quality (0-100)';

  @override
  String get bitrateKbps => 'Bitrate (kbps)';

  @override
  String get crf => 'CRF';

  @override
  String get bitrateMode => 'Bitrate mode';

  @override
  String get audioCodec => 'Audio codec';

  @override
  String get flacLevel => 'FLAC level';

  @override
  String get hardwareEncoding => 'Hardware encoding';

  @override
  String get renderScale => 'Scale';

  @override
  String get loudnessLufs => 'Loudness (LUFS)';

  @override
  String get h264Profile => 'H.264 profile';

  @override
  String get h264IntraOnly => 'H.264 intra-only';

  @override
  String get proresProfile => 'ProRes profile';

  @override
  String get dnxProfile => 'DNx profile';

  @override
  String get apvProfile => 'APV profile';

  @override
  String get mxfVideoCodec => 'MXF video codec';

  @override
  String get burnCaptions => 'Burn captions';

  @override
  String get alphaChannel => 'Alpha channel';

  @override
  String get exrCompression => 'EXR compression';

  @override
  String get captionSidecar => 'Caption sidecar';

  @override
  String get extraParams => 'Extra export params (JSON)';

  @override
  String get invalidJson => 'Invalid JSON';

  @override
  String get defaultOption => 'Default';

  @override
  String get serverUrl => 'Server URL';

  @override
  String get connect => 'Connect';

  @override
  String get connecting => 'Connecting…';

  @override
  String finishSetupInBrowser(String url) {
    return 'This server has no admin account yet. Finish setup in a browser at $url.';
  }

  @override
  String serverUnreachable(Object error) {
    return 'Can\'t reach the server: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get license => 'License';

  @override
  String get licenseAgpl => 'Licensed under AGPL-3.0';

  @override
  String get viewOnGitlab => 'View on GitLab';

  @override
  String get loadMore => 'Load more';

  @override
  String deleteRenderBody(Object name) {
    return 'Delete the \"$name\" render? Its exported files stay in the project.';
  }

  @override
  String get sessions => 'Sessions';

  @override
  String get currentSession => 'This session';

  @override
  String get revoke => 'Revoke';

  @override
  String get revokeSessionBody => 'Sign out this session?';

  @override
  String sessionLastSeen(Object time) {
    return 'Last seen $time';
  }

  @override
  String get readOnly => 'Read only';

  @override
  String get takeOver => 'Take ownership';

  @override
  String takeOverBody(Object name) {
    return 'Take ownership of $name?';
  }

  @override
  String ownedBy(Object name) {
    return 'by $name';
  }

  @override
  String get selectFiles => 'Select';

  @override
  String get selectAll => 'Select all';

  @override
  String get moveSelected => 'Move selected';

  @override
  String get deleteSelected => 'Delete selected';

  @override
  String get downloadZip => 'Download zip';

  @override
  String get destFolder => 'Destination folder';

  @override
  String selectedCount(Object n) {
    return '$n selected';
  }

  @override
  String get changePhoto => 'Change photo';

  @override
  String get action => 'Action';

  @override
  String get actor => 'Actor';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get chunkSize => 'Upload chunk size';

  @override
  String get account => 'Account';

  @override
  String get invite => 'Invite';

  @override
  String get newInvite => 'New invite';

  @override
  String get inviteReady => 'Invite ready';

  @override
  String get inviteUrl => 'Invite link';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteEmail => 'Email body';

  @override
  String inviteEmailBody(Object url) {
    return 'You have been invited to WFM. Sign up here: $url';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get invites => 'Invites';

  @override
  String get used => 'Used';

  @override
  String get expired => 'Expired';

  @override
  String get pending => 'Pending';

  @override
  String get usernameOptional => 'Username (optional)';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get inviteSignup => 'Create your account';

  @override
  String get signUp => 'Sign up';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsMismatch => 'Passwords do not match';

  @override
  String get revoked => 'Revoked';

  @override
  String get share => 'Share';

  @override
  String get shareProject => 'Share project';

  @override
  String get send => 'Send';

  @override
  String get canView => 'Can view';

  @override
  String get canEdit => 'Can edit';

  @override
  String get accepted => 'Accepted';

  @override
  String get declined => 'Declined';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String shareInviteFrom(Object level, Object user) {
    return 'Invited by $user · $level';
  }

  @override
  String get navShared => 'Shared with me';

  @override
  String get pendingInvites => 'Pending invites';

  @override
  String get sharedProjects => 'Shared projects';

  @override
  String get noShares => 'Nothing shared with you yet';

  @override
  String get autoShares => 'Auto-share';

  @override
  String get autoSharesHint =>
      'These people are invited to every new project your students create.';

  @override
  String get autoShareAdd => 'Add auto-share';

  @override
  String get quotaMb => 'Storage quota (MB)';

  @override
  String get quotaMbHint => 'Leave empty for unlimited';

  @override
  String storageUsed(Object used, Object quota) {
    return '$used of $quota used';
  }

  @override
  String get navNotifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String notifShareInvite(Object from, Object project) {
    return '$from invited you to $project';
  }

  @override
  String notifShareAuto(Object from, Object project) {
    return '$from shared $project with you';
  }

  @override
  String notifShareAccepted(Object from, Object project) {
    return '$from accepted your invite to $project';
  }

  @override
  String notifShareDeclined(Object from, Object project) {
    return '$from declined your invite to $project';
  }

  @override
  String notifRenderDone(Object name, Object project) {
    return 'Render finished: $name in $project';
  }

  @override
  String notifRenderFailed(Object name, Object project) {
    return 'Render failed: $name in $project';
  }

  @override
  String notifNodeOffline(Object name) {
    return 'Render node $name went offline';
  }

  @override
  String get shareLinks => 'Share links';

  @override
  String get createLink => 'Create link';

  @override
  String get scopeProject => 'Whole project';

  @override
  String get scopeRenders => 'Renders only';

  @override
  String get expiryNever => 'Never expires';

  @override
  String get expiryDay => '1 day';

  @override
  String get expiryWeek => '7 days';

  @override
  String get expiryMonth => '30 days';

  @override
  String linkExpires(Object when) {
    return 'Expires $when';
  }

  @override
  String get linkEmpty => 'Nothing to show';

  @override
  String get linkRendersOnly => 'Renders only';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get saveCopy => 'Save a copy';

  @override
  String get useTemplate => 'Use template';

  @override
  String get template => 'Template';

  @override
  String get markTemplate => 'Mark as template';

  @override
  String get unmarkTemplate => 'Unmark template';

  @override
  String get projectDuplicated => 'Copy created';

  @override
  String get comments => 'Comments';

  @override
  String get noComments => 'No comments yet';

  @override
  String get writeComment => 'Write a comment';

  @override
  String get editComment => 'Edit comment';

  @override
  String get edited => 'edited';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String get withdrawSubmission => 'Withdraw submission';

  @override
  String get markReviewed => 'Mark reviewed';

  @override
  String get returnToDraft => 'Return to draft';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusReviewed => 'Reviewed';

  @override
  String notifComment(Object from, Object project) {
    return '$from commented on $project';
  }

  @override
  String notifSubmitted(Object from, Object project) {
    return '$from submitted $project for review';
  }

  @override
  String notifReviewed(Object from, Object project) {
    return '$from marked $project reviewed';
  }

  @override
  String notifReturned(Object from, Object project) {
    return '$from returned $project to draft';
  }

  @override
  String get editors => 'Editors';

  @override
  String get filmcraftShortcuts => 'FilmCraft shortcuts';

  @override
  String get scriptcraftShortcuts => 'ScriptCraft shortcuts';

  @override
  String get searchShortcuts => 'Search actions';

  @override
  String get pressShortcut => 'Press the new shortcut';

  @override
  String shortcutConflict(Object action) {
    return 'Already used by $action';
  }

  @override
  String get clearShortcut => 'Clear';

  @override
  String get unbound => 'Unbound';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get resetAllShortcuts => 'Reset all shortcuts';

  @override
  String get resetAllShortcutsBody => 'Restore every shortcut to its default?';

  @override
  String unsupportedUploadType(Object names) {
    return 'File type isn\'t allowed: $names';
  }

  @override
  String get assign => 'Assign';

  @override
  String get assignProject => 'Assign to students';

  @override
  String get assignment => 'Assignment';

  @override
  String get dueDate => 'Due date';

  @override
  String get noDueDate => 'No due date';

  @override
  String get allowWithdraw => 'Allow unsubmission';

  @override
  String get maxSubmissions => 'Max submissions (0 = unlimited)';

  @override
  String get hiddenFromStudents => 'Hidden from students';

  @override
  String get lockedForStudents => 'Locked';

  @override
  String get submissions => 'Submissions';

  @override
  String attemptsUsed(Object max, Object used) {
    return '$used of $max attempts';
  }

  @override
  String get overdue => 'Overdue';

  @override
  String get unassign => 'Remove assignment';

  @override
  String get unassignBody =>
      'Remove this assignment? Student copies stay as ordinary projects.';

  @override
  String get noStudents => 'No students to assign';

  @override
  String get lateSubmission => 'late';

  @override
  String get assignedToYou => 'Assigned to you';

  @override
  String get dueNow => 'due now';

  @override
  String inMinutes(Object count) {
    return 'in ${count}m';
  }

  @override
  String inHours(Object count) {
    return 'in ${count}h';
  }

  @override
  String inDays(Object count) {
    return 'in ${count}d';
  }

  @override
  String get notStarted => 'Not started';

  @override
  String get inProgress => 'In progress';
}

/// The translations for English, as used in the United Kingdom (`en_GB`).
class AppLocalizationsEnGb extends AppLocalizationsEn {
  AppLocalizationsEnGb() : super('en_GB');

  @override
  String deleteAccountBody(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get gridView => 'Grid view';

  @override
  String get searchProjects => 'Search projects';

  @override
  String get sortProjects => 'Sort projects';

  @override
  String get sortCreated => 'Created date';

  @override
  String get sortActivity => 'Last activity';

  @override
  String get pinProject => 'Pin project';

  @override
  String get unpinProject => 'Unpin project';

  @override
  String get listView => 'List view';

  @override
  String get noAccounts => 'No accounts';

  @override
  String get license => 'Licence';

  @override
  String get licenseAgpl => 'Licensed under AGPL-3.0';

  @override
  String get viewOnGitlab => 'View on GitLab';

  @override
  String get loadMore => 'Load more';

  @override
  String deleteRenderBody(Object name) {
    return 'Delete the \"$name\" render? Its exported files stay in the project.';
  }

  @override
  String get sessions => 'Sessions';

  @override
  String get revoke => 'Revoke';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get action => 'Action';

  @override
  String get actor => 'Actor';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get chunkSize => 'Upload chunk size';

  @override
  String get account => 'Account';

  @override
  String get invite => 'Invite';

  @override
  String get newInvite => 'New invite';

  @override
  String get inviteReady => 'Invite ready';

  @override
  String get inviteUrl => 'Invite link';

  @override
  String get inviteCode => 'Invite code';

  @override
  String get inviteEmail => 'Email body';

  @override
  String inviteEmailBody(Object url) {
    return 'You have been invited to WFM. Sign up here: $url';
  }

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get invites => 'Invites';

  @override
  String get used => 'Used';

  @override
  String get expired => 'Expired';

  @override
  String get pending => 'Pending';

  @override
  String get usernameOptional => 'Username (optional)';

  @override
  String get nameOptional => 'Name (optional)';

  @override
  String get inviteSignup => 'Create your account';

  @override
  String get signUp => 'Sign up';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get passwordsMismatch => 'Passwords do not match';

  @override
  String get revoked => 'Revoked';

  @override
  String get share => 'Share';

  @override
  String get shareProject => 'Share project';

  @override
  String get send => 'Send';

  @override
  String get canView => 'Can view';

  @override
  String get canEdit => 'Can edit';

  @override
  String get accepted => 'Accepted';

  @override
  String get declined => 'Declined';

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String shareInviteFrom(Object level, Object user) {
    return 'Invited by $user · $level';
  }

  @override
  String get navShared => 'Shared with me';

  @override
  String get pendingInvites => 'Pending invites';

  @override
  String get sharedProjects => 'Shared projects';

  @override
  String get noShares => 'Nothing shared with you yet';

  @override
  String get autoShares => 'Auto-share';

  @override
  String get autoSharesHint =>
      'These people are invited to every new project your students create.';

  @override
  String get autoShareAdd => 'Add auto-share';

  @override
  String get quotaMb => 'Storage quota (MB)';

  @override
  String get quotaMbHint => 'Leave empty for unlimited';

  @override
  String storageUsed(Object used, Object quota) {
    return '$used of $quota used';
  }

  @override
  String get navNotifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String notifShareInvite(Object from, Object project) {
    return '$from invited you to $project';
  }

  @override
  String notifShareAuto(Object from, Object project) {
    return '$from shared $project with you';
  }

  @override
  String notifShareAccepted(Object from, Object project) {
    return '$from accepted your invite to $project';
  }

  @override
  String notifShareDeclined(Object from, Object project) {
    return '$from declined your invite to $project';
  }

  @override
  String notifRenderDone(Object name, Object project) {
    return 'Render finished: $name in $project';
  }

  @override
  String notifRenderFailed(Object name, Object project) {
    return 'Render failed: $name in $project';
  }

  @override
  String notifNodeOffline(Object name) {
    return 'Render node $name went offline';
  }

  @override
  String get shareLinks => 'Share links';

  @override
  String get createLink => 'Create link';

  @override
  String get scopeProject => 'Whole project';

  @override
  String get scopeRenders => 'Renders only';

  @override
  String get expiryNever => 'Never expires';

  @override
  String get expiryDay => '1 day';

  @override
  String get expiryWeek => '7 days';

  @override
  String get expiryMonth => '30 days';

  @override
  String linkExpires(Object when) {
    return 'Expires $when';
  }

  @override
  String get linkEmpty => 'Nothing to show';

  @override
  String get linkRendersOnly => 'Renders only';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get saveCopy => 'Save a copy';

  @override
  String get useTemplate => 'Use template';

  @override
  String get template => 'Template';

  @override
  String get markTemplate => 'Mark as template';

  @override
  String get unmarkTemplate => 'Unmark template';

  @override
  String get projectDuplicated => 'Copy created';

  @override
  String get comments => 'Comments';

  @override
  String get noComments => 'No comments yet';

  @override
  String get writeComment => 'Write a comment';

  @override
  String get editComment => 'Edit comment';

  @override
  String get edited => 'edited';

  @override
  String get submitForReview => 'Submit for review';

  @override
  String get withdrawSubmission => 'Withdraw submission';

  @override
  String get markReviewed => 'Mark reviewed';

  @override
  String get returnToDraft => 'Return to draft';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String get statusReviewed => 'Reviewed';

  @override
  String notifComment(Object from, Object project) {
    return '$from commented on $project';
  }

  @override
  String notifSubmitted(Object from, Object project) {
    return '$from submitted $project for review';
  }

  @override
  String notifReviewed(Object from, Object project) {
    return '$from marked $project reviewed';
  }

  @override
  String notifReturned(Object from, Object project) {
    return '$from returned $project to draft';
  }

  @override
  String get editors => 'Editors';

  @override
  String get filmcraftShortcuts => 'FilmCraft shortcuts';

  @override
  String get scriptcraftShortcuts => 'ScriptCraft shortcuts';

  @override
  String get searchShortcuts => 'Search actions';

  @override
  String get pressShortcut => 'Press the new shortcut';

  @override
  String shortcutConflict(Object action) {
    return 'Already used by $action';
  }

  @override
  String get clearShortcut => 'Clear';

  @override
  String get unbound => 'Unbound';

  @override
  String get resetToDefault => 'Reset to default';

  @override
  String get resetAllShortcuts => 'Reset all shortcuts';

  @override
  String get resetAllShortcutsBody => 'Restore every shortcut to its default?';
}
