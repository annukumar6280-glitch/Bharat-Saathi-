create table if not exists public.ai_call_assistant_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sim_slot smallint not null default 1 check (sim_slot in (1, 2)),
  phone_number text not null default '' check (char_length(phone_number) <= 20),
  transfer_number text not null default '' check (char_length(transfer_number) <= 20),
  assistant_instructions text not null default '' check (char_length(assistant_instructions) <= 4000),
  enabled boolean not null default false,
  forwarding_mode text not null default 'no_answer'
    check (forwarding_mode in ('no_answer', 'busy', 'unreachable')),
  disclosure_accepted_at timestamptz,
  transcript_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.ai_call_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider_call_id text,
  direction text not null default 'incoming'
    check (direction in ('incoming', 'outgoing', 'test')),
  caller_number text not null default '' check (char_length(caller_number) <= 30),
  caller_name text not null default '' check (char_length(caller_name) <= 200),
  caller_address text not null default '' check (char_length(caller_address) <= 500),
  call_reason text not null default '' check (char_length(call_reason) <= 1000),
  summary text not null default '' check (char_length(summary) <= 8000),
  transcript jsonb not null default '[]'::jsonb check (jsonb_typeof(transcript) = 'array'),
  status text not null default 'received'
    check (status in ('received', 'answered', 'missed', 'transferred', 'completed', 'failed')),
  transfer_status text not null default 'not_requested'
    check (transfer_status in ('not_requested', 'requested', 'completed', 'failed')),
  started_at timestamptz,
  ended_at timestamptz,
  duration_seconds integer check (duration_seconds is null or duration_seconds >= 0),
  created_at timestamptz not null default now(),
  unique (provider_call_id)
);

create index if not exists ai_call_logs_user_created_idx
  on public.ai_call_logs (user_id, created_at desc);

alter table public.ai_call_assistant_settings enable row level security;
alter table public.ai_call_logs enable row level security;

revoke all on public.ai_call_assistant_settings from anon, authenticated, public;
revoke all on public.ai_call_logs from anon, authenticated, public;

grant select, insert, update, delete on public.ai_call_assistant_settings to authenticated;
grant select, delete on public.ai_call_logs to authenticated;
grant all on public.ai_call_assistant_settings to service_role;
grant all on public.ai_call_logs to service_role;

create policy "Users manage their own AI call assistant settings"
  on public.ai_call_assistant_settings
  for all
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Users read their own AI call logs"
  on public.ai_call_logs
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users delete their own AI call logs"
  on public.ai_call_logs
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
