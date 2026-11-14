# Bharat Saathi

Bharat Saathi is a Flutter Android app for personal finance and small-retailer operations.

## Current app implementation

- Hindi-first retailer dashboard with a muted slate background.
- Product list, sale entry, expense entry, customer khata and customer payment entries.
- Separate Personal Finance tab for income, expenses, net balance and a user-defined spending limit.
- On-device persistence for current prototype records using SharedPreferences.
- Expense history alongside sales.
- Provider-dependent recharge, BBPS, challan, UPI and transfer screens explicitly marked Coming Soon.
- Empty first-run state: no seeded sample customers, fake invoices, chart totals or fictional cash balance.
- Android debug APK is built by GitHub Actions; analyzer, widget test and APK build are part of CI.

## Data and production status

The current retailer records are stored locally on the device. They are **not yet synced to Supabase**, are not shared across devices, and are not a production-grade financial ledger. SharedPreferences is used for the current prototype only; before production financial use it must be migrated to a transactional local database with backup/export and conflict-safe sync.

Supabase project schema includes account membership, personal finance transactions and budgets, parties/khata, products, purchases, sales, stock movements and a stock summary view. The Flutter client is not yet connected to Supabase Auth or the live database. Never place a Supabase secret/service-role key in the mobile app. A publishable key and auth/provider configuration must be supplied through secure build configuration before live account sign-in can be enabled.

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

1. Move local records to SQLite/Drift with migrations and CSV/PDF export.
2. Implement Supabase Auth onboarding and connect account-scoped tables/RPCs using a publishable key.
3. Extend personal finance with categories, recurring bills, family accounts, monthly budgets and reports.
4. Finish retailer workflows: customer/supplier management, purchases, stock adjustments, invoice details and sales returns.
5. Add tested backup/restore, offline-first sync, audit trail and release signing.
6. Integrate external services only after credentials and provider certification are available.
