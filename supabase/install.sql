begin;
-- Run schema.sql, functions.sql, rls.sql together, in this order, in a transaction.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists meeting_private;
revoke all on schema meeting_private from public, anon, authenticated;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'user' check(role in ('admin','teacher','user')),
 display_name text not null default '', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.teachers (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 80),
 class_name text not null default '', active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.meeting_periods (
 id uuid primary key default gen_random_uuid(), year integer not null check(year between 2000 and 2200), month integer not null check(month between 1 and 12),
 title text not null check(length(trim(title))>0), status text not null default 'draft' check(status in ('draft','collecting','closed','scheduled')),
 timezone text not null default 'Asia/Shanghai' check(timezone in ('Asia/Shanghai','Asia/Tokyo')),
 default_capacity integer not null default 3 check(default_capacity between 1 and 100), revision integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(year,month)
);
create table public.period_teacher_status (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 teacher_id uuid not null references public.teachers(id) on delete restrict, name_snapshot text not null, class_snapshot text not null default '',
 excluded boolean not null default false, sort_order integer not null default 0,
 first_submitted_at timestamptz, last_submitted_at timestamptz, submission_source text check(submission_source in ('online','import')), submission_revision integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(period_id,teacher_id)
);
create table public.meeting_slots (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 meeting_date date not null, start_time time not null, end_time time not null,
 capacity_override integer check(capacity_override between 0 and 100), sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(start_time<end_time),
 unique(period_id,id), unique(period_id,meeting_date,start_time,end_time)
);
create table public.teacher_slot_permissions (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade, unique(period_id,teacher_id,slot_id)
);
create table public.teacher_availability (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id,slot_id) references public.teacher_slot_permissions(period_id,teacher_id,slot_id) on delete cascade,
 unique(period_id,teacher_id,slot_id)
);
create table public.leaders (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 80), active boolean not null default true,
 teacher_id uuid references public.teachers(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(teacher_id)
);
create table public.period_leaders (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 leader_id uuid not null references public.leaders(id) on delete restrict, name_snapshot text not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(period_id,leader_id)
);
create table public.leader_availability (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, leader_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,leader_id) references public.period_leaders(period_id,leader_id) on delete cascade,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade, unique(period_id,leader_id,slot_id)
);
create table public.fixed_assignments (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null, slot_id uuid not null, sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade, unique(period_id,teacher_id)
);
create table public.schedule_runs (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 source_revision integer not null, algorithm_version text not null, generated_by uuid references auth.users(id) on delete set null,
 is_current boolean not null default true, issues jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(period_id,id)
);
create unique index one_current_run on public.schedule_runs(period_id) where is_current;
create table public.meeting_assignments (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, run_id uuid not null, teacher_id uuid not null, slot_id uuid not null, is_fixed boolean not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,run_id) references public.schedule_runs(period_id,id) on delete cascade,
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete restrict,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete restrict, unique(run_id,teacher_id)
);
create table public.meeting_assignment_leaders (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, run_id uuid not null, leader_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,run_id) references public.schedule_runs(period_id,id) on delete cascade,
 foreign key(period_id,leader_id) references public.period_leaders(period_id,leader_id) on delete restrict,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete restrict, unique(run_id,slot_id,leader_id)
);
create table meeting_private.teacher_access_tokens (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null,
 token_hash text not null unique, expires_at timestamptz not null, revoked_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade
);
create unique index one_active_token on meeting_private.teacher_access_tokens(period_id,teacher_id) where revoked_at is null;
create index pts_teacher on public.period_teacher_status(teacher_id);
create index permissions_slot on public.teacher_slot_permissions(period_id,slot_id);
create index availability_slot on public.teacher_availability(period_id,slot_id);
create index leaders_teacher on public.leaders(teacher_id);
create index period_leaders_leader on public.period_leaders(leader_id);
create index leader_slots on public.leader_availability(period_id,slot_id);
create index fixed_slots on public.fixed_assignments(period_id,slot_id);
create index assignments_teacher on public.meeting_assignments(period_id,teacher_id);
create index assignments_slot on public.meeting_assignments(period_id,slot_id);
create index assignment_leaders_leader on public.meeting_assignment_leaders(period_id,leader_id);
create index assignment_leaders_slot on public.meeting_assignment_leaders(period_id,slot_id);
create index runs_creator on public.schedule_runs(generated_by);

create function meeting_private.touch_updated_at() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end $$;
do $$ declare n text; begin
 foreach n in array array['profiles','teachers','meeting_periods','period_teacher_status','meeting_slots','teacher_slot_permissions','teacher_availability','leaders','period_leaders','leader_availability','fixed_assignments','schedule_runs','meeting_assignments','meeting_assignment_leaders'] loop
 execute format('create trigger touch_updated_at before update on public.%I for each row execute function meeting_private.touch_updated_at()',n);
 execute format('alter table public.%I enable row level security',n);
 end loop;
