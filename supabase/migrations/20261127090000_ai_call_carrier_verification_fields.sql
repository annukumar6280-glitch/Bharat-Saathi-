-- Keep the AI assistant's mobile verification independent from Bharat Saathi Auth.
alter table public.ai_call_assistant_settings
  add column if not exists phone_verification_status text not null default 'pending'
    check (phone_verification_status in ('pending', 'verified', 'failed')),
  add column if not exists carrier_name text not null default '',
  add column if not exists provider_name text not null default 'exotel',
  add column if not exists provider_did text not null default '',
  add column if not exists forwarding_configured_at timestamptz;

comment on column public.ai_call_assistant_settings.phone_verification_status is
  'Verified only by the carrier Number Verification integration; never inferred from Supabase Auth phone.';
comment on column public.ai_call_assistant_settings.provider_did is
  'Assigned Exotel virtual number used as the conditional call-forwarding destination.';
