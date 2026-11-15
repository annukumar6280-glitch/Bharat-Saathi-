-- Keep login throttling state outside the exposed public API schema.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
ALTER TABLE public.phone_login_rate_limits SET SCHEMA private;
ALTER TABLE private.phone_login_rate_limits DISABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE private.phone_login_rate_limits FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.consume_phone_login_rate_limit(p_phone text, p_ip text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, private, extensions
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
  INSERT INTO private.phone_login_rate_limits(scope, key_hash) VALUES ('phone', v_phone_hash)
  ON CONFLICT (scope, key_hash) DO NOTHING;
  SELECT blocked_until INTO v_blocked_until FROM private.phone_login_rate_limits
  WHERE scope = 'phone' AND key_hash = v_phone_hash FOR UPDATE;
  v_now := clock_timestamp();
  IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
  UPDATE private.phone_login_rate_limits
  SET window_started_at = CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN v_now ELSE window_started_at END,
      attempts = CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN 1 ELSE attempts + 1 END,
      blocked_until = CASE WHEN (CASE WHEN window_started_at <= v_now - interval '15 minutes' THEN 1 ELSE attempts + 1 END) > 8 THEN v_now + interval '15 minutes' ELSE NULL END
  WHERE scope = 'phone' AND key_hash = v_phone_hash
  RETURNING attempts, blocked_until INTO v_attempts, v_blocked_until;
  IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
  IF coalesce(p_ip, '') <> '' AND p_ip <> 'unknown' THEN
    v_ip_hash := encode(extensions.digest(convert_to('ip:' || p_ip, 'UTF8'), 'sha256'), 'hex');
    INSERT INTO private.phone_login_rate_limits(scope, key_hash) VALUES ('ip', v_ip_hash)
    ON CONFLICT (scope, key_hash) DO NOTHING;
    SELECT blocked_until INTO v_blocked_until FROM private.phone_login_rate_limits
    WHERE scope = 'ip' AND key_hash = v_ip_hash FOR UPDATE;
    IF v_blocked_until IS NOT NULL AND v_blocked_until > v_now THEN RETURN false; END IF;
    UPDATE private.phone_login_rate_limits
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
