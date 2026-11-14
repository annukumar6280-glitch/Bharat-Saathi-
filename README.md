# Bharat Saathi

Bharat Saathi – Personal finance and retailer management app.

## Retailer UI prototype (v0.2)
The Flutter prototype currently includes:
- A redesigned retailer dashboard with cash/bank balance, sales, expenses and customer dues cards
- Quick actions for sale entry, expense entry and customer khata
- Weekly sales chart visual and recent activity list
- Product inventory list with low-stock highlighting
- Sales records, customer khata and profile/settings screens
- Bottom navigation and local demo entry forms

**Important:** the dashboard figures, chart and sample records are illustrative demo data stored only in app memory. They are not real business records and do not persist after closing the app. Supabase authentication and live database integration are not connected yet.

## Run locally
1. Install Flutter SDK and Android Studio with Android SDK.
2. From this repository root run `flutter pub get`.
3. Run on an Android device/emulator with `flutter run`.

## Next development stages
1. Run Flutter analyzer/build and refine UI against an Android device.
2. Add Supabase Auth and account onboarding using environment-provided URL and publishable key (never commit secrets).
3. Connect inventory, purchases, sales, stock ledger and khata to secured database RPCs.
4. Add personal finance screens, reports, tests, offline sync, backup and release signing.
