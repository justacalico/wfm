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
  String get tagline => '整个班级的影片项目，集中在一处。';

  @override
  String get heroBody =>
      'WFM 是一个自托管的媒体管理器，面向学校影视课程。学生上传素材，在浏览器编辑器中剪辑，并排队渲染。教师则掌控账户、权限和活动记录。';

  @override
  String get openApp => '打开应用';

  @override
  String get featureEditTitle => '在浏览器中剪辑';

  @override
  String get featureEditBody => '由 FilmCraft 驱动的时间线剪辑，无需安装。';

  @override
  String get featureMediaTitle => '媒体井井有条';

  @override
  String get featureMediaBody => '每个项目都有 Raw、Audio、Images 和 Exports 文件夹。';

  @override
  String get featureRenderTitle => '服务器渲染';

  @override
  String get featureRenderBody => '在服务器或远程渲染节点上排队导出。';

  @override
  String get featureSchoolTitle => '为学校打造';

  @override
  String get featureSchoolBody => '学生、协管、教师和管理员角色，带审计日志。';

  @override
  String get downloadsTitle => '下载';

  @override
  String get downloadsBody => '直接从 GitLab 获取最新版本。';

  @override
  String get releasesError => '暂时无法加载版本列表。';

  @override
  String get viewAllReleases => '在 GitLab 上查看全部版本';

  @override
  String get licenseNote => '自由开源软件 (AGPL-3.0)。';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeOled => '纯黑';

  @override
  String get language => '语言';

  @override
  String get langSystem => '跟随系统';

  @override
  String get showcaseTimeline => '在浏览器的时间线上剪辑';

  @override
  String get showcaseFiles => '每个项目都有托管文件夹';

  @override
  String get showcaseRenders => '在服务器上看着导出完成';

  @override
  String get screenshotsTitle => '界面截图';
}
