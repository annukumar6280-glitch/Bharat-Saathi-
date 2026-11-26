create or replace function public.get_location_connections() returns jsonb
language sql stable security definer set search_path=''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id',c.id,
    'other_user_id',case when c.user_a=(select auth.uid()) then c.user_b else c.user_a end,
    'display_name',coalesce(nullif(p.full_name,''),'Bharat Saathi User'),
    'phone',p.phone,
    'status',c.status,
    'is_requester',c.requested_by=(select auth.uid()),
    'is_sharing',(c.status='accepted' and coalesce(s.enabled,false)),
    'latitude',case when c.status='accepted' and s.enabled then l.latitude else null end,
    'longitude',case when c.status='accepted' and s.enabled then l.longitude else null end,
    'accuracy_m',case when c.status='accepted' and s.enabled then l.accuracy_m else null end,
    'location_updated_at',case when c.status='accepted' and s.enabled then l.updated_at else null end
  ) order by c.updated_at desc),'[]'::jsonb)
  from public.location_connections c
  join public.profiles p on p.id=case when c.user_a=(select auth.uid()) then c.user_b else c.user_a end
  left join public.location_shares s on s.user_id=p.id
  left join public.active_locations l on l.user_id=p.id
  where (select auth.uid()) in (c.user_a,c.user_b);
$$;
revoke all on function public.get_location_connections() from public,anon;
grant execute on function public.get_location_connections() to authenticated;
