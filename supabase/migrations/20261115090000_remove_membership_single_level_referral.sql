-- Remove paid membership/subscription eligibility and use a free, single-level service referral model.
alter table public.commerce_profiles
  drop constraint if exists commerce_profiles_lifetime_verified;

alter table public.commerce_profiles
  add column if not exists first_success_rewarded_at timestamptz;

alter table public.commerce_profiles
  drop column if exists plan_tier,
  drop column if exists lifetime_verified_at,
  drop column if exists lifetime_order_id;

drop table if exists public.commerce_subscription_events;
drop table if exists public.referral_subscription_rules;

alter table public.service_commission_rules
  drop constraint if exists service_commission_free_allocation,
  drop constraint if exists service_commission_lifetime_allocation;

alter table public.service_commission_rules
  rename column free_self_pct to self_commission_pct;
alter table public.service_commission_rules
  rename column level1_pct to referral_commission_pct;

alter table public.service_commission_rules
  drop column if exists lifetime_self_pct,
  drop column if exists level2_pct,
  drop column if exists level3_pct;

alter table public.service_commission_rules
  add constraint service_commission_single_level_allocation
  check (company_share_pct + self_commission_pct + referral_commission_pct <= total_provider_commission_pct);

comment on column public.service_commission_rules.self_commission_pct is
  'Self commission rate paid to the user who completed the service transaction.';
comment on column public.service_commission_rules.referral_commission_pct is
  'Single-level service commission rate paid only to the direct referrer of the user completing the service transaction.';
comment on column public.commerce_profiles.first_success_rewarded_at is
  'Timestamp when the direct referrer received the one-time INR 10 first-successful-service referral reward.';

create or replace function public.finalize_bharat_saathi_service_transaction(
  p_transaction_id uuid,
  p_provider_reference text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_tx public.commerce_service_transactions%rowtype;
  v_referrer uuid;
  v_rewarded_at timestamptz;
  v_rule public.service_commission_rules%rowtype;
  v_self_amount numeric(14,2) := 0;
  v_referral_amount numeric(14,2) := 0;
  v_reward_amount numeric(14,2) := 0;
  v_ledger_id uuid;
begin
  select * into v_tx
  from public.commerce_service_transactions
  where id = p_transaction_id
  for update;

  if not found then
    raise exception 'Service transaction not found';
  end if;

  if v_tx.status = 'success' then
    return jsonb_build_object('already_processed', true, 'transaction_id', v_tx.id);
  end if;

  if v_tx.status <> 'pending' then
    raise exception 'Only pending service transactions can be finalized';
  end if;

  select referred_by, first_success_rewarded_at
    into v_referrer, v_rewarded_at
  from public.commerce_profiles
  where user_id = v_tx.user_id
  for update;

  if not found then
    raise exception 'Commerce profile not found for service user';
  end if;

  update public.commerce_service_transactions
  set status = 'success',
      provider_reference = coalesce(nullif(p_provider_reference, ''), provider_reference),
      completed_at = coalesce(completed_at, now())
  where id = v_tx.id;

  select * into v_rule
  from public.service_commission_rules
  where service_code = v_tx.service_code and is_active = true;

  if found then
    v_self_amount := round(v_tx.amount * v_rule.self_commission_pct / 100, 2);
    v_referral_amount := case
      when v_referrer is not null
      then round(v_tx.amount * v_rule.referral_commission_pct / 100, 2)
      else 0
    end;

    if v_self_amount > 0 then
      insert into public.commerce_commission_ledger(
        beneficiary_user_id, source_user_id, source_reference, commission_type,
        level, service_code, base_amount, commission_rate_pct, amount, status
      ) values (
        v_tx.user_id, v_tx.user_id, v_tx.id::text, 'service',
        0, v_tx.service_code, v_tx.amount, v_rule.self_commission_pct, v_self_amount, 'credited'
      )
      on conflict (beneficiary_user_id, source_reference, commission_type, level) do nothing
      returning id into v_ledger_id;

      if v_ledger_id is not null then
        insert into public.commerce_wallets(user_id) values (v_tx.user_id)
        on conflict (user_id) do nothing;
        update public.commerce_wallets
        set commission_balance = commission_balance + v_self_amount, updated_at = now()
        where user_id = v_tx.user_id;
      end if;
    end if;

    if v_referral_amount > 0 then
      insert into public.commerce_commission_ledger(
        beneficiary_user_id, source_user_id, source_reference, commission_type,
        level, service_code, base_amount, commission_rate_pct, amount, status
      ) values (
        v_referrer, v_tx.user_id, v_tx.id::text, 'service',
        1, v_tx.service_code, v_tx.amount, v_rule.referral_commission_pct, v_referral_amount, 'credited'
      )
      on conflict (beneficiary_user_id, source_reference, commission_type, level) do nothing
      returning id into v_ledger_id;

      if v_ledger_id is not null then
        insert into public.commerce_wallets(user_id) values (v_referrer)
        on conflict (user_id) do nothing;
        update public.commerce_wallets
        set commission_balance = commission_balance + v_referral_amount, updated_at = now()
        where user_id = v_referrer;
      end if;
    end if;
  end if;

  -- Pay INR 10 once, when this referred user's first successful service transaction is confirmed.
  if v_referrer is not null and v_rewarded_at is null then
    update public.commerce_profiles
    set first_success_rewarded_at = now(), updated_at = now()
    where user_id = v_tx.user_id and first_success_rewarded_at is null
    returning first_success_rewarded_at into v_rewarded_at;

    if v_rewarded_at is not null then
      v_reward_amount := 10.00;
      insert into public.commerce_commission_ledger(
        beneficiary_user_id, source_user_id, source_reference, commission_type,
        level, base_amount, amount, status
      ) values (
        v_referrer, v_tx.user_id, v_tx.id::text, 'referral',
        1, 0, v_reward_amount, 'credited'
      )
      on conflict (beneficiary_user_id, source_reference, commission_type, level) do nothing
      returning id into v_ledger_id;

      if v_ledger_id is not null then
        insert into public.commerce_wallets(user_id) values (v_referrer)
        on conflict (user_id) do nothing;
        update public.commerce_wallets
        set commission_balance = commission_balance + v_reward_amount, updated_at = now()
        where user_id = v_referrer;
      else
        v_reward_amount := 0;
      end if;
    end if;
  end if;

  return jsonb_build_object(
    'already_processed', false,
    'transaction_id', v_tx.id,
    'self_commission', v_self_amount,
    'direct_referral_service_commission', v_referral_amount,
    'first_success_referral_reward', v_reward_amount
  );
end;
$$;

revoke all on function public.finalize_bharat_saathi_service_transaction(uuid, text) from public, anon, authenticated;
grant execute on function public.finalize_bharat_saathi_service_transaction(uuid, text) to service_role;
