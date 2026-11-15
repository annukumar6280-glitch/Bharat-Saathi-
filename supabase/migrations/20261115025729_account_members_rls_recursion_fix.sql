-- Break the account_members -> accounts -> account_members RLS recursion.
-- The helper is kept in a non-exposed schema and only checks whether the
-- authenticated caller created the target account.
create schema if not exists private;
revoke all on schema private from public;
revoke all on schema private from anon, authenticated;
grant usage on schema private to authenticated;

create or replace function private.is_account_creator(p_account_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $function$
  select exists (
    select 1
    from public.accounts a
    where a.id = p_account_id
      and a.created_by = (select auth.uid())
  );
$function$;

revoke all on function private.is_account_creator(uuid) from public;
revoke all on function private.is_account_creator(uuid) from anon;
grant execute on function private.is_account_creator(uuid) to authenticated;

drop policy if exists "Account creators can add themselves as owner"
  on public.account_members;

create policy "Account creators can add themselves as owner"
on public.account_members
for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and role = 'owner'
  and (select private.is_account_creator(account_id))
);

-- Repair accounts created before their owner membership could be inserted.
insert into public.account_members (account_id, user_id, role)
select a.id, a.created_by, 'owner'
from public.accounts a
where not exists (
  select 1
  from public.account_members m
  where m.account_id = a.id
    and m.user_id = a.created_by
)
on conflict (account_id, user_id) do nothing;
