begin;
insert into public.meeting_periods(id,year,month,title,status) values('a1000000-0000-4000-8000-000000000001',2199,11,'共享入口测试','draft'),('a1000000-0000-4000-8000-000000000002',2199,12,'其他月份','collecting');
insert into public.teachers(id,name) values('a2000000-0000-4000-8000-000000000001','共享测试甲'),('a2000000-0000-4000-8000-000000000002','共享测试乙');
insert into public.period_teacher_status(period_id,teacher_id,name_snapshot) select 'a1000000-0000-4000-8000-000000000001',id,name from public.teachers where id in ('a2000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002');
insert into public.meeting_slots(id,period_id,meeting_date,start_time,end_time) values('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','2199-11-01','10:00','10:30'),('a3000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','2199-12-01','10:00','10:30');

select set_config('request.jwt.claim.sub',(select id::text from public.profiles where role='admin' limit 1),true);
set local role authenticated;
do $$ declare payload jsonb; first_time timestamptz; rev integer; begin
 payload=jsonb_build_object('period_id','a1000000-0000-4000-8000-000000000001','revision',0,'teacher_id','a2000000-0000-4000-8000-000000000001','submission_revision',0,'slot_ids',jsonb_build_array('a3000000-0000-4000-8000-000000000001'));
 perform public.admin_command('submission_update',payload);
 select first_submitted_at into first_time from public.period_teacher_status where period_id='a1000000-0000-4000-8000-000000000001' and teacher_id='a2000000-0000-4000-8000-000000000001';
 assert first_time is not null;
 assert (select count(*)=1 from public.teacher_availability where period_id='a1000000-0000-4000-8000-000000000001');
 begin
  perform public.admin_command('submission_update',payload);
  raise exception 'stale accepted';
 exception when serialization_failure then null; end;
 begin
  perform public.admin_command('submission_update',payload||jsonb_build_object('revision',1,'submission_revision',1,'slot_ids',jsonb_build_array('a3000000-0000-4000-8000-000000000002')));
  raise exception 'cross month accepted';
 exception when raise_exception then if sqlerrm<>'包含其他月份或无效的时间' then raise; end if; end;
 perform public.admin_command('submission_update',payload||jsonb_build_object('revision',1,'submission_revision',1,'slot_ids','[]'::jsonb));
 assert (select first_submitted_at=first_time from public.period_teacher_status where period_id='a1000000-0000-4000-8000-000000000001' and teacher_id='a2000000-0000-4000-8000-000000000001');
 assert not exists(select 1 from public.teacher_availability where period_id='a1000000-0000-4000-8000-000000000001');
 perform public.admin_command('submission_delete',payload||jsonb_build_object('revision',2,'submission_revision',2));
 assert (select first_submitted_at is null and last_submitted_at is null and submission_revision=3 from public.period_teacher_status where period_id='a1000000-0000-4000-8000-000000000001' and teacher_id='a2000000-0000-4000-8000-000000000001');
 assert (select submission_revision=0 from public.period_teacher_status where period_id='a1000000-0000-4000-8000-000000000001' and teacher_id='a2000000-0000-4000-8000-000000000002');
 perform set_config('request.jwt.claim.sub','a2000000-0000-4000-8000-000000000002',true);
 begin
  perform public.admin_command('submission_delete',payload||jsonb_build_object('revision',3,'submission_revision',3));
  raise exception 'non-admin accepted';
 exception when insufficient_privilege then null; end;
end $$;
rollback;
