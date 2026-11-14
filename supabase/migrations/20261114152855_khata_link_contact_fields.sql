alter table public.khata_links add column if not exists retailer_phone text, add column if not exists customer_phone text;
create or replace function public.request_khata_link(p_phone text,p_shop_name text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid:=auth.uid(); v_phone text:=right(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'),10);
v_customer uuid; v_customer_name text; v_customer_phone text; v_retailer_name text; v_retailer_phone text; v_link uuid;
begin
if v_user is null then raise exception 'लॉगिन आवश्यक है'; end if;
if length(v_phone)<>10 then raise exception '10 अंकों का मोबाइल नंबर दर्ज करें'; end if;
select p.id,p.full_name,p.phone into v_customer,v_customer_name,v_customer_phone from public.profiles p
where right(regexp_replace(coalesce(p.phone,''),'[^0-9]','','g'),10)=v_phone and p.id<>v_user limit 1;
if v_customer is null then raise exception 'इस नंबर से कोई रजिस्टर्ड Bharat Saathi अकाउंट नहीं मिला'; end if;
select p.full_name,p.phone into v_retailer_name,v_retailer_phone from public.profiles p where p.id=v_user;
if exists(select 1 from public.khata_links l where l.status in ('pending','accepted') and
((l.retailer_id=v_user and l.customer_id=v_customer) or (l.retailer_id=v_customer and l.customer_id=v_user))) then
raise exception 'इस व्यक्ति के साथ खाता पहले से जुड़ा है या अनुरोध लंबित है'; end if;
insert into public.khata_links(retailer_id,customer_id,shop_name,retailer_name,customer_name,retailer_phone,customer_phone)
values(v_user,v_customer,nullif(trim(coalesce(p_shop_name,'')),''),v_retailer_name,v_customer_name,v_retailer_phone,v_customer_phone) returning id into v_link;
return v_link;
end; $$;
revoke all on function public.request_khata_link(text,text) from public,anon;
grant execute on function public.request_khata_link(text,text) to authenticated;