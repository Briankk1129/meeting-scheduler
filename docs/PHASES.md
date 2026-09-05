# 分阶段交付与测试

用户提供的原版 `meeting-scheduler-local/index.html` 未修改。

## Phase 1：原版分析

已完成。旧版为单文件、本地 state/localStorage、XLSX.js。核心使用固定安排优先、容量展开和增广路径匹配。

保留重点：原始老师/时间排序、最少可选时间优先、固定失败不改排、负责人至少一位即可、不计容量、零容量、排除人员、未安排原因。

## Phase 2：数据库与权限

文件：`supabase/schema.sql`、`functions.sql`、`rls.sql`、`install.sql`、`tests/security.sql`、`tests/isolation.sql`。

功能：月份隔离、名单与月份关联、老师可选权限和实际选择分离、负责人配置、固定安排、排除、排期批次、token 摘要、RLS、事务写入与 revision 冲突检查。

真实 Supabase PostgreSQL 测试已通过：管理员读写；普通账号和匿名访问拒绝；不能自行提升角色；老师提交替换；空选择提交；过期版本拒绝；关闭填写后拒绝；排期保存；跨月份拒绝；Excel availability 导入；token 轮换；零容量拒绝；失败事务不残留半份排期。

部署项目：`dettcrledxjrhtitsbhx`。SQL 测试使用事务回滚，不保留假老师和假月份。

发现并修复：Supabase Data API 的 pg-safeupdate 检查要求显式 WHERE，月份版本更新已经兼容。

## Phase 3：管理员登录

文件：`admin/login.html`、`js/login.js`、`js/auth.js`、`js/supabase.js`、`js/config.js`。

功能：Supabase Auth 邮箱密码登录、身份和角色验证、刷新会话、退出、修改密码。业务权限由 RLS 和服务端检查保护。

测试：使用临时验收账号完成真实 Supabase Auth 登录；非管理员数据访问另由 SQL 测试覆盖。正式邮箱为 `briankk1129@gmail.com`，正式账号创建/角色设置状态见最终交付说明。

## Phase 4：后台管理

文件：`admin/index.html`、`js/admin.js`、`js/views/*`、`css/style.css`。

功能：独立导航视图、月份选择、名单增改停用删除、批量导入、日期与时间容量、负责人、按人授权、按日期全选、复制权限、所有老师追加开放、提交筛选。

测试方法：先创建月份，再添加两位老师、两天时间、一位负责人；分别开放不同时间。删除已关联历史排期的档案会被拒绝，使用停用保留历史。

发现并修复：创建月份后重复刷新可能覆盖新页面表单；自己的实时通知可能覆盖保存提示。现在创建月份只刷新一次，云端更新用独立提示。

## Phase 5：班主任在线填写

文件：`index.html`、`js/teacher.js`、`js/api/teacher-api.js`、`supabase/functions/teacher-portal/index.ts`。

功能：每人每月专属 token、只展示获授权时间、提交和修改、原选项恢复、首次/末次提交、停止填写、撤销链接。Edge Function 已部署。

测试方法：两位老师分别打开链接，检查选项不同；勾选提交后刷新，勾选保留；关闭填写后按钮隐藏且服务端拒绝写入。

发现并修复：同一标签页切换仅 fragment 不同的链接时需要重新加载身份；现在监听链接变更，清空旧视图并重新校验 token，异步响应也核对当前身份。

## Phase 6：排期迁移

文件：`js/scheduler/core.js`、`adapter.js`、`js/views/scheduler.js`、`tests/scheduler.test.js`、`tests/fixtures/legacy.html`。

功能：Supabase 快照转原算法输入，输出以 UUID 保存；固定安排优先，不安排排除，负责人不计人数，失败原因保留。

测试：8 个测试全部通过，其中包含 300 组固定种子输入与原版对照；专项覆盖增广路径、固定失败、容量0、同名ID、单个负责人、输入不变、旧表日期解析。

算法本身不依赖 Supabase、DOM、localStorage，可以单独执行。没有增加人数均衡或最少会议数量目标。

## Phase 7：会议日历

文件：`js/views/calendar.js`、`vendor/fullcalendar.js`。

功能：月视图、上一月/下一月/今天、点击日期/事件查看负责人、班主任和班级。没有创建的月份显示说明。

测试方法：保存排期后打开日历，点击事件核对时间、负责人和固定班主任。日历展示数据库结果，不根据老师填写临时推算。

## Phase 8：导出、异常处理与发布

文件：`js/excel/import.js`、`js/excel/export.js`、`js/views/export.js`、`scripts/build.js`、`.github/workflows/pages.yml`、`README.md`、`vendor/`。

功能：排期和提交情况 Excel 导出、原识别数据与未安排问题表、Excel 预览导入、手机布局、网络/权限/版本冲突提示、静态构建与 GitHub Pages 自动部署。

原 XLSX.js 0.18.5 更新为 0.20.3，API 保持兼容，浏览器依赖本地分发。

GitHub Pages 已发布到 https://briankk1129.github.io/meeting-scheduler/ 。仓库 main 分支通过 GitHub Actions 自动测试、构建并部署。

## 已知边界

- 已有历史排期引用的时间段不可直接改写或删除，新增时间段保留原会议历史。
- 免账号链接的持有人可以代填；可撤销并重新生成。
- 管理员共享全校数据，没有增加多学校租户层。
- 不支持跨午夜的单段会议；会议时区在月份设置中显式选择。
- Supabase 安全检查提示项目未开启泄露密码保护，这是 Auth 项目设置，可在正式账号启用时检查：[密码保护说明](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)。业务表未出现缺失 RLS 或公开 token 警告。

## 最终实际验收结果

2026-09-06，使用临时账号和独立 Chrome 会话，连接真实 Supabase：

- 邮箱密码登录、退出及刷新会话：通过。
- 创建月份、两位班主任、两个日期时间、一位负责人：通过。
- 所有老师追加开放，再单独限制第二位老师只可选择一个时间：通过。
- 两条真实 token 链接在独立手机会话访问：通过，只展示各自获授权时间。
- 两位老师实际提交、重新打开和刷新保持勾选：通过。
- 管理员读取两位老师已提交状态：通过。
- 关闭填写、设置固定安排、自动生成并保存：通过。
- 会议月历事件与详情：通过。
- 两个 Excel 文件实际下载并重新读取核对：通过。会议表含两位老师，第一位为固定安排，填写表两位均已提交。
- 关闭后老师不能编辑，页面重新载入仍能读取结果：通过。
- 完整流程浏览器脚本异常：0。
- 390×844 手机填写页、1440×1050 桌面月历截图已检查。

临时账号、月份、老师、负责人、token 和排期数据在验收后清理。截图使用的 2197 年数据仅为隔离测试，交付系统不包含该演示数据。

## 正式部署验证

- GitHub 仓库：Briankk1129/meeting-scheduler，保留原始提交历史。
- GitHub Actions 测试、构建、Pages 发布全部成功。
- 已核对线上首页、登录页、主脚本、样式和依赖文件的 SHA-256，与本机验证版本一致。
- 正式 /admin/ 未登录时跳转登录页；无 token 的班主任入口提示使用专属链接，浏览器控制台无错误。
- 正式管理员邮箱 briankk1129@gmail.com 尚未出现在 Supabase Auth 用户表，需要用户在控制台创建网站账号后设置 profiles.admin；Supabase 控制台登录账号与本网站登录账号是两回事。
