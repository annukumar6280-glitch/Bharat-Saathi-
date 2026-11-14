# Bharat Saathi

Bharat Saathi – Personal finance and retailer management app.

## Current prototype
- Retailer dashboard with business summary and quick actions
- Product and stock list
- Sales list with add-sale interaction
- Customer khata list with add-entry interaction
- Profile/settings placeholder
- Add-product and add-expense demo interactions

All sample figures and edits are local in-memory demo data only. They are not real transactions and are not connected to Supabase yet.

## Run locally
1. Install Flutter SDK and Android Studio with Android SDK.
2. From this repository root run: flutter pub get
3. Run on an Android device/emulator: flutter run

## Next integration steps
Configure Supabase URL and publishable key through build-time environment values (never commit secrets), implement Auth/account selection, connect secured database RPCs, then add tests, loading/error states, offline sync and release signing.
