# Bharat Saathi — Google Play Data Safety working declaration

This is an internal preparation note, not a substitute for completing the Play Console form. Re-check the exact release APK and current SDK documentation before submitting.

## Data categories identified in the current source

- **Personal info — Name:** full name is collected during account registration and saved to the Supabase profiles table.
- **Personal info — Email address:** used by Supabase Auth for account registration, login and password reset.
- **Personal info — Phone number:** registration profile phone number; linked-khata lookup uses a registered mobile number.
- **Financial info — Other financial info:** shop/personal income and expense records, sales, purchases, stock/khata balances and notes can be included in an explicitly user-triggered cloud backup; linked-khata credit/payment records are stored server-side.
- **App activity / app interactions:** Google Mobile Ads SDK may collect ad interactions.
- **App info and performance / diagnostics:** Google Mobile Ads SDK may collect diagnostics.
- **Device or other IDs:** Google Mobile Ads SDK may collect advertising ID, app set ID and other device/account identifiers.

## Processing and sharing

- Supabase processes account, profile, linked-khata and user-requested backup data as the backend/auth provider.
- Google Mobile Ads SDK may collect/share IP address, ad interactions, diagnostics and identifiers for advertising, analytics and fraud prevention. Current source uses Google's test App ID and test banner unit ID only.
- Local app records remain on device until app data is cleared or the user completes in-app account deletion.
- Cloud backup is user initiated; the app does not automatically synchronise local records.

## Likely form choices to verify

For each relevant data type, determine whether collected, shared, processed ephemerally, required/optional, purpose, encryption in transit, and deletion request availability. Do not select “no data collected” while the Google Mobile Ads SDK or user-initiated cloud backup is included.

## Release blockers / checks

- Replace Google test App ID and test banner unit ID with production IDs before public release, then re-audit Google's current SDK disclosure.
- Confirm the deployed Privacy Policy URL and external account-deletion URL are public and working.
- Confirm in-app account deletion works end-to-end and cascade deletes all user-linked records.
- Confirm the app's final target audience, permissions, ads declaration, app access instructions and content rating in Play Console.
- Re-audit any new payment/recharge/BBPS SDK or API before enabling it; none is currently integrated in the inspected app source.
