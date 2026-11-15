-- Ensure the lockout check uses a fresh wall-clock timestamp for each call.
CREATE OR REPLACE FUNCTION public.is_phone_login_rate_limited(p_phone text, p_ip text)
RETURNS boolean
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = pg_catalog, private, extensions
AS $$
DECLARE
  v_phone_hash text;
  v_ip_hash text;
  v_now timestamptz := clock_timestamp();
BEGIN
  IF p_phone !~ '^[6-9][0-9]{9}$' THEN RETURN true; END IF;
  v_phone_hash := encode(extensions.digest(convert_to('phone:' || p_phone, 'UTF8'), 'sha256'), 'hex');
  IF EXISTS (SELECT 1 FROM private.phone_login_rate_limits WHERE scope='phone' AND key_hash=v_phone_hash AND blocked_until IS NOT NULL AND blocked_until>v_now) THEN RETURN true; END IF;
  IF coalesce(p_ip, '') <> '' AND p_ip <> 'unknown' THEN
    v_ip_hash := encode(extensions.digest(convert_to('ip:' || p_ip, 'UTF8'), 'sha256'), 'hex');
    IF EXISTS (SELECT 1 FROM private.phone_login_rate_limits WHERE scope='ip' AND key_hash=v_ip_hash AND blocked_until IS NOT NULL AND blocked_until>v_now) THEN RETURN true; END IF;
  END IF;
  RETURN false;
END;
$$;
REVOKE ALL ON FUNCTION public.is_phone_login_rate_limited(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_phone_login_rate_limited(text, text) TO service_role;
