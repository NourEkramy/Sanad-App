# 7. Testing strategy

| Layer | Where | What | Run |
|-------|-------|------|-----|
| Domain & value objects | `app/test/core/value_objects_test.dart` | Phone normalisation/validation, money parsing, Arabic name normalisation, validators | `flutter test` |
| Database & repositories | `app/test/core/database/local_repositories_test.dart` | Real SQLite (in memory, FFI): seed data; unique names with Arabic spelling variants; **duplicate phone** (use case and constraint); **phone search** (full, prefix, partial 4+, Arabic digits, `+20`) and name search; archived customers; visit counts; **records**: snapshot, actual price in piasters, payment method, **history frozen** after nurse/service/area renames, customer moves and default-price changes; double save; inactive nurse / archived customer rejected; ordering; filters + totals; correction; dashboard numbers; **Excel import** (matching existing data, review flags, revenue), duplicate-file refusal, **rollback** keeping used data, re-import, export; **upgrade of a 1.0.2 database** (schema 1 → 2) keeping its data; reset; change notifications | `flutter test` |
| Use cases | `app/test/features/customers`, `…/records` | Customer creation, duplicate phone (incl. archived), search (full, partial, Arabic digits, name, too-short), area de-duplication, adding records, required fields, **price handling** (actual price, piasters, invalid/negative), **payment method** rules, future dates, history | `flutter test` |
| Cubits | `record_form_cubit_test`, `customer_search_test`, `sheet_cubit_test` | Default date/time, **price suggestion vs typed price**, variable price, draft save/restore, failed save keeps input; debounced search; **Google Sheet**: wrong link refused before sending, connection code asked for, an empty sheet receives the phone's data, a sheet with data waits for the choice then loads and reloads every screen, customers counted once, changes written a moment after they are made, offline failure shown then written when back online, written at once when the app goes to the background, disconnect | `flutter test` |
| Google Sheet: domain | `app/test/features/sheet/sheet_ops_test`, `layout_detector_test`, `local_sheet_store_test` | Cells of a visit in the workbook's format (times `9م`, payment text, one name column), upserts / stamps / clears / list appends, receipts; detection of the original workbook's visits (header row 3), customers and lists sheets and of an empty spreadsheet; rows marked written only if unchanged since, linking loaded rows, import rollback clearing written rows, the sheet's prices winning, keep / clear | `flutter test` |
| Google Sheet: connector | `apps_script_connector_test` | Link checks (`/exec`, `/dev`, other pages), JSON over POST and the redirect, every sheet read (dates, times, blanks), content fingerprint, writes, sign-in page / 404 / 5xx / script errors / missing sheet / no network / timeout, **a real HTTP server answering 302 to a POST** (the phone's client) | `flutter test` |
| Google Sheet: end to end | `sheet_sync_e2e_test` | The app's code over real HTTP against **the real script** (`Code.gs` in Node, on a copy of the workbook's layout): connect, load, IDs written, new visit in the first pre-numbered row keeping number and formulas, correction in place, deletion clears the row, new nurse appended, load again keeping IDs with nothing written twice, second phone needs the code. Skipped when Node.js is missing. | `flutter test` |
| Sheet script | `tools/google-sheets/test/connector.test.js` | `Code.gs` against a fake `SpreadsheetApp`: pairing and codes, reading, first free row with formulas and numbers kept, updates, stamps, clears, customers matched by phone (and re-linked after a reload), copied rows, lists, created sheets, growing sheets, bad requests, header names, new columns never over unlabelled cells, months kept as text (`2026-10`, as the monthly summary expects), **each sheet read once per request** | `node --test tools/google-sheets/test/*.test.js` |
| Excel | `app/test/features/excel` | Parsers (Arabic times `9م` `11.30م` `5.30 ص` `12ص`, ambiguous `11.3`, dates incl. serials, prices `45ج`, payment labels); **header detection** on the legacy layout; **import planner** on a synthetic copy of the real sheet; **export** (sheets, headers, formats, totals, RTL, selected sheets); **round-trip** export → import; files written by other tools; unreadable files | `flutter test` |
| Widgets | `customer_search_test`, `record_form_page_test`, `sheet_page_test` | Name + phone shown together, *Customer not found* + add, Arabic RTL, **the full add-record flow** (nurse → service → price → payment → save), inline validation; Google Sheet screen: setup steps, script copied, link and code sent, load / replace (confirmed), waiting count, failure explained, Arabic layout | `flutter test` |
| CI | `.github/workflows/ci.yml` | format check, analyze, all Flutter tests, script tests | on push / PR |

**Current result:** 173 Flutter tests and 18 script tests pass. `flutter analyze` reports no issues.

## End-to-end verification performed during development

Not part of CI.

* The real workbook's 271 rows were imported into the app's SQLite database
  through the app's own planner and repository: 271 records, 0 skipped,
  revenue 60,282 EGP, 129 customers (7 needing review). That data stays on
  the development machine and is never committed.
* **The real workbook through the real script**: all 8 sheets served by the
  stand-in server, connected and synced by the app's code. Read and planned
  in about 0.4 s; 271 visits loaded (60,282 EGP); the first update wrote the
  271 IDs and filled the customers sheet (28 customers that were only in the
  visits sheet added) with **no other cell of the visits sheet changed** and
  no list entry added; a new visit went to row 275, right after the last one,
  keeping running number 272 (weekday and month written like the
  workbook's: `Saturday`, `2026-10` as text); loading again and updating changed nothing in
  the visits sheet and only the ID column of the customers sheet. This found
  a stray value in an unlabelled column of the visits sheet, which is why new
  columns go after the last used column.
* **Web build in headless Chromium** against the stand-in server, through the
  app's screens: banner → Google Sheet → link → *connection code needed*
  (another client had paired) → code → found card → load → dashboard
  updated; new customer and visits added from the app reached the customers
  sheet and the first pre-numbered visits row (number and formulas kept,
  payment and ID filled); the sheet's price replaced the built-in one. This
  found that the browser refused the script's redirect (fixed).
* Web build driven in headless Chromium at phone size, with data kept in the
  browser between runs: dashboard, phone search → *not found* → new customer
  (area picker with the seeded areas) → success screen → add record (nurse
  added from the picker, service from the seeded price list fills the price,
  Cash) → profile history and totals; restored draft banner; Excel export
  (downloaded and opened with openpyxl: 5 sheets, totals formula); Excel
  import preview → commit (existing customer matched) → dashboard review
  banner; Arabic RTL.

The real Google Apps Script service could not be called from here (it needs
the user's Google account). The script is tested against a fake
`SpreadsheetApp` that implements what it uses, and the app against that
script over real HTTP, including Google's POST → 302 → GET answer.

## Manual checklist before a release

1. Primary flow on a real phone (keypad, pickers, date/time pickers).
2. A copy of the workbook as a Google Sheet with the current `Code.gs`
   deployed → More → Google Sheet → Connect → Load: the counts match the
   sheet; the visits sheet gets `طريقة الدفع` and `معرف سند` after the last
   used column and nothing else changes.
3. Add a record → within seconds it appears in the first free row; the
   dashboard sheet's totals change. Edit it → same row. Delete it → the row
   is cleared, its number and formulas stay.
4. Airplane mode → add a record → *1 change waiting* → reconnect → written.
5. Second phone (or reinstall) → same link → code from **سند → رمز الربط** →
   Load the sheet's data → same records.
6. Export → open in Excel (Windows/Mac) and Google Sheets.
