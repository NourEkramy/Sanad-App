# 8. Deployment

## 8.1 Prerequisites

* Flutter **3.47** (stable) / Dart 3.13
* Supabase CLI (`npx supabase`) and Docker for local development
* A Supabase project for production (EU region recommended for Egypt latency)

## 8.2 Local development

```bash
# 1. Backend: Postgres, Auth, REST, Studio (applies migrations + seed)
npx supabase start                     # prints API URL and keys
# 2. First admin (local)
#    Studio → Authentication → Add user (email + password, auto-confirm), then:
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres \
  -c "update public.profiles set role = 'admin' where email = 'you@example.com';"
# 3. App configuration
cp app/env/local.example.json app/env/local.json   # fill in the publishable key
cd app
flutter pub get
flutter run --dart-define-from-file=env/local.json   # or -d chrome
```

Database tests without Docker: `supabase/tests/run.sh` (needs a local PostgreSQL binary).

## 8.3 Production backend (Supabase)

1. Create the project. In **Authentication → Providers → Email**:
   disable sign-ups, minimum password length 8. Set **Site URL** and add redirect
   URLs: `com.sanad.sanad://auth-callback` and your web URL.
2. Configure SMTP (Authentication → SMTP) so invitations and password resets
   are delivered from your domain.
3. Apply the schema and reference data:
   ```bash
   npx supabase link --project-ref <ref>
   npx supabase db push                 # runs supabase/migrations
   psql "$DATABASE_URL" -f supabase/seed.sql   # areas + service price list
   ```
4. Deploy the invite function and its redirect:
   ```bash
   npx supabase functions deploy invite-user
   npx supabase secrets set SANAD_AUTH_REDIRECT_URL=com.sanad.sanad://auth-callback
   ```
5. Create the first administrator: invite yourself (Dashboard → Authentication →
   Invite) and run in the SQL editor:
   `update public.profiles set role = 'admin' where email = 'you@example.com';`
6. **Backups:** enable Point-in-Time Recovery (Pro plan) or schedule
   `pg_dump`. Regular Excel exports are an additional human-readable backup.

## 8.4 Migrating the existing workbook

1. Download the workbook from SharePoint as `.xlsx` (the owner must allow
   downloads, or use *File → Save a copy*).
2. Sign in as admin → More → **Import from Excel** → choose the file.
3. Check the detected columns (sheet `سجل الزيارات`, header row 3).
4. Review the preview. Expected for the analysed version: 271 records,
   0 skipped, 129 customers, 60,282 EGP (see [01-excel-analysis.md](01-excel-analysis.md)).
5. Import. If something looks wrong, **Roll back** from the import history, fix
   the file and import again.
6. Fix the 7 *needs review* customers from the dashboard banner.

## 8.5 Building the apps

Configuration is passed at build time (no keys in source):

```json
// app/env/prod.json  (git-ignored)
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_…",
  "AUTH_REDIRECT_URL": "com.sanad.sanad://auth-callback"
}
```

```bash
cd app
# Android (Play Store)
flutter build appbundle --release --dart-define-from-file=env/prod.json
# iOS (App Store / TestFlight; on macOS)
flutter build ipa --release --dart-define-from-file=env/prod.json
# Web (any static host: Netlify, Vercel, Cloudflare Pages, Supabase Storage…)
flutter build web --release --dart-define-from-file=env/prod.json
```

* **Android signing:** create an upload keystore and reference it in
  `android/key.properties` + `android/app/build.gradle.kts` (see Flutter's
  "Build and release an Android app"). Application ID: `com.sanad.sanad`.
* **iOS:** set the team and bundle identifier in Xcode (`Runner`). The URL scheme
  `com.sanad.sanad` is already registered for password-reset links.
* **Web:** for the web build, set `AUTH_REDIRECT_URL` to the site URL and add
  it to Supabase's redirect list.
* App icons are in the platform folders. Regenerate them from the brand mark
  if the logo changes.

## 8.6 Operations

* **Add staff:** More → Users → *Invite user* (admin).
* **Remove access:** deactivate the user (immediate, even with a valid token).
* **Prices change:** edit the service's default price. Past records are not affected.
* **Monitoring:** Supabase dashboard (API, Auth, database health). The
  `audit_log` table records every change to customers and records.
* **Schema changes:** add a new file under `supabase/migrations/`, run
  `supabase/tests/run.sh`, then `supabase db push`.
