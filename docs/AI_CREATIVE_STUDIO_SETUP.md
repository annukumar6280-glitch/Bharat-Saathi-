# AI Creative Studio setup

The Android app calls the authenticated Supabase Edge Function `ai-creative-studio`. Image and video generation use **fal.ai**; Gemini is not used by this feature.

## Backend setup

1. Deploy `supabase/functions/ai-creative-studio/index.ts` as the `ai-creative-studio` Edge Function.
2. Add the provider key as a Supabase Edge Function secret named `FAL_KEY`.
3. Keep `SUPABASE_SERVICE_ROLE_KEY` and `FAL_KEY` server-side. Never add either key to Flutter assets, source constants, Remote Config, or the Android APK.
4. Keep Edge Function JWT verification enabled. The function independently validates the caller's Supabase session.
5. Confirm the AI coin wallet migrations and RPCs are applied before enabling customer generation.

## Image generation

- Text-to-image uses `fal-ai/flux/schnell`.
- Reference-image editing uses `fal-ai/flux-2/flash/edit`.
- The app accepts JPG, PNG and WebP reference images and requests a vertical 4:5 composition.
- The Edge Function charges the account through `consume_ai_coin_credit` and refunds failed provider requests through `refund_ai_coin_credit`.

## Video generation

- Text-to-video and image-to-video use the Fal Kling v2.5 Turbo Pro queue models.
- Each generated clip is five seconds. The Android app polls the queue, downloads the MP4, previews it and shares it.
- The app displays a 50-coin charge before starting a video. Fal provider usage is billed separately to the configured Fal account.
- Failed queued jobs are refunded through the server-side `refund_ai_video_job` flow. Do not rely on a client-side balance update as proof of payment or refund.

## Billing and release gate

- Coin purchase and rewarded-ad earning remain unavailable until verified server-side payment/reward webhooks are implemented.
- Never credit a wallet from a mobile client callback alone.
- Test with a non-production account before enabling customer access. Live generation consumes provider credits and may incur provider charges.
- Keep prompts, uploaded images, provider responses and API keys out of application logs unless safely redacted.
