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
  String get download => '下载';

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
  String get cardProjects => '项目';

  @override
  String get cardProjectsSub => '打开你的影片项目';

  @override
  String get cardManage => '管理';

  @override
  String get cardManageSub => '账户与权限';

  @override
  String get cardSettings => '设置';

  @override
  String get cardSettingsSub => '主题和语言';

  @override
  String get projects => '项目';

  @override
  String get newProject => '新建项目';

  @override
  String get projectName => '项目名称';

  @override
  String get noProjects => '还没有项目，创建一个开始使用。';

  @override
  String createdAgo(Object when) {
    return '创建于 $when';
  }

  @override
  String get editInFilmcraft => '编辑';

  @override
  String get openScript => '剧本';

  @override
  String get openBoards => '故事板';

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
  String get newGroup => '新建分组';

  @override
  String get groupName => '分组名称';

  @override
  String get ungrouped => '未分组';

  @override
  String get noGroup => '无分组';

  @override
  String get moveToGroup => '移动到分组';

  @override
  String get renameGroup => '重命名分组';

  @override
  String deleteGroupBody(Object name) {
    return '删除分组“$name”？其中的项目会保留并变为未分组。';
  }

  @override
  String get editTags => '编辑标签';

  @override
  String get tagsHint => '标签，用逗号分隔';

  @override
  String get noMatchingProjects => '没有符合此标签的项目。';

  @override
  String get files => '文件';

  @override
  String get renders => '渲染';

  @override
  String get emptyFolder => '空文件夹';

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
  String renderStatusWorker(Object status, Object worker, Object when) {
    return '$status，节点 $worker  ·  $when';
  }

  @override
  String renderStatus(Object status, Object when) {
    return '$status  ·  $when';
  }

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
  String get renderMode => '渲染位置';

  @override
  String get renderOnDevice => '本机渲染';

  @override
  String get renderOnServer => '服务器渲染';

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
  String get serverUrl => '服务器地址';

  @override
  String get connect => '连接';

  @override
  String get connecting => '连接中…';

  @override
  String finishSetupInBrowser(String url) {
    return '该服务器还没有管理员账号。请在浏览器中打开 $url 完成初始化。';
  }

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
  String get readOnly => '只读';

  @override
  String get takeOver => '接管';

  @override
  String takeOverBody(Object name) {
    return '接管项目 $name？';
  }

  @override
  String ownedBy(Object name) {
    return '$name 的项目';
  }

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
  String get noShares => '还没有人与你共享内容';

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
}
