# 8. Setup & deployment

Sanad runs entirely on the phone. There is no server to deploy, no Google
Cloud project and no API key. The one-time setup is a permanent signing key
(8.3), so that updates install over the app, and, to keep the data in a
Google Sheet, pasting the Sanad script into that sheet (8.4).

## 8.1 Prerequisites

* Flutter **3.47** (stable) / Dart 3.13, with the Android toolchain
  (Android Studio or the Android command-line tools) — check with `flutter doctor`.
* An Android phone (Android 7 or newer) with a USB cable, or an emulator.
* Node.js 18+ only to run the script's tests or the local stand-in server.

## 8.2 Run it

```bash
cd app
flutter pub get
flutter run            # phone connected by USB, or an emulator
flutter run -d chrome  # quick look in the browser (its data stays in that browser)
```

To try the Google Sheet link without Google, run the stand-in server, which
runs the real script on an in-memory spreadsheet, and paste
`http://127.0.0.1:8787/exec` in the app (browser or emulator):

```bash
node tools/google-sheets/dev-server.js [workbook.json] 8787
curl http://127.0.0.1:8787/state     # what the "sheet" contains now
```

## 8.3 One permanent signing key (once)

Android installs an update over an app only when it is signed with the same
key. Sign every copy you install with one permanent key.

On your PC (PowerShell; `keytool` comes with Android Studio's Java, e.g.
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`):

```powershell
cd "E:\Sanad App\app\android"
keytool -genkeypair -v -keystore sanad-release.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias sanad
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
installed over the existing app. Without `key.properties` the build is
signed with the debug key (fine for trying, not for phones you update).

## 8.4 Connecting the Google Sheet (once, free)

On a computer, signed in to the Google account that should hold the data:

1. **Put the workbook in Google Drive.** drive.google.com → *New → File
   upload* → the `.xlsx`. Open it, then *File → Save as Google Sheets* and
   use that copy from now on. (Or create an empty Google Sheet: Sanad then
   creates its own sheets `سجل الزيارات`, `بيانات الحالات` and `قوائم`.)
2. **Paste the script.** In the Google Sheet: *Extensions → Apps Script*.
   Delete the code shown, paste the whole of
   [`tools/google-sheets/Code.gs`](../tools/google-sheets/Code.gs) (the app
   can copy it too: More → Google Sheet → *Copy the Sanad script*), click
   *Save*.
3. **Deploy it.** *Deploy → New deployment →* ⚙ *→ Web app*.
   *Execute as:* **Me**. *Who has access:* **Anyone**. *Deploy*.
4. **Allow it.** *Authorize access* → your account → *Google hasn't verified
   this app* → *Advanced* → *Go to … (unsafe)* → *Allow*. The warning appears
   for every personal script; this one can only see and change **this**
   spreadsheet (`@OnlyCurrentDoc`).
5. **Copy the Web app URL** (`https://script.google.com/macros/s/…/exec`),
   send it to the phone (e.g. e-mail it to yourself) and paste it in
   Sanad → More → **Google Sheet** → *Connect*.
6. Sanad shows what it found (visits, customers, revenue, dates). Tap
   **Load the sheet's data**. From then on every change is written into the
   sheet a few seconds later.

The link works like a password: anyone who has it **and** the connection
code can write to the sheet. The first phone is paired automatically.

### What Sanad writes, and where

| Sheet | What happens |
|---|---|
| Visits (`سجل الزيارات`) | A new visit goes into the first free row after the last visit, reusing the pre-numbered rows: the number in `م` and the formulas in `اليوم` / `الشهر` stay. Corrections rewrite the same row; deleting a record clears its row (number and formulas stay). Two columns are added after the last used column: `طريقة الدفع` (payment) and `معرف سند` (the record's ID: how Sanad finds its row again — **do not edit or delete this column**). |
| Customers (`بيانات الحالات`) | New customers are added at the end. A customer already in the sheet is found by phone; only its empty cells are filled. |
| Lists (`قوائم`) | New services (with their price, `**` when it varies), nurses and areas are added to their column. |
| Everything else | Never touched: the dashboard, monthly summary and expenses keep calculating from the visits sheet. |

Columns are found by their header text, so they can be moved. Phone numbers
are written as text (the leading 0 stays).

### Another phone

Paste the same link on the other phone. Sanad asks for the **connection
code**: in the sheet, menu **سند → رمز الربط** shows it. To lock out every
phone (e.g. a lost phone): **سند → رمز ربط جديد**, then connect the phones
you keep again with the new code.

### Updating the script

When a Sanad version needs a newer script: *Extensions → Apps Script* →
paste the new `Code.gs` → *Save* → *Deploy → Manage deployments* → ✏ →
*Version: New version* → *Deploy*. The link stays the same. (A *New
deployment* would create a new link; then connect again in the app.)

### Limits

* Sanad writes to the sheet; it does not read changes made directly in the
  sheet. After editing the sheet by hand, use More → Google Sheet → **Load
  all data from the sheet again** (it replaces the phone's data with the
  sheet's, keeping each row's ID).
* The file is a Google Sheet. To get an Excel file: *File → Download →
  Microsoft Excel (.xlsx)*, or Export to Excel in the app.

## 8.4a Build and install on phones

```powershell
cd "E:\Sanad App\app"
flutter build apk --release --split-per-abi
```

Copy `app\build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` to any
Android phone (7 or newer) and open it. Google Play services are not
needed: the sheet link is plain HTTPS. iPhone needs a separate build on a Mac.

If a copy of the app was installed with a different key (e.g. a test build),
uninstall it first: Android refuses to replace an app signed with another
key. Make sure its data is in the Google Sheet (or exported) before
uninstalling.

## 8.5 Bring in the existing workbook

With the Google Sheet connected (8.4), the workbook's data is loaded when
connecting. To bring in an Excel file instead:

1. Download the workbook as `.xlsx` (e.g. from SharePoint: *File → Save a
   copy*, or *Download*; the owner must allow downloads).
2. Put it on the phone (e.g. in Downloads or Google Drive).
3. Sanad → More → **Import from Excel** → choose the file.
4. Check the detected columns (sheet `سجل الزيارات`, header row 3).
5. Review the preview. Expected for the analysed version: 271 records,
   0 skipped, 129 customers, 60,282 EGP (see [01-excel-analysis.md](01-excel-analysis.md)).
6. Import. If something looks wrong, **Roll back** from the import history,
   fix the file and import again. Records of an import that were already
   written to a connected sheet are cleared from it again.
7. Fix the 7 *needs review* customers from the dashboard banner.

## 8.6 Everyday operation

* **The sheet updates by itself** a few seconds after each change and when
  the app goes to the background. The icon on Home shows the state (✓ up to
  date, clock = waiting, warning = failed); More → Google Sheet shows the
  last update and **Update now**.
* **Offline**: changes wait on the phone and are written when the connection
  is back (retried automatically).
* **Share the data**: share the Google Sheet like any Google file, download
  it as Excel, or use **Export to Excel** in the app for a specific period.
* **New phone**: install Sanad → More → Google Sheet → paste the link (and the
  code) → **Load the sheet's data**.
* **Prices change**: edit the service's default price in the app (it is
  written to the lists sheet). Past records are not affected.
* **Schema changes** (development): bump `SanadDatabase.schemaVersion` and add
  the statements to `_migrations`; new installs run the same steps.
