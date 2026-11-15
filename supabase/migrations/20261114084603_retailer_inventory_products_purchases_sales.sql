create table public.products (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  sku text, barcode text, name text not null, description text,
  unit text not null default 'piece',
  purchase_price numeric(14,2) not null default 0 check (purchase_price >= 0),
  sale_price numeric(14,2) not null default 0 check (sale_price >= 0),
  reorder_level numeric(14,3) not null default 0 check (reorder_level >= 0),
  is_active boolean not null default true,
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint products_account_id_id_unique unique (account_id,id),
  constraint products_sku_nonempty check (sku is null or length(trim(sku)) > 0),
  constraint products_barcode_nonempty check (barcode is null or length(trim(barcode)) > 0)
);
create unique index products_account_sku_unique on public.products(account_id, lower(sku)) where sku is not null;
create unique index products_account_barcode_unique on public.products(account_id, barcode) where barcode is not null;
create index products_account_name_idx on public.products(account_id, name);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  product_id uuid not null,
  movement_type text not null check (movement_type in ('opening','purchase','sale','adjustment_in','adjustment_out','return_in','return_out')),
  quantity_delta numeric(14,3) not null check (quantity_delta <> 0),
  unit_cost numeric(14,2) check (unit_cost is null or unit_cost >= 0),
  reference text, note text, occurred_at timestamptz not null default now(),
  created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
  constraint stock_movements_product_account_fkey foreign key (account_id,product_id) references public.products(account_id,id) on delete restrict,
  constraint stock_movement_direction_check check (
    (movement_type in ('opening','purchase','adjustment_in','return_in') and quantity_delta > 0)
    or (movement_type in ('sale','adjustment_out','return_out') and quantity_delta < 0)
  )
);
create index stock_movements_account_product_date_idx on public.stock_movements(account_id,product_id,occurred_at desc);
create index stock_movements_account_date_idx on public.stock_movements(account_id,occurred_at desc);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  supplier_id uuid, invoice_number text, purchase_date date not null default current_date,
  status text not null default 'draft' check (status in ('draft','received','cancelled')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  notes text, created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint purchases_account_id_id_unique unique (account_id,id),
  constraint purchases_supplier_account_fkey foreign key (account_id,supplier_id) references public.parties(account_id,id) on delete restrict
);
create index purchases_account_date_idx on public.purchases(account_id,purchase_date desc);
create index purchases_supplier_idx on public.purchases(account_id,supplier_id);

create table public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  purchase_id uuid not null, product_id uuid not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_cost numeric(14,2) not null check (unit_cost >= 0),
  line_total numeric(14,2) generated always as (round(quantity * unit_cost,2)) stored,
  created_at timestamptz not null default now(),
  constraint purchase_items_purchase_account_fkey foreign key (account_id,purchase_id) references public.purchases(account_id,id) on delete cascade,
  constraint purchase_items_product_account_fkey foreign key (account_id,product_id) references public.products(account_id,id) on delete restrict
);
create index purchase_items_purchase_idx on public.purchase_items(account_id,purchase_id);
create index purchase_items_product_idx on public.purchase_items(account_id,product_id);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  customer_id uuid, invoice_number text, sale_date date not null default current_date,
  status text not null default 'draft' check (status in ('draft','completed','cancelled')),
  subtotal numeric(14,2) not null default 0 check (subtotal >= 0),
  discount_amount numeric(14,2) not null default 0 check (discount_amount >= 0),
  tax_amount numeric(14,2) not null default 0 check (tax_amount >= 0),
  total_amount numeric(14,2) not null default 0 check (total_amount >= 0),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','partial','paid')),
  notes text, created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  constraint sales_account_id_id_unique unique (account_id,id),
  constraint sales_customer_account_fkey foreign key (account_id,customer_id) references public.parties(account_id,id) on delete restrict
);
create index sales_account_date_idx on public.sales(account_id,sale_date desc);
create index sales_customer_idx on public.sales(account_id,customer_id);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  sale_id uuid not null, product_id uuid not null,
  quantity numeric(14,3) not null check (quantity > 0),
  unit_price numeric(14,2) not null check (unit_price >= 0),
  line_total numeric(14,2) generated always as (round(quantity * unit_price,2)) stored,
  created_at timestamptz not null default now(),
  constraint sale_items_sale_account_fkey foreign key (account_id,sale_id) references public.sales(account_id,id) on delete cascade,
  constraint sale_items_product_account_fkey foreign key (account_id,product_id) references public.products(account_id,id) on delete restrict
);
create index sale_items_sale_idx on public.sale_items(account_id,sale_id);
create index sale_items_product_idx on public.sale_items(account_id,product_id);

alter table public.products enable row level security;
alter table public.stock_movements enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;

