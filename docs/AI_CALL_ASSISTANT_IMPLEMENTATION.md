# Bharat Saathi AI Calling Assistant — implementation notes

## Target experience

Build an India-focused assistant similar in capability to hiRobin, without changing Bharat Saathi's existing Google/email authentication:

1. User selects SIM 1 or SIM 2 and saves their own mobile number.
2. Ownership is verified using an operator-backed CAMARA/GSMA Number Verification API when access is provisioned. This is a network verification flow, not a Supabase Auth phone-change OTP.
3. User receives/assigns an Exotel virtual number (ExoPhone) as the conditional call-forwarding destination.
4. User enables carrier conditional call forwarding (no-answer, busy, or unreachable) from their chosen SIM to the ExoPhone.
5. Exotel routes inbound calls to a bidirectional AgentStream WebSocket voice runtime.
6. The runtime connects to the AI voice model, follows the user's instructions, announces that it is an AI assistant, and can escalate to the user's transfer number.
7. Call status, transcript (only with the required notice/consent), and summary are stored in user-scoped call logs.

## Important platform facts

- The SIM selector in Flutter is only a preference until Android native Telecom/SIM integration is implemented. It does not itself capture carrier audio or set call forwarding.
- The app must not claim a number is verified merely because the signed-in Supabase Auth user has a phone value.
- Conditional call forwarding is configured by the mobile operator and may incur operator call charges.
- Exotel requires an approved account, assigned ExoPhone, API credentials, and an internet-reachable secure WebSocket endpoint. Exotel's AgentStream supports bidirectional audio. See the official Exotel Connect Voice AI and WebSocket protocol documentation.
- A carrier Number Verification API requires operator/aggregator onboarding and credentials; it is not a free, universal Android API.
- The mobile app must never contain Exotel API credentials, service-role keys, or OpenAI API keys.

## Supabase Edge Function

Function: `ai-call-assistant`

Actions:
- `POST ?action=start-outbound`: authenticated user starts an outbound call via Exotel Connect Voice AI.
- `POST ?action=status&token=...`: receives Exotel status callbacks and updates the matching call log.

Required Supabase Edge Function secrets:
- `EXOTEL_API_KEY`
- `EXOTEL_API_TOKEN`
- `EXOTEL_ACCOUNT_SID`
- `EXOTEL_CALLER_ID` (assigned ExoPhone)
- `EXOTEL_AI_STREAM_URL` (secure, deployed AgentStream WebSocket endpoint)
- `EXOTEL_STATUS_WEBHOOK_SECRET`

The outbound action intentionally refuses to call until the account's carrier verification status is `verified` and disclosure consent is stored. This prevents a false-success demo.

## Still required before live inbound AI calling

- CAMARA/GSMA carrier Number Verification integration and provider access.
- Production Exotel account/KYC, ExoPhone and approved forwarding setup.
- A deployed bidirectional AgentStream runtime connected to the chosen AI voice model, including Hindi/English audio handling, interruption/barge-in, transfer, timeout and failure fallback.
- Android native default-dialer/Telecom role and SIM-aware setup UX, if the app is to provide hiRobin-style on-device call handling. Android role approval and Play policy review are required.
- Real-device tests across supported Android versions and Airtel/Jio/Vi SIMs, including forwarding cancellation and emergency-call safeguards.

No live call should be advertised as working until the full inbound and outbound paths have been tested end-to-end.
