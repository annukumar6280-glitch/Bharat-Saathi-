-- Reserve a user's earned commission as a discount during service checkout.
-- Gateway/provider callbacks must call the service-role finalization/release paths only.

alter table public.commerce_service_transactions
  add column if not exists checkout_request_id uuid,
  add column if not exists commission_discount_amount numeric(14,2) not null default 0,
  add column if not exists gateway_payable_amount numeric(14,2),
  add column if not exists commission_reserved boolean not null default false,
  add column if not exists commission_reservation_status text not null default 'none';

update public.commerce_service_transactions
set gateway_payable_amount = amount
where gateway_payable_amount is null;

alter table public.commerce_service_transactions
  alter column gateway_payable_amount set not null;

alter table public.commerce_service_transactions
  add constraint commerce_service_transactions_discount_nonnegative
    check (commission_discount_amount >= 0),
  add constraint commerce_service_transactions_gateway_nonnegative
    check (gateway_payable_amount >= 0),
  add constraint commerce_service_transactions_amount_split
    check (round(commission_discount_amount + gateway_payable_amount, 2) = round(amount, 2)),
  add constraint commerce_service_transactions_reservation_status
    check (commission_reservation_status in ('none','reserved','consumed','released'));

create unique index if not exists commerce_service_transactions_checkout_request_uidx
  on public.commerce_service_transactions(user_id, checkout_request_id)
  where checkout_request_id is not null;

create or replace function public.create_bharat_saathi_service_checkout(
  p_request_id uuid, p_service_code text, p_amount numeric, p_commission_to_use numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  v_user uuid := auth.uid();
  v_amount numeric(14,2);
  v_discount numeric(14,2);
  v_wallet public.commerce_wallets%rowtype;
  v_tx public.commerce_service_transactions%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_request_id is null then raise exception 'Checkout request id is required'; end if;
  if p_service_code is null or length(trim(p_service_code)) = 0 then raise exception 'Service code is required'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Enter a valid service amount'; end if;
  if p_commission_to_use is null or p_commission_to_use < 0 then raise exception 'Enter a valid commission discount'; end if;

  v_amount := round(p_amount, 2);
  v_discount := round(p_commission_to_use, 2);
  if v_discount > v_amount then raise exception 'Commission discount cannot exceed service amount'; end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text || ':' || p_request_id::text, 0));
  select * into v_tx from public.commerce_service_transactions
  where user_id = v_user and checkout_request_id = p_request_id;

  if found then
    if v_tx.service_code <> lower(trim(p_service_code))
       or v_tx.amount <> v_amount
       or v_tx.commission_discount_amount <> v_discount then
      raise exception 'Checkout request id was already used with different details';
    end if;
    return jsonb_build_object(
      'transaction_id', v_tx.id, 'status', v_tx.status, 'amount', v_tx.amount,
      'commission_discount', v_tx.commission_discount_amount,
      'gateway_payable', v_tx.gateway_payable_amount,
      'reservation_status', v_tx.commission_reservation_status, 'already_created', true
    );
  end if;

  if v_discount > 0 then
    insert into public.commerce_wallets(user_id) values (v_user) on conflict (user_id) do nothing;
    select * into v_wallet from public.commerce_wallets where user_id = v_user for update;
    if v_wallet.commission_balance < v_discount then raise exception 'Insufficient commission balance'; end if;
  end if;

  insert into public.commerce_service_transactions(
    user_id, service_code, amount, status, checkout_request_id,
    commission_discount_amount, gateway_payable_amount, commission_reserved, commission_reservation_status
  )
  values (
    v_user, lower(trim(p_service_code)), v_amount, 'pending', p_request_id,
    v_discount, v_amount - v_discount, v_discount > 0,
    case when v_discount > 0 then 'reserved' else 'none' end
  )
  returning * into v_tx;

  if v_discount > 0 then
    update public.commerce_wallets
    set commission_balance = commission_balance - v_discount, updated_at = now()
    where user_id = v_user;
    insert into public.commerce_wallet_transactions(
      user_id, wallet_type, transaction_type, amount, reference_type, reference_id, description
    ) values (
      v_user, 'commission', 'debit', v_discount, 'service_checkout_reservation',
      v_tx.id::text, 'Commission reserved for service discount'
    );
  end if;

  return jsonb_build_object(
    'transaction_id', v_tx.id, 'status', v_tx.status, 'amount', v_tx.amount,
    'commission_discount', v_tx.commission_discount_amount,
    'gateway_payable', v_tx.gateway_payable_amount,
    'reservation_status', v_tx.commission_reservation_status, 'already_created', false
  );
end;
$function$;

revoke all on function public.create_bharat_saathi_service_checkout(uuid,text,numeric,numeric) from public, anon, service_role;
grant execute on function public.create_bharat_saathi_service_checkout(uuid,text,numeric,numeric) to authenticated;

create or replace function public.release_bharat_saathi_service_checkout(
  p_transaction_id uuid, p_failure_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare v_tx public.commerce_service_transactions%rowtype;
begin
  select * into v_tx from public.commerce_service_transactions where id = p_transaction_id for update;
  if not found then raise exception 'Service transaction not found'; end if;
  if v_tx.status = 'success' then raise exception 'A successful service transaction cannot be released'; end if;
  if v_tx.status = 'failed' and v_tx.commission_reservation_status in ('released','none') then
    return jsonb_build_object('transaction_id', v_tx.id, 'already_released', true);
  end if;
  if v_tx.status <> 'pending' then raise exception 'Only pending service transactions can be released'; end if;

  if v_tx.commission_reserved and v_tx.commission_reservation_status = 'reserved' then
    insert into public.commerce_wallets(user_id) values (v_tx.user_id) on conflict (user_id) do nothing;
    update public.commerce_wallets
    set commission_balance = commission_balance + v_tx.commission_discount_amount, updated_at = now()
    where user_id = v_tx.user_id;
    insert into public.commerce_wallet_transactions(
      user_id, wallet_type, transaction_type, amount, reference_type, reference_id, description
    ) values (
      v_tx.user_id, 'commission', 'credit', v_tx.commission_discount_amount,
      'service_checkout_release', v_tx.id::text, 'Commission restored after failed service checkout'
    );
  end if;

  update public.commerce_service_transactions
  set status = 'failed',
      commission_reservation_status = case when commission_reserved then 'released' else 'none' end,
      completed_at = coalesce(completed_at, now()),
      provider_reference = coalesce(provider_reference, nullif(p_failure_reason, ''))
  where id = v_tx.id;

  return jsonb_build_object(
    'transaction_id', v_tx.id, 'status', 'failed',
    'commission_restored', case when v_tx.commission_reserved then v_tx.commission_discount_amount else 0 end
  );
end;
$function$;

revoke all on function public.release_bharat_saathi_service_checkout(uuid,text) from public, anon, authenticated;
grant execute on function public.release_bharat_saathi_service_checkout(uuid,text) to service_role;

create or replace function public.mark_bharat_saathi_commission_reservation_consumed()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
begin
  if new.status = 'success' and old.status is distinct from 'success'
     and new.commission_reserved and new.commission_reservation_status = 'reserved' then
    new.commission_reservation_status := 'consumed';
  end if;
  return new;
end;
$function$;

revoke all on function public.mark_bharat_saathi_commission_reservation_consumed() from public, anon, authenticated;

drop trigger if exists trg_mark_bharat_saathi_commission_reservation_consumed
  on public.commerce_service_transactions;
create trigger trg_mark_bharat_saathi_commission_reservation_consumed
before update of status on public.commerce_service_transactions
for each row execute function public.mark_bharat_saathi_commission_reservation_consumed();
