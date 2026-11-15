-- Service checkout is not exposed in the current app; keep its RPC server-only until a provider is certified.
REVOKE ALL ON FUNCTION public.create_bharat_saathi_service_checkout(uuid, text, numeric, numeric) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_bharat_saathi_service_checkout(uuid, text, numeric, numeric) TO service_role;