end $$;
alter table meeting_private.teacher_access_tokens enable row level security;
create index assignments_run on public.meeting_assignments(period_id,run_id);
create index assignment_leaders_run on public.meeting_assignment_leaders(period_id,run_id);

create function meeting_private.is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;
create function public.admin_snapshot(p_period uuid default null) returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if not meeting_private.is_admin() then raise exception '需要管理员权限' using errcode='42501'; end if;
 return jsonb_build_object(
 'periods',coalesce((select jsonb_agg(x order by year desc,month desc) from public.meeting_periods x),'[]'),
 'teachers',coalesce((select jsonb_agg(x order by created_at,id) from public.teachers x),'[]'),
 'leaders',coalesce((select jsonb_agg(x order by created_at,id) from public.leaders x),'[]'),
 'members',coalesce((select jsonb_agg(x order by sort_order,id) from public.period_teacher_status x where period_id=p_period),'[]'),
 'slots',coalesce((select jsonb_agg(x order by sort_order,id) from public.meeting_slots x where period_id=p_period),'[]'),
 'permissions',coalesce((select jsonb_agg(x) from public.teacher_slot_permissions x where period_id=p_period),'[]'),
 'availability',coalesce((select jsonb_agg(x) from public.teacher_availability x where period_id=p_period),'[]'),
 'periodLeaders',coalesce((select jsonb_agg(x) from public.period_leaders x where period_id=p_period),'[]'),
 'leaderAvailability',coalesce((select jsonb_agg(x) from public.leader_availability x where period_id=p_period),'[]'),
 'fixed',coalesce((select jsonb_agg(x order by sort_order,id) from public.fixed_assignments x where period_id=p_period),'[]'),
 'runs',coalesce((select jsonb_agg(x) from public.schedule_runs x where period_id=p_period and is_current),'[]'),
 'assignments',coalesce((select jsonb_agg(x) from public.meeting_assignments x where period_id=p_period and run_id in(select id from public.schedule_runs where period_id=p_period and is_current)),'[]'),
 'assignmentLeaders',coalesce((select jsonb_agg(x) from public.meeting_assignment_leaders x where period_id=p_period and run_id in(select id from public.schedule_runs where period_id=p_period and is_current)),'[]')
 );
end $$;

