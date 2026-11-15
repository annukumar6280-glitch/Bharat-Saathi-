create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  phone text,
  avatar_path text,
  preferred_language text not null default 'hi' check (preferred_language in ('hi','en')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  account_type text not null check (account_type in ('personal','retailer')),
  display_name text not null,
  currency_code text not null default 'INR' check (currency_code = 'INR'),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.account_members (
  account_id uuid not null references public.accounts(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','admin','staff','member')),
  joined_at timestamptz not null default now(),
  primary key (account_id, user_id)
);

create index account_members_user_id_idx on public.account_members(user_id);
create index accounts_created_by_idx on public.accounts(created_by);

alter table public.profiles enable row level security;
alter table public.accounts enable row level security;
alter table public.account_members enable row level security;

create policy "Users can read own profile"
  on public.profiles for select to authenticated
  using ((select auth.uid()) = id);

create policy "Users can create own profile"
  on public.profiles for insert to authenticated
  with check ((select auth.uid()) = id);

create policy "Users can update own profile"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "Members can read their accounts"
  on public.accounts for select to authenticated
  using (
    exists (
      select 1 from public.account_members m
      where m.account_id = accounts.id
        and m.user_id = (select auth.uid())
    )
  );

create policy "Users can create accounts"
  on public.accounts for insert to authenticated
  with check ((select auth.uid()) = created_by);

create policy "Owners and admins can update accounts"
  on public.accounts for update to authenticated
  using (
    exists (
      select 1 from public.account_members m
      where m.account_id = accounts.id
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    )
  )
  with check (
    exists (
      select 1 from public.account_members m
      where m.account_id = accounts.id
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    )
  );

create policy "Users can read their own memberships"
  on public.account_members for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Account creators can add themselves as owner"
  on public.account_members for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and role = 'owner'
    and exists (
      select 1 from public.accounts a
      where a.id = account_members.account_id
        and a.created_by = (select auth.uid())
    )
  );

grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.accounts to authenticated;
grant select, insert on public.account_members to authenticated;
