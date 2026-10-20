begin;

insert into public.meeting_periods(id,year,month,title,status,default_capacity)
values('e1000000-0000-4000-8000-000000000001',2199,7,'清空排期测试','scheduled',4);
insert into public.meeting_slots(id,period_id,meeting_date,start_time,end_time,capacity_override)
values('e3000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001','2199-07-01','19:00','19:30',4);
insert into public.schedule_runs(id,period_id,source_revision,algorithm_version)
values('e4000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000001',0,'test');

select set_config('request.jwt.claim.sub',(select id::text from public.profiles where role='admin' limit 1),true);
set local role authenticated;
select public.admin_command('period_update',jsonb_build_object('period_id','e1000000-0000-4000-8000-000000000001','revision',0,'default_capacity',3,'status','closed','apply_default_capacity',true));
select public.admin_command('clear_schedule',jsonb_build_object('period_id','e1000000-0000-4000-8000-000000000001','revision',1));
reset role;

do $$ begin
 assert (select default_capacity=3 from public.meeting_periods where id='e1000000-0000-4000-8000-000000000001'),'default capacity not updated';
 assert (select capacity_override is null from public.meeting_slots where id='e3000000-0000-4000-8000-000000000001'),'slot capacity override not cleared';
 assert not exists(select 1 from public.schedule_runs where period_id='e1000000-0000-4000-8000-000000000001'),'schedule runs remain';
 assert (select status='closed' and revision=2 from public.meeting_periods where id='e1000000-0000-4000-8000-000000000001'),'period state mismatch';
end $$;

rollback;
