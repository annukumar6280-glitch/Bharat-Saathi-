# Bharat Saathi – Production Readiness

This file is the source of truth for what is implemented, what is local-only, and what is blocked on external credentials or approvals.

## Working in the current Flutter prototype

- Hindi retailer dashboard and six-tab navigation: Home, Personal, Stock, Sales, Khata and Profile.
- Personal ledger: income, expense, net total and a user-configured spending cap.
- Retailer ledger: products, stock count, sales, expenses and customer receivables.
- Sales select an existing product and quantity, validate available stock, and deduct inventory.
- Sales distinguish cash/bank payment from customer credit. Credit sales create a khata receivable; recorded customer payments reduce receivables and add to recorded cash flow.
- Retailer purchase entry records supplier, product, quantity and unit cost. Cash purchases reduce cash; credit purchases increase supplier payable. Supplier payments reduce payable and cash.
- Sales returns validate the customer's recorded sold quantity, restore stock, and record either a cash refund or a customer-credit adjustment.
- Manual stock increases are recorded in a stock-adjustment history.
- Records persist in a transactional SQLite app-state table. Existing SharedPreferences JSON is imported into SQLite when no database snapshot exists.
- First launch contains no fabricated customer, invoice, stock or balance data.
- Provider-dependent service tiles display Coming Soon.
- Local reports summarize sales, business expenses, customer khata, personal income/expenses and estimated stock value. CSV rows can be copied to the clipboard for use in a spreadsheet.

## Reports and export limitation

The reports page operates on the current device snapshot, supports date-range filtering, and shares CSV files. New financial records store a timestamp; older records without a timestamp are excluded from a date-filtered report. PDF statements are not available yet. CSV export does not imply cloud synchronization.

## Important data limitation

SQLite currently stores the full app state as one transactional JSON snapshot. It is more resilient than the previous key-value-only write but is not yet a normalized accounting ledger, is not encrypted as a financial vault, has no automatic cloud backup, and does not synchronize between devices. Do not use it as the final ledger for real business transactions. Before production, normalize the schema, add audit history, encryption strategy and conflict-safe Supabase sync.

## Supabase backend already present

Project is active in Mumbai. Existing database migrations cover:
- Profiles, accounts and account membership.
- Financial categories, financial transactions and budgets.
- Parties and khata entries.
- Products, stock movements, purchases, purchase items, sales, sale items and stock summary.
- Database routines for receiving purchases, completing sales and adjusting inventory.

The Flutter client initializes Supabase with the project's public publishable key and supports email/password sign-up/sign-in. On successful authentication it upserts the user's profile and provisions personal and retailer accounts with owner memberships using RLS-protected inserts. Local finance and retailer records are not yet synchronized to normalized ledger tables. A manual JSON snapshot backup/restore is available; restore replaces the current device snapshot after confirmation. Email confirmation depends on Supabase Auth settings and production SMTP configuration. SMS OTP remains Coming Soon. A service-role/secret key must never be embedded in the APK.

## Coming Soon – external provider dependencies

Keep these disabled until credentials, contracts, callback/webhook validation, reconciliation and compliance approval are complete:
- Mobile, DTH and FASTag recharge.
- BBPS bill payments.
- Traffic challan payments.
- UPI collect, payout, wallet and money transfer.
- SMS/WhatsApp OTP and transactional messaging.
- Subscription payments, platform commissions and settlement.

Never simulate a successful external transaction or fabricate balances, commissions, provider references or transaction history.

## Remaining product work

1. Normalize the SQLite snapshot into transaction, inventory and audit tables with schema migrations.
2. Extend the current Supabase email auth/account provisioning with account switching, session lifecycle handling, password recovery and verified email delivery.
3. Sync personal finance, budgets, parties, khata, products, purchases, sales and stock movements through RLS-protected tables/RPCs.
4. Add full customer/supplier profiles and contacts, invoice numbering/printable tax invoices, stock adjustment reversals and tax fields.
5. Add live sync from local records to normalized tables with conflict handling; add categories, recurring bills/reminders, family accounts, date filters, reports and CSV/PDF export.
6. Add backup/restore, account deletion/export flows, privacy policy, terms, support and accessibility review.
7. Complete security advisor review, API exposure verification, end-to-end tests and Android release signing.
8. Integrate external services only after provider credentials and approvals are supplied.

## CI validation

GitHub Actions runs Flutter analysis, widget tests and Android debug APK build. A passing debug build is not equivalent to a signed Play Store release or provider certification.
