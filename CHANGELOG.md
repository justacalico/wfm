# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
## v0.45.0 - 2026-11-28
#### Features
- (**app**) 备份按钮移至项目管理页 - (ee3e619) - calico

- - -

## v0.44.2 - 2026-11-27
#### Bug Fixes
- (**settings**) avoid ambiguous backup limit dropdown in tests - (976c338) - HttpAnimations
- protect editor saves and add project backups - (0b92eac) - HttpAnimations

- - -

## v0.44.1 - 2026-11-25
#### Bug Fixes
- 修复时间线音频波形不生成 - (52b71c0) - calico

- - -

## v0.44.0 - 2026-11-24
#### Features
- 移除首页快捷卡片 - (6fe3ccf) - calico

- - -

## v0.43.0 - 2026-11-23
#### Features
- (**app**) 首页显示任务与动态 - (04b0498) - calico
- (**app**) 评论支持嵌套回复 - (9187467) - calico
- (**app**) 提交前弹出确认 - (1de31d7) - calico
- (**app**) 创建项目后停留当前页 - (607cea3) - calico
- (**app**) 用户项目页在应用壳内打开 - (c019040) - calico
- (**app**) 渲染节点加入设置说明 - (2432ec9) - calico
- (**server**) 项目提交需教师批准 - (64d4132) - calico
- (**server**) 新增存储用量统计 - (c4fbc02) - calico
- (**server**) 所有者可清空审计日志 - (2457e68) - calico
- (**server**) 撤销邀请直接删除并显示使用人 - (020e03e) - calico
- (**server**) 仅教师可创建学生和班级 - (3df6df2) - calico
#### Bug Fixes
- (**app**) 文件夹卡片支持单击并匹配高度 - (d43e5fd) - calico

- - -

## v0.42.0 - 2026-11-23
#### Features
- (**app**) 设置页添加 AI 助手令牌管理 - (fe284b4) - calico
- (**server**) 新增 MCP 远程接口与代理令牌 - (493d567) - calico

- - -

## v0.41.2 - 2026-11-23
#### Bug Fixes
- (**deckcraft**) 由 WFM 托管 DeckCraft 快捷键 - (a610685) - calico
- (**server**) docker 构建补上 deckcraft 快捷键目录 - (52cfea1) - calico

- - -

## v0.41.1 - 2026-11-23
#### Bug Fixes
- (**server**) docker 镜像构建时应用 deckcraft 补丁 - (aaf0f62) - calico

- - -

## v0.41.0 - 2026-11-22
#### Features
- (**app**) 渲染输出名冲突时确认覆盖或自动改名 - (0233d6b) - calico
- (**app**) 新建渲染默认在服务器上渲染 - (6950838) - calico
#### Bug Fixes
- (**app**) 通知跳转前检查项目是否仍存在 - (e3298de) - calico
- (**app**) 渲染通知点击后打开项目渲染页 - (98fdf18) - calico
- (**server**) 空 project.fcproj 不再运行 inspect；非 JSON 响应给出正常错误 - (806d771) - calico
- (**server**) S3 缺失对象按未找到处理 - (724a869) - calico

- - -

## v0.40.1 - 2026-11-22
#### Bug Fixes
- (**app**) 项目卡片显示上次编辑时间 - (6c113f8) - calico
- (**app**) 系统主题按平台亮度传给编辑器 - (b95ee02) - calico
- (**server**) 项目活动时间只在编辑操作时更新 - (036c3a2) - calico

- - -

## v0.40.0 - 2026-11-22
#### Features
- (**scriptcraft**) 移除打印与文件导出 - (709142f) - calico
#### Bug Fixes
- (**scriptcraft**) 脚本保存按文档格式写回原路径 - (2b15874) - calico

- - -

## v0.39.0 - 2026-11-22
#### Features
- (**app**) 原生编辑器模式与本地检出同步 - (c4fee53) - calico
- (**crafts**) 原生缺失文档补丁与构建脚本 - (4d9bcce) - calico
- (**server**) 文件修订号与写前置条件，支持桌面同步 - (657413a) - calico
#### Bug Fixes
- (**app**) 首次打开时创建文档父目录 - (eb075fe) - calico
- (**crafts**) 强制 LF 检出以修复 Windows 补丁应用 - (bb40f9e) - calico
- (**windows**) 兼容 MSVC 移除实验协程后的插件编译 - (1d4d894) - calico

- - -

## v0.38.0 - 2026-11-20
#### Features
- DeckCraft 故事板锁定为编辑器并托管文件生成 - (cae0738) - calico
- 班级协作教师，主讲教师可添加协作教师共同管理班级 - (ca56d5b) - calico

- - -

## v0.37.0 - 2026-11-20
#### Features
- craft 编辑器适配移动端布局 - (8fedcbd) - calico
- 班级功能，教师可建班并在班级内隔离学生分享可见性 - (16fb512) - calico

