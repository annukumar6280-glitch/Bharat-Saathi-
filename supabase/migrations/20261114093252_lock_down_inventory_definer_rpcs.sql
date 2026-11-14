REVOKE EXECUTE ON FUNCTION public.adjust_inventory_stock(uuid, uuid, numeric, text) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.complete_sale(uuid, numeric) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.receive_purchase(uuid, numeric) FROM PUBLIC, anon, authenticated;
