# Bharat Saathi

Bharat Saathi is a Flutter Android app for personal finance and small-retailer operations.

## Current app implementation

- Hindi-first dashboard and account shell.
- Five main navigation areas: Dashboard, Khata, Expenses, History and Profile.
- Shop and personal khata, linked khata requests and linked-account entries.
- Business expense recording and expense history.
- Service category screens for recharge, bill payment and challan; provider-dependent transactions remain marked Coming Soon.
- History lists successful service transactions only.
- Profile settings include language/theme controls and cloud snapshot restore.
- Transactional on-device SQLite persistence with one-time import of older SharedPreferences records.
- Google Mobile Ads SDK is included with Google's test ad identifiers in the development build.
- The current navigation does not expose stock, product, purchase or sales-management screens. Legacy product/stock/sales fields remain in the data model for compatibility with older snapshots and may still appear in legacy exports; they are not current user-facing features.
- GitHub Actions runs Flutter analysis, widget tests and an Android debug APK build.

## Data and production status

The current retailer and personal-finance records are stored locally on the device first. Each local snapshot is keyed by the signed-in Supabase user ID so multiple accounts on one phone keep separate local records. On upgrade from the previous single-snapshot version, the app asks which account should receive the legacy snapshot and imports it only after explicit confirmation and only when that account has no existing local snapshot. If declined or the account already has data, the snapshot remains unassigned so a different account can be selected later; existing records are never overwritten. Sign in first with the account that previously used the device. SQLite stores the local app snapshot transactionally and imports the previous SharedPreferences snapshot during the confirmed one-time legacy migration.

When a user is signed in, Bharat Saathi automatically synchronizes the latest account-specific local snapshot to that user's Supabase cloud-backup record. Changes are queued with a short debounce; sync is retried periodically while the app is running and when it resumes. If the device is offline, records remain stored locally and are synchronized when connectivity returns and the app gets an opportunity to run. Background sync is not guaranteed while the app is fully closed. The current implementation is account-scoped snapshot synchronization, not row-by-row synchronization to a normalized accounting ledger or a conflict-safe multi-device ledger. The cloud snapshot can be restored on another device by signing in to the same account; restore replaces that device's current local snapshot after confirmation.

Supabase project schema includes account membership, personal finance transactions and budgets, parties/khata, linked khata, user backups and referral/commission records. Legacy products, purchases, sales and stock tables remain in the database for compatibility but are not exposed in the current app navigation. The Flutter client initializes Supabase, supports email-confirmed registration and mobile-number/password login, and provisions account memberships. Phone login uses a database-side account lookup (not a first-1,000-users scan) and persistent per-phone/per-IP failed-attempt throttling. Email confirmation depends on the project's Auth email settings and production SMTP configuration. Never place a Supabase secret/service-role key in the mobile app; only the publishable key is included.

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

## Next implementation priorities

1. Strengthen and test account-scoped automatic cloud snapshot sync/restore, account switching, offline retry behavior and recovery from interrupted writes.
2. Complete Auth hardening: enable leaked-password protection where the Supabase plan supports it, configure production SMTP, verify password recovery and document an MFA strategy.
3. Move from whole-snapshot backup toward a normalized, conflict-aware server-side transaction ledger with audit history before relying on multi-device financial workflows.
4. Improve current khata and expense workflows, account statements and Hindi PDF export.
5. Complete signed Android release configuration, real-device testing and Play Store declarations.
6. Integrate recharge, BBPS, UPI or other external services only after approved providers, credentials, webhook verification, reconciliation and compliance checks are available.
