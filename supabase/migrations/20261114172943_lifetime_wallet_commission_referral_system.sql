-- Separate service and commission wallets, subscription entitlement, referral tree and admin-configurable commission rules.
create or replace function public.is_bharat_saathi_admin()
returns boolean language sql stable set search_path = pg_catalog
as $$ select coalesce((auth.jwt() -> 'app_metadata' ->> 'role') in ('admin','super_admin'), false); $$;

create table if not exists public.commerce_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 plan_tier text not null default 'free' check (plan_tier in ('free','lifetime')),
 referral_code text not null unique,
 referred_by uuid references auth.users(id) on delete set null,
 lifetime_verified_at timestamptz,
 lifetime_order_id text unique,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint commerce_profiles_no_self_referral check (referred_by is null or referred_by <> user_id),
 constraint commerce_profiles_lifetime_verified check ((plan_tier='free' and lifetime_verified_at is null) or (plan_tier='lifetime' and lifetime_verified_at is not null))
);
create table if not exists public.commerce_wallets (
 user_id uuid primary key references auth.users(id) on delete cascade,
 service_balance numeric(14,2) not null default 0 check (service_balance >= 0),
 commission_balance numeric(14,2) not null default 0 check (commission_balance >= 0),
 updated_at timestamptz not null default now()
);
create table if not exists public.commerce_wallet_transactions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 wallet_type text not null check (wallet_type in ('service','commission')),
 transaction_type text not null check (transaction_type in ('credit','debit','transfer_in','transfer_out')),
 amount numeric(14,2) not null check (amount > 0),
 reference_type text, reference_id text, description text,
 created_at timestamptz not null default now()
);
create table if not exists public.service_commission_rules (
 service_code text primary key, service_name text not null,
 total_provider_commission_pct numeric(7,4) not null default 0 check (total_provider_commission_pct between 0 and 100),
 company_share_pct numeric(7,4) not null default 0 check (company_share_pct between 0 and 100),
 free_self_pct numeric(7,4) not null default 0 check (free_self_pct between 0 and 100),
 lifetime_self_pct numeric(7,4) not null default 0 check (lifetime_self_pct between 0 and 100),
 level1_pct numeric(7,4) not null default 0 check (level1_pct between 0 and 100),
 level2_pct numeric(7,4) not null default 0 check (level2_pct between 0 and 100),
 level3_pct numeric(7,4) not null default 0 check (level3_pct between 0 and 100),
 is_active boolean not null default true, updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 constraint service_commission_free_allocation check (company_share_pct + free_self_pct <= total_provider_commission_pct),
 constraint service_commission_lifetime_allocation check (company_share_pct + lifetime_self_pct + level1_pct + level2_pct + level3_pct <= total_provider_commission_pct)
);
create table if not exists public.referral_subscription_rules (
 level smallint primary key check (level between 1 and 3),
 amount numeric(14,2) not null check (amount >= 0),
 is_active boolean not null default true, updated_at timestamptz not null default now(),
 updated_by uuid references auth.users(id)
);
insert into public.referral_subscription_rules(level,amount) values (1,50),(2,30),(3,20) on conflict(level) do nothing;

create table if not exists public.commerce_service_transactions (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 service_code text not null, amount numeric(14,2) not null check (amount > 0),
 status text not null default 'pending' check (status in ('pending','success','failed','reversed')),
 provider_reference text, created_at timestamptz not null default now(), completed_at timestamptz
);
create table if not exists public.commerce_commission_ledger (
 id uuid primary key default gen_random_uuid(),
 beneficiary_user_id uuid not null references auth.users(id) on delete cascade,
 source_user_id uuid not null references auth.users(id) on delete cascade,
 source_reference text not null,
 commission_type text not null check (commission_type in ('service','referral')),
 level smallint not null check (level between 0 and 3),
 service_code text, base_amount numeric(14,2) not null default 0 check (base_amount >= 0),
 commission_rate_pct numeric(7,4), amount numeric(14,2) not null check (amount >= 0),
 status text not null default 'credited' check (status in ('pending','credited','reversed')),
 created_at timestamptz not null default now(),
 unique (beneficiary_user_id,source_reference,commission_type,level)
);
create table if not exists public.commerce_subscription_events (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 platform text not null default 'google_play' check (platform='google_play'),
 product_id text not null, order_id text unique, purchase_token_sha256 text,
 status text not null default 'pending' check (status in ('pending','verified','rejected','refunded')),
 verified_at timestamptz, created_at timestamptz not null default now()
);

create index if not exists commerce_profiles_referred_by_idx on public.commerce_profiles(referred_by);
create index if not exists commerce_wallet_transactions_user_created_idx on public.commerce_wallet_transactions(user_id,created_at desc);
create index if not exists commerce_commission_ledger_beneficiary_created_idx on public.commerce_commission_ledger(beneficiary_user_id,created_at desc);
create index if not exists commerce_service_transactions_user_created_idx on public.commerce_service_transactions(user_id,created_at desc);

alter table public.commerce_profiles enable row level security;
alter table public.commerce_wallets enable row level security;
alter table public.commerce_wallet_transactions enable row level security;
alter table public.service_commission_rules enable row level security;
alter table public.referral_subscription_rules enable row level security;
alter table public.commerce_service_transactions enable row level security;
alter table public.commerce_commission_ledger enable row level security;
alter table public.commerce_subscription_events enable row level security;

