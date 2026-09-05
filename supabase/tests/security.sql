-- Integration tests: real PostgreSQL roles + Supabase auth.uid(). Always rollback fixtures.
begin;
insert into auth.users(id,email) values('10000000-0000-4000-8000-000000000001','scheduler-test-admin@example.invalid'),('10000000-0000-4000-8000-000000000002','scheduler-test-user@example.invalid');
insert into public.profiles(id,role) values('10000000-0000-4000-8000-000000000001','admin'),('10000000-0000-4000-8000-000000000002','user');
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
set local role authenticated;
do $$ declare pid uuid; other uuid; tid uuid; sid uuid; lid uuid; data jsonb; rev integer; token text; begin
 pid=(public.admin_command('period_create','{"year":2199,"month":9,"title":"测试九月"}')->>'id')::uuid;
 other=(public.admin_command('period_create','{"year":2199,"month":10,"title":"测试十月"}')->>'id')::uuid;
 select revision into rev from public.meeting_periods where id=pid;
 tid=(public.admin_command('teacher_save',jsonb_build_object('period_id',pid,'revision',rev,'name','测试老师','class_name','一班'))->>'id')::uuid;
 select revision into rev from public.meeting_periods where id=pid;
 sid=(public.admin_command('slot_save',jsonb_build_object('period_id',pid,'revision',rev,'meeting_date','2199-09-07','start_time','19:00','end_time','19:30'))->>'id')::uuid;
 select revision into rev from public.meeting_periods where id=pid;
 lid=(public.admin_command('leader_save',jsonb_build_object('period_id',pid,'revision',rev,'name','测试负责人'))->>'id')::uuid;
 select revision into rev from public.meeting_periods where id=pid;
 perform public.admin_command('permissions',jsonb_build_object('period_id',pid,'revision',rev,'teacher_ids',jsonb_build_array(tid),'slot_ids',jsonb_build_array(sid)));
 select revision into rev from public.meeting_periods where id=pid;
 perform public.admin_command('leader_slots',jsonb_build_object('period_id',pid,'revision',rev,'leader_id',lid,'slot_ids',jsonb_build_array(sid)));
 select revision into rev from public.meeting_periods where id=pid;
 perform public.admin_command('period_update',jsonb_build_object('period_id',pid,'revision',rev,'status','collecting'));
 select revision into rev from public.meeting_periods where id=pid;
 token=public.admin_command('issue_link',jsonb_build_object('period_id',pid,'revision',rev,'teacher_id',tid))->>'token';
 perform set_config('test.pid',pid::text,true);perform set_config('test.tid',tid::text,true);perform set_config('test.sid',sid::text,true);perform set_config('test.token',token,true);perform set_config('test.other',other::text,true);
 if length(token)<>64 then raise exception 'token length';end if;
 begin
  perform public.admin_command('period_update',jsonb_build_object('period_id',pid,'revision',-1,'status','closed'));
  raise exception 'stale write accepted';
 exception when serialization_failure then null;end;
 begin update public.profiles set role='admin';raise exception 'direct profile update accepted';exception when insufficient_privilege then null;end;
 begin insert into public.teachers(name) values('绕过事务');raise exception 'direct insert accepted';exception when insufficient_privilege then null;end;
 data=public.admin_snapshot(pid);if jsonb_array_length(data->'members')<>1 then raise exception 'member missing';end if;
end $$;
reset role;
set local role service_role;
do $$ declare data jsonb; begin
 data=public.teacher_portal(current_setting('test.token'));
 if jsonb_array_length(data->'slots')<>1 or data ? 'teachers' or data ? 'teacher_id' then raise exception 'portal leakage';end if;
 data=public.teacher_portal(current_setting('test.token'),array[current_setting('test.sid')::uuid],(data->>'revision')::integer);
 if data->>'first_submitted_at' is null then raise exception 'submission missing';end if;
 begin perform public.teacher_portal(current_setting('test.token'),array[]::uuid[],0);raise exception 'stale submission accepted';exception when serialization_failure then null;end;
 begin perform public.teacher_portal(current_setting('test.token'),array[gen_random_uuid()],(data->>'revision')::integer);raise exception 'unauthorized slot accepted';exception when raise_exception then if sqlerrm='unauthorized slot accepted' then raise;end if;end;
 data=public.teacher_portal(current_setting('test.token'),array[]::uuid[],(data->>'revision')::integer);
 if data->>'first_submitted_at' is null or jsonb_array_length(data->'selected')<>0 then raise exception 'empty submission wrong';end if;
 perform public.teacher_portal(current_setting('test.token'),array[current_setting('test.sid')::uuid],(data->>'revision')::integer);
end $$;
reset role;
set local role authenticated;
do $$ declare rev integer; pid uuid=current_setting('test.pid')::uuid; r jsonb; begin
 select revision into rev from public.meeting_periods where id=pid;
 perform public.admin_command('fixed_save',jsonb_build_object('period_id',pid,'revision',rev,'teacher_id',current_setting('test.tid'),'slot_id',current_setting('test.sid')));
 select revision into rev from public.meeting_periods where id=pid;
 perform public.admin_command('period_update',jsonb_build_object('period_id',pid,'revision',rev,'status','closed'));
 select revision into rev from public.meeting_periods where id=pid;
 r=public.admin_command('save_schedule',jsonb_build_object('period_id',pid,'revision',rev,'algorithm_version','legacy-matching-1.0','assignments',jsonb_build_array(jsonb_build_object('teacher_id',current_setting('test.tid'),'slot_id',current_setting('test.sid'),'is_fixed',true))));
 if not exists(select 1 from public.meeting_assignments where run_id=(r->>'id')::uuid) then raise exception 'schedule not saved';end if;
 if (select count(*) from public.meeting_assignment_leaders where run_id=(r->>'id')::uuid)<>1 then raise exception 'leader not saved';end if;
end $$;
reset role;
set local role service_role;
do $$ begin
 begin perform public.teacher_portal(current_setting('test.token'),array[]::uuid[],3);raise exception 'closed write accepted';exception when raise_exception then if sqlerrm='closed write accepted' then raise;end if;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.teachers) then raise exception 'nonadmin sees teachers';end if;
 begin perform public.admin_snapshot();raise exception 'nonadmin snapshot accepted';exception when insufficient_privilege then null;end;
 begin perform public.admin_command('period_create','{"year":2198,"month":1,"title":"攻击"}');raise exception 'nonadmin command accepted';exception when insufficient_privilege then null;end;
 begin perform public.teacher_portal(current_setting('test.token'));raise exception 'nonadmin portal RPC accepted';exception when insufficient_privilege then null;end;
 begin update public.profiles set role='admin' where id=auth.uid();raise exception 'self promotion accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 begin perform 1 from public.teachers;raise exception 'anon read accepted';exception when insufficient_privilege then null;end;
 begin perform public.admin_snapshot();raise exception 'anon snapshot accepted';exception when insufficient_privilege then null;end;
 begin perform public.teacher_portal(current_setting('test.token'));raise exception 'anon RPC accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: administrator, RLS, token scope, submission replacement, stale version, closed period, persisted schedule' as test_result;
rollback;
