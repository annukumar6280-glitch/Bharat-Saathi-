-- The app no longer supports inventory, purchase or sales management.
-- The six affected tables were verified empty before removal.
DROP VIEW IF EXISTS public.inventory_stock_summary;
DROP FUNCTION IF EXISTS public.adjust_inventory_stock(uuid, uuid, numeric, text);
DROP FUNCTION IF EXISTS public.complete_sale(uuid, numeric);
DROP FUNCTION IF EXISTS public.receive_purchase(uuid, numeric);
DROP TABLE IF EXISTS public.sale_items, public.sales, public.purchase_items, public.purchases, public.stock_movements, public.products CASCADE;