create policy "Account members read products" on public.products for select to authenticated
using (exists (select 1 from public.account_members am where am.account_id=products.account_id and am.user_id=(select auth.uid())));
create policy "Account admins insert products" on public.products for insert to authenticated
with check (created_by=(select auth.uid()) and exists (select 1 from public.account_members am where am.account_id=products.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));
create policy "Account admins update products" on public.products for update to authenticated
using (exists (select 1 from public.account_members am where am.account_id=products.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')))
with check (exists (select 1 from public.account_members am where am.account_id=products.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));
create policy "Account admins delete products" on public.products for delete to authenticated
using (exists (select 1 from public.account_members am where am.account_id=products.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));

create policy "Account members read stock movements" on public.stock_movements for select to authenticated
using (exists (select 1 from public.account_members am where am.account_id=stock_movements.account_id and am.user_id=(select auth.uid())));
create policy "Account admins insert stock movements" on public.stock_movements for insert to authenticated
with check (created_by=(select auth.uid()) and exists (select 1 from public.account_members am where am.account_id=stock_movements.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));

create policy "Account members read purchases" on public.purchases for select to authenticated
using (exists (select 1 from public.account_members am where am.account_id=purchases.account_id and am.user_id=(select auth.uid())));
create policy "Account members create purchases" on public.purchases for insert to authenticated
with check (created_by=(select auth.uid()) and exists (select 1 from public.account_members am where am.account_id=purchases.account_id and am.user_id=(select auth.uid())));
create policy "Account admins update purchases" on public.purchases for update to authenticated
using (exists (select 1 from public.account_members am where am.account_id=purchases.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')))
with check (exists (select 1 from public.account_members am where am.account_id=purchases.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));
create policy "Account admins delete purchases" on public.purchases for delete to authenticated
using (exists (select 1 from public.account_members am where am.account_id=purchases.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));

create policy "Account members read purchase items" on public.purchase_items for select to authenticated
using (exists (select 1 from public.account_members am where am.account_id=purchase_items.account_id and am.user_id=(select auth.uid())));
create policy "Account members create purchase items" on public.purchase_items for insert to authenticated
with check (exists (select 1 from public.account_members am where am.account_id=purchase_items.account_id and am.user_id=(select auth.uid())) and exists (select 1 from public.purchases p where p.id=purchase_items.purchase_id and p.account_id=purchase_items.account_id and p.status='draft'));

create policy "Account members read sales" on public.sales for select to authenticated
using (exists (select 1 from public.account_members am where am.account_id=sales.account_id and am.user_id=(select auth.uid())));
create policy "Account members create sales" on public.sales for insert to authenticated
with check (created_by=(select auth.uid()) and exists (select 1 from public.account_members am where am.account_id=sales.account_id and am.user_id=(select auth.uid())));
create policy "Account admins update sales" on public.sales for update to authenticated
using (exists (select 1 from public.account_members am where am.account_id=sales.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')))
with check (exists (select 1 from public.account_members am where am.account_id=sales.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));
create policy "Account admins delete sales" on public.sales for delete to authenticated
using (exists (select 1 from public.account_members am where am.account_id=sales.account_id and am.user_id=(select auth.uid()) and am.role in ('owner','admin')));

create policy "Account members read sale items" on public.sale_items for select to authenticated
using (exists (select 1 from public.account_members am where am.account_id=sale_items.account_id and am.user_id=(select auth.uid())));
create policy "Account members create sale items" on public.sale_items for insert to authenticated
with check (exists (select 1 from public.account_members am where am.account_id=sale_items.account_id and am.user_id=(select auth.uid())) and exists (select 1 from public.sales s where s.id=sale_items.sale_id and s.account_id=sale_items.account_id and s.status='draft'));

grant select, insert, update, delete on public.products to authenticated;
grant select, insert on public.stock_movements to authenticated;
grant select, insert, update, delete on public.purchases to authenticated;
grant select, insert on public.purchase_items to authenticated;
grant select, insert, update, delete on public.sales to authenticated;
grant select, insert on public.sale_items to authenticated;

create view public.inventory_stock_summary with (security_invoker = true) as
select p.account_id,p.id as product_id,p.sku,p.barcode,p.name,p.unit,p.reorder_level,
       coalesce(sum(sm.quantity_delta),0)::numeric(14,3) as quantity_on_hand,
       (coalesce(sum(sm.quantity_delta),0) <= p.reorder_level) as is_low_stock
from public.products p
left join public.stock_movements sm on sm.account_id=p.account_id and sm.product_id=p.id
where p.is_active
group by p.account_id,p.id,p.sku,p.barcode,p.name,p.unit,p.reorder_level;
grant select on public.inventory_stock_summary to authenticated;
