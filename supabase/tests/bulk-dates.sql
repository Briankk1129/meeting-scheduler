begin;
-- Run with an existing administrator; transaction always rolls back fixtures.
select set_config('request.jwt.claim.sub',(select id::text from public.profiles where role='admin' limit 1),true);
insert into public.meeting_periods(id,year,month,title) values('b1000000-0000-4000-8000-000000000001',2199,10,'批量日期测试');
set local role authenticated;
do $$ declare d jsonb; payload jsonb; rev integer; begin
 payload=jsonb_build_object('period_id','b1000000-0000-4000-8000-000000000001','revision',0,'dates',jsonb_build_array('2199-10-01','2199-10-03','2199-10-05'),'times',jsonb_build_array(jsonb_build_object('start_time','19:00','end_time','19:30'),jsonb_build_object('start_time','20:00','end_time','20:30')),'capacity_override','0');
 d=public.admin_command('slot_bulk',payload);
 assert (d->>'added')::int=6,'multi date/time product';
 assert (select count(*)=6 from public.meeting_slots where period_id='b1000000-0000-4000-8000-000000000001' and capacity_override=0),'zero capacity lost';
 select revision into rev from public.meeting_periods where id='b1000000-0000-4000-8000-000000000001';
 d=public.admin_command('slot_bulk',payload||jsonb_build_object('revision',rev));
 assert (d->>'added')::int=0 and (d->>'skipped')::int=6,'duplicate handling';
 select revision into rev from public.meeting_periods where id='b1000000-0000-4000-8000-000000000001';
 begin
  perform public.admin_command('slot_bulk',payload||jsonb_build_object('revision',rev,'dates',jsonb_build_array('2199-10-07','2199-11-01')));
  raise exception 'cross month accepted';
 exception when raise_exception then if sqlerrm<>'日期必须属于当前月份' then raise; end if; end;
 assert (select count(*)=6 from public.meeting_slots where period_id='b1000000-0000-4000-8000-000000000001'),'partial batch committed';
 begin
  perform public.admin_command('slot_bulk',payload||jsonb_build_object('revision',rev,'times',jsonb_build_array(jsonb_build_object('start_time','20:00','end_time','19:00'))));
  raise exception 'invalid time accepted';
 exception when raise_exception then if sqlerrm<>'每段结束时间必须晚于开始时间' then raise; end if; end;
 begin
  perform public.admin_command('slot_bulk',payload);
  raise exception 'stale revision accepted';
 exception when serialization_failure then null; end;
end $$;
rollback;
