create unique index if not exists location_requests_pending_pair_unique
on public.location_requests(requester_id,target_id) where status='pending';

create or replace function public.request_live_location(p_connection_id uuid) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid(); v_target uuid; v_id uuid;
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  select case when c.user_a=v_me then c.user_b else c.user_a end into v_target
  from public.location_connections c
  where c.id=p_connection_id and c.status='accepted' and v_me in (c.user_a,c.user_b);
  if v_target is null then raise exception 'Accepted connection not found'; end if;
  select id into v_id from public.location_requests
    where requester_id=v_me and target_id=v_target and status='pending' limit 1;
  if v_id is not null then return v_id; end if;
  insert into public.location_requests(requester_id,target_id,status)
    values(v_me,v_target,'pending') returning id into v_id;
  return v_id;
end;
$$;
revoke all on function public.request_live_location(uuid) from public,anon;
grant execute on function public.request_live_location(uuid) to authenticated;

create or replace function public.request_location_connection(p_phone text) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid(); v_digits text; v_target uuid; v_a uuid; v_b uuid; v_existing public.location_connections%rowtype;
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  if (select count(*) from public.location_connections c
      where c.requested_by=v_me and c.status='pending' and c.created_at>now()-interval '1 hour') >= 20 then
    raise exception 'Too many pending invitations. Try again later.';
  end if;
  v_digits:=right(regexp_replace(coalesce(p_phone,''),'[^0-9]','','g'),10);
  if length(v_digits)<>10 then raise exception 'Enter a valid 10-digit mobile number'; end if;
  select p.id into v_target from public.profiles p where p.phone_normalized=v_digits limit 1;
  if v_target is null or v_target=v_me then
    return jsonb_build_object('ok',true,'message','If the number belongs to a Bharat Saathi account, a request has been sent.');
  end if;
  v_a:=least(v_me,v_target); v_b:=greatest(v_me,v_target);
  select * into v_existing from public.location_connections c where c.user_a=v_a and c.user_b=v_b;
  if found then
    if v_existing.status='accepted' then return jsonb_build_object('ok',true,'status','accepted'); end if;
    if v_existing.status='pending' then return jsonb_build_object('ok',true,'status','pending'); end if;
    update public.location_connections set requested_by=v_me,status='pending',updated_at=now() where id=v_existing.id;
  else
    insert into public.location_connections(user_a,user_b,requested_by,status) values(v_a,v_b,v_me,'pending');
  end if;
  return jsonb_build_object('ok',true,'message','If the number belongs to a Bharat Saathi account, a request has been sent.');
end;
$$;
revoke all on function public.request_location_connection(text) from public,anon;
grant execute on function public.request_location_connection(text) to authenticated;
