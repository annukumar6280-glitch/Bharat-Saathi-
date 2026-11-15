create table public.financial_categories (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  transaction_type text not null check (transaction_type in ('income','expense')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (id, account_id),
  unique (account_id, name, transaction_type)
);

create table public.financial_transactions (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  category_id uuid,
  transaction_type text not null check (transaction_type in ('income','expense')),
  amount numeric(14,2) not null check (amount > 0),
  transaction_date date not null default current_date,
  description text,
  payment_method text not null default 'cash'
    check (payment_method in ('cash','upi','bank','card','cheque','other')),
  reference_number text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (category_id, account_id)
    references public.financial_categories(id, account_id) on delete restrict
);

create table public.budgets (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  category_id uuid,
  name text not null,
  amount numeric(14,2) not null check (amount > 0),
  period_start date not null,
  period_end date not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  check (period_end >= period_start),
  foreign key (category_id, account_id)
    references public.financial_categories(id, account_id) on delete restrict
);

create table public.parties (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  party_type text not null check (party_type in ('customer','supplier','both')),
  name text not null,
  phone text,
  address text,
  notes text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, account_id)
);

create index parties_account_name_idx on public.parties(account_id, name);
create index parties_account_phone_idx on public.parties(account_id, phone);

create table public.khata_entries (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  party_id uuid not null,
  entry_type text not null check (entry_type in ('charge','payment','adjustment')),
  balance_side text not null check (balance_side in ('receivable','payable')),
  amount numeric(14,2) not null check (amount > 0),
  entry_date date not null default current_date,
  note text,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  foreign key (party_id, account_id)
    references public.parties(id, account_id) on delete restrict,
  check (entry_type <> 'adjustment' or (note is not null and length(trim(note)) > 0))
);

create index financial_transactions_account_date_idx
  on public.financial_transactions(account_id, transaction_date desc);
create index financial_transactions_category_idx
  on public.financial_transactions(category_id);
create index budgets_account_period_idx
  on public.budgets(account_id, period_start, period_end);
create index khata_entries_account_party_date_idx
  on public.khata_entries(account_id, party_id, entry_date desc);

alter table public.financial_categories enable row level security;
alter table public.financial_transactions enable row level security;
alter table public.budgets enable row level security;
alter table public.parties enable row level security;
alter table public.khata_entries enable row level security;

create policy "Members can read account categories"
  on public.financial_categories for select to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = financial_categories.account_id
      and m.user_id = (select auth.uid())
  ));

create policy "Owners and admins manage categories"
  on public.financial_categories for all to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = financial_categories.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ))
  with check (exists (
    select 1 from public.account_members m
    where m.account_id = financial_categories.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ));

create policy "Members can read account transactions"
  on public.financial_transactions for select to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = financial_transactions.account_id
      and m.user_id = (select auth.uid())
  ));

create policy "Members can add account transactions"
  on public.financial_transactions for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.account_members m
      where m.account_id = financial_transactions.account_id
        and m.user_id = (select auth.uid())
    )
  );

create policy "Creators or admins can update transactions"
  on public.financial_transactions for update to authenticated
  using (
    created_by = (select auth.uid())
    or exists (
      select 1 from public.account_members m
      where m.account_id = financial_transactions.account_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    )
  )
  with check (
    created_by = (select auth.uid())
    or exists (
      select 1 from public.account_members m
      where m.account_id = financial_transactions.account_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    )
  );

create policy "Admins can delete transactions"
  on public.financial_transactions for delete to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = financial_transactions.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ));

create policy "Members can read budgets"
  on public.budgets for select to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = budgets.account_id
      and m.user_id = (select auth.uid())
  ));

create policy "Members can create budgets"
  on public.budgets for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.account_members m
      where m.account_id = budgets.account_id
        and m.user_id = (select auth.uid())
    )
  );

create policy "Creators or admins can update budgets"
  on public.budgets for update to authenticated
  using (
    created_by = (select auth.uid())
    or exists (
      select 1 from public.account_members m
      where m.account_id = budgets.account_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    )
  )
  with check (
    created_by = (select auth.uid())
    or exists (
      select 1 from public.account_members m
      where m.account_id = budgets.account_id
        and m.user_id = (select auth.uid())
        and m.role in ('owner','admin')
    )
  );

create policy "Admins can delete budgets"
  on public.budgets for delete to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = budgets.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ));

create policy "Members can read parties"
  on public.parties for select to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = parties.account_id
      and m.user_id = (select auth.uid())
  ));

create policy "Members can create parties"
  on public.parties for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.account_members m
      where m.account_id = parties.account_id
        and m.user_id = (select auth.uid())
    )
  );

create policy "Members can update parties"
  on public.parties for update to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = parties.account_id
      and m.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.account_members m
    where m.account_id = parties.account_id
      and m.user_id = (select auth.uid())
  ));

create policy "Admins can delete parties"
  on public.parties for delete to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = parties.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ));

create policy "Members can read khata entries"
  on public.khata_entries for select to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = khata_entries.account_id
      and m.user_id = (select auth.uid())
  ));

create policy "Members can add khata entries"
  on public.khata_entries for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.account_members m
      where m.account_id = khata_entries.account_id
        and m.user_id = (select auth.uid())
    )
  );

grant select, insert, update, delete on public.financial_categories to authenticated;
grant select, insert, update, delete on public.financial_transactions to authenticated;
grant select, insert, update, delete on public.budgets to authenticated;
grant select, insert, update, delete on public.parties to authenticated;
grant select, insert on public.khata_entries to authenticated;
