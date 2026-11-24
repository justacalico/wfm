// coverage:ignore-file

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'WFM';

  @override
  String get cancel => '取消';

  @override
  String get ok => '确定';

  @override
  String get confirm => '确认';

  @override
  String get done => '完成';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get rename => '重命名';

  @override
  String get fileExists => '同名文件已存在。';

  @override
  String get extensionLocked => '更改文件扩展名会破坏文件，此操作已被阻止。';

  @override
  String get renameFailed => '重命名文件失败。';

  @override
  String get download => '下载';

  @override
  String get close => '关闭';

  @override
  String get playInBrowser => '在浏览器中播放';

  @override
  String get create => '创建';

  @override
  String get refresh => '刷新';

  @override
  String get uploadingFiles => '正在上传文件';

  @override
  String get upload => '上传';

  @override
  String get enable => '启用';

  @override
  String get disable => '禁用';

  @override
  String get logout => '退出登录';

  @override
  String get welcomeTitle => '欢迎使用 WFM';

  @override
  String get setupSubtitle => '创建所有者账户以开始使用。';

  @override
  String get yourName => '你的姓名';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get creating => '正在创建…';

  @override
  String get createOwner => '创建所有者';

  @override
  String get signIn => '登录';

  @override
  String get signingIn => '正在登录…';

  @override
  String signInFailed(Object error) {
    return '登录失败：$error';
  }

  @override
  String get trustedProxies => '受信任的代理';

  @override
  String get trustedProxiesHint =>
      '以逗号分隔的 IP 或 CIDR 网段，例如 10.0.0.1, 172.16.0.0/12';

  @override
  String get navHome => '首页';

  @override
  String get navProjects => '项目';

  @override
  String get navManage => '管理';

  @override
  String get navSettings => '设置';

  @override
  String greeting(Object name) {
    return '你好，$name';
  }

  @override
  String get projects => '项目';

  @override
  String get newProject => '新建项目';

  @override
  String get projectName => '项目名称';

  @override
  String get noProjects => '还没有项目，创建一个开始使用。';

  @override
  String editedAgo(Object when) {
    return '编辑于 $when';
  }

  @override
  String get editInFilmcraft => '编辑';

  @override
  String get openScript => '写剧本';

  @override
  String get openBoards => '画故事板';

  @override
  String get renameProject => '重命名项目';

  @override
  String get displayName => '显示名称';

  @override
  String get deleteProject => '删除项目';

  @override
  String deleteAccountBody(Object name) {
    return '删除“$name”？此操作无法撤销。';
  }

  @override
  String deleteProjectBody(Object name) {
    return '删除“$name”及其所有媒体？此操作无法撤销。';
  }

  @override
  String get back => '返回';

  @override
  String get addToFolder => '添加到文件夹';

  @override
  String get noFolder => '无文件夹';

  @override
  String get renameFolder => '重命名文件夹';

  @override
  String deleteFolderBody(Object name) {
    return '删除文件夹“$name”？其中的项目会保留并移出。';
  }

  @override
  String get noMatchingProjects => '没有符合搜索条件的项目。';

  @override
  String get files => '文件';

  @override
  String get renders => '渲染';

  @override
  String get emptyFolder => '空文件夹';

  @override
  String get emptyFolderUpload => '空文件夹。点击“上传”添加文件。';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get newName => '新名称';

  @override
  String deleteFileBody(Object path) {
    return '删除“$path”？';
  }

  @override
  String get noRenders => '还没有渲染任务。';

  @override
  String get newRender => '新建渲染';

  @override
  String get render => '渲染';

  @override
  String get queuing => '正在排队…';

  @override
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

  @override
  String get renderAlreadyActive => '该项目已有一个正在进行的渲染。';

  @override
  String get outputName => '输出名称';

  @override
  String get resolution => '分辨率';

  @override
  String get addClips => '从浏览器中添加片段';

  @override
  String clipsCount(Object count) {
    return '片段 ($count)';
  }

  @override
  String browseFolder(Object folder) {
    return '浏览：$folder';
  }

  @override
  String get manage => '管理';

  @override
  String get nothingToManage => '没有可管理的内容。';

  @override
  String get accounts => '账户';

  @override
  String get classes => '班级';

  @override
  String get schoolClass => '班级';

  @override
  String get newClass => '新建班级';

  @override
  String get className => '班级名称';

  @override
  String get renameClass => '重命名班级';

  @override
  String get noClasses => '还没有班级';

  @override
  String get unmanagedClass => '未分班';

  @override
  String memberCount(Object count) {
    return '$count 名成员';
  }

  @override
  String get moveToClass => '移到班级';

  @override
  String deleteClassBody(Object name) {
    return '删除班级“$name”？其中成员将移入未分班。';
  }

  @override
  String get add => '添加';

  @override
  String get remove => '移除';

  @override
  String get coTeachers => '协作教师';

  @override
  String coTeacherCount(Object count) {
    return '$count 位协作教师';
  }

  @override
  String get addCoTeacher => '添加协作教师';

  @override
  String get coTeacherNew => '创建新账号';

  @override
  String removeCoTeacherBody(Object name) {
    return '将 $name 移出协作教师？其账号将保留。';
  }

  @override
  String get activity => '动态';

  @override
  String get renderNodes => '渲染节点';

  @override
  String get newAccount => '新建账户';

  @override
  String get editAccount => '编辑账户';

  @override
  String get name => '姓名';

  @override
  String get role => '角色';

  @override
  String get studentIdOptional => '学号（可选）';

  @override
  String get noteOptional => '备注（最多 20 个字符）';

  @override
  String get resetPassword => '重置密码';

  @override
  String resetPasswordTitle(Object username) {
    return '重置密码：$username';
  }

  @override
  String get newPassword => '新密码';

  @override
  String get passwordReset => '密码已重置';

  @override
  String get disabledSuffix => '（已禁用）';

  @override
  String userLine(Object username, Object when) {
    return '@$username  ·  上次登录 $when';
  }

  @override
  String get gridView => '网格视图';

  @override
  String get searchProjects => '搜索项目';

  @override
  String get sortProjects => '项目排序';

  @override
  String get sortCreated => '创建时间';

  @override
  String get sortActivity => '最近活动';

  @override
  String get pinProject => '置顶项目';

  @override
  String get unpinProject => '取消置顶';

  @override
  String get listView => '列表视图';

  @override
  String get noAccounts => '暂无账号。';

  @override
  String get nothingRecorded => '暂无记录。';

  @override
  String get newNode => '新建节点';

  @override
  String get nodeName => '节点名称';

  @override
  String nodeCreatedTitle(Object name) {
    return '节点“$name”已创建';
  }

  @override
  String get nodeTokenNote => '请保存此令牌，它只显示一次。启动节点：';

  @override
  String get noNodes => '没有渲染节点，服务器上的本地渲染仍会运行。';

  @override
  String lastSeen(Object when) {
    return '最近在线 $when';
  }

  @override
  String get deleteNode => '删除节点';

  @override
  String deleteNodeBody(Object name) {
    return '删除节点“$name”？';
  }

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get langSystem => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeOled => '纯黑';

  @override
  String get changePassword => '修改密码';

  @override
  String get currentPassword => '当前密码';

  @override
  String get passwordChanged => '密码已修改';

  @override
  String get serverSection => '服务器';

  @override
  String get trustedProxiesHelp =>
      '仅信任来自这些地址的 X-Forwarded-For。除非服务器位于反向代理之后，否则请留空。';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get checkUpdates => '检查更新';

  @override
  String get checking => '正在检查…';

  @override
  String upToDate(Object version) {
    return 'WFM 已是最新版本 (v$version)';
  }

  @override
  String updateAvailable(Object version) {
    return '发现新版本：$version';
  }

  @override
  String get checkFailed => '检查更新失败';

  @override
  String get viewRelease => '查看版本';

  @override
  String versionLabel(Object version) {
    return '版本 $version';
  }

  @override
  String get never => '从未';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String daysAgo(Object count) {
    return '$count 天前';
  }

  @override
  String weeksAgo(Object count) {
    return '$count 周前';
  }

  @override
  String monthsAgo(Object count) {
    return '$count 个月前';
  }

  @override
  String yearsAgo(Object count) {
    return '$count 年前';
  }

  @override
  String get renderMode => '渲染位置';

  @override
  String get renderOnDevice => '本机渲染';

  @override
  String get renderOnServer => '服务器渲染';

  @override
  String get renderNameTaken => '名称已被使用';

  @override
  String renderNameTakenBody(Object name) {
    return '已存在名为“$name”的渲染，覆盖将清除旧渲染。';
  }

  @override
  String get overwrite => '覆盖';

  @override
  String useOtherName(Object name) {
    return '使用“$name”';
  }

  @override
  String get sequence => '序列';

  @override
  String get matchSource => '匹配源';

  @override
  String get outputFormat => '格式';

  @override
  String get exportRange => '范围';

  @override
  String get rangeEntire => '整个序列';

  @override
  String get rangeInOut => '入点/出点';

  @override
  String get rangeWorkArea => '工作区域';

  @override
  String get rangeCustom => '自定义';

  @override
  String get rangeStart => '开始（秒）';

  @override
  String get rangeEnd => '结束（秒）';

  @override
  String get rangeNeedTimes => '请输入以秒为单位的起止时间';

  @override
  String get renderAudio => '音频';

  @override
  String get preset => '预设（可选）';

  @override
  String get advancedOptions => '高级选项';

  @override
  String get openInFilmcraftFirst => '请先在 FilmCraft 中打开一次该项目后再渲染。';

  @override
  String get noSequences => '该项目没有可导出的序列。';

  @override
  String get quality => '质量（0-100）';

  @override
  String get bitrateKbps => '码率（kbps）';

  @override
  String get crf => 'CRF';

  @override
  String get bitrateMode => '码率模式';

  @override
  String get audioCodec => '音频编码';

  @override
  String get flacLevel => 'FLAC 级别';

  @override
  String get hardwareEncoding => '硬件编码';

  @override
  String get renderScale => '缩放';

  @override
  String get loudnessLufs => '响度（LUFS）';

  @override
  String get h264Profile => 'H.264 档次';

  @override
  String get h264IntraOnly => 'H.264 仅帧内';

  @override
  String get proresProfile => 'ProRes 档次';

  @override
  String get dnxProfile => 'DNx 档次';

  @override
  String get apvProfile => 'APV 档次';

  @override
  String get mxfVideoCodec => 'MXF 视频编码';

  @override
  String get burnCaptions => '烧录字幕';

  @override
  String get alphaChannel => 'Alpha 通道';

  @override
  String get exrCompression => 'EXR 压缩';

  @override
  String get captionSidecar => '字幕旁挂文件';

  @override
  String get extraParams => '额外导出参数（JSON）';

  @override
  String get invalidJson => 'JSON 无效';

  @override
  String get defaultOption => '默认';

  @override
  String serverUnreachable(Object error) {
    return '无法连接服务器:$error';
  }

  @override
  String get retry => '重试';

  @override
  String get license => '许可证';

  @override
  String get licenseAgpl => '基于 AGPL-3.0 许可';

  @override
  String get viewOnGitlab => '在 GitLab 上查看';

  @override
  String get loadMore => '加载更多';

  @override
  String deleteRenderBody(Object name) {
    return '删除“$name”的渲染记录？导出的文件会保留在项目中。';
  }

  @override
  String get sessions => '登录设备';

  @override
  String get currentSession => '当前会话';

  @override
  String get revoke => '撤销';

  @override
  String get revokeSessionBody => '退出此会话？';

  @override
  String sessionLastSeen(Object time) {
    return '最近活动 $time';
  }

  @override
  String get mcp => 'AI 助手';

  @override
  String get mcpSubtitle => '让代理帮你操作 WFM';

  @override
  String get mcpHint =>
      '把 AI 代理指向本服务器，它就能帮你创建项目、上传素材、剪辑时间线。你的设备无需安装任何东西，代理通过网络凭你创建的令牌连接。';

  @override
  String get mcpUrl => '服务器地址';

  @override
  String get mcpTokens => '代理令牌';

  @override
  String get mcpTokensHint => '每个令牌相当于一个代理的密码，可随时吊销。';

  @override
  String get mcpEmpty => '还没有令牌。创建一个即可让代理接入。';

  @override
  String get mcpNew => '新建令牌';

  @override
  String get mcpName => '令牌名称';

  @override
  String get mcpNameHint => '例如：Claude 桌面版';

  @override
  String get mcpReady => '令牌已生成';

  @override
  String get mcpOnce => '令牌仅显示这一次。请复制下面的提示词或配置到你的代理。';

  @override
  String get mcpPrompt => '待粘贴的提示词';

  @override
  String get mcpConfig => '待粘贴的配置';

  @override
  String get mcpRevokeBody => '使用该令牌的代理将立即失去访问权限。确定吊销？';

  @override
  String get readOnly => '只读';

  @override
  String get takeOver => '取得所有权';

  @override
  String takeOverBody(Object name) {
    return '接管项目 $name？';
  }

  @override
  String ownedBy(Object name) {
    return '$name 的项目';
  }

  @override
  String userProjects(Object name) {
    return '$name 的项目';
  }

  @override
  String get userProjectsEmpty => '还没有项目。';

  @override
  String get selectFiles => '选择';

  @override
  String get selectAll => '全选';

  @override
  String get moveSelected => '移动所选';

  @override
  String get deleteSelected => '删除所选';

  @override
  String get downloadZip => '打包下载';

  @override
  String get destFolder => '目标文件夹';

  @override
  String selectedCount(Object n) {
    return '已选 $n 项';
  }

  @override
  String get changePhoto => '更换头像';

  @override
  String get action => '操作';

  @override
  String get actor => '操作者';

  @override
  String get from => '开始';

  @override
  String get to => '结束';

  @override
  String get applyFilters => '应用筛选';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get chunkSize => '上传分块大小';

  @override
  String get account => '账户';

  @override
  String get invite => '邀请';

  @override
  String get newInvite => '新建邀请';

  @override
  String get inviteReady => '邀请已创建';

  @override
  String get inviteUrl => '邀请链接';

  @override
  String get inviteCode => '邀请码';

  @override
  String get inviteEmail => '邮件内容';

  @override
  String inviteEmailBody(Object url) {
    return '你已被邀请加入 WFM。点此注册：$url';
  }

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get invites => '邀请';

  @override
  String get used => '已使用';

  @override
  String get expired => '已过期';

  @override
  String get pending => '待使用';

  @override
  String get usernameOptional => '用户名（可选）';

  @override
  String get nameOptional => '姓名（可选）';

  @override
  String get inviteSignup => '创建你的账户';

  @override
  String get signUp => '注册';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get passwordsMismatch => '两次输入的密码不一致';

  @override
  String get revoked => '已撤销';

  @override
  String get share => '分享';

  @override
  String get shareProject => '分享项目';

  @override
  String get send => '发送';

  @override
  String get canView => '可查看';

  @override
  String get canEdit => '可编辑';

  @override
  String get accepted => '已接受';

  @override
  String get declined => '已拒绝';

  @override
  String get accept => '接受';

  @override
  String get decline => '拒绝';

  @override
  String shareInviteFrom(Object level, Object user) {
    return '$user 邀请你 · $level';
  }

  @override
  String get navShared => '与我共享';

  @override
  String get pendingInvites => '待处理邀请';

  @override
  String get sharedProjects => '共享的项目';

  @override
  String get noShares => '还没有人共享项目给你。别人共享给你的项目会出现在这里。';

  @override
  String get autoShares => '自动共享';

  @override
  String get autoSharesHint => '你的学生创建的每个新项目都会自动邀请这些人。';

  @override
  String get autoShareAdd => '添加自动共享';

  @override
  String get quotaMb => '存储配额（MB）';

  @override
  String get quotaMbHint => '留空表示不限制';

  @override
  String storageUsed(Object used, Object quota) {
    return '已使用 $used / $quota';
  }

  @override
  String get navNotifications => '通知';

  @override
  String get noNotifications => '暂无通知';

  @override
  String get markAllRead => '全部标为已读';

  @override
  String notifShareInvite(Object from, Object project) {
    return '$from 邀请你加入 $project';
  }

  @override
  String notifShareAuto(Object from, Object project) {
    return '$from 已将 $project 共享给你';
  }

  @override
  String notifShareAccepted(Object from, Object project) {
    return '$from 接受了你发出的 $project 邀请';
  }

  @override
  String notifShareDeclined(Object from, Object project) {
    return '$from 拒绝了你的 $project 邀请';
  }

  @override
  String notifRenderDone(Object name, Object project) {
    return '渲染完成:$name($project)';
  }

  @override
  String notifRenderFailed(Object name, Object project) {
    return '渲染失败:$name($project)';
  }

  @override
  String notifNodeOffline(Object name) {
    return '渲染节点 $name 已离线';
  }

  @override
  String get shareLinks => '分享链接';

  @override
  String get createLink => '创建链接';

  @override
  String get scopeProject => '整个项目';

  @override
  String get scopeRenders => '仅渲染成品';

  @override
  String get expiryNever => '永不过期';

  @override
  String get expiryDay => '1 天';

  @override
  String get expiryWeek => '7 天';

  @override
  String get expiryMonth => '30 天';

  @override
  String linkExpires(Object when) {
    return '$when 过期';
  }

  @override
  String get linkEmpty => '暂无内容';

  @override
  String get linkRendersOnly => '仅渲染成品';

  @override
  String get duplicate => '创建副本';

  @override
  String get saveCopy => '保存副本';

  @override
  String get useTemplate => '使用模板';

  @override
  String get template => '模板';

  @override
  String get markTemplate => '标记为模板';

  @override
  String get unmarkTemplate => '取消模板标记';

  @override
  String get projectDuplicated => '已创建副本';

  @override
  String get projectGone => '该项目已不存在。';

  @override
  String get comments => '评论';

  @override
  String get noComments => '还没有评论';

  @override
  String get writeComment => '写评论';

  @override
  String get editComment => '编辑评论';

  @override
  String get edited => '已编辑';

  @override
  String get submitForReview => '提交审核';

  @override
  String get withdrawSubmission => '撤回提交';

  @override
  String get markReviewed => '标记已审核';

  @override
  String get returnToDraft => '退回草稿';

  @override
  String get statusSubmitted => '已提交';

  @override
  String get statusReviewed => '已审核';

  @override
  String notifCoTeacher(Object from, Object name) {
    return '$from 已将你添加为“$name”的协作教师';
  }

  @override
  String notifComment(Object from, Object project) {
    return '$from 评论了 $project';
  }

  @override
  String notifSubmitted(Object from, Object project) {
    return '$from 提交了 $project 待审核';
  }

  @override
  String notifReviewed(Object from, Object project) {
    return '$from 已将 $project 标记为已审核';
  }

  @override
  String notifReturned(Object from, Object project) {
    return '$from 将 $project 退回草稿';
  }

  @override
  String get editors => '编辑器';

  @override
  String get filmcraftShortcuts => 'FilmCraft 快捷键';

  @override
  String get scriptcraftShortcuts => 'ScriptCraft 快捷键';

  @override
  String get deckcraftShortcuts => 'DeckCraft 快捷键';

  @override
  String get searchShortcuts => '搜索操作';

  @override
  String get pressShortcut => '按下新的快捷键';

  @override
  String shortcutConflict(Object action) {
    return '已被 $action 使用';
  }

  @override
  String get clearShortcut => '清除';

  @override
  String get unbound => '未绑定';

  @override
  String get resetToDefault => '恢复默认';

  @override
  String get resetAllShortcuts => '重置所有快捷键';

  @override
  String get resetAllShortcutsBody => '将所有快捷键恢复为默认？';

  @override
  String unsupportedUploadType(Object names) {
    return '不允许的文件类型：$names';
  }

  @override
  String get assign => '分配';

  @override
  String get assignProject => '分配给学生';

  @override
  String get assignment => '作业';

  @override
  String get dueDate => '截止日期';

  @override
  String get noDueDate => '无截止日期';

  @override
  String get allowWithdraw => '允许撤回提交';

  @override
  String get maxSubmissions => '最大提交次数（0 为不限）';

  @override
  String get hiddenFromStudents => '对学生隐藏';

  @override
  String get lockedForStudents => '锁定';

  @override
  String get submissions => '提交情况';

  @override
  String attemptsUsed(Object max, Object used) {
    return '已用 $used/$max 次';
  }

  @override
  String get overdue => '已逾期';

  @override
  String get unassign => '移除作业';

  @override
  String get unassignBody => '移除该作业？学生的副本将保留为普通项目。';

  @override
  String get noStudents => '没有可分配的学生';

  @override
  String get lateSubmission => '迟交';

  @override
  String get assignedToYou => '布置给你的作业';

  @override
  String get dueNow => '已到期';

  @override
  String inMinutes(Object count) {
    return '$count 分钟后';
  }

  @override
  String inHours(Object count) {
    return '$count 小时后';
  }

  @override
  String inDays(Object count) {
    return '$count 天后';
  }

  @override
  String get notStarted => '未开始';

  @override
  String get inProgress => '进行中';

  @override
  String inviteUsedBy(Object name) {
    return '已被 $name 使用';
  }

  @override
  String get wipeAudit => '清空日志';

  @override
  String get wipeAuditBody => '删除此活动日志中的所有条目？此操作无法撤销。';

  @override
  String get nodeSetupHint => '在另一台机器上安装 WFM，在此创建节点，然后运行显示的命令。节点会轮询此服务器获取渲染任务。';

  @override
  String get nodeGuide => '配置指南';

  @override
  String get storage => '存储';

  @override
  String get storageMedia => '媒体存储';

  @override
  String get storageDatabase => '数据库';

  @override
  String get storageNoUsers => '暂无用户使用存储。';

  @override
  String get openSubmissions => '开放提交';

  @override
  String get closeSubmissions => '关闭提交';

  @override
  String submitConfirmBody(Object name) {
    return '提交 $name 以供审核？';
  }

  @override
  String get reply => '回复';

  @override
  String replyingTo(Object name) {
    return '回复 $name';
  }

  @override
  String get writeReply => '写下回复';

  @override
  String notifReply(Object from, Object project) {
    return '$from 在 $project 中回复了你';
  }

  @override
  String get recentProjects => '最近的项目';

  @override
  String get latestActivity => '最新动态';
}
