create table if not exists public.khata_links (
  id uuid primary key default gen_random_uuid(),
  retailer_id uuid not null references auth.users(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  shop_name text,
  status text not null default 'pending' check (status in ('pending','accepted','rejected','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint khata_links_distinct_users check (retailer_id <> customer_id)
);
create index if not exists khata_links_retailer_idx on public.khata_links(retailer_id,status);
create index if not exists khata_links_customer_idx on public.khata_links(customer_id,status);
create table if not exists public.khata_transactions (
  id uuid primary key default gen_random_uuid(),
  link_id uuid not null references public.khata_links(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('credit','payment')),
  amount numeric(12,2) not null check (amount > 0),
  note text,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create index if not exists khata_transactions_link_date_idx on public.khata_transactions(link_id,created_at desc);
alter table public.khata_links enable row level security;
alter table public.khata_transactions enable row level security;
create policy "Participants can read their khata links" on public.khata_links for select to authenticated
using ((select auth.uid()) = retailer_id or (select auth.uid()) = customer_id);
create policy "Accepted link participants can read transactions" on public.khata_transactions for select to authenticated
using (exists (select 1 from public.khata_links l where l.id = khata_transactions.link_id and l.status = 'accepted'
and ((select auth.uid()) = l.retailer_id or (select auth.uid()) = l.customer_id)));
create or replace function public.request_khata_link(p_phone text,p_shop_name text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_phone text := right(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'),10);
v_customer uuid; v_link uuid;
begin
if v_user is null then raise exception 'लॉगिन आवश्यक है'; end if;
if length(v_phone) <> 10 then raise exception '10 अंकों का मोबाइल नंबर दर्ज करें'; end if;
select p.id into v_customer from public.profiles p where right(regexp_replace(coalesce(p.phone,''),'[^0-9]','','g'),10)=v_phone and p.id<>v_user limit 1;
if v_customer is null then raise exception 'इस नंबर से कोई रजिस्टर्ड Bharat Saathi अकाउंट नहीं मिला'; end if;
if exists(select 1 from public.khata_links l where l.status in ('pending','accepted') and
((l.retailer_id=v_user and l.customer_id=v_customer) or (l.retailer_id=v_customer and l.customer_id=v_user))) then
raise exception 'इस व्यक्ति के साथ खाता पहले से जुड़ा है या अनुरोध लंबित है'; end if;
insert into public.khata_links(retailer_id,customer_id,shop_name) values(v_user,v_customer,nullif(trim(coalesce(p_shop_name,'')),'')) returning id into v_link;
return v_link;
end; $$;
create or replace function public.respond_khata_link(p_link_id uuid,p_accept boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
if auth.uid() is null then raise exception 'लॉगिन आवश्यक है'; end if;
update public.khata_links set status=case when p_accept then 'accepted' else 'rejected' end,updated_at=now()
where id=p_link_id and customer_id=auth.uid() and status='pending';
if not found then raise exception 'अनुरोध उपलब्ध नहीं है या पहले ही संसाधित हो चुका है'; end if;
end; $$;
create or replace function public.add_khata_transaction(p_link_id uuid,p_type text,p_amount numeric,p_note text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid:=auth.uid(); v_link public.khata_links%rowtype; v_id uuid;
begin
if v_user is null then raise exception 'लॉगिन आवश्यक है'; end if;
if p_type not in ('credit','payment') then raise exception 'लेन-देन का प्रकार सही नहीं है'; end if;
if p_amount is null or p_amount<=0 then raise exception 'राशि शून्य से अधिक होनी चाहिए'; end if;
select * into v_link from public.khata_links where id=p_link_id and status='accepted' and (retailer_id=v_user or customer_id=v_user);
if not found then raise exception 'लिंक किया हुआ खाता उपलब्ध नहीं है'; end if;
if p_type='credit' and v_link.retailer_id<>v_user then raise exception 'उधार केवल दुकानदार दर्ज कर सकता है'; end if;
insert into public.khata_transactions(link_id,transaction_type,amount,note,created_by) values(p_link_id,p_type,p_amount,nullif(trim(coalesce(p_note,'')),''),v_user) returning id into v_id;
return v_id;
end; $$;
revoke all on function public.request_khata_link(text,text) from public,anon;
revoke all on function public.respond_khata_link(uuid,boolean) from public,anon;
revoke all on function public.add_khata_transaction(uuid,text,numeric,text) from public,anon;
grant execute on function public.request_khata_link(text,text) to authenticated;
grant execute on function public.respond_khata_link(uuid,boolean) to authenticated;
grant execute on function public.add_khata_transaction(uuid,text,numeric,text) to authenticated;
do $$ begin
if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='khata_transactions') then
alter publication supabase_realtime add table public.khata_transactions; end if;
exception when undefined_object then null; end $$;