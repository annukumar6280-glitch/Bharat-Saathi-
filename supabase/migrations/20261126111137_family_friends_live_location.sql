create table if not exists public.location_connections (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  requested_by uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint location_connections_distinct_users check (user_a <> user_b),
  constraint location_connections_ordered check (user_a < user_b),
  constraint location_connections_requester check (requested_by in (user_a,user_b)),
  constraint location_connections_pair_unique unique (user_a,user_b)
);
create table if not exists public.location_shares (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);
create table if not exists public.active_locations (
  user_id uuid primary key references auth.users(id) on delete cascade,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  accuracy_m double precision,
  updated_at timestamptz not null default now()
);
create table if not exists public.location_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  constraint location_requests_distinct_users check (requester_id <> target_id)
);
create index if not exists location_connections_user_a_idx on public.location_connections(user_a,status);
create index if not exists location_connections_user_b_idx on public.location_connections(user_b,status);
create index if not exists location_requests_target_status_idx on public.location_requests(target_id,status,created_at desc);
alter table public.location_connections enable row level security;
alter table public.location_shares enable row level security;
alter table public.active_locations enable row level security;
alter table public.location_requests enable row level security;
drop policy if exists "Members can view their location connections" on public.location_connections;
create policy "Members can view their location connections" on public.location_connections for select to authenticated
using ((select auth.uid()) in (user_a,user_b));
drop policy if exists "Users can view location share settings in accepted connections" on public.location_shares;
create policy "Users can view location share settings in accepted connections" on public.location_shares for select to authenticated
using (user_id = (select auth.uid()) or exists (
  select 1 from public.location_connections c where c.status='accepted'
  and ((c.user_a=(select auth.uid()) and c.user_b=location_shares.user_id)
    or (c.user_b=(select auth.uid()) and c.user_a=location_shares.user_id))
));
drop policy if exists "Users can manage own location share setting" on public.location_shares;
create policy "Users can manage own location share setting" on public.location_shares for all to authenticated
using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
drop policy if exists "Users can read locations they are allowed to see" on public.active_locations;
create policy "Users can read locations they are allowed to see" on public.active_locations for select to authenticated
using (user_id=(select auth.uid()) or (
  exists (select 1 from public.location_shares s where s.user_id=active_locations.user_id and s.enabled=true)
  and exists (select 1 from public.location_connections c where c.status='accepted'
    and ((c.user_a=(select auth.uid()) and c.user_b=active_locations.user_id)
      or (c.user_b=(select auth.uid()) and c.user_a=active_locations.user_id)))
));
drop policy if exists "Users can publish own location to accepted connections" on public.active_locations;
create policy "Users can publish own location to accepted connections" on public.active_locations for all to authenticated
using (user_id=(select auth.uid())
  and exists (select 1 from public.location_shares s where s.user_id=(select auth.uid()) and s.enabled=true)
  and exists (select 1 from public.location_connections c where c.status='accepted' and (c.user_a=(select auth.uid()) or c.user_b=(select auth.uid()))))
with check (user_id=(select auth.uid())
  and exists (select 1 from public.location_shares s where s.user_id=(select auth.uid()) and s.enabled=true)
  and exists (select 1 from public.location_connections c where c.status='accepted' and (c.user_a=(select auth.uid()) or c.user_b=(select auth.uid()))));
drop policy if exists "Participants can view location requests" on public.location_requests;
create policy "Participants can view location requests" on public.location_requests for select to authenticated
using ((select auth.uid()) in (requester_id,target_id));
revoke all on public.location_connections from anon,authenticated;
grant select on public.location_connections to authenticated;
revoke all on public.location_shares from anon,authenticated;
grant select,insert,update,delete on public.location_shares to authenticated;
revoke all on public.active_locations from anon,authenticated;
grant select,insert,update,delete on public.active_locations to authenticated;
revoke all on public.location_requests from anon,authenticated;
grant select on public.location_requests to authenticated;

create or replace function public.request_location_connection(p_phone text) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid(); v_digits text; v_target uuid; v_a uuid; v_b uuid; v_existing public.location_connections%rowtype;
begin
  if v_me is null then raise exception 'Authentication required'; end if;
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

