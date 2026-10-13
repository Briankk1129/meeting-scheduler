begin;

insert into public.meeting_periods(id,year,month,title,status)
values('c1000000-0000-4000-8000-000000000001',2199,8,'删除老师测试','scheduled');
insert into public.teachers(id,name,class_name)
values
 ('c2000000-0000-4000-8000-000000000001','待删除老师','测试班'),
 ('c2000000-0000-4000-8000-000000000002','保留老师','对照班');
insert into public.period_teacher_status(period_id,teacher_id,name_snapshot,class_snapshot,first_submitted_at,last_submitted_at,submission_source)
values
 ('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','待删除老师','测试班',now(),now(),'online'),
 ('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000002','保留老师','对照班',now(),now(),'online');
insert into public.meeting_slots(id,period_id,meeting_date,start_time,end_time)
values('c3000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001','2199-08-01','19:00','19:30');
insert into public.teacher_slot_permissions(period_id,teacher_id,slot_id)
values('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001');
insert into public.teacher_availability(period_id,teacher_id,slot_id)
values('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001');
insert into public.fixed_assignments(period_id,teacher_id,slot_id)
values('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001');
insert into public.schedule_runs(id,period_id,source_revision,algorithm_version)
values('c4000000-0000-4000-8000-000000000001','c1000000-0000-4000-8000-000000000001',0,'test');
insert into public.meeting_assignments(period_id,run_id,teacher_id,slot_id,is_fixed)
values('c1000000-0000-4000-8000-000000000001','c4000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001','c3000000-0000-4000-8000-000000000001',true);
insert into public.leaders(id,name,teacher_id)
values('c5000000-0000-4000-8000-000000000001','关联负责人','c2000000-0000-4000-8000-000000000001');
insert into meeting_private.teacher_access_tokens(period_id,teacher_id,token_hash,expires_at)
values('c1000000-0000-4000-8000-000000000001','c2000000-0000-4000-8000-000000000001',repeat('c',64),now()+interval '1 day');

select set_config('request.jwt.claim.sub',(select id::text from public.profiles where role='admin' limit 1),true);
set local role authenticated;
select public.admin_command('teacher_delete',jsonb_build_object('id','c2000000-0000-4000-8000-000000000001'));
reset role;

do $$ begin
 assert not exists(select 1 from public.teachers where id='c2000000-0000-4000-8000-000000000001'),'teacher remains';
 assert not exists(select 1 from public.period_teacher_status where teacher_id='c2000000-0000-4000-8000-000000000001'),'membership remains';
 assert not exists(select 1 from public.meeting_assignments where teacher_id='c2000000-0000-4000-8000-000000000001'),'assignment remains';
 assert not exists(select 1 from public.teacher_availability where teacher_id='c2000000-0000-4000-8000-000000000001'),'availability remains';
 assert not exists(select 1 from public.fixed_assignments where teacher_id='c2000000-0000-4000-8000-000000000001'),'fixed assignment remains';
 assert not exists(select 1 from meeting_private.teacher_access_tokens where teacher_id='c2000000-0000-4000-8000-000000000001'),'token remains';
 assert exists(select 1 from public.leaders where id='c5000000-0000-4000-8000-000000000001' and teacher_id is null),'leader was not retained independently';
 assert exists(select 1 from public.teachers where id='c2000000-0000-4000-8000-000000000002'),'other teacher deleted';
 assert (select revision=1 from public.meeting_periods where id='c1000000-0000-4000-8000-000000000001'),'period not invalidated';
end $$;

set local role authenticated;
do $$ begin
 begin
  perform public.admin_command('teacher_delete',jsonb_build_object('id','c2000000-0000-4000-8000-000000000001'));
  raise exception 'missing teacher accepted';
 exception when raise_exception then
  if sqlerrm<>'老师不存在' then raise; end if;
 end;
end $$;

rollback;
