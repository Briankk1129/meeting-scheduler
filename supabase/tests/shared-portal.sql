begin;
insert into public.meeting_periods(id,year,month,title,status) values('a1000000-0000-4000-8000-000000000001',2199,11,'共享入口测试','draft'),('a1000000-0000-4000-8000-000000000002',2199,12,'其他月份','collecting');
insert into public.teachers(id,name) values('a2000000-0000-4000-8000-000000000001','共享测试甲'),('a2000000-0000-4000-8000-000000000002','共享测试乙');
insert into public.period_teacher_status(period_id,teacher_id,name_snapshot) select 'a1000000-0000-4000-8000-000000000001',id,name from public.teachers where id in ('a2000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000002');
insert into public.meeting_slots(id,period_id,meeting_date,start_time,end_time) values('a3000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001','2199-11-01','10:00','10:30'),('a3000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002','2199-12-01','10:00','10:30');
set local role service_role;
do $$ declare d jsonb; begin
 d=public.shared_teacher_portal(2199,11);
 assert jsonb_array_length(d->'teachers')=2;
 assert jsonb_array_length(d->'slots')=0,'draft leaked slots';
 d=public.shared_teacher_portal(2198,1);
 assert jsonb_array_length(d->'slots')=0,'missing month must be empty';
 update public.meeting_periods set status='collecting' where id='a1000000-0000-4000-8000-000000000001';
 d=public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000001');
 assert jsonb_array_length(d->'slots')=1,'all slots without permissions';
 d=public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000001',array['a3000000-0000-4000-8000-000000000001']::uuid[],0,0);
 assert jsonb_array_length(d->'selected')=1;
 assert (d->'member'->>'revision')::int=1;
 assert d->'member'->>'first_submitted_at' is not null;
 begin
  perform public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000001','{}'::uuid[],0,0);
  raise exception 'stale accepted';
 exception when serialization_failure then null; end;
 begin
  perform public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000001',array['a3000000-0000-4000-8000-000000000002']::uuid[],1,1);
  raise exception 'cross month accepted';
 exception when raise_exception then if sqlerrm<>'包含其他月份或无效的时间' then raise; end if; end;
 d=public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000002');
 assert jsonb_array_length(d->'selected')=0,'name switch leaked selections';
 d=public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000001','{}'::uuid[],1,1);
 assert jsonb_array_length(d->'selected')=0;
 assert d->'member'->>'first_submitted_at' is not null,'empty is submitted';
 update public.meeting_periods set status='closed' where id='a1000000-0000-4000-8000-000000000001';
 begin
  perform public.shared_teacher_portal(2199,11,'a2000000-0000-4000-8000-000000000001','{}'::uuid[],2,2);
  raise exception 'closed accepted';
 exception when raise_exception then if sqlerrm<>'当前已停止填写' then raise; end if; end;
 insert into public.schedule_runs(id,period_id,source_revision,algorithm_version) values('a4000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',2,'test');
 insert into public.meeting_assignments(period_id,run_id,teacher_id,slot_id,is_fixed) values('a1000000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001',false);
 d=public.shared_teacher_portal(2199,11);
 assert jsonb_array_length(d->'meetings')=1,'shared meeting missing';
 assert d->'meetings'->0->'teachers'->0->>'name'='共享测试甲';
 assert not (d->>'schedule_stale')::boolean;
 assert not has_function_privilege('anon','public.shared_teacher_portal(integer,integer,uuid,uuid[],integer,integer)','execute');
 assert not has_table_privilege('anon','public.teachers','select');
end $$;
rollback;
