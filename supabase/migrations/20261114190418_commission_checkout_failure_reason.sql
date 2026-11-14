-- Store a provider failure reason separately from the provider reference.
alter table public.commerce_service_transactions
  add column if not exists failure_reason text;

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
      failure_reason = nullif(p_failure_reason, '')
  where id = v_tx.id;

  return jsonb_build_object(
    'transaction_id', v_tx.id, 'status', 'failed',
    'commission_restored', case when v_tx.commission_reserved then v_tx.commission_discount_amount else 0 end
  );
end;
$function$;

revoke all on function public.release_bharat_saathi_service_checkout(uuid,text) from public, anon, authenticated;
grant execute on function public.release_bharat_saathi_service_checkout(uuid,text) to service_role;
