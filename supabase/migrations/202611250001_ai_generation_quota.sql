create table if not exists public.ai_generation_quota (
  user_id uuid not null references auth.users(id) on delete cascade,
  month_start date not null,
  free_used integer not null default 0 check (free_used >= 0),
  paid_credits integer not null default 0 check (paid_credits >= 0),
  primary key (user_id, month_start)
);

alter table public.ai_generation_quota enable row level security;
revoke all on public.ai_generation_quota from anon, authenticated;

create or replace function public.consume_ai_generation_credit(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
  v_free_used integer;
  v_paid integer;
begin
  insert into public.ai_generation_quota(user_id, month_start)
  values (p_user_id, v_month)
  on conflict (user_id, month_start) do nothing;

  select free_used, paid_credits into v_free_used, v_paid
  from public.ai_generation_quota
  where user_id = p_user_id and month_start = v_month
  for update;

  if v_free_used < 10 then
    update public.ai_generation_quota
    set free_used = free_used + 1
    where user_id = p_user_id and month_start = v_month;
    return jsonb_build_object('allowed', true, 'creditSource', 'free', 'freeRemaining', 9 - v_free_used, 'paidCredits', v_paid);
  elsif v_paid > 0 then
    update public.ai_generation_quota
    set paid_credits = paid_credits - 1
    where user_id = p_user_id and month_start = v_month;
    return jsonb_build_object('allowed', true, 'creditSource', 'paid', 'freeRemaining', 0, 'paidCredits', v_paid - 1);
  end if;

  return jsonb_build_object('allowed', false, 'creditSource', 'none', 'freeRemaining', 0, 'paidCredits', 0);
end;
$$;

create or replace function public.refund_ai_generation_credit(p_user_id uuid, p_source text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_month date := date_trunc('month', timezone('utc', now()))::date;
begin
  if p_source = 'free' then
    update public.ai_generation_quota
    set free_used = greatest(0, free_used - 1)
    where user_id = p_user_id and month_start = v_month;
  elsif p_source = 'paid' then
    update public.ai_generation_quota
    set paid_credits = paid_credits + 1
    where user_id = p_user_id and month_start = v_month;
  end if;
end;
$$;

revoke all on function public.consume_ai_generation_credit(uuid) from public, anon, authenticated;
revoke all on function public.refund_ai_generation_credit(uuid, text) from public, anon, authenticated;
grant execute on function public.consume_ai_generation_credit(uuid) to service_role;
grant execute on function public.refund_ai_generation_credit(uuid, text) to service_role;
