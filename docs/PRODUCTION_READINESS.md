# Bharat Saathi — Current implementation and release readiness

Last reviewed: 15 November 2026. This document describes the current source in `main`; always verify the exact release APK before publishing.

## Current Android app features

- Account registration with name, email, 10-digit mobile number and password; email confirmation is required.
- Login using the registered mobile number and password.
- Profile and account settings, Hindi/English language selection and dark theme.
- Personal finance income/expense records, net balance and user-defined spending limit.
- Shop and personal khata, linked khata, expense records and service history. Product, purchase, sales and stock-management code has been removed from the Android app; legacy Supabase tables remain unused by the current client.
- Current navigation: Dashboard, Khata, Expenses, History and Profile. Khata provides shop/personal ledgers and linked khata; Expenses records business expenses; History lists successful service transactions; Profile provides account/settings and cloud-restore access.
- Linked khata, referral code/history and commission list/settings screens.
- Recharge, BBPS, challan, UPI payment/transfer, wallet/payout and other provider-dependent transactions remain marked Coming Soon; no real provider transaction should be simulated.
- Google Mobile Ads SDK is present with Google's test App ID and test banner ad unit ID in the development build.

## Local storage and account separation

- App data is stored first in a transactional SQLite snapshot on the device.
- The current implementation keys each local snapshot by the authenticated Supabase user ID. Different accounts on the same phone read and write separate local rows.
- Upgrade migration from the previous single-row local database preserves the legacy snapshot separately. The app asks which account should receive it and imports it only after explicit confirmation. If the user declines or that account already has local records, the legacy snapshot remains unassigned for another account; existing account data is never overwritten. Users should sign in first with the account that previously used the device.
- SQLite is stored in the app's private device storage. App-level SQLCipher/database encryption is not implemented; do not describe the local database as encrypted at rest.
- Existing SharedPreferences data is imported once during the same legacy migration.

## Automatic cloud snapshot synchronization

- When a user is signed in, the app automatically synchronizes the account's local snapshot to that user's `user_backups` row in Supabase.
- Changes are queued with a short debounce. Sync retries periodically while the app is running and when it resumes.
- Offline records remain local and are retried when connectivity returns and the app gets an opportunity to run. Android background sync is not guaranteed while the app is fully terminated.
- Restore downloads the signed-in user's snapshot and replaces that device's local snapshot after confirmation.
- This is account-scoped JSON snapshot backup, not row-by-row synchronization to normalized financial tables and not a conflict-safe multi-device ledger. Keep this limitation visible until a proper transaction-level sync engine exists.

## Authentication and login hardening

- Supabase Auth verifies the password and email-confirmation state.
- Phone login now resolves the mobile number in the database rather than scanning only the first 1,000 Auth users.
- Phone login has persistent failed-attempt rate limits: 8 failures per phone per 15-minute window and 40 failures per source IP per 15-minute window. Successful logins do not consume this failure budget.
- The registered mobile number is not currently verified by SMS OTP. It is a user-provided lookup identifier, not proof of phone ownership. Configure an approved SMS provider and verify phone ownership before treating mobile numbers as verified identity for public registration or linked-khata discovery.
- The service-role key is used only by the Supabase Edge Function and must never be placed in the APK.
- Supabase Auth leaked-password protection still needs to be enabled in the Supabase Dashboard's Auth password security settings before production release.
- Configure production SMTP and verify email confirmation/password reset delivery before release.

## Privacy and account deletion

- The in-app and hosted Privacy Policy must match the exact release APK and SDK configuration.
- The current app does not have an in-app account-deletion button. Users request deletion through the external Account Deletion Request page/WhatsApp support; support verifies ownership before processing.
- Local copies on other devices are not remotely erased by account deletion.
- The Google Mobile Ads test identifiers must be replaced with approved production identifiers before monetization/release, followed by a Data Safety re-review.

## Database and security

- Supabase public tables have RLS enabled; each table's policies and every SECURITY DEFINER function must continue to be reviewed after migrations.
- The cloud-backup table is scoped to the authenticated user.
- Provider-dependent money movement, recharge and bill-payment functionality must remain disabled until authorized providers, credentials, webhooks, reconciliation and compliance checks are in place.
- Never put a Supabase service-role/secret key in client code.

## CI and release status

- GitHub Actions runs Flutter dependency installation, `flutter analyze`, widget tests and an Android debug APK build.
- CI target API check sets and verifies Android API 36.
- A passing debug APK build is not a signed release APK, Play Console approval, live-provider certification or proof of end-to-end operation on physical devices.
- Before production: test registration, email verification, login, account switching on one device, offline sync retry, restore on a second device, data export, linked khata access control and account-deletion requests on real Android devices.
- Local SQLite snapshot is not encrypted at the application layer; assess whether to implement database encryption before handling sensitive production financial records.

## Known release gates

1. Enable leaked-password protection in Supabase Auth.
2. Verify production SMTP, recovery emails and account ownership/deletion workflow.
3. Run real-device multi-account isolation and cross-device restore tests.
4. Validate all RLS policies and SECURITY DEFINER function permissions with the Supabase Security Advisor.
5. Replace Google test ad identifiers only when production ad configuration and consent/disclosure requirements are ready.
6. Produce and test a signed Android release bundle/APK and complete Play Console declarations.
7. Do not claim that external payment/recharge services are live until real providers and compliance are completed.
