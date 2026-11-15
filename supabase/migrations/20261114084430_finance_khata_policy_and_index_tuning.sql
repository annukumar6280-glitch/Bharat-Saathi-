drop policy "Owners and admins manage categories" on public.financial_categories;

create policy "Owners and admins insert categories"
  on public.financial_categories for insert to authenticated
  with check (exists (
    select 1 from public.account_members m
    where m.account_id = financial_categories.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ));

create policy "Owners and admins update categories"
  on public.financial_categories for update to authenticated
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

create policy "Owners and admins delete categories"
  on public.financial_categories for delete to authenticated
  using (exists (
    select 1 from public.account_members m
    where m.account_id = financial_categories.account_id
      and m.user_id = (select auth.uid())
      and m.role in ('owner','admin')
  ));

create index financial_categories_created_by_idx on public.financial_categories(created_by);
create index financial_categories_id_account_idx on public.financial_categories(id, account_id);
create index financial_transactions_category_account_idx on public.financial_transactions(category_id, account_id);
create index financial_transactions_created_by_idx on public.financial_transactions(created_by);
create index budgets_category_account_idx on public.budgets(category_id, account_id);
create index budgets_created_by_idx on public.budgets(created_by);
create index parties_created_by_idx on public.parties(created_by);
create index khata_entries_party_account_idx on public.khata_entries(party_id, account_id);
create index khata_entries_created_by_idx on public.khata_entries(created_by);