- - -

## v0.36.3 - 2026-11-20
#### Bug Fixes
- 项目页只显示自己的项目，他人项目从管理页查看 - (5e366fa) - calico

- - -

## v0.36.2 - 2026-11-20
#### Bug Fixes
- 修复窄屏项目页与分享对话框布局 - (8162600) - calico

- - -

## v0.36.1 - 2026-11-20
#### Bug Fixes
- 修复窄屏账号列表文字挤压换行 - (d274a01) - calico

- - -

## v0.36.0 - 2026-11-20
#### Features
- 落地页补齐编剧分镜应用与新截图 - (1375409) - calico

- - -

## v0.35.0 - 2026-11-20
#### Features
- craft 应用 OLED 纯黑主题 - (9e34010) - calico

- - -

## v0.34.0 - 2026-11-20
#### Features
- 新建项目后直接进入项目页 - (d679bdf) - calico

- - -

## v0.33.0 - 2026-11-20
#### Features
- 空状态补充提示文案 - (1904a83) - calico

- - -

## v0.32.0 - 2026-11-20
#### Features
- 卡片按钮改为动词优先标签 - (4aa67c6) - calico

- - -

## v0.31.2 - 2026-11-20
#### Bug Fixes
- 项目卡片只在服务端允许时显示接管入口 - (bc1f645) - calico

- - -

## v0.31.1 - 2026-11-20
#### Bug Fixes
- 渲染媒体暂存名与客户端注册名一致 - (5ffccb0) - calico

- - -

## v0.31.0 - 2026-11-20
#### Features
- FilmCraft 打开后实时同步项目媒体列表 - (c9e3345) - calico

- - -

## v0.30.1 - 2026-11-20
#### Bug Fixes
- FilmCraft 宿主模式禁止本地文件导入 - (9740655) - calico

- - -

## v0.30.0 - 2026-11-20
#### Features
- 首页展示布置给我的作业 - (67cdbeb) - calico

- - -

## v0.29.0 - 2026-11-20
#### Features
- 作业布置与学生提交策略 - (f9224b2) - calico

- - -

## v0.28.0 - 2026-11-20
#### Features
- 按可见范围限制分享与账号树 - (91f4d11) - calico

- - -

## v0.27.0 - 2026-11-20
#### Features
- 锁定 DeckCraft 宿主模式 - (cbdba87) - calico

- - -

## v0.26.0 - 2026-11-20
#### Features
- ScriptCraft 快捷键由 WFM 设置管理 - (538d777) - calico
#### Bug Fixes
- Docker 构建包含 ScriptCraft 快捷键目录 - (67668eb) - calico

- - -

## v0.25.0 - 2026-11-20
#### Features
- 锁定 ScriptCraft 宿主模式 - (b2336ed) - calico

- - -

## v0.24.0 - 2026-11-20
#### Features
- 限制项目上传文件类型并校验文件内容 - (4287b2c) - calico

- - -

## v0.23.0 - 2026-11-20
#### Features
- allow only one active render per project - (5f9afaa) - calico
#### Bug Fixes
- 项目模板标记仅限教职工设置 - (afbfad3) - calico
- retry media bin restore while remote chunks load - (18902ea) - calico

- - -

## v0.22.2 - 2026-11-20
#### Bug Fixes
- block renames that change a file's extension - (87de79e) - calico

- - -

## v0.22.1 - 2026-11-20
#### Bug Fixes
- friendly rename errors and same-path no-ops - (f991d7f) - calico

- - -

## v0.22.0 - 2026-11-20
#### Features
- navigate to the renders tab after queuing a render - (37f02a4) - calico
#### Bug Fixes
- drop the worker name from render job status lines - (4cd40e9) - calico

- - -

## v0.21.2 - 2026-11-19
#### Bug Fixes
- keep the files tab's folder across project tab switches - (05cbc50) - calico
- bound remote media range fetches in FilmCraft - (f850131) - calico

- - -

## v0.21.1 - 2026-11-19
#### Bug Fixes
- run the update check through the server - (b430d78) - calico

- - -

## v0.21.0 - 2026-11-19
#### Features
- make ScriptCraft and DeckCraft follow the WFM theme - (d6f1336) - calico

- - -

## v0.20.0 - 2026-11-19
#### Features
- give ScriptCraft and DeckCraft their own document lock kinds - (7f9eb16) - calico

- - -

## v0.19.0 - 2026-11-19
#### Features
- in-app media preview modal for files - (078a0d4) - calico

- - -

## v0.18.0 - 2026-11-19
#### Features
- relative comment timestamps and author avatars - (f56d345) - calico
- slim project cards to three actions and move render/share to the menu - (6ad4a34) - calico
- group FilmCraft shortcuts under an Editors settings section - (e666933) - calico

- - -

## v0.17.0 - 2026-11-19
#### Features
- default new renders to the device and reorder advanced options - (bc408d8) - calico

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