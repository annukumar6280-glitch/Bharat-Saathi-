-- Remove the retired AI Call Assistant schema and its optional redemption RPC.
drop function if exists public.redeem_ai_call_month();
drop table if exists public.ai_call_logs cascade;
drop table if exists public.ai_call_assistant_settings cascade;
drop table if exists public.ai_call_subscriptions cascade;
