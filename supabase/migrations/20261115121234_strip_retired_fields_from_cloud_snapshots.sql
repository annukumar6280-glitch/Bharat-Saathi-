-- Remove retired feature fields from existing account-scoped cloud snapshots.
UPDATE public.user_backups
SET payload = payload - ARRAY['products','sales','purchases','supplierLedger','salesReturns','stockAdjustments']::text[],
    updated_at = now()
WHERE payload ?| ARRAY['products','sales','purchases','supplierLedger','salesReturns','stockAdjustments'];
