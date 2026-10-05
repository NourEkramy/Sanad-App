# 7. Testing strategy

| Layer | Where | What | Run |
|-------|-------|------|-----|
| Domain & value objects | `app/test/core/value_objects_test.dart` | Phone normalisation/validation, money parsing, Arabic name normalisation, validators | `flutter test` |
| Database & repositories | `app/test/core/database/local_repositories_test.dart` | Real SQLite (in memory, FFI): seed data; unique names with Arabic spelling variants; **duplicate phone** (use case and constraint); **phone search** (full, prefix, partial 4+, Arabic digits, `+20`) and name search; archived customers; visit counts; **records**: snapshot, actual price in piasters, payment method, **history frozen** after nurse/service/area renames, customer moves and default-price changes; double save; inactive nurse / archived customer rejected; ordering; filters + totals; correction; dashboard numbers; **Excel import** (matching existing data, review flags, revenue), duplicate-file refusal, **rollback** keeping used data, re-import, export; **backup** dump/restore, invalid backup refused, change notifications | `flutter test` |
| Use cases | `app/test/features/customers`, `…/records` | Customer creation, duplicate phone (incl. archived), search (full, partial, Arabic digits, name, too-short), area de-duplication, adding records, required fields, **price handling** (actual price, piasters, invalid/negative), **payment method** rules, future dates, history | `flutter test` |
| Cubits | `record_form_cubit_test`, `customer_search_test`, `backup_test` | Default date/time, **price suggestion vs typed price**, variable price, draft save/restore, failed save keeps input; debounced search; **Google Drive backup**: first backup on connect, existing backup never overwritten without asking, never overwritten when the app is closed before choosing or when Drive can't be checked, automatic backup after changes (one upload per burst), retry when back online, pending changes survive a restart, restore, canceled sign-in, disconnect | `flutter test` |
| Google Drive client | `backup_test` (`DriveApi`) | Folder and files created once then replaced in place, download, expired token refreshed once, refused permission | `flutter test` |
| Excel | `app/test/features/excel` | Parsers (Arabic times `9م` `11.30م` `5.30 ص` `12ص`, ambiguous `11.3`, dates incl. serials, prices `45ج`, payment labels); **header detection** on the legacy layout; **import planner** on a synthetic copy of the real sheet; **export** (sheets, headers, formats, totals, RTL, selected sheets); **round-trip** export → import; files written by other tools; unreadable files | `flutter test` |
| Widgets | `customer_search_test`, `record_form_page_test` | Name + phone shown together, *Customer not found* + add, Arabic RTL, **the full add-record flow** (nurse → service → price → payment → save), inline validation | `flutter test` |
| CI | `.github/workflows/ci.yml` | format check, analyze, all Flutter tests | on push / PR |

**Current result:** 133 Flutter tests pass. `flutter analyze` reports no issues.

## End-to-end verification performed during development

Not part of CI.

* The real workbook's 271 rows were imported into the app's SQLite database
  through the app's own planner and repository: 271 records, 0 skipped,
  revenue 60,282 EGP, 129 customers (7 needing review). The full backup of
  that data is about 0.5 MB. That data stays on the development machine and
  is never committed.
* Web build driven in headless Chromium at phone size, with data kept in the
  browser between runs: dashboard, phone search → *not found* → new customer
  (area picker with the seeded areas) → success screen → add record (nurse
  added from the picker, service from the seeded price list fills the price,
  Cash) → profile history and totals; restored draft banner; Excel export
  (downloaded and opened with openpyxl: 5 sheets, totals formula); Excel
  import preview → commit (existing customer matched) → dashboard review
  banner; Arabic RTL.

Google Drive backup could not be exercised end to end here (it needs an
Android device signed in to Google and the OAuth client described in
[08-deployment.md](08-deployment.md)); its logic and REST calls are covered by
the tests above.

## Manual checklist before a release

1. Primary flow on a real phone (keypad, pickers, date/time pickers).
2. More → Google Drive backup → Connect → check `Sanad/Sanad.xlsx` and
   `Sanad/Sanad-backup.json` appear in Drive; add a record, send the app to the
   background, check the file's modified time in Drive.
3. Airplane mode → add a record → the backup shows *waiting* → reconnect → it
   completes.
4. Uninstall / reinstall (or a second phone) → Connect the same account →
   *A backup is already in this Drive* → Restore → data is back.
5. Export → open in Excel (Windows/Mac) and Google Sheets.
