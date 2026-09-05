-- Run schema.sql, functions.sql, rls.sql together, in this order, in a transaction.
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists meeting_private;
revoke all on schema meeting_private from public, anon, authenticated;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 role text not null default 'user' check(role in ('admin','teacher','user')),
 display_name text not null default '', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.teachers (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 80),
 class_name text not null default '', active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.meeting_periods (
 id uuid primary key default gen_random_uuid(), year integer not null check(year between 2000 and 2200), month integer not null check(month between 1 and 12),
 title text not null check(length(trim(title))>0), status text not null default 'draft' check(status in ('draft','collecting','closed','scheduled')),
 timezone text not null default 'Asia/Shanghai' check(timezone in ('Asia/Shanghai','Asia/Tokyo')),
 default_capacity integer not null default 3 check(default_capacity between 1 and 100), revision integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(year,month)
);
create table public.period_teacher_status (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 teacher_id uuid not null references public.teachers(id) on delete restrict, name_snapshot text not null, class_snapshot text not null default '',
 excluded boolean not null default false, sort_order integer not null default 0,
 first_submitted_at timestamptz, last_submitted_at timestamptz, submission_source text check(submission_source in ('online','import')), submission_revision integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(period_id,teacher_id)
);
create table public.meeting_slots (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 meeting_date date not null, start_time time not null, end_time time not null,
 capacity_override integer check(capacity_override between 0 and 100), sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), check(start_time<end_time),
 unique(period_id,id), unique(period_id,meeting_date,start_time,end_time)
);
create table public.teacher_slot_permissions (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade, unique(period_id,teacher_id,slot_id)
);
create table public.teacher_availability (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id,slot_id) references public.teacher_slot_permissions(period_id,teacher_id,slot_id) on delete cascade,
 unique(period_id,teacher_id,slot_id)
);
create table public.leaders (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 80), active boolean not null default true,
 teacher_id uuid references public.teachers(id) on delete restrict,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(teacher_id)
);
create table public.period_leaders (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 leader_id uuid not null references public.leaders(id) on delete restrict, name_snapshot text not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(period_id,leader_id)
);
create table public.leader_availability (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, leader_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,leader_id) references public.period_leaders(period_id,leader_id) on delete cascade,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade, unique(period_id,leader_id,slot_id)
);
create table public.fixed_assignments (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null, slot_id uuid not null, sort_order integer not null default 0,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete cascade, unique(period_id,teacher_id)
);
create table public.schedule_runs (
 id uuid primary key default gen_random_uuid(), period_id uuid not null references public.meeting_periods(id) on delete cascade,
 source_revision integer not null, algorithm_version text not null, generated_by uuid references auth.users(id) on delete set null,
 is_current boolean not null default true, issues jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(period_id,id)
);
create unique index one_current_run on public.schedule_runs(period_id) where is_current;
create table public.meeting_assignments (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, run_id uuid not null, teacher_id uuid not null, slot_id uuid not null, is_fixed boolean not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,run_id) references public.schedule_runs(period_id,id) on delete cascade,
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete restrict,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete restrict, unique(run_id,teacher_id)
);
create table public.meeting_assignment_leaders (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, run_id uuid not null, leader_id uuid not null, slot_id uuid not null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,run_id) references public.schedule_runs(period_id,id) on delete cascade,
 foreign key(period_id,leader_id) references public.period_leaders(period_id,leader_id) on delete restrict,
 foreign key(period_id,slot_id) references public.meeting_slots(period_id,id) on delete restrict, unique(run_id,slot_id,leader_id)
);
create table meeting_private.teacher_access_tokens (
 id uuid primary key default gen_random_uuid(), period_id uuid not null, teacher_id uuid not null,
 token_hash text not null unique, expires_at timestamptz not null, revoked_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 foreign key(period_id,teacher_id) references public.period_teacher_status(period_id,teacher_id) on delete cascade
);
create unique index one_active_token on meeting_private.teacher_access_tokens(period_id,teacher_id) where revoked_at is null;
create index pts_teacher on public.period_teacher_status(teacher_id);
create index permissions_slot on public.teacher_slot_permissions(period_id,slot_id);
create index availability_slot on public.teacher_availability(period_id,slot_id);
create index leaders_teacher on public.leaders(teacher_id);
create index period_leaders_leader on public.period_leaders(leader_id);
create index leader_slots on public.leader_availability(period_id,slot_id);
create index fixed_slots on public.fixed_assignments(period_id,slot_id);
create index assignments_teacher on public.meeting_assignments(period_id,teacher_id);
create index assignments_slot on public.meeting_assignments(period_id,slot_id);
create index assignment_leaders_leader on public.meeting_assignment_leaders(period_id,leader_id);
create index assignment_leaders_slot on public.meeting_assignment_leaders(period_id,slot_id);
create index runs_creator on public.schedule_runs(generated_by);

create function meeting_private.touch_updated_at() returns trigger language plpgsql set search_path='' as $$
begin new.updated_at=now(); return new; end $$;
do $$ declare n text; begin
 foreach n in array array['profiles','teachers','meeting_periods','period_teacher_status','meeting_slots','teacher_slot_permissions','teacher_availability','leaders','period_leaders','leader_availability','fixed_assignments','schedule_runs','meeting_assignments','meeting_assignment_leaders'] loop
 execute format('create trigger touch_updated_at before update on public.%I for each row execute function meeting_private.touch_updated_at()',n);
 execute format('alter table public.%I enable row level security',n);
 end loop;
end $$;
alter table meeting_private.teacher_access_tokens enable row level security;
create index assignments_run on public.meeting_assignments(period_id,run_id);
create index assignment_leaders_run on public.meeting_assignment_leaders(period_id,run_id);
