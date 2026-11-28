# Bharat Saathi

Bharat Saathi is an Android-first Flutter app centred on eight core features: Khata Book, Bill / Item List, QR Code Maker, AI Poster Maker & Video Maker, Reminders & Notes, Family & Friends Live Location, Smart Calculator and AI Teacher Academy.

## Current app implementation

- Hindi-first dashboard with exactly eight primary feature tiles: Khata Book, Bill / Item List, QR Code Maker, AI Poster Maker & Video Maker, Reminders & Notes, Family & Friends Live Location, Smart Calculator and AI Teacher Academy.
- Khata Book supports shop and personal ledgers, linked khata requests and linked-account entries.
- Bill / Item List supports bill creation, item lists, PDF export and sharing.
- QR Code Maker supports text/URL and UPI QR creation, camera scanning, and PNG image export/share.
- AI Poster Maker & Video Maker supports Fal AI image generation/editing and queued 5-second vertical Kling video generation. Video generation costs 50 Bharat Saathi coins plus Fal provider billing (currently about US$0.35 per 5-second output); it requires a configured `FAL_KEY` and has not been run in CI because that would incur provider charges.
- Reminders & Notes stores reminders and notes locally. New reminders can schedule Android local notifications after the user grants notification permission; exact delivery can still be affected by OEM battery restrictions.
- Family & Friends Live Location supports phone-number invitations, two-way opt-in, live satellite map updates, location pause/resume and re-share requests.
- Smart Calculator includes standard arithmetic, GST add/remove, discount percentage and profit/margin calculations.
- AI Teacher Academy includes four course categories, short lesson notes, course quizzes, locally saved progress, push-to-talk speech-to-text, spoken answers and a five-minute daily voice allowance enforced per signed-in account through Supabase; speech recognition and spoken answers use the Android/device speech services. Actual course video lessons are not bundled. Text Q&A uses the authenticated `ai-teacher-assistant` Edge Function.
- Profile and account shell retain sign-in, privacy, language, help and cloud backup controls. Recharge, bill payment, challan, Payment Sound Box, AI Calling Assistant, referral and commission modules are retired from this branch.
- Transactional on-device SQLite persistence with one-time import of older SharedPreferences records.
- Google Mobile Ads SDK is included with Google's test ad identifiers in the development build.
- Family & Friends Live Location supports phone-number invitations, two-way opt-in, live map updates, location pause/resume and re-share requests. Android foreground location notification is used while tracking; force-stop, revoked permission, GPS/network loss or battery restrictions can interrupt updates. Realtime request cards work while the app is connected; push notifications while the app is fully closed still require Firebase Cloud Messaging setup. 
- GitHub Actions runs Flutter analysis, widget tests and an Android debug APK build.

## Data and production status

The current khata, expense and personal-finance records are stored locally on the device first. Each local snapshot is keyed by the signed-in Supabase user ID so multiple accounts on one phone keep separate local records. On upgrade from the previous single-snapshot version, the app asks which account should receive the legacy snapshot and imports it only after explicit confirmation and only when that account has no existing local snapshot. If declined or the account already has data, the snapshot remains unassigned so a different account can be selected later; existing records are never overwritten. Sign in first with the account that previously used the device. SQLite stores the local app snapshot transactionally and imports the previous SharedPreferences snapshot during the confirmed one-time legacy migration.

When a user is signed in, Bharat Saathi automatically synchronizes the latest account-specific local snapshot to that user's Supabase cloud-backup record. Changes are queued with a short debounce; sync is retried periodically while the app is running and when it resumes. If the device is offline, records remain stored locally and are synchronized when connectivity returns and the app gets an opportunity to run. Background sync is not guaranteed while the app is fully closed. The current implementation is account-scoped snapshot synchronization, not row-by-row synchronization to a normalized accounting ledger or a conflict-safe multi-device ledger. The cloud snapshot can be restored on another device by signing in to the same account; restore replaces that device's current local snapshot after confirmation.

Supabase project schema includes account membership, personal finance transactions and budgets, parties/khata, linked khata, user backups and RLS-protected Family & Friends location-sharing records. Older referral/commission tables, if present, are legacy backend data and are no longer exposed as app features. Location is visible only to accepted connections when the owner has enabled sharing. Phone numbers are not currently verified by SMS OTP, so production release must add ownership verification or another strong identity check before relying on phone-number matching. The Flutter client initializes Supabase, supports email-confirmed registration and mobile-number/password login, and provisions account memberships. Phone login uses a database-side account lookup (not a first-1,000-users scan) and persistent per-phone/per-IP failed-attempt throttling. The mobile number is not yet verified by SMS OTP; phone-ownership verification is a release gate before treating it as verified identity. Email confirmation depends on the project's Auth email settings and production SMTP configuration. Never place a Supabase secret/service-role key in the mobile app; only the publishable key is included.

## Provider-dependent services

The following remain **Coming Soon** until approved provider credentials, commercial agreements, webhook verification, reconciliation and required compliance checks are available:
- Mobile, DTH and FASTag recharge.
- BBPS bill payments.
- Challan / traffic fine payments.
- UPI collect, payouts, wallet or money transfer.
- SMS/WhatsApp OTP and transactional notifications.
- Paid plans, commissions and payment settlement.

The app must not create simulated payment success, balances, commissions or transaction references for these services.

## Build

GitHub Actions workflow: `.github/workflows/flutter-android.yml`
1. Install Flutter stable and Java 17.
2. Generate Android platform files.
3. Run `flutter pub get`.
4. Run `flutter analyze`.
5. Run widget tests.
6. Build a debug APK and upload it as an artifact.

## Remaining release checks

1. Confirm `FAL_KEY` is configured in Supabase Edge Function Secrets, then run one paid video generation only after reviewing the 50-coin app charge and Fal provider billing. CI does not invoke the paid model.
2. Sign in with a real Bharat Saathi test account and verify `OPENAI_API_KEY` / `GEMINI_API_KEY` are configured for AI Teacher text Q&A.
3. Test speech recognition, Hindi/English TTS, the five-minute local voice cap and microphone permission on physical Android devices. Voice usage is recorded per account in Supabase and is not reset by clearing app data.
4. Test scheduled reminder notifications after granting Android notification permission, including reboot and battery restrictions on Vivo and other OEM devices.
5. Test Family & Friends background location, precise/background permissions, battery restrictions and Google Play background-location disclosures. Firebase Cloud Messaging is still needed for push notifications when the app is fully closed, and phone-number ownership is not SMS-OTP verified.
6. Complete real-device tests for QR export, PDF/WhatsApp sharing, Khata/Expenses sync and account switching. The current cloud backup is account-scoped snapshot synchronization, not a conflict-safe normalized multi-device ledger.
7. Add verified, licensed course video content if video lessons are required; the current Academy has lesson notes, quizzes and voice-based tutoring but no bundled course video library.
8. Complete signed Android release configuration, production SMTP/password recovery checks, privacy/Data Safety review and Play Store declarations.

Flutter analysis, widget tests and Android debug APK build must pass before merging. Paid AI generation and real-device background behavior are not validated by CI.