drop policy if exists "Users read own commerce profile" on public.commerce_profiles;
create policy "Users read own commerce profile" on public.commerce_profiles for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "Users read own commerce wallets" on public.commerce_wallets;
create policy "Users read own commerce wallets" on public.commerce_wallets for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "Users read own commerce wallet transactions" on public.commerce_wallet_transactions;
create policy "Users read own commerce wallet transactions" on public.commerce_wallet_transactions for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "Authenticated users read active service commission rules" on public.service_commission_rules;
create policy "Authenticated users read active service commission rules" on public.service_commission_rules for select to authenticated using (is_active=true);
drop policy if exists "Admins manage service commission rules" on public.service_commission_rules;
create policy "Admins manage service commission rules" on public.service_commission_rules for all to authenticated using ((select public.is_bharat_saathi_admin())) with check ((select public.is_bharat_saathi_admin()));
drop policy if exists "Authenticated users read active referral rules" on public.referral_subscription_rules;
create policy "Authenticated users read active referral rules" on public.referral_subscription_rules for select to authenticated using (is_active=true);
drop policy if exists "Admins manage referral rules" on public.referral_subscription_rules;
create policy "Admins manage referral rules" on public.referral_subscription_rules for all to authenticated using ((select public.is_bharat_saathi_admin())) with check ((select public.is_bharat_saathi_admin()));
drop policy if exists "Users read own service transactions" on public.commerce_service_transactions;
create policy "Users read own service transactions" on public.commerce_service_transactions for select to authenticated using ((select auth.uid())=user_id);
drop policy if exists "Users read own commission entries" on public.commerce_commission_ledger;
create policy "Users read own commission entries" on public.commerce_commission_ledger for select to authenticated using ((select auth.uid())=beneficiary_user_id);
drop policy if exists "Users read own subscription events" on public.commerce_subscription_events;
create policy "Users read own subscription events" on public.commerce_subscription_events for select to authenticated using ((select auth.uid())=user_id);

create or replace function public.create_commerce_records_for_new_user()
returns trigger language plpgsql security definer set search_path=pg_catalog,public
as $$
begin
 insert into public.commerce_profiles(user_id,referral_code) values(new.id,upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))) on conflict(user_id) do nothing;
 insert into public.commerce_wallets(user_id) values(new.id) on conflict(user_id) do nothing;
 return new;
end; $$;
drop trigger if exists on_auth_user_created_commerce on auth.users;
create trigger on_auth_user_created_commerce after insert on auth.users for each row execute function public.create_commerce_records_for_new_user();
revoke all on function public.create_commerce_records_for_new_user() from public,anon,authenticated;
insert into public.commerce_profiles(user_id,referral_code) select u.id,upper(substr(replace(gen_random_uuid()::text,'-',''),1,10)) from auth.users u on conflict(user_id) do nothing;
insert into public.commerce_wallets(user_id) select u.id from auth.users u on conflict(user_id) do nothing;

create or replace function public.apply_bharat_saathi_referral_code(p_referral_code text)
returns uuid language plpgsql security definer set search_path=pg_catalog,public
as $$
declare v_user uuid:=auth.uid(); v_referrer uuid; v_existing uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 select referred_by into v_existing from public.commerce_profiles where user_id=v_user for update;
 if not found then raise exception 'Commerce profile not found'; end if;
 if v_existing is not null then raise exception 'Referral code already applied'; end if;
 select user_id into v_referrer from public.commerce_profiles where upper(referral_code)=upper(trim(p_referral_code));
 if v_referrer is null then raise exception 'Referral code not found'; end if;
 if v_referrer=v_user then raise exception 'Self referral is not allowed'; end if;
 update public.commerce_profiles set referred_by=v_referrer,updated_at=now() where user_id=v_user;
 return v_referrer;
end; $$;

create or replace function public.transfer_commission_to_service_wallet(p_amount numeric)
returns table(service_balance numeric,commission_balance numeric)
language plpgsql security definer set search_path=pg_catalog,public
as $$
declare v_user uuid:=auth.uid(); v_wallet public.commerce_wallets%rowtype;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 if p_amount is null or p_amount<=0 then raise exception 'Enter a valid transfer amount'; end if;
 select * into v_wallet from public.commerce_wallets where user_id=v_user for update;
 if not found then raise exception 'Wallet not found'; end if;
 if v_wallet.commission_balance<p_amount then raise exception 'Insufficient commission balance'; end if;
 update public.commerce_wallets set commission_balance=commission_balance-p_amount,service_balance=service_balance+p_amount,updated_at=now()
 where user_id=v_user returning commerce_wallets.service_balance,commerce_wallets.commission_balance into service_balance,commission_balance;
 insert into public.commerce_wallet_transactions(user_id,wallet_type,transaction_type,amount,reference_type,description)
 values (v_user,'commission','transfer_out',p_amount,'wallet_transfer','Commission balance moved to service wallet'),
 (v_user,'service','transfer_in',p_amount,'wallet_transfer','Transferred from commission wallet');
 return next;
end; $$;

revoke all on function public.apply_bharat_saathi_referral_code(text) from public,anon;
grant execute on function public.apply_bharat_saathi_referral_code(text) to authenticated;
revoke all on function public.transfer_commission_to_service_wallet(numeric) from public,anon;
grant execute on function public.transfer_commission_to_service_wallet(numeric) to authenticated;
grant select on public.commerce_profiles,public.commerce_wallets,public.commerce_wallet_transactions,public.service_commission_rules,public.referral_subscription_rules,public.commerce_service_transactions,public.commerce_commission_ledger,public.commerce_subscription_events to authenticated;
grant select,insert,update,delete on public.service_commission_rules,public.referral_subscription_rules to authenticated;
