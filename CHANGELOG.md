# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
## v0.16.0 - 2026-11-19
#### Features
- show Loading media while FilmCraft restores host media - (54faf33) - calico, *Devin*

- - -

## v0.15.0 - 2026-11-19
#### Features
- move the sessions list into its own settings sub-page - (3bea9aa) - calico, *Devin*
#### Bug Fixes
- send web upload chunks as Blob slices to avoid UI-thread copies - (2035683) - calico, *Devin*

- - -

## v0.14.1 - 2026-11-19
#### Bug Fixes
- throttle upload progress notifications - (c772198) - calico, *Devin*

- - -

## v0.14.0 - 2026-11-19
#### Features
- rename project card Open action to Edit - (9fb2a0b) - calico, *Devin*

- - -

## v0.13.1 - 2026-11-19
#### Bug Fixes
- read filmcraft:open names before the host crate's basename clean - (d5f8477) - calico, *Devin*

- - -

## v0.13.0 - 2026-11-19
#### Features
- 集成 DeckCraft 故事板 - (8c56f0c) - calico
- 集成 ScriptCraft 剧本编辑器 - (9773ea8) - calico
- 管理界面的 Windows/macOS/Linux 桌面端 - (1504b34) - calico
- 设置页管理 FilmCraft 快捷键 - (8e7016b) - calico
- 项目评论与送审状态 - (4561868) - calico
- 项目复制与教师模板 - (595be52) - calico
- 项目只读分享链接 - (30af54b) - calico
- 应用内通知收件箱 - (617d929) - calico
- 存储用量与配额 - (b1295b2) - calico
- 教师自动共享列表 - (6380fbf) - calico
- “与我共享”页面与导航角标 - (7a3d409) - calico
- 按用户名邀请共享项目 - (865fc3e) - calico
- 邀请码自助注册 - (c0737cc) - calico
- 分块上传与可配置块大小 - (f64944a) - calico
- 审计日志保留期、筛选与分页 - (f2b5673) - calico
- 项目页在壳布局内打开 - (e70dbb3) - calico
- 用户头像上传与展示 - (ee7b355) - calico
- 批量文件操作与目录打包下载 - (334d94c) - calico
- 文件拖拽上传与逐文件进度 - (4a2d233) - calico
- 文件页媒体缩略图与预览 - (3715ab2) - calico
- 教师可查看学生项目并接管 - (695d06f) - calico
- 会话管理列表与撤销 - (db15307) - calico
- FilmCraft 移除本地项目入口 - (ba049ef) - calico
- FilmCraft 移除项目设置本地路径页 - (566d1fc) - calico
- FilmCraft 移除另存为模板 - (0f363d5) - calico
- FilmCraft 图形菜单改名 - (637ea7a) - calico
- 渲染列表重试删除与分页 - (50f3918) - calico
- FilmCraft 只保留编辑模式 - (f1143e4) - calico
- 精简 FilmCraft 关于对话框 - (5b36f10) - calico
- 去掉 FilmCraft 顶栏音量和全屏按钮 - (8ea69a7) - calico
- 设置页显示许可证和 GitLab 链接 - (b96dcd6) - calico
#### Bug Fixes
- 移除未跟踪的补丁目录复制 - (9e507c9) - calico
- 修复 Docker 镜像构建 - (82b2945) - calico
- 快捷键补丁改为基于最新补丁序列生成 - (2d3e1f8) - calico
- 补齐 postgres 测试 User 字段 - (d42fbb3) - calico
- postgres 测试补 avatar 字段 - (9ee9d78) - calico
- 打开项目时按需拉取媒体 - (ba273a6) - calico
- 编辑锁丢失时阻止写入并提示 - (ca12c09) - calico
- FilmCraft 宿主传输改用无歧义格式 - (f09be29) - calico
- 渲染任务校验缺失媒体与输出文件 - (6bd76da) - calico
- FilmCraft 仅限宿主模式并校验消息来源 - (c4ec882) - calico
- FilmCraft 跟随应用主题 - (0878d2f) - calico
- 隐藏 FilmCraft 项目管理器入口 - (25b467b) - calico
- 设置页移除上次登录时间 - (9f88460) - calico
- 补齐测试格式 - (beecfea) - calico

- - -

## v0.12.0 - 2026-11-18
#### Features
- (**projects**) 支持置顶项目 - (dd17a85) - calico
- 支持删除账号 - (fa1f943) - calico

- - -

## v0.11.0 - 2026-11-18
#### Features
- (**projects**) 记录项目最近访问时间 - (8b500b2) - calico

