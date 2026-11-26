# AI Creative Studio setup

The Android client never asks customers for a Gemini API key. Image generation is routed through the authenticated Supabase Edge Function `ai-creative-studio`.

## Image generation release setup

1. Apply `supabase/migrations/202611250001_ai_generation_quota.sql` to the Supabase project.
2. Deploy `supabase/functions/ai-creative-studio/index.ts` as the `ai-creative-studio` Edge Function.
3. Add the Google AI Studio key as a Supabase Edge Function secret named `GEMINI_API_KEY`. Never add this secret to Flutter assets, source constants, Remote Config, or the Android APK.
4. Sign in to the app and test an image generation from AI Creative Studio.

The database enforces 10 free image generations per account per UTC calendar month. After that, the Edge Function requires paid credits. Paid credits are not purchasable in this build: a verified payment-gateway webhook must credit `ai_generation_quota.paid_credits` before charging customers. Do not expose a client-side method to increase credits.

The app supports two creative modes: general-purpose creative work and shop/business advertising. A customer may optionally upload a JPG, PNG, or WebP reference photo for an image edit/generation request. Shop name and phone number are optional and only used in shop mode.

## Video generation

The video screen is present, but video generation is intentionally not represented as live. Production video generation requires a Google Cloud / Vertex AI Veo project, server-side service-account authentication, and a Cloud Storage output bucket with controlled download access. These credentials must remain server-side. Configure and test that backend before enabling video generation for customers.

## Billing release gate

Before selling credits or subscriptions, add a verified payment webhook that updates paid entitlements server-side, idempotently, and only after a confirmed payment. The mobile app must never mark a payment successful based on a client callback alone.