create function meeting_private.admin_command(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 pid uuid := nullif(p_data->>'period_id','')::uuid; tid uuid; sid uuid; lid uuid; rid uuid; slot_ids uuid[]; idx integer; rec jsonb; raw_token text;
 period public.meeting_periods; result jsonb := '{}'::jsonb; global_action boolean;
begin
 if not meeting_private.is_admin() then raise exception '需要管理员权限' using errcode='42501'; end if;
 global_action := p_action in ('teacher_save','teacher_bulk','teacher_delete','leader_save');
 -- Every writer uses the same period locks, including global edits and teacher submissions.
 if global_action then perform 1 from public.meeting_periods order by id for update; end if;
 if pid is not null then
  select * into period from public.meeting_periods where id=pid for update;
  if not found then raise exception '月份不存在'; end if;
  if (p_data->>'revision')::integer is distinct from period.revision then raise exception '数据已变化，请刷新后重试' using errcode='40001'; end if;
 end if;
 if not global_action and p_action<>'period_create' and pid is null then raise exception '请先选择月份'; end if;
 case p_action
 when 'period_create' then
  insert into public.meeting_periods(year,month,title,timezone,default_capacity)
  values((p_data->>'year')::integer,(p_data->>'month')::integer,p_data->>'title',coalesce(p_data->>'timezone','Asia/Shanghai'),coalesce((p_data->>'default_capacity')::integer,3)) returning id into pid;
  insert into public.period_teacher_status(period_id,teacher_id,name_snapshot,class_snapshot,sort_order)
  select pid,id,name,class_name,row_number() over(order by created_at,id) from public.teachers where active;
  insert into public.period_leaders(period_id,leader_id,name_snapshot) select pid,id,name from public.leaders where active;
  result=jsonb_build_object('id',pid);
 when 'period_update' then
  if coalesce(p_data->>'status',period.status) not in ('draft','collecting','closed') then raise exception '请通过自动排期生成已排期状态'; end if;
  update public.meeting_periods set title=coalesce(p_data->>'title',title),status=coalesce(p_data->>'status',status),
   default_capacity=coalesce((p_data->>'default_capacity')::integer,default_capacity),timezone=coalesce(p_data->>'timezone',timezone) where id=pid;
 when 'teacher_save' then
  tid=nullif(p_data->>'id','')::uuid;
  if tid is null then
   insert into public.teachers(name,class_name,active) values(trim(p_data->>'name'),coalesce(p_data->>'class_name',''),coalesce((p_data->>'active')::boolean,true)) returning id into tid;
  else
   update public.teachers set name=trim(p_data->>'name'),class_name=coalesce(p_data->>'class_name',''),active=coalesce((p_data->>'active')::boolean,true) where id=tid;
   if not found then raise exception '老师不存在'; end if;
  end if;
  if pid is not null then insert into public.period_teacher_status(period_id,teacher_id,name_snapshot,class_snapshot,sort_order)
   select pid,id,name,class_name,(select coalesce(max(sort_order),0)+1 from public.period_teacher_status where period_id=pid) from public.teachers where id=tid on conflict do nothing; end if;
  update public.period_teacher_status m set name_snapshot=t.name,class_snapshot=t.class_name from public.teachers t where t.id=tid and m.teacher_id=tid and not exists(select 1 from public.schedule_runs r where r.period_id=m.period_id);
  result=jsonb_build_object('id',tid);
 when 'teacher_bulk' then
  if jsonb_array_length(p_data->'teachers')>500 then raise exception '每次最多导入500位'; end if;
  for rec in select value from jsonb_array_elements(p_data->'teachers') loop
   insert into public.teachers(name,class_name) values(trim(rec->>'name'),coalesce(rec->>'class_name','')) returning id into tid;
   if pid is not null then insert into public.period_teacher_status(period_id,teacher_id,name_snapshot,class_snapshot,sort_order)
    values(pid,tid,trim(rec->>'name'),coalesce(rec->>'class_name',''),(select coalesce(max(sort_order),0)+1 from public.period_teacher_status where period_id=pid)); end if;
  end loop;
 when 'teacher_delete' then
  tid=(p_data->>'id')::uuid;
  if exists(select 1 from public.meeting_assignments where teacher_id=tid) then raise exception '老师已有历史排期，请使用停用'; end if;
  delete from public.period_teacher_status where teacher_id=tid;
  delete from public.teachers where id=tid; -- Linked leader identities still use RESTRICT.

 when 'member_add' then
  insert into public.period_teacher_status(period_id,teacher_id,name_snapshot,class_snapshot,sort_order)
  select pid,id,name,class_name,(select coalesce(max(sort_order),0) from public.period_teacher_status where period_id=pid)+row_number() over(order by created_at,id)
  from public.teachers where active and id in(select value::uuid from jsonb_array_elements_text(p_data->'teacher_ids')) on conflict do nothing;
 when 'submission_update', 'submission_delete' then
  tid=(p_data->>'teacher_id')::uuid;
  if not exists(select 1 from public.period_teacher_status where period_id=pid and teacher_id=tid) then raise exception '老师不在本月名单'; end if;
  if (p_data->>'submission_revision')::integer is distinct from (select submission_revision from public.period_teacher_status where period_id=pid and teacher_id=tid) then raise exception '填写内容已变化，请刷新后重试' using errcode='40001'; end if;
  if p_action='submission_delete' then
   delete from public.teacher_availability where period_id=pid and teacher_id=tid;
   delete from public.fixed_assignments where period_id=pid and teacher_id=tid;
   update public.period_teacher_status set first_submitted_at=null,last_submitted_at=null,submission_source=null,submission_revision=submission_revision+1 where period_id=pid and teacher_id=tid;
  else
   if jsonb_typeof(p_data->'slot_ids') is distinct from 'array' then raise exception '请选择可参加时间'; end if;
   if jsonb_array_length(p_data->'slot_ids')>1000 then raise exception '时间段过多'; end if;
   if exists(select 1 from jsonb_array_elements_text(p_data->'slot_ids') x where x.value is null or not exists(select 1 from public.meeting_slots where period_id=pid and id=x.value::uuid)) then raise exception '包含其他月份或无效的时间'; end if;
   select coalesce(array_agg(distinct value::uuid),'{}'::uuid[]) into slot_ids from jsonb_array_elements_text(p_data->'slot_ids');
   delete from public.fixed_assignments where period_id=pid and teacher_id=tid and not(slot_id=any(slot_ids));
   delete from public.teacher_availability where period_id=pid and teacher_id=tid;
   insert into public.teacher_availability(period_id,teacher_id,slot_id) select pid,tid,unnest(slot_ids);
   update public.period_teacher_status set first_submitted_at=coalesce(first_submitted_at,now()),last_submitted_at=now(),submission_source=coalesce(submission_source,'online'),submission_revision=submission_revision+1 where period_id=pid and teacher_id=tid;
  end if;
 when 'member_set' then
  tid=(p_data->>'teacher_id')::uuid;
  update public.period_teacher_status set excluded=(p_data->>'excluded')::boolean where period_id=pid and teacher_id=tid;
  if not found then raise exception '本月名单中没有该老师'; end if;
  if (p_data->>'excluded')::boolean then delete from public.fixed_assignments where period_id=pid and teacher_id=tid; end if;
 when 'slot_bulk' then
  declare added integer; total integer;
  begin
   if jsonb_typeof(p_data->'dates') is distinct from 'array' or jsonb_typeof(p_data->'times') is distinct from 'array' then raise exception '请选择日期和时间段'; end if;
   if jsonb_array_length(p_data->'dates') not between 1 and 31 or jsonb_array_length(p_data->'times') not between 1 and 24 then raise exception '每批请选择1至31天和1至24个时间段'; end if;
   if exists(select 1 from jsonb_array_elements_text(p_data->'dates') x where x.value is null or extract(year from x.value::date)<>period.year or extract(month from x.value::date)<>period.month) then raise exception '日期必须属于当前月份'; end if;
   if exists(select 1 from jsonb_array_elements(p_data->'times') x where nullif(x.value->>'start_time','') is null or nullif(x.value->>'end_time','') is null or (x.value->>'start_time')::time >= (x.value->>'end_time')::time) then raise exception '每段结束时间必须晚于开始时间'; end if;
   select count(*) into total from (select distinct value::date from jsonb_array_elements_text(p_data->'dates')) d cross join (select distinct (value->>'start_time')::time,(value->>'end_time')::time from jsonb_array_elements(p_data->'times')) t;
   insert into public.meeting_slots(period_id,meeting_date,start_time,end_time,capacity_override,sort_order)
   select pid,d.dt,t.st,t.et,nullif(p_data->>'capacity_override','')::integer,(select coalesce(max(sort_order),0) from public.meeting_slots where period_id=pid)+row_number() over(order by d.dt,t.st,t.et)
   from (select distinct value::date dt from jsonb_array_elements_text(p_data->'dates')) d cross join (select distinct (value->>'start_time')::time st,(value->>'end_time')::time et from jsonb_array_elements(p_data->'times')) t
   on conflict(period_id,meeting_date,start_time,end_time) do nothing;
   get diagnostics added = row_count;
   result=jsonb_build_object('added',added,'skipped',total-added);
  end;
 when 'slot_save' then
  if extract(year from (p_data->>'meeting_date')::date)<>period.year or extract(month from (p_data->>'meeting_date')::date)<>period.month then raise exception '日期必须属于当前月份'; end if;
  sid=nullif(p_data->>'id','')::uuid;
  if sid is null then
   insert into public.meeting_slots(period_id,meeting_date,start_time,end_time,capacity_override,sort_order)
   values(pid,(p_data->>'meeting_date')::date,(p_data->>'start_time')::time,(p_data->>'end_time')::time,nullif(p_data->>'capacity_override','')::integer,(select coalesce(max(sort_order),0)+1 from public.meeting_slots where period_id=pid)) returning id into sid;
  else
   if exists(select 1 from public.meeting_assignments where slot_id=sid) or exists(select 1 from public.meeting_assignment_leaders where slot_id=sid) then raise exception '该时间已有历史排期，请新增时间段以保留历史'; end if;
   update public.meeting_slots set meeting_date=(p_data->>'meeting_date')::date,start_time=(p_data->>'start_time')::time,end_time=(p_data->>'end_time')::time,capacity_override=nullif(p_data->>'capacity_override','')::integer where id=sid and period_id=pid;
   if not found then raise exception '时间不存在'; end if;
  end if;
  result=jsonb_build_object('id',sid);
 when 'slot_delete' then delete from public.meeting_slots where id=(p_data->>'id')::uuid and period_id=pid;
 when 'date_delete' then delete from public.meeting_slots where period_id=pid and meeting_date=(p_data->>'meeting_date')::date;
 when 'permissions' then raise exception '已改为所有班主任共用会议时间，无需单独设置权限';
 when 'leader_save' then
  lid=nullif(p_data->>'id','')::uuid;
  if lid is null then insert into public.leaders(name,active,teacher_id) values(trim(p_data->>'name'),coalesce((p_data->>'active')::boolean,true),nullif(p_data->>'teacher_id','')::uuid) returning id into lid;
  else update public.leaders set name=trim(p_data->>'name'),active=coalesce((p_data->>'active')::boolean,true),teacher_id=nullif(p_data->>'teacher_id','')::uuid where id=lid; end if;
  if pid is not null then insert into public.period_leaders(period_id,leader_id,name_snapshot) select pid,id,name from public.leaders where id=lid on conflict do nothing; end if;
  update public.period_leaders m set name_snapshot=l.name from public.leaders l where l.id=lid and m.leader_id=lid and not exists(select 1 from public.schedule_runs r where r.period_id=m.period_id);
  result=jsonb_build_object('id',lid);
 when 'leader_slots' then
  lid=(p_data->>'leader_id')::uuid;
  insert into public.period_leaders(period_id,leader_id,name_snapshot) select pid,id,name from public.leaders where id=lid and active on conflict do nothing;
  delete from public.leader_availability where period_id=pid and leader_id=lid;
  insert into public.leader_availability(period_id,leader_id,slot_id) select pid,lid,value::uuid from jsonb_array_elements_text(p_data->'slot_ids');
 when 'fixed_save' then
  tid=(p_data->>'teacher_id')::uuid; sid=(p_data->>'slot_id')::uuid;
  if not exists(select 1 from public.period_teacher_status m join public.teachers t on t.id=m.teacher_id where m.period_id=pid and t.id=tid and t.active and not m.excluded) then raise exception '老师已停用或本月不安排'; end if;
  if exists(select 1 from public.leaders l join public.period_leaders pl on pl.leader_id=l.id where pl.period_id=pid and l.teacher_id=tid) then raise exception '负责人不需要固定安排'; end if;
  if not exists(select 1 from public.teacher_availability where period_id=pid and teacher_id=tid and slot_id=sid) then raise exception '老师没有勾选该时间或未获授权'; end if;
  if not exists(select 1 from public.leader_availability a join public.leaders l on l.id=a.leader_id where a.period_id=pid and a.slot_id=sid and l.active) then raise exception '该时间没有负责人'; end if;
  if (select count(*) from public.fixed_assignments where period_id=pid and slot_id=sid and teacher_id<>tid)>=(select coalesce(capacity_override,period.default_capacity) from public.meeting_slots where period_id=pid and id=sid) then raise exception '固定安排已达人数上限'; end if;
  insert into public.fixed_assignments(period_id,teacher_id,slot_id,sort_order) values(pid,tid,sid,(select coalesce(max(sort_order),0)+1 from public.fixed_assignments where period_id=pid))
  on conflict(period_id,teacher_id) do update set slot_id=excluded.slot_id;
 when 'fixed_delete' then delete from public.fixed_assignments where period_id=pid and teacher_id=(p_data->>'teacher_id')::uuid;
 when 'issue_link' then
  tid=(p_data->>'teacher_id')::uuid;
  if not exists(select 1 from public.period_teacher_status where period_id=pid and teacher_id=tid) then raise exception '老师不在本月名单'; end if;
  update meeting_private.teacher_access_tokens set revoked_at=now(),updated_at=now() where period_id=pid and teacher_id=tid and revoked_at is null;
  raw_token=encode(extensions.gen_random_bytes(32),'hex');
  insert into meeting_private.teacher_access_tokens(period_id,teacher_id,token_hash,expires_at) values(pid,tid,encode(extensions.digest(raw_token,'sha256'),'hex'),now()+interval '180 days');
  return jsonb_build_object('token',raw_token);
 when 'revoke_link' then
  update meeting_private.teacher_access_tokens set revoked_at=now(),updated_at=now() where period_id=pid and teacher_id=(p_data->>'teacher_id')::uuid and revoked_at is null;
  return '{}'::jsonb;
 when 'legacy_import' then
  if period.status not in ('draft','collecting') then raise exception '请在草稿或收集中导入'; end if;
  if jsonb_array_length(p_data->'teachers')>500 or jsonb_array_length(p_data->'slots')>1000 then raise exception '导入数据过多'; end if;
  slot_ids=array[]::uuid[];
  for rec in select value from jsonb_array_elements(p_data->'slots') loop
   if extract(year from (rec->>'meeting_date')::date)<>period.year or extract(month from (rec->>'meeting_date')::date)<>period.month then raise exception '导入日期不属于当前月份'; end if;
   insert into public.meeting_slots(period_id,meeting_date,start_time,end_time,sort_order)
   values(pid,(rec->>'meeting_date')::date,(rec->>'start_time')::time,(rec->>'end_time')::time,(select coalesce(max(sort_order),0)+1 from public.meeting_slots where period_id=pid))
   on conflict(period_id,meeting_date,start_time,end_time) do update set period_id=excluded.period_id returning id into sid;
   slot_ids=array_append(slot_ids,sid);
  end loop;
  idx=0;
  for rec in select value from jsonb_array_elements(p_data->'teachers') loop
   select l.id into lid from public.leaders l where l.active and l.name=trim(rec->>'name') order by created_at,id limit 1;
   if found then
    insert into public.period_leaders(period_id,leader_id,name_snapshot) values(pid,lid,trim(rec->>'name')) on conflict do nothing;
    delete from public.leader_availability where period_id=pid and leader_id=lid;
    insert into public.leader_availability(period_id,leader_id,slot_id)
     select pid,lid,slot_ids[n] from generate_subscripts(slot_ids,1) n where coalesce((p_data->'availability'->idx->>(n-1))::boolean,false) on conflict do nothing;
   else
    insert into public.teachers(name,class_name) values(trim(rec->>'name'),coalesce(rec->>'class_name','')) returning id into tid;
    insert into public.period_teacher_status(period_id,teacher_id,name_snapshot,class_snapshot,sort_order,first_submitted_at,last_submitted_at,submission_source)
    values(pid,tid,trim(rec->>'name'),coalesce(rec->>'class_name',''),(select coalesce(max(sort_order),0)+1 from public.period_teacher_status where period_id=pid),now(),now(),'import');
    insert into public.teacher_slot_permissions(period_id,teacher_id,slot_id) select pid,tid,unnest(slot_ids) on conflict do nothing;
    insert into public.teacher_availability(period_id,teacher_id,slot_id)
     select pid,tid,slot_ids[n] from generate_subscripts(slot_ids,1) n where coalesce((p_data->'availability'->idx->>(n-1))::boolean,false) on conflict do nothing;
   end if;
   idx=idx+1;
  end loop;
 when 'save_schedule' then
  if period.status not in ('closed','scheduled') then raise exception '请先关闭填写，再进行排期'; end if;
  if (p_data->>'algorithm_version') is distinct from 'legacy-matching-1.0' then raise exception '算法版本不支持'; end if;
  if jsonb_typeof(p_data->'assignments') is distinct from 'array' then raise exception '排期结果格式错误'; end if;
  -- Validate each submitted row, even if the browser was modified.
  if exists(
   select 1 from jsonb_array_elements(p_data->'assignments') a
   left join public.period_teacher_status m on m.period_id=pid and m.teacher_id=(a->>'teacher_id')::uuid
   left join public.teachers t on t.id=m.teacher_id
   left join public.meeting_slots s on s.period_id=pid and s.id=(a->>'slot_id')::uuid
   where m.id is null or s.id is null or m.excluded or not t.active
    or exists(select 1 from public.leaders l join public.period_leaders pl on pl.leader_id=l.id where pl.period_id=pid and l.teacher_id=t.id)
    or not exists(select 1 from public.teacher_availability av where av.period_id=pid and av.teacher_id=t.id and av.slot_id=s.id)
    or not exists(select 1 from public.leader_availability av join public.leaders l on l.id=av.leader_id where av.period_id=pid and av.slot_id=s.id and l.active)
    or ((a->>'is_fixed')::boolean is distinct from exists(select 1 from public.fixed_assignments f where f.period_id=pid and f.teacher_id=t.id and f.slot_id=s.id))
    or exists(select 1 from public.fixed_assignments f where f.period_id=pid and f.teacher_id=t.id and f.slot_id<>s.id)
  ) then raise exception '排期含无效安排，请重新生成'; end if;
  if exists(select 1 from jsonb_array_elements(p_data->'assignments') a join public.meeting_slots s on s.id=(a->>'slot_id')::uuid group by s.id,s.capacity_override having count(*)>coalesce(s.capacity_override,period.default_capacity)) then raise exception '排期超过人数上限'; end if;
  if exists(select 1 from jsonb_array_elements(p_data->'assignments') a group by a->>'teacher_id' having count(*)>1) then raise exception '同一老师只能安排一次'; end if;
  update public.schedule_runs set is_current=false where period_id=pid and is_current;
  insert into public.schedule_runs(period_id,source_revision,algorithm_version,generated_by,issues)
  values(pid,period.revision,p_data->>'algorithm_version',auth.uid(),coalesce(p_data->'issues','{}'::jsonb)) returning id into rid;
  insert into public.meeting_assignments(period_id,run_id,teacher_id,slot_id,is_fixed)
  select pid,rid,(a->>'teacher_id')::uuid,(a->>'slot_id')::uuid,(a->>'is_fixed')::boolean from jsonb_array_elements(p_data->'assignments') a;
  -- Preserve old behavior: all leader-available slots get their available leaders, including zero-teacher slots.
  insert into public.meeting_assignment_leaders(period_id,run_id,leader_id,slot_id)
  select pid,rid,av.leader_id,av.slot_id from public.leader_availability av join public.leaders l on l.id=av.leader_id where av.period_id=pid and l.active;
  update public.meeting_periods set status='scheduled' where id=pid;
  return jsonb_build_object('id',rid);
 else raise exception '不支持的操作';
 end case;
 if global_action then update public.meeting_periods set revision=revision+1 where id is not null;
 elsif p_action<>'period_create' then update public.meeting_periods set revision=revision+1 where id=pid; end if;
 return result;
end $$;
create function public.admin_command(p_action text,p_data jsonb) returns jsonb language sql security invoker set search_path='' as $$
 select meeting_private.admin_command(p_action,p_data);
$$;

-- Only service_role can execute this function; the Edge Function supplies the token.
-- It is SECURITY INVOKER: no anonymous privileged database function is exposed.
create function public.teacher_portal(p_token text,p_slots uuid[] default null,p_revision integer default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare tok meeting_private.teacher_access_tokens; per public.meeting_periods; member public.period_teacher_status;
begin
 if current_user<>'service_role' then raise exception '拒绝访问' using errcode='42501'; end if;
 if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception '链接无效或已过期'; end if;
 select * into tok from meeting_private.teacher_access_tokens where token_hash=encode(extensions.digest(p_token,'sha256'),'hex');
 if not found then raise exception '链接无效或已过期'; end if;
 select * into per from public.meeting_periods where id=tok.period_id for update;
 -- Re-read after the lock so link revocation cannot race submission.
 select * into tok from meeting_private.teacher_access_tokens where id=tok.id and revoked_at is null and expires_at>now();
 if not found or per.status='draft' then raise exception '链接无效或尚未开放'; end if;
 select * into member from public.period_teacher_status where period_id=tok.period_id and teacher_id=tok.teacher_id;
 if not exists(select 1 from public.teachers where id=tok.teacher_id and active) then raise exception '该老师已停用'; end if;
 if p_slots is not null then
  if per.status<>'collecting' or member.excluded then raise exception '当前已停止填写'; end if;
  if p_revision is distinct from member.submission_revision then raise exception '填写内容或可选时间已变化，请刷新后重试' using errcode='40001'; end if;
  if cardinality(p_slots)>1000 or exists(select 1 from unnest(p_slots) s where s is null or not exists(select 1 from public.teacher_slot_permissions where period_id=tok.period_id and teacher_id=tok.teacher_id and slot_id=s)) then raise exception '包含未开放的时间'; end if;
  delete from public.fixed_assignments where period_id=tok.period_id and teacher_id=tok.teacher_id and not(slot_id=any(p_slots));
  delete from public.teacher_availability where period_id=tok.period_id and teacher_id=tok.teacher_id;
  insert into public.teacher_availability(period_id,teacher_id,slot_id) select tok.period_id,tok.teacher_id,s from (select distinct unnest(p_slots) s) x;
  update public.period_teacher_status set first_submitted_at=coalesce(first_submitted_at,now()),last_submitted_at=now(),submission_source='online',submission_revision=submission_revision+1 where id=member.id returning * into member;
  update public.meeting_periods set revision=revision+1 where id=per.id;
 end if;
 return jsonb_build_object('name',member.name_snapshot,'class_name',member.class_snapshot,'title',per.title,'timezone',per.timezone,
  'status',per.status,'excluded',member.excluded,'revision',member.submission_revision,'first_submitted_at',member.first_submitted_at,'last_submitted_at',member.last_submitted_at,
  'slots',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'meeting_date',s.meeting_date,'start_time',s.start_time,'end_time',s.end_time) order by s.meeting_date,s.start_time) from public.meeting_slots s join public.teacher_slot_permissions a on a.slot_id=s.id and a.period_id=s.period_id where a.period_id=per.id and a.teacher_id=tok.teacher_id),'[]'),
  'selected',coalesce((select jsonb_agg(slot_id) from public.teacher_availability where period_id=per.id and teacher_id=tok.teacher_id),'[]'));