- - -

## v0.10.0 - 2026-11-18
#### Features
- (**projects**) 项目页支持搜索和排序 - (a87ae38) - calico
#### Bug Fixes
- (**ui**) 清理控制器泄漏、提示条位置与错误重试 - (383a0f3) - calico

- - -

## v0.9.0 - 2026-11-18
#### Features
- (**files**) 文件页增加列表/网格视图切换 - (991b140) - calico

- - -

## v0.8.0 - 2026-11-18
#### Features
- (**projects**) 项目页增加列表/网格视图切换 - (0f286f2) - calico
#### Bug Fixes
- (**accounts**) 对话框提交前做本地校验 - (cfbd5b9) - calico

- - -

## v0.7.1 - 2026-11-18
#### Bug Fixes
- (**l10n**) 补上英语语言选项并修正语言偏好存储 - (2971406) - calico

- - -

## v0.7.0 - 2026-11-18
#### Features
- (**projects**) 卡片添加渲染按钮 - (2183a67) - calico
- (**projects**) 卡片按可用宽度自适应排列 - (b8d8733) - calico

- - -

## v0.6.4 - 2026-11-18
#### Bug Fixes
- (**projects**) 打开按钮移到卡片右下角 - (6297ff4) - calico

- - -

## v0.6.3 - 2026-11-18
#### Bug Fixes
- (**manage**) 账号列表为空时显示占位提示 - (b13e2cb) - calico

- - -

## v0.6.2 - 2026-11-18
#### Bug Fixes
- (**theme**) 主题选择器改为下拉框 - (49ba226) - calico

- - -

## v0.6.1 - 2026-11-18
#### Bug Fixes
- (**theme**) 默认主题改为跟随系统 - (35a9ac0) - calico

- - -

## v0.6.0 - 2026-11-18
#### Features
- (**shell**) show app icon in nav sidebar title - (b294d24) - calico

- - -

## v0.5.18 - 2026-11-18
#### Bug Fixes
- (**settings**) keep proxies edits across rebuilds - (e74c8d9) - calico

- - -

## v0.5.17 - 2026-11-18
#### Bug Fixes
- distinct auth and server-error states in the app shell - (fbaea7d) - Devin

- - -

## v0.5.16 - 2026-11-18
#### Bug Fixes
- stream large file transfers instead of buffering in memory - (d7dd534) - Devin

- - -

## v0.5.15 - 2026-11-18
#### Bug Fixes
- server config and api polish nits - (c4382fd) - Devin
- enforce unique render node names and reserve synthetic worker identities - (0932dbc) - Devin

- - -

## v0.5.14 - 2026-11-18
#### Bug Fixes
- 修复 Postgres 后端迁移与用户名大小写并纳入持续集成 - (efc7441) - calico

- - -

## v0.5.13 - 2026-11-18
#### Bug Fixes
- S3 后端时间戳、对象大小与 Range 边界及默认密钥修正 - (74d4ff1) - calico
- 过期渲染任务不再重复发布输出并清理取消标记 - (b4029cd) - calico

- - -

## v0.5.12 - 2026-11-18
#### Bug Fixes
- 补齐审计日志缺失的目录创建渲染取消与节点管理记录 - (24fb7ae) - calico

- - -

## v0.5.11 - 2026-11-18
#### Bug Fixes
- 限制渲染节点仅能操作自己认领的任务 - (737fe43) - calico

- - -

## v0.5.10 - 2026-11-18
#### Bug Fixes
- 未知角色值映射为学生而非所有者防止提权 - (88f7fae) - calico, *Devin*

- - -

## v0.5.9 - 2026-11-18
#### Bug Fixes
- 原子化初始化防止并发请求创建两个所有者账户 - (c1886cd) - calico, *Devin*
- 定期清理残留的临时与暂存目录防止磁盘泄漏 - (1bc3cba) - calico, *Devin*

- - -

## v0.5.8 - 2026-11-17
#### Bug Fixes
- 容器内以非 root 运行并添加健康检查 - (51a78fa) - calico, *Devin*

- - -

## v0.5.7 - 2026-11-17
#### Bug Fixes
- 修改密码后仅保留当前会话其余全部注销 - (0548997) - calico, *Devin*

- - -

## v0.5.6 - 2026-11-17
#### Bug Fixes
- 定期清理登录节流表防止其无限增长 - (4cac605) - calico, *Devin*

- - -

