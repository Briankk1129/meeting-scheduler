create or replace function meeting_private.admin_command(p_action text,p_data jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
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