end $$;

-- Explicit grants: newly created Supabase tables are not automatically exposed.
-- Profiles cannot be self-promoted, including by an existing administrator browser.
revoke all on public.profiles from anon,authenticated;
grant select on public.profiles to authenticated;
grant usage on schema meeting_private to authenticated,service_role;
revoke all on all functions in schema meeting_private from public,anon,authenticated;
grant execute on function meeting_private.is_admin() to authenticated;
grant execute on function meeting_private.admin_command(text,jsonb) to authenticated;
create policy profiles_read on public.profiles for select to authenticated using(id=(select auth.uid()) or (select meeting_private.is_admin()));
do $$ declare n text; begin
 foreach n in array array['teachers','meeting_periods','period_teacher_status','meeting_slots','teacher_slot_permissions','teacher_availability','leaders','period_leaders','leader_availability','fixed_assignments','schedule_runs','meeting_assignments','meeting_assignment_leaders'] loop
 execute format('revoke all on public.%I from anon,authenticated',n);
 execute format('grant select on public.%I to authenticated',n);
 execute format('create policy admin_read on public.%I for select to authenticated using ((select meeting_private.is_admin()))',n);
 -- All browser writes go through the auth-checked command, preserving locks and revisions.
 end loop;
end $$;
grant select,insert,update,delete on public.profiles,public.teachers,public.meeting_periods,public.period_teacher_status,public.meeting_slots,public.teacher_slot_permissions,public.teacher_availability,public.leaders,public.period_leaders,public.leader_availability,public.fixed_assignments,public.schedule_runs,public.meeting_assignments,public.meeting_assignment_leaders to service_role;
grant select,insert,update,delete on meeting_private.teacher_access_tokens to service_role;
revoke all on function public.admin_snapshot(uuid),public.admin_command(text,jsonb),public.teacher_portal(text,uuid[],integer) from public,anon,authenticated;
grant execute on function public.admin_snapshot(uuid),public.admin_command(text,jsonb) to authenticated;
grant execute on function public.teacher_portal(text,uuid[],integer) to service_role;
-- Optional live subscription; safe to skip if Realtime is disabled.
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='meeting_periods') then
  alter publication supabase_realtime add table public.meeting_periods;
 end if;
