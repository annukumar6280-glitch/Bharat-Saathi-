create index if not exists location_connections_requested_by_idx on public.location_connections(requested_by);
create index if not exists location_requests_requester_idx on public.location_requests(requester_id);
create or replace function public.respond_live_location_request(p_request_id uuid,p_accept boolean) returns void
language plpgsql security definer set search_path=''
as $$
declare v_me uuid:=auth.uid();
begin
  if v_me is null then raise exception 'Authentication required'; end if;
  update public.location_requests set status=case when p_accept then 'accepted' else 'rejected' end,responded_at=now()
  where id=p_request_id and target_id=v_me and status='pending';
  if not found then raise exception 'Request not found or not allowed'; end if;
end;
$$;
revoke all on function public.respond_live_location_request(uuid,boolean) from public,anon;
grant execute on function public.respond_live_location_request(uuid,boolean) to authenticated;
