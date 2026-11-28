# Bharat Saathi Incoming AI Message Assistant

## Current product scope

- Incoming calls only.
- No outgoing calls.
- No call transfer.
- No Exotel integration, Exotel credentials, paid Exotel minutes, or Exotel status webhook.
- The app settings screen stores the user's mobile number, selected SIM slot, assistant instructions, disclosure preference, and transcript preference.
- The app can display call/message records already present in the user-scoped `ai_call_logs` table.

## Important implementation boundary

The current Flutter screen is a settings and message-history screen only. It does not answer ordinary carrier/PSTN calls, access cellular call audio, or create call records by itself.

A normal third-party Android app cannot simply take over the audio path of an incoming cellular call and speak to the caller. A supported carrier/device call-screening or telephony integration is still required for real incoming-call AI. Do not mark the feature as enabled or advertise it as live until a viable, policy-compliant, per-user solution has been implemented and tested on real devices.

## Cost requirement

Any future design must avoid per-minute cloud telephony charges at the scale Bharat Saathi targets. Do not add Exotel or another metered telephony provider without explicit product approval and a documented cost model. Do not add outbound calling or transfer functionality.

## Data and security

- Keep call records scoped to the authenticated Supabase user through database RLS.
- Do not store provider secrets in the Android app.
- Do not claim SIM ownership is verified merely because a number and SIM slot were saved.
- Only save transcripts when the caller has been appropriately informed and the user has enabled transcript storage.
- Existing database migrations are historical schema changes and should not be deleted merely to remove the Exotel implementation; review any schema cleanup separately after confirming production data and migration history.
