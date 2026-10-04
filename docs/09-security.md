# 9. Security & privacy

Sanad stores health-related customer data (names, phone numbers, addresses,
services received). It is treated as sensitive.

| Area | Measure |
|------|---------|
| **Authentication** | Supabase Auth, email + password (min 8). Public sign-up disabled. Accounts are created by admins only (`invite-user` Edge Function, which checks `is_admin()` with the caller's JWT before using the service role). |
| **Authorisation** | Row Level Security on **every** table. Policies call `is_staff()` / `is_admin()`, which also require `profiles.is_active`, so deactivation is immediate. Role changes are guarded by a trigger: only admins, and never on themselves. |
| **No destructive API** | API roles have no `DELETE` grant. Archiving is a soft delete through admin-only RPCs. Every update or delete of customers and records is written to `audit_log`. |
| **Least privilege** | `anon` has no table access. Writes to imports happen only through `SECURITY DEFINER` functions that check the role first and use a fixed `search_path`. |
| **Data integrity** | Constraints in the database (unique phone, valid phone format, price ≥ 0, required fields, legacy-only values). Snapshots and the active-reference check are done by triggers, so a modified client cannot bypass them. |
| **Secrets** | Only the publishable (anon) key ships in the app, injected at build time. The service-role key lives only in Supabase (Edge Function secret). `env/*.json` is git-ignored. |
| **Transport** | HTTPS to Supabase. Android cleartext traffic is not enabled for release builds. |
| **Session storage** | Session and PKCE verifier are stored in the Keychain (iOS) / EncryptedSharedPreferences-Keystore (Android) through `flutter_secure_storage`, not plain preferences. |
| **Data at rest on the device** | The offline queue, form drafts and cached profile are kept in the same secure storage. Android `allowBackup=false` keeps them out of device backups. |
| **Logging** | Errors are reduced to a type and a stable code. Server messages, which can echo customer data, are never logged or shown. The Edge Function logs only status codes. |
| **Validation** | Done on the client (for feedback) **and** in the database (for enforcement). Search input is passed as a function parameter, never concatenated into SQL. |
| **Session expiry** | Refresh failure → login screen with an explanation. Unsaved drafts stay on the device. Sign-out warns about unsynced records. |
| **Imports** | Admin-only, one transaction, duplicate-file protection, full row-level audit, reversible. |
| **Exports** | Admin-only. Files are produced on the device and shared by the user. Nothing is uploaded to third parties. |
| **Repository hygiene** | The real workbook and its data are not committed. Test fixtures are synthetic. |

## Recommended operational practices

* Enable PITR backups and MFA for Supabase dashboard accounts.
* Rotate the service-role key if a staff member with dashboard access leaves.
* Review `audit_log` periodically, and deactivate users who no longer need access.
* Keep exported workbooks in access-controlled storage. They contain customer data.
