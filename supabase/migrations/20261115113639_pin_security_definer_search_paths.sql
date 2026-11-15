-- Pin all custom SECURITY DEFINER functions to an empty search_path.
ALTER FUNCTION public.add_khata_transaction(uuid, text, numeric, text) SET search_path = '';
ALTER FUNCTION public.request_khata_link(text, text) SET search_path = '';
ALTER FUNCTION public.respond_khata_link(uuid, boolean) SET search_path = '';
ALTER FUNCTION public.apply_bharat_saathi_referral_code(text) SET search_path = '';

ALTER FUNCTION public.lookup_auth_user_for_phone_login(text) SET search_path = '';
ALTER FUNCTION public.consume_phone_login_rate_limit(text, text) SET search_path = '';
ALTER FUNCTION public.is_phone_login_rate_limited(text, text) SET search_path = '';
