-- Disable the legacy commission-to-prepaid-service-wallet transfer path.
REVOKE EXECUTE ON FUNCTION public.transfer_commission_to_service_wallet(numeric) FROM PUBLIC, anon, authenticated, service_role;
