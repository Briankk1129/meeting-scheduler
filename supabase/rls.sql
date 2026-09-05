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