## v0.5.5 - 2026-11-17
#### Bug Fixes
- 发布脚本同步 server crate 版本使 /api/version 跟随发布标签 - (ee69ec3) - calico, *Devin*

- - -

## v0.5.4 - 2026-11-17
#### Bug Fixes
- FilmCraft 包装页在非安全上下文下生成 UUID 并可诊断加载错误 - (5abb5f4) - calico, *Devin*

- - -

## v0.5.3 - 2026-11-17
#### Bug Fixes
- 窄屏管理页去掉重复标题仅保留标签栏 - (4c43506) - calico, *Devin*

- - -

## v0.5.2 - 2026-11-17
#### Bug Fixes
- 渲染对话框对畸形 JSON 参数提示而非崩溃 - (bd13862) - calico, *Devin*

- - -

## v0.5.1 - 2026-11-17
#### Bug Fixes
- 发布卡片链接到 GitLab 发布页面而非 API JSON - (4589dc3) - calico, *Devin*

- - -

## v0.5.0 - 2026-11-17
#### Features
- 用 FilmCraft 引擎替换自定义渲染 - (68ac0a4) - calico
- 移除媒体浏览器导入入口并显示上传进度 - (e1d9756) - calico
- 支持编辑已有账号 - (c985d5e) - calico
#### Bug Fixes
- FilmCraft 加载失败时提示返回 WFM - (6dc86b6) - Devin

- - -

## v0.4.3 - 2026-11-17
#### Bug Fixes
- 修复文件上传与 FilmCraft 存储同步 - (df2eebd) - calico

- - -

## v0.4.2 - 2026-11-17
#### Bug Fixes
- 发布产物按名下载避免缓存工件干扰 - (5f7a895) - calico

- - -

## v0.4.1 - 2026-11-17
#### Bug Fixes
- 镜像同步允许强制推送 - (faf8027) - calico
- 修复发布产物校验步骤 - (7806ca4) - calico

- - -

## v0.4.0 - 2026-11-17
#### Features
- 发布 GitLab 注册表镜像与一键部署 - (8a8fa37) - calico
- 精简 FilmCraft 界面并改用打开按钮 - (44b08d4) - calico

- - -

## v0.3.0 - 2026-11-17
#### Features
- FilmCraft 源码补丁与项目媒体集成 - (ff79110) - calico
#### Bug Fixes
- filmcraft 路由放行内联脚本 - (cb714c5) - calico

- - -

## v0.2.0 - 2026-11-17
#### Features
- 项目分组与标签 - (d0b2d7a) - calico
#### Bug Fixes
- 窄屏设置页布局修正 - (c85c2d5) - calico
- 移动端首页卡片铺满宽度 - (bd6c137) - calico
- 窄屏下主题切换改为弹出菜单 - (8f1d14a) - calico
- 修复主题切换与通知样式 - (9c37f4e) - calico
- 登录前界面与通知提示优化 - (8ad7608) - calico

- - -

## v0.1.2 - 2026-11-16
#### Bug Fixes
- 前端资源全部改为同源加载 - (ae127cd) - calico

- - -

## v0.1.1 - 2026-11-16
#### Bug Fixes
- Pages 根域名下使用根资源路径 - (c3be4c3) - calico, *Devin*

- - -

## v0.1.0 - 2026-11-16
#### Features
- 落地页截图区块与代码格式化 - (424116a) - calico
- 落地页：本地化、主题、发布与展示图形 - (9e2c21d) - calico
- 完整本地化、OLED 主题与更新检查 - (6fd437d) - calico
- 受信代理与所有者服务器设置 - (1269659) - calico
- 落地页与项目文档 - (ec69ab4) - calico
- 应用界面：项目文件、渲染队列、账号管理与静态资源压缩 - (ec318fb) - calico
- Flutter 界面：登录、项目、管理、设置 - (b367a1c) - calico
- 后端：Rust 服务、数据库层与 S3 媒体存储 - (73da5a8) - calico
#### Bug Fixes
- 修复发布构建的 FilmCraft 拉取与 arm64 Flutter - (0e2d7fe) - calico, *Devin*
- SSH 密钥脚本兼容 sh - (bb09083) - calico
- CI 验证顺序与测试导入 - (ab67129) - calico
- 编辑器页面：修复会话解析与关闭时释放锁 - (46f2f9b) - calico
- 初始化后自动登录、渲染上传改为落盘、ffprobe 补齐时长 - (b7e928c) - calico

- - -

Changelog generated by [cocogitto](https://github.com/cocogitto/cocogitto).