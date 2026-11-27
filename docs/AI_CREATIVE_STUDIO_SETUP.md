# AI Creative Studio setup

The Android client never asks customers for a Gemini API key. Image and video generation are routed through the authenticated Supabase Edge Function `ai-creative-studio`.

## Backend setup

1. Deploy `supabase/functions/ai-creative-studio/index.ts` as the `ai-creative-studio` Edge Function.
2. Add the Google AI Studio key as a Supabase Edge Function secret named `GEMINI_API_KEY`.
3. Keep the Gemini key server-side. Never add it to Flutter assets, source constants, Remote Config, or the Android APK.
4. Keep Edge Function JWT verification enabled and require a signed-in user.
5. Test with a non-production account before enabling customer access.

## Image generation

The image path uses Gemini image generation. The app supports general-purpose creative work and shop/business advertising. A customer may optionally upload a JPG, PNG, or WebP reference image. Shop name and phone number are optional and are only used in shop mode.

The live quota RPC currently allows five free image generations per account per UTC month. Paid image generations use the configured coin wallet. Failed provider requests are refunded by the Edge Function.

## Video generation

The video path uses the Gemini Interactions API with the `gemini-omni-1.2-flash` model. It supports text-to-video and image-to-video, returns an MP4 to the Android app, and the app previews and shares the result locally. It does not require the Google Flow app or a separate APK.

A successful video generation costs 50 Bharat Saathi coins according to the server-side quota RPC. The Google Gemini API may also incur separate provider charges. The Gemini Developer API video model requires an eligible paid project and available provider quota/billing. A saved API key alone does not guarantee video generation will work. Do not run live generation tests on a customer's account without their explicit confirmation because provider billing may apply.

Google Flow and the Gemini Developer API are separate products. This app integrates the Gemini API directly; it does not automate or embed the Google Flow website.

## Billing and safety release gate

Before selling credits or subscriptions, add a verified payment webhook that updates paid entitlements server-side, idempotently, and only after a confirmed payment. The mobile app must never mark a payment successful based on a client callback alone. Preserve provider error details for support, but never log API keys or full user-uploaded media.
