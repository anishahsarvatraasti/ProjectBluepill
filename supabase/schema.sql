-- Project BluePill database schema.
-- Run this in the Supabase SQL editor after creating your project.

create extension if not exists "pgcrypto";

do $$ begin
  create type public.goal_type as enum ('life', 'yearly', 'monthly', 'weekly');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.goal_status as enum ('active', 'paused', 'completed', 'archived');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.task_priority as enum ('high', 'medium', 'low');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.task_category as enum ('study', 'work', 'health', 'finance', 'personal', 'career');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.task_status as enum ('pending', 'completed', 'missed');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.habit_frequency as enum ('daily', 'weekly', 'custom');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.habit_log_status as enum ('completed', 'missed', 'partial');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.checkin_type as enum ('morning', 'afternoon', 'night', 'weekly');
exception when duplicate_object then null;
end $$;

do $$ begin
  create type public.feedback_type as enum ('suggestion', 'motivation', 'warning', 'weekly_summary');
exception when duplicate_object then null;
end $$;

create table if not exists public.users_profile (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  main_mission text not null,
  location_city text,
  dob date,
  education_status text,
  dream_goal text,
  skills text[] default '{}',
  interests text[] default '{}',
  "current_role" text,
  yearly_goal text,
  main_struggle text,
  desired_habits text[] default '{}',
  motivation_style text default 'friendly',
  wake_time time,
  sleep_time time,
  created_at timestamptz not null default now()
);

alter table if exists public.users_profile
  add column if not exists location_city text,
  add column if not exists dob date,
  add column if not exists education_status text,
  add column if not exists dream_goal text,
  add column if not exists skills text[] default '{}',
  add column if not exists interests text[] default '{}';

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  description text,
  goal_type public.goal_type not null default 'weekly',
  parent_goal_id uuid references public.goals(id) on delete set null,
  deadline date,
  progress_percent numeric not null default 0 check (progress_percent >= 0 and progress_percent <= 100),
  status public.goal_status not null default 'active',
  created_at timestamptz not null default now()
);

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  goal_id uuid references public.goals(id) on delete set null,
  title text not null,
  description text,
  priority public.task_priority not null default 'medium',
  category public.task_category not null default 'personal',
  status public.task_status not null default 'pending',
  due_date date,
  estimated_minutes integer check (estimated_minutes is null or estimated_minutes > 0),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

alter table if exists public.tasks
  add column if not exists goal_id uuid references public.goals(id) on delete set null;

alter table if exists public.tasks
  add column if not exists google_task_id text,
  add column if not exists google_task_list_id text,
  add column if not exists google_task_updated_at timestamptz;

create unique index if not exists idx_tasks_user_google_task
  on public.tasks(user_id, google_task_list_id, google_task_id)
  where google_task_id is not null;

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  category text default 'personal',
  frequency public.habit_frequency not null default 'daily',
  target text,
  current_streak integer not null default 0,
  completion_rate numeric not null default 0 check (completion_rate >= 0 and completion_rate <= 100),
  created_at timestamptz not null default now()
);

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null default current_date,
  status public.habit_log_status not null default 'completed',
  notes text,
  created_at timestamptz not null default now(),
  unique (habit_id, date)
);

create table if not exists public.checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type public.checkin_type not null,
  question text not null,
  user_answer text not null,
  ai_extracted_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.progress_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null default current_date,
  tasks_completed integer not null default 0,
  tasks_missed integer not null default 0,
  habits_completed integer not null default 0,
  habits_missed integer not null default 0,
  focus_score integer check (focus_score is null or (focus_score >= 0 and focus_score <= 10)),
  mood text,
  blocker text,
  life_score integer not null default 0 check (life_score >= 0 and life_score <= 100),
  ai_summary text,
  created_at timestamptz not null default now(),
  unique (user_id, date)
);

create table if not exists public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  feedback_type public.feedback_type not null,
  message text not null,
  related_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null default current_date,
  mood text,
  content text not null,
  ai_summary text,
  created_at timestamptz not null default now(),
  unique (user_id, date)
);

create index if not exists idx_goals_user_type on public.goals(user_id, goal_type, status);
create index if not exists idx_tasks_user_due_status on public.tasks(user_id, due_date, status);
create index if not exists idx_habits_user on public.habits(user_id);
create index if not exists idx_habit_logs_user_date on public.habit_logs(user_id, date);
create index if not exists idx_checkins_user_created on public.checkins(user_id, created_at desc);
create index if not exists idx_progress_logs_user_date on public.progress_logs(user_id, date desc);
create index if not exists idx_ai_feedback_user_created on public.ai_feedback(user_id, created_at desc);
create index if not exists idx_journal_user_date on public.journal_entries(user_id, date desc);

alter table public.users_profile enable row level security;
alter table public.goals enable row level security;
alter table public.tasks enable row level security;
alter table public.habits enable row level security;
alter table public.habit_logs enable row level security;
alter table public.checkins enable row level security;
alter table public.progress_logs enable row level security;
alter table public.ai_feedback enable row level security;
alter table public.journal_entries enable row level security;

drop policy if exists "Users can read own profile" on public.users_profile;
create policy "Users can read own profile" on public.users_profile
  for select using (auth.uid() = user_id);

drop policy if exists "Users can insert own profile" on public.users_profile;
create policy "Users can insert own profile" on public.users_profile
  for insert with check (auth.uid() = user_id);

drop policy if exists "Users can update own profile" on public.users_profile;
create policy "Users can update own profile" on public.users_profile
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can delete own profile" on public.users_profile;
create policy "Users can delete own profile" on public.users_profile
  for delete using (auth.uid() = user_id);

drop policy if exists "Users can manage own goals" on public.goals;
create policy "Users can manage own goals" on public.goals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own tasks" on public.tasks;
create policy "Users can manage own tasks" on public.tasks
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own habits" on public.habits;
create policy "Users can manage own habits" on public.habits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own habit logs" on public.habit_logs;
create policy "Users can manage own habit logs" on public.habit_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own checkins" on public.checkins;
create policy "Users can manage own checkins" on public.checkins
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own progress logs" on public.progress_logs;
create policy "Users can manage own progress logs" on public.progress_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own ai feedback" on public.ai_feedback;
create policy "Users can manage own ai feedback" on public.ai_feedback
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "Users can manage own journal" on public.journal_entries;
create policy "Users can manage own journal" on public.journal_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
