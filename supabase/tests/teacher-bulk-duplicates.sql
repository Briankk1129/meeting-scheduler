begin;

insert into public.meeting_periods(id,year,month,title)
values('d1000000-0000-4000-8000-000000000001',2199,9,'批量去重测试');
insert into public.teachers(id,name,class_name)
values('d2000000-0000-4000-8000-000000000001','已有老师','原班级');

select set_config('request.jwt.claim.sub',(select id::text from public.profiles where role='admin' limit 1),true);
set local role authenticated;
do $$ declare result jsonb; begin
 result=public.admin_command('teacher_bulk',jsonb_build_object(
  'period_id','d1000000-0000-4000-8000-000000000001',
  'revision',0,
  'teachers','[{"name":"已有老师","class_name":"新班级"},{"name":"新老师","class_name":"一班"},{"name":"新老师","class_name":"二班"}]'::jsonb
 ));
 assert result->>'added'='1','added count mismatch';
 assert result->>'skipped'='2','skipped count mismatch';
 assert result->'added_names'='["新老师"]'::jsonb,'added names mismatch';
 assert result->'skipped_names'='["已有老师","新老师"]'::jsonb,'skipped names mismatch';
end $$;
reset role;

do $$ begin
 assert (select count(*)=1 from public.teachers where name='已有老师'),'existing teacher duplicated';
 assert (select class_name='原班级' from public.teachers where name='已有老师'),'existing teacher changed';
 assert (select count(*)=1 from public.teachers where name='新老师'),'batch duplicate was inserted';
 assert (select class_name='一班' from public.teachers where name='新老师'),'first occurrence was not retained';
 assert (select count(*)=1 from public.period_teacher_status where period_id='d1000000-0000-4000-8000-000000000001' and name_snapshot='新老师'),'membership duplicate was inserted';
 assert (select revision=1 from public.meeting_periods where id='d1000000-0000-4000-8000-000000000001'),'period revision mismatch';
end $$;

rollback;