create or replace function public.respond_location_connection(p_connection_id uuid,p_accept boolean) returns void
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid();
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  update public.location_connections set status=case when p_accept then 'accepted' else 'rejected' end,updated_at=now()
  where id=p_connection_id and status='pending' and v_me in (user_a,user_b) and requested_by<>v_me;
  if not found then raise exception 'Request not found or not allowed'; end if;
end;
$$;

create or replace function public.set_location_sharing(p_enabled boolean) returns void
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid();
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  if p_enabled and not exists (select 1 from public.location_connections c where c.status='accepted' and v_me in (c.user_a,c.user_b)) then
    raise exception 'Add and accept a Family/Friend connection before sharing location';
  end if;
  insert into public.location_shares(user_id,enabled,updated_at) values(v_me,p_enabled,now())
  on conflict(user_id) do update set enabled=excluded.enabled,updated_at=now();
  if not p_enabled then delete from public.active_locations where user_id=v_me; end if;
end;
$$;

create or replace function public.request_live_location(p_connection_id uuid) returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid(); v_target uuid; v_id uuid;
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  select case when c.user_a=v_me then c.user_b else c.user_a end into v_target
  from public.location_connections c where c.id=p_connection_id and c.status='accepted' and v_me in (c.user_a,c.user_b);
  if v_target is null then raise exception 'Accepted connection not found'; end if;
  insert into public.location_requests(requester_id,target_id,status) values(v_me,v_target,'pending') returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.get_location_connections() returns jsonb
language sql stable security definer set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,'other_user_id',case when c.user_a=(select auth.uid()) then c.user_b else c.user_a end,
    'display_name',coalesce(nullif(p.full_name,''),'Bharat Saathi User'),'phone',p.phone,'status',c.status,
    'is_requester',c.requested_by=(select auth.uid()),'is_sharing',coalesce(s.enabled,false),
    'latitude',case when s.enabled then l.latitude else null end,
    'longitude',case when s.enabled then l.longitude else null end,
    'accuracy_m',case when s.enabled then l.accuracy_m else null end,
    'location_updated_at',case when s.enabled then l.updated_at else null end
  ) order by c.updated_at desc),'[]'::jsonb)
  from public.location_connections c
  join public.profiles p on p.id=case when c.user_a=(select auth.uid()) then c.user_b else c.user_a end
  left join public.location_shares s on s.user_id=p.id
  left join public.active_locations l on l.user_id=p.id
  where (select auth.uid()) in (c.user_a,c.user_b);
$$;

create or replace function public.get_location_requests() returns jsonb
language sql stable security definer set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',r.id,'requester_id',r.requester_id,'target_id',r.target_id,
    'is_incoming',r.target_id=(select auth.uid()),'status',r.status,'created_at',r.created_at,
    'display_name',coalesce(nullif(p.full_name,''),'Bharat Saathi User')
  ) order by r.created_at desc),'[]'::jsonb)
  from public.location_requests r
  join public.profiles p on p.id=case when r.target_id=(select auth.uid()) then r.requester_id else r.target_id end
  where (select auth.uid()) in (r.requester_id,r.target_id);
$$;

do $$
begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') then
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='location_connections') then alter publication supabase_realtime add table public.location_connections; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='location_shares') then alter publication supabase_realtime add table public.location_shares; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='active_locations') then alter publication supabase_realtime add table public.active_locations; end if;
  if not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='location_requests') then alter publication supabase_realtime add table public.location_requests; end if;
 end if;
end $$;

revoke all on function public.request_location_connection(text) from public,anon;
revoke all on function public.respond_location_connection(uuid,boolean) from public,anon;
revoke all on function public.set_location_sharing(boolean) from public,anon;
revoke all on function public.request_live_location(uuid) from public,anon;
revoke all on function public.get_location_connections() from public,anon;
revoke all on function public.get_location_requests() from public,anon;
grant execute on function public.request_location_connection(text) to authenticated;
grant execute on function public.respond_location_connection(uuid,boolean) to authenticated;
grant execute on function public.set_location_sharing(boolean) to authenticated;
grant execute on function public.request_live_location(uuid) to authenticated;
grant execute on function public.get_location_connections() to authenticated;
grant execute on function public.get_location_requests() to authenticated;
