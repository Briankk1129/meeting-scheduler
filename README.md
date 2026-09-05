# 班主任会议在线排期系统

原生 HTML + CSS + JavaScript，Supabase Auth/PostgreSQL/RLS，GitHub Pages 静态部署。

## 当前状态

- 现有排期核心已迁移，300 组随机输入与原版对照一致。
- 数据库和 teacher-portal Edge Function 已部署到 `dettcrledxjrhtitsbhx`。
- 前端已配置该项目的 **publishable key**，不包含 service_role 或数据库密码。
- GitHub Pages 已发布：[班主任入口](https://briankk1129.github.io/meeting-scheduler/) · [管理员入口](https://briankk1129.github.io/meeting-scheduler/admin/)。
- 主代码仓库：[Briankk1129/meeting-scheduler](https://github.com/Briankk1129/meeting-scheduler)。
- 正式管理员账号已创建并授予 admin 角色。
- 测试记录和各 Phase 的文件/测试/限制见 [阶段交付](docs/PHASES.md)。

## 本机打开

Mac 双击 `启动.command`，打开 http://127.0.0.1:4173/admin/ 。

如系统拦截脚本，在项目目录运行：

```sh
python3 -m http.server 4173 --bind 127.0.0.1
```

本机页面使用真实云端数据库。本机地址只能在这台电脑打开；给老师发链接前，先部署 GitHub Pages。

## 创建管理员

1. 在 Supabase 项目 → Authentication → Users → Add user 中创建邮箱密码用户，按需要勾选 Auto Confirm。
2. 在 SQL Editor 执行以下 SQL，将邮箱替换为刚创建的邮箱。密码不放进 SQL，也不放进仓库。

```sql
insert into public.profiles(id, role, display_name)
select id, 'admin', '管理员'
from auth.users
where email = '替换为管理员邮箱'
on conflict (id) do update set role = 'admin';
```

检查返回影响行数为 1。浏览器不能自行改 role。第一版关闭公开注册，不提供老师账号注册页面。Supabase 控制台建议关闭 Allow new users to sign up。

3. 在 `/admin/login.html` 登录。可在“系统设置”修改密码。

## 正常使用流程

1. 会议日期与时间 → 选择年月，默认日本时区；只保留一套会议设置。日期日历和开始/结束时间始终显示，添加时间段时可自动创建新月份（自动加入启用老师和负责人）。
2. 班主任管理 → 新增或批量添加老师；后添加的档案会加入当前月份。
3. 会议日期与时间 → 在日历中多选日期（支持整月全选、工作日全选），设置一个或多个时间段并批量添加；重复时间自动跳过，单个时间仍可编辑。
4. 负责人管理 → 添加负责人，按日期勾选本月可参加日期（支持日期全选，保存时覆盖当天全部已设置时间段）；兼任班主任可关联相应档案。
5. 会议日期与时间 → 开放填写。草稿或未配置时间的月份显示“会议时间尚未准备好”。
6. 班主任管理 → 复制统一填写链接，发送给所有班主任。
7. 班主任打开同一链接，选择月份和自己的姓名/班级，填写全部可参加时间。所有人看到该月相同的时间段，并可查看该月已生成的会议安排。
8. 填写情况 → 查看提交进度，修改已填日期/时间段或删除整份填写（恢复未填写）；管理首页/填写情况自动更新，其他页面提示数据变化以保护未保存的表单。
9. 关闭填写 → 设置固定安排及本月不安排 → 生成并保存排期。
10. 会议日历直接显示老师姓名，点击查看详情，数据导出下载会议安排和填写情况。

老师可以提交“全部没空”，仍记录为已填写。首次提交时间保留，重交只替换最新选择。填写页面刷新可恢复数据。

## GitHub Pages 部署

把本目录作为仓库根目录，推送到 `main`。在仓库 Settings → Pages → Build and deployment 选择 **GitHub Actions**。

`.github/workflows/pages.yml` 会运行算法测试、构建 `dist/` 并发布。无构建框架、无需 npm install。

```sh
node --test tests/*.test.js
node scripts/build.js
```

站点路径为 `https://用户名.github.io/仓库名/`，管理员入口追加 `admin/`。所有资源使用相对路径，支持仓库子路径。

只发布 `dist/`。其中包含 HTML、CSS、JS 和浏览器依赖，不包含 SQL、测试、文档或后端源码。统一入口不再使用个人 token，旧链接也进入统一选择页面。

## 在其他 Supabase 项目安装

当前项目已经安装，无需重复执行！安装到全新项目时：

1. 执行 `supabase/install.sql`（已包含事务与统一入口升级）。
2. 修改 `js/config.js` 的 URL 和 publishable key。
3. 部署 `supabase/functions/teacher-portal/index.ts` 为 `teacher-portal`。设置 `verify_jwt=false`，因为按产品要求，此入口公开提供月份和姓名选择，不使用老师 Auth JWT。
4. Supabase 自动提供 `SUPABASE_URL` 和 `SUPABASE_SERVICE_ROLE_KEY` 给 Edge Function；这些值仅用于后端。
5. 可选设置 Edge Function 的 `ALLOWED_ORIGINS`，逗号分隔的完整来源，例如 `https://yourname.github.io,http://127.0.0.1:4173`。CORS 仅限制浏览器来源，统一入口不核验填写者身份。
6. 运行 `supabase/tests/shared-portal.sql`，它会回滚测试数据。旧版 security/isolation.sql 记录个人 token 模式的历史测试，不适用于新版入口。不要并发执行同一个测试。
7. 创建管理员账号。

## 数据和权限

- 所有业务表启用 RLS；管理员读取策略检查 `profiles.role`。
- 管理员浏览器写入统一走 `admin_command`：服务端检查角色、锁定月份、验证数据和 revision。
- `profiles` 浏览器只读，普通账号无法提升角色。
- `anon` 无任何业务表读写权限；普通 authenticated 用户也无法读取后台。
- 旧 token 与权限表保留以兼容历史资料，但界面已移除，旧 token RPC 已禁用。
- `shared_teacher_portal` 数据库函数仅允许 service_role 调用；Edge Function 严格接收月份、名单中的 teacher_id 和时间 UUID，不转发任意查询。
- 统一入口公开显示当月启用班主任名单、公共时间段和已生成的会议安排；选择姓名后显示该人的已填内容。
- 可用时间直接关联月份名单与时间段，不再依赖逐人权限表；升级保留已有填写记录。
- 提交与关闭月份共用数据库行锁；过期版本返回冲突，不覆盖较新的填写。
- 排期保存再次校验重复安排、容量、可用时间、负责人、固定安排和月份范围。
- 结果保存为批次；输入更改后旧结果标记过期，导出要求重新排期。

统一入口按姓名自选，不验证身份；任何获得入口的人都可以查看名单、会议安排及选择姓名代填。此为当前明确要求的共享填写方式，前端提交前提示确认姓名和班级。

## 与原版的差异

- 排期匹配顺序、座位展开、增广路径、固定失败不改排等行为保留。
- 负责人改为数据库配置；至少一位负责人有空即可使用该时间。
- 结果使用 UUID，支持同名老师；显示姓名和班级快照。
- 排期是最大人数匹配，不保证人数均衡或最少场次。
- Excel 第一张工作表、自动表头检测、“非空即可参加”规则保留。导入先预览，不会覆盖其他月份。
- 无时间列的“姓名/班级”表也能导入。旧 availability 表可选择迁移到当前月份；缺少年份使用当前年份，日期不属于当前月份则拒绝。
- 旧表中与已配置启用负责人同名的行作为负责人 availability 导入；没有匹配则作为班主任新档案。请先建立负责人，预览后确认。
- 导入记录标记来源为 import，时间是导入时间，不伪造历史提交时间。
- XLSX.js 从 0.18.5 更新为固定 0.20.3，保留原 API，并规避旧解析版本已知问题。
- 已有历史排期引用的时间段禁止直接修改或删除，需新增时间段；保留历史日期和导出一致性。
- 不支持跨午夜或跨月份的单个时间段。
- 本版按单个学校/管理团队设计，多个管理员共享全部业务数据。

## 依赖

浏览器文件随项目分发，无运行时 CDN 依赖：

- supabase-js 2.57.4（MIT）
- FullCalendar 6.1.19（MIT）
- SheetJS CE 0.20.3（Apache-2.0）

来源及许可证见 `vendor/README.md`。网络断开会显示失败，不会声称已提交成功。localStorage 仅用于 Auth 会话与当前月份偏好，业务数据以 Supabase 为准。
