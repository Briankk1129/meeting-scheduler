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
