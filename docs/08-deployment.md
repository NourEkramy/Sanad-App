# 8. Setup & deployment

Sanad runs entirely on the phone. There is no server to deploy. The only
one-time setup is a permanent signing key (8.3) and registering the app with
Google so it may write backups into its users' Google Drive (8.4).

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

## 8.3 One permanent signing key (once)

Google recognises the app by its package name **and the fingerprint (SHA-1)
of the key it is signed with**. Sign every copy you install with the same
permanent key, and register that key once: then the app works on every
Android phone it is installed on.

On your PC (PowerShell; `keytool` comes with Android Studio's Java, e.g.
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`):

```powershell
cd "E:\Sanad App\app\android"
keytool -genkeypair -v -keystore sanad-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias sanad
keytool -list -v -keystore sanad-release.jks -alias sanad     # copy the SHA1 line
```

Create `app\android\key.properties` (git-ignored, never share it):

```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=sanad
storeFile=../sanad-release.jks
```

**Back up `sanad-release.jks` and the password** (e.g. a private USB stick
and your password manager). Losing them means future updates cannot be
installed over the existing app.

## 8.4 Google Cloud setup (once): any Google account, any phone

Signed in to Google Cloud with the account that owns the project:

1. <https://console.cloud.google.com/> → **New project** `Sanad` → select it.
2. **APIs & Services → Library → Google Drive API → Enable.**
3. **Google Auth Platform → Branding**: app name `Sanad`, support e-mail,
   developer contact e-mail → Save. (Don't upload a logo: that requires
   Google's brand review.)
4. **Data access → Add or remove scopes** → `…/auth/drive.file` → Update → Save.
5. **Audience → Publish app → Confirm.** Status must be **In production**.
   This is what lets **any Google account** connect. `drive.file` is a
   non-sensitive scope, so Google does not require a review. (In *Testing*,
   only listed test users can connect.)
6. **Clients → Create client → Android**: package `com.sanad.sanad`,
   SHA-1 from 8.3. Add one Android client per signing key you use (e.g. a
   test key, and Google Play's app-signing key if you publish on Play).
7. **Clients → Create client → Web application**: name `Sanad sign-in`, no
   URLs needed → copy its **Client ID** (`….apps.googleusercontent.com`).
   With it, Sanad signs in to the Google account first and then asks for
   Drive access for exactly that account (Google's main Android flow).

Changes can take a few minutes to reach phones.

## 8.4a Build and install on phones

```powershell
cd "E:\Sanad App\app"
flutter build apk --release --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID
```

Copy `app\build\app\outputs\flutter-apk\app-release.apk` to any Android
phone and open it (or publish it on Google Play). Every phone then shows
**Connect Google Drive**; the user picks **any** Google account, and the
backup goes to that account's own Drive.

Phone requirements: Android 7 or newer **with Google Play services**
(practically every Android phone except recent Huawei models). On phones
without Google services the app works fully; use **Export to Excel** and
share the file instead of the automatic Drive copy. iPhone needs a separate
build on a Mac and an **iOS** client in step 6.

If a copy of the app was installed with a different key (e.g. a test build),
uninstall it first: Android refuses to replace an app signed with another
key. Back up or export before uninstalling.

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
