# 8. Setup & deployment

Sanad runs entirely on the phone. There is no server to deploy. The only
one-time setup is registering the app with Google so it may write its backup
into your Google Drive (8.3).

## 8.1 Prerequisites

* Flutter **3.47** (stable) / Dart 3.13, with the Android toolchain
  (Android Studio or the Android command-line tools) — check with `flutter doctor`.
* An Android phone (Android 7 or newer) with a USB cable, or an emulator.

## 8.2 Run it

```bash
cd app
flutter pub get
flutter run            # phone connected by USB, or an emulator
flutter run -d chrome  # quick look in the browser (data stays in that browser; no Drive backup)
```

## 8.3 Google Drive setup (once, about 10 minutes)

Google requires every app that writes to Drive to be registered. Do this
signed in with **the Google account that will hold the backups**.

1. Open <https://console.cloud.google.com/> → project picker → **New project**
   → name it `Sanad` → **Create**, and select it.
2. **APIs & Services → Library** → search **Google Drive API** → **Enable**.
3. **Google Auth Platform** (APIs & Services → OAuth consent screen) →
   **Get started**: app name `Sanad`, your e-mail as support e-mail, audience
   **External**, your e-mail as contact → **Create**.
4. **Data access → Add or remove scopes** → filter for `drive.file` → tick
   `…/auth/drive.file` ("See, edit, create and delete only the specific Google
   Drive files you use with this app") → **Update** → **Save**.
5. **Audience → Publish app** → confirm. (`drive.file` is a non-sensitive
   scope, so Google does not require a review. If you leave the app in
   *Testing*, add your account under *Test users*; Google then asks you to
   allow access again every 7 days.)
6. Get your computer's signing fingerprint (SHA-1). In a terminal:
   ```powershell
   cd "E:\Sanad App\app\android"
   .\gradlew signingReport
   ```
   (on macOS/Linux: `./gradlew signingReport`). Copy the **SHA1** line of the
   `debug` variant. If `gradlew` is missing, run `flutter build apk` once first.
7. **Clients → Create client** → type **Android** → package name
   `com.sanad.sanad` → paste the SHA-1 → **Create**.

Nothing has to be copied into the app: Google recognises it by package name
and signing certificate. Then on the phone: More → **Google Drive backup** →
**Connect Google Drive**.

> The fingerprint belongs to the computer that builds the app (its
> `~/.android/debug.keystore`). If you build on another computer, add its
> SHA-1 as another Android client, or copy the keystore file. If sign-in shows
> "Google sign-in is not set up for this copy of the app", the package name or
> SHA-1 does not match, or the Drive API is not enabled.

## 8.4 Install on your phone

```bash
cd app
flutter build apk --release
```

Copy `app/build/app/outputs/flutter-apk/app-release.apk` to the phone and
open it (allow installing from this source when Android asks), or with the
phone connected: `flutter install --release`.

Release builds are signed with the computer's debug key (the Flutter
default), which is fine for personal use and matches the SHA-1 from 8.3. To
publish on Google Play later, create an upload key ("Build and release an
Android app" in the Flutter docs) and add its SHA-1 as another Android client.

## 8.5 Bring in the existing workbook

1. Download the workbook from SharePoint as `.xlsx` (*File → Save a copy*, or
   *Download*; the owner must allow downloads).
2. Put it on the phone (e.g. in Downloads or Google Drive).
3. Sanad → More → **Import from Excel** → choose the file.
4. Check the detected columns (sheet `سجل الزيارات`, header row 3).
5. Review the preview. Expected for the analysed version: 271 records,
   0 skipped, 129 customers, 60,282 EGP (see [01-excel-analysis.md](01-excel-analysis.md)).
6. Import. If something looks wrong, **Roll back** from the import history,
   fix the file and import again.
7. Fix the 7 *needs review* customers from the dashboard banner.

## 8.6 Everyday operation

* **Backup** runs by itself after changes. The cloud icon on Home shows the
  state; More → Google Drive backup shows the last backup and **Back up now**.
* **Share the data**: in Google Drive open `Sanad` → `Sanad.xlsx` → *Share*;
  or in the app **Export to Excel** for a specific period and share the file.
* **New phone**: install Sanad → More → Google Drive backup → Connect the same
  account → **Restore from Google Drive**.
* **Prices change**: edit the service's default price. Past records are not affected.
* **Schema changes** (development): bump `SanadDatabase.schemaVersion` and add
  an `onUpgrade` step; backups record their schema version.
