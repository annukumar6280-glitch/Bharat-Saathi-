create or replace function public.add_khata_transaction(p_link_id uuid,p_type text,p_amount numeric,p_note text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid:=auth.uid(); v_link public.khata_links%rowtype; v_id uuid; v_due numeric(12,2);
begin
if v_user is null then raise exception 'लॉगिन आवश्यक है'; end if;
if p_type not in ('credit','payment') then raise exception 'लेन-देन का प्रकार सही नहीं है'; end if;
if p_amount is null or p_amount<=0 then raise exception 'राशि शून्य से अधिक होनी चाहिए'; end if;
select * into v_link from public.khata_links where id=p_link_id and status='accepted'
and (retailer_id=v_user or customer_id=v_user) for update;
if not found then raise exception 'लिंक किया हुआ खाता उपलब्ध नहीं है'; end if;
if p_type='credit' and v_link.retailer_id<>v_user then raise exception 'उधार केवल दुकानदार दर्ज कर सकता है'; end if;
if p_type='payment' then
select coalesce(sum(case when transaction_type='credit' then amount else -amount end),0) into v_due
from public.khata_transactions where link_id=p_link_id;
if p_amount>v_due then raise exception 'वापसी की राशि मौजूदा बकाया से अधिक नहीं हो सकती'; end if;
end if;
insert into public.khata_transactions(link_id,transaction_type,amount,note,created_by)
values(p_link_id,p_type,p_amount,nullif(trim(coalesce(p_note,'')),''),v_user) returning id into v_id;
return v_id;
end; $$;
revoke all on function public.add_khata_transaction(uuid,text,numeric,text) from public,anon;
grant execute on function public.add_khata_transaction(uuid,text,numeric,text) to authenticated;