# Bharat Saathi — Exotel + OpenAI Voice Server

This folder contains the Exotel AgentStream ↔ OpenAI Realtime sample adapted as a starting point for Bharat Saathi.

## Important status

- This is source code only. It is not deployed and does not yet have a public WSS URL.
- Exotel must enable the Voicebot / bidirectional AgentStream feature for the account and number.
- Do not configure an Exotel Flow or make live calls until the WSS service has been deployed, secured, and tested.
- The upstream Exotel sample says it is a starting sample, not a production multi-tenant autoscaling service. Review and harden before production.
- Do not commit real API keys or tokens. Put them in the hosting provider's secret/environment-variable settings.

## Architecture

Exotel AgentStream (8 kHz mono PCM) ↔ this server ↔ OpenAI Realtime (24 kHz PCM).

The bridge handles audio conversion and streaming. The initial system instructions are deliberately conservative; the final call purpose and permitted actions still need to be defined.

## Required environment

Copy `.env.example` to `.env` for local testing, or configure these as environment variables in the hosting service:

- `OPENAI_API_KEY` — reuse the existing OpenAI API key value; do not paste it into GitHub or chat.
- `OPENAI_MODEL=gpt-realtime`
- `OPENAI_VOICE=coral`
- `COMPANY_NAME=Bharat Saathi`
- `SALES_BOT_NAME=Bharat Saathi Assistant`
- `SERVER_HOST=0.0.0.0`
- `SERVER_PORT=5000`
- `SAMPLE_RATE=8000`
- `DEFAULT_SAMPLE_RATE=8000`
- `SEND_TEST_TONE=false`

The key already saved in Supabase can be reused, but a separate hosting service cannot automatically read Supabase Edge Function secrets. The same key value must be entered securely in the hosting service's secret settings.

## Run locally

Python 3.10+ is required.

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Add OPENAI_API_KEY to .env locally; never commit .env
python main.py
```

The server listens on port 5000. For a temporary test only, expose it through a secure WSS tunnel. Production requires a stable, always-on HTTPS/WSS host.

## Exotel Stream URL

The upstream integration uses:

```
wss://YOUR_HOST/?sample-rate=8000
```

Exotel's support team must confirm AgentStream/Voicebot enablement and the correct flow setup first.

## Upstream source

Based on Exotel's public MIT-licensed sample:
https://github.com/exotel/Agent-Stream/tree/main/integrations/openai-realtime

This branch keeps the voice-server work isolated from the app's main branch.
