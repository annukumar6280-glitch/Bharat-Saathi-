-- Harden phone/password login lookup and add persistent abuse throttling.
CREATE OR REPLACE FUNCTION public.normalize_indian_mobile(p_value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
PARALLEL SAFE
SET search_path = pg_catalog
AS $$
  SELECT CASE
    WHEN length(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g')) = 12
      AND left(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g'), 2) = '91'
      THEN right(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g'), 10)
    WHEN length(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g'), '[^0-9]', '', 'g')) = 11
      AND left(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g'), 1) = '0'
      THEN right(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g'), 10)
    WHEN length(regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g')) = 10
      THEN regexp_replace(coalesce(p_value, ''), '[^0-9]', '', 'g')
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public.lookup_auth_user_for_phone_login(p_phone text)
RETURNS TABLE(user_id uuid, user_email text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, auth
AS $$
  SELECT matches.id, matches.email
  FROM (
    SELECT p.id, u.email
    FROM public.profiles AS p
    JOIN auth.users AS u ON u.id = p.id
    WHERE p.phone_normalized = p_phone
    UNION
    SELECT u.id, u.email
    FROM auth.users AS u
    WHERE public.normalize_indian_mobile(u.raw_user_meta_data ->> 'phone') = p_phone
  ) AS matches
  WHERE p_phone ~ '^[6-9][0-9]{9}$'
  ORDER BY matches.id
  LIMIT 2;
$$;

REVOKE ALL ON FUNCTION public.lookup_auth_user_for_phone_login(text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.lookup_auth_user_for_phone_login(text) TO service_role;

CREATE TABLE IF NOT EXISTS public.phone_login_rate_limits (
  scope text NOT NULL CHECK (scope IN ('phone', 'ip')),
  key_hash text NOT NULL,
  window_started_at timestamptz NOT NULL DEFAULT clock_timestamp(),
  attempts integer NOT NULL DEFAULT 0 CHECK (attempts >= 0),
  blocked_until timestamptz,
  PRIMARY KEY (scope, key_hash)
);
ALTER TABLE public.phone_login_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.phone_login_rate_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.phone_login_rate_limits TO service_role;

CREATE OR REPLACE FUNCTION public.consume_phone_login_rate_limit(p_phone text, p_ip text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, extensions
AS $$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_phone_hash text;
  v_ip_hash text;
  v_attempts integer;
  v_blocked_until timestamptz;
BEGIN
  IF p_phone !~ '^[6-9][0-9]{9}$' THEN RETURN false; END IF;
  v_phone_hash := encode(extensions.digest(convert_to('phone:' || p_phone, 'UTF8'), 'sha256'), 'hex');
  INSERT INTO public.phone_login_rate_limits(scope, key_hash) VALUES ('phone', v_phone_hash)
  ON CONFLICT (scope, key_hash) DO NOTHING;
  SELECT blocked_until INTO v_blocked_until FROM public.phone_login_rate_limits
  WHERE scope = 'phone' AND key_hash = v_phone_hash FOR UPDATE;
  v_now := clock_timestamp();
  IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
  UPDATE public.phone_login_rate_limits
  SET window_started_at = CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN v_now ELSE window_started_at END,
      attempts = CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN 1 ELSE attempts + 1 END,
      blocked_until = CASE WHEN (CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN 1 ELSE attempts + 1 END) > 8 THEN v_now + interval '15 minutes' ELSE NULL END
  WHERE scope = 'phone' AND key_hash = v_phone_hash
  RETURNING attempts, blocked_until INTO v_attempts, v_blocked_until;
  IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
  IF coalesce(p_ip, '') <> '' AND p_ip <> 'unknown' THEN
    v_ip_hash := encode(extensions.digest(convert_to('ip:' || p_ip, 'UTF8'), 'sha256'), 'hex');
    INSERT INTO public.phone_login_rate_limits(scope, key_hash) VALUES ('ip', v_ip_hash)
    ON CONFLICT (scope, key_hash) DO NOTHING;
    SELECT blocked_until INTO v_blocked_until FROM public.phone_login_rate_limits
    WHERE scope = 'ip' AND key_hash = v_ip_hash FOR UPDATE;
    IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
    UPDATE public.phone_login_rate_limits
    SET window_started_at = CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN v_now ELSE window_started_at END,
        attempts = CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN 1 ELSE attempts + 1 END,
        blocked_until = CASE WHEN (CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN 1 ELSE attempts + 1 END) > 40 THEN v_now + interval '15 minutes' ELSE NULL END
    WHERE scope = 'ip' AND key_hash = v_ip_hash
    RETURNING attempts, blocked_until INTO v_attempts, v_blocked_until;
    IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
  END IF;
  RETURN true;
END;
$$;
REVOKE ALL ON FUNCTION public.consume_phone_login_rate_limit(text, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_phone_login_rate_limit(text, text) TO service_role;