end $$;
-- Explicit deny documents that only the service-role token gateway may touch tokens.
create policy token_client_deny on meeting_private.teacher_access_tokens for all to anon,authenticated using(false) with check(false);

-- Preserve existing availability, decoupling it from retired individual permissions.
alter table public.teacher_availability drop constraint teacher_availability_period_id_teacher_id_slot_id_fkey;
alter table public.teacher_availability add constraint availability_member_fkey foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade;
alter table public.teacher_availability add constraint availability_period_slot_fkey foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade;
-- The Edge gateway exposes only the deliberately public month/name workflow.
create or replace function public.shared_teacher_portal(p_year integer,p_month integer,p_teacher uuid default null,p_slots uuid[] default null,p_revision integer default null,p_period_revision integer default null) returns jsonb
language plpgsql security invoker set search_path='' as $$
declare per public.meeting_periods; member public.period_teacher_status; result jsonb; rid uuid;
begin
 if current_user<>'service_role' then raise exception '拒绝访问' using errcode='42501'; end if;
 if p_year is null or p_year not between 2000 and 2200 or p_month is null or p_month not between 1 and 12 then raise exception '月份无效'; end if;
 select * into per from public.meeting_periods where year=p_year and month=p_month for update;
 if per.id is null then
  if p_slots is not null then raise exception '本月会议时间尚未准备好'; end if;
  return jsonb_build_object('title',p_year||'年'||p_month||'月','status','draft','timezone','Asia/Shanghai','period_revision',0,'teachers','[]'::jsonb,'member',null,'slots','[]'::jsonb,'selected','[]'::jsonb,'meetings','[]'::jsonb,'schedule_stale',false);
 end if;
 if p_teacher is not null then
  select m.* into member from public.period_teacher_status m join public.teachers t on t.id=m.teacher_id and t.active where m.period_id=per.id and m.teacher_id=p_teacher;
 end if;
 if p_slots is not null then
  if member.id is null then raise exception '请选择本月名单中的班主任'; end if;
  if per.status<>'collecting' or member.excluded then raise exception '当前已停止填写'; end if;
  if not exists(select 1 from public.meeting_slots where period_id=per.id) then raise exception '本月会议时间尚未准备好'; end if;
  if p_revision is distinct from member.submission_revision or p_period_revision is distinct from per.revision then raise exception '会议资料或填写内容已变化，请刷新后重试' using errcode='40001'; end if;
  if cardinality(p_slots)>1000 or exists(select 1 from unnest(p_slots) s where s is null or not exists(select 1 from public.meeting_slots where period_id=per.id and id=s)) then raise exception '包含其他月份或无效的时间'; end if;
  delete from public.fixed_assignments where period_id=per.id and teacher_id=p_teacher and not(slot_id=any(p_slots));
  delete from public.teacher_availability where period_id=per.id and teacher_id=p_teacher;
  insert into public.teacher_availability(period_id,teacher_id,slot_id) select per.id,p_teacher,s from (select distinct unnest(p_slots) s) x;
  update public.period_teacher_status set first_submitted_at=coalesce(first_submitted_at,now()),last_submitted_at=now(),submission_source='online',submission_revision=submission_revision+1 where id=member.id returning * into member;
  update public.meeting_periods set revision=revision+1 where id=per.id returning * into per;
 end if;
 select id into rid from public.schedule_runs where period_id=per.id and is_current;
 return jsonb_build_object('title',per.title,'status',per.status,'timezone',per.timezone,'period_revision',per.revision,
 'teachers',coalesce((select jsonb_agg(jsonb_build_object('id',m.teacher_id,'name',m.name_snapshot,'class_name',m.class_snapshot) order by m.sort_order,m.id) from public.period_teacher_status m join public.teachers t on t.id=m.teacher_id and t.active where m.period_id=per.id),'[]'),
 'member',case when member.id is null then null else jsonb_build_object('name',member.name_snapshot,'class_name',member.class_snapshot,'excluded',member.excluded,'revision',member.submission_revision,'first_submitted_at',member.first_submitted_at,'last_submitted_at',member.last_submitted_at) end,
 'slots',coalesce((select jsonb_agg(jsonb_build_object('id',s.id,'meeting_date',s.meeting_date,'start_time',s.start_time,'end_time',s.end_time) order by s.meeting_date,s.start_time) from public.meeting_slots s where s.period_id=per.id and per.status<>'draft'),'[]'),
 'selected',coalesce((select jsonb_agg(slot_id) from public.teacher_availability where period_id=per.id and teacher_id=member.teacher_id and per.status<>'draft'),'[]'),
 'schedule_stale',coalesce((select source_revision<>per.revision from public.schedule_runs where id=rid),false),
 'meetings',coalesce((select jsonb_agg(jsonb_build_object('meeting_date',s.meeting_date,'start_time',s.start_time,'end_time',s.end_time,
  'teachers',(select jsonb_agg(jsonb_build_object('name',m.name_snapshot,'class_name',m.class_snapshot) order by m.sort_order,m.id) from public.meeting_assignments a join public.period_teacher_status m on m.period_id=a.period_id and m.teacher_id=a.teacher_id where a.run_id=rid and a.slot_id=s.id),
  'leaders',coalesce((select jsonb_agg(l.name_snapshot order by l.name_snapshot) from public.meeting_assignment_leaders a join public.period_leaders l on l.period_id=a.period_id and l.leader_id=a.leader_id where a.run_id=rid and a.slot_id=s.id),'[]')) order by s.meeting_date,s.start_time) from public.meeting_slots s where s.period_id=per.id and per.status<>'draft' and exists(select 1 from public.meeting_assignments where run_id=rid and slot_id=s.id)),'[]'));
end $$;
revoke all on function public.shared_teacher_portal(integer,integer,uuid,uuid[],integer,integer) from public,anon,authenticated;
grant execute on function public.shared_teacher_portal(integer,integer,uuid,uuid[],integer,integer) to service_role;
-- Retire the previous personal-token API. Keep old records for historical compatibility.
revoke all on function public.teacher_portal(text,uuid[],integer) from service_role;

commit;
