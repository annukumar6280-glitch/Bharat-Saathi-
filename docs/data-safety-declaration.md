# Bharat Saathi — Google Play Data Safety working declaration

Internal preparation note only. Re-check the exact release APK, all included SDKs and the current Google Play Console questions before submission.

## Data categories identified in the current source

- **Personal info — Name:** entered during registration and stored in the Supabase profiles table.
- **Personal info — Email address:** processed by Supabase Auth for registration, email confirmation, login and password recovery.
- **Personal info — Phone number:** entered during registration, associated with the user profile, and used for phone/password login lookup and linked-khata features. The current app does not verify phone ownership by SMS OTP.
- **Financial info — Other financial info:** current personal and shop records may include income, expenses, budgets, khata balances, credit/payment entries and transaction notes. Linked-khata entries and referral/commission records are stored in Supabase when those features are used.
- **App activity / app interactions:** Google Mobile Ads SDK may collect ad interactions.
- **App info and performance / diagnostics:** Google Mobile Ads SDK may collect diagnostics.
- **Device or other IDs:** Google Mobile Ads SDK may collect advertising ID, app-set ID and other device/account identifiers.\n- **Location — precise location:** Family & Friends Live Location collects GPS coordinates and location accuracy while the user has explicitly enabled sharing. The latest location is stored in Supabase and shared only with accepted connections while sharing is enabled.

## Processing and sharing

- Supabase processes authentication, profile, linked-khata, referral/commission, automatic cloud-backup and the latest live-location data for accepted Family & Friends connections.
- Google Mobile Ads SDK may process/share IP address, ad interactions, diagnostics and identifiers for advertising, analytics and fraud prevention. Current development source uses Google's test App ID and test banner unit ID only.
- Ordinary financial and shop records are saved locally first. When signed in and internet is available, an account-specific snapshot is automatically synchronized to Supabase; it is not a user-triggered manual backup.
- Local snapshots are separated by signed-in Supabase user ID on the same device. On upgrade, a legacy unassigned snapshot is imported only after the user confirms the correct account and only if that account has no existing local snapshot; existing account data is never overwritten.
- Location is collected only after in-app sharing is enabled and the relevant Android location permission is granted. The user can stop sharing at any time. The latest location is stored; a location-history trail is not intentionally retained.\n- Data is transmitted over HTTPS/TLS. The SQLite database is not separately encrypted at the application layer.
- Account deletion is requested through the external deletion page/WhatsApp support and is processed after ownership verification; there is no in-app deletion button in the current source.

## Play Console answers to verify

For each relevant data type, determine whether collected, shared, processed ephemerally, required/optional, purpose, encryption in transit, and deletion request availability. Google Mobile Ads SDK data handling must be declared accurately. Do not select “no data collected” while the SDK or account/cloud features are included.

## Release gates

- Replace Google test App ID and test banner unit ID with production IDs only when approved, then re-audit Google's current SDK disclosure and consent requirements.
- Confirm the hosted Privacy Policy URL and external Account Deletion Request URL are public and working.\n- Complete Google Play background-location declaration, prominent in-app disclosure and foreground-service permission review for Family & Friends Live Location before release.
- Test the external account-deletion request and verify the server-side deletion process and retention policy.
- Confirm the final target audience, permissions, ads declaration, app access instructions and content rating in Play Console.
- Re-audit any new payment/recharge/BBPS SDK or API before enabling it; provider-dependent services are not active in the current app.
- Test the exact release APK on physical Android devices, including account switching, offline sync and cross-device restore.
