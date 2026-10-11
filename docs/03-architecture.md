# 3. Architecture

```
┌──────────────────────────── Flutter app (Android · iOS · Web) ───────────────────────────┐
│  Presentation   pages · widgets · Cubits (flutter_bloc) · go_router · l10n (ar/en)        │
│        │  calls                                                                         │
│  Domain         entities · value objects · repository interfaces · use cases (pure Dart)  │
│        │  implemented by                                                                │
│  Data           SQLite repositories · Excel codec · sheet connector client · secure store │
└────────┼──────────────────────────────────────┼──────────────────────────────────────────┘
         │                                      │ HTTPS (JSON), link + pairing key
┌────────▼──────────────────────────┐   ┌───────▼──────────────────────────────────────┐
│ This phone                         │   │ The user's Google Sheet (Google Drive)        │
│  sanad.db (SQLite, app storage)    │   │  Sanad script (Apps Script Web app)           │
│  form drafts, preferences,         │   │   reads every sheet · writes changed rows     │
│  sheet link (Keystore-encrypted)   │   │  سجل الزيارات · بيانات الحالات · قوائم · …     │
└────────────────────────────────────┘   └──────────────────────────────────────────────┘
```

## 3.1 Storage choice: on-device SQLite + the user's Google Sheet

Sanad is used by one person (or a few phones) for their own work. The data
stays with them:

* **Working copy: SQLite on the phone** (`sqflite`). Every screen reads and
  writes it directly, so the app is fast and works with no connection at all.
  There is no server, no account to create and nothing published.
* **The spreadsheet: the user's own Google Sheet.** A small script
  (`tools/google-sheets/Code.gs`) is pasted into the spreadsheet and deployed
  as a Web app (*Execute as: Me*). The app talks to it over HTTPS:
  * when connecting, it **reads every sheet** and loads the visits, customers
    and lists into the phone;
  * after that, every new or changed row is **written into the sheet** a few
    seconds later, in the sheet's own layout (the original workbook's visits
    log, customers sheet and lists), so its dashboard and formulas keep
    working.

Why this design:

| Need | How it is met |
|------|---------------|
| Free, no Google Cloud setup | Apps Script Web apps are free; the script runs as the spreadsheet's owner. No OAuth client, no API key, no Google sign-in in the app. |
| Any Google account, any phone | The phone only needs the Web app link (and, for a second phone, a connection code). No Google Play services needed. |
| Private, not published | Data goes only to the owner's spreadsheet. The script can only open the spreadsheet it is pasted into (`@OnlyCurrentDoc`). Writes need the pairing key. |
| The Excel sheet stays the one they use | The workbook is converted to a Google Sheet once; Sanad writes into its existing sheets, by header name, without touching other sheets or formulas. |
| Works offline | Everything is local; changes wait and are written when the connection is back. |
| Relational rules | SQLite with foreign keys, `UNIQUE` phone and names, `CHECK` constraints, transactions. |
| History never changes | Snapshots written by the repository inside the same transaction as the record. |
| New phone / lost phone | Install, paste the link (and code) → **Load the sheet's data**. A new code locks out other phones. |

The sync is **one-way** (phone → sheet). Edits made directly in the sheet are
read only when the user chooses **Load all data from the sheet again**, which
replaces the phone's data with the sheet's (rows keep their Sanad ID). Two-way
merging of edits made in two places would create conflicts and lost changes.

The repository interfaces do not depend on SQLite. A shared online database
can be added later as another implementation without touching the domain or
the screens.

## 3.2 Flutter project structure (feature-first clean architecture)

```
app/lib/
├── main.dart                  bootstrap
├── app/                       composition root
│   ├── app.dart               MaterialApp, app-wide cubits (language, sheet), reload after loading the sheet
│   ├── di.dart                get_it registrations (only place that knows implementations)
│   ├── router.dart            go_router
│   ├── routes.dart            route paths
│   └── shell.dart             bottom navigation (Home · Customers · Records · More)
├── core/
│   ├── database/              SanadDatabase (schema, migrations, seed, transactions), SheetState, SQL helpers
│   ├── errors/                Failure types + exception → failure mapping
│   ├── files/                 file picking / sharing gateway
│   ├── network/               connectivity (sheet update retries)
│   ├── result/                Result<T> (Success / Err)
│   ├── storage/               secure key-value store (drafts, preferences, sheet link)
│   ├── theme/                 design tokens + Material 3 theme
│   ├── utils/                 Money, PhoneNumber, LocalTime, Dates, TextNormalizer
│   ├── validation/            validators + error codes
│   └── widgets/               design-system components, failure messages, l10n helpers
├── features/
│   ├── dashboard/             statistics + quick actions
│   ├── customers/             search, list, create/edit (duplicate guard), profile
│   ├── records/               add/edit (with drafts), details, list + filters + totals
│   ├── nurses/ care_services/ areas/   reference data
│   ├── excel/                 import (detector, parsers, planner) and export
│   ├── sheet/                 Google Sheet link: connector client, layout detection, sync
│   └── settings/              More, settings, generic catalogue screens
└── l10n/                      app_en.arb, app_ar.arb (+ generated classes)

tools/google-sheets/
├── Code.gs                    the script pasted into the spreadsheet (also bundled as an app asset)
├── dev-server.js              local stand-in: runs Code.gs on an in-memory spreadsheet
└── test/                      Node tests of Code.gs against a fake SpreadsheetApp
```

Each feature follows `domain/` (entities, repository interfaces, use cases)
→ `data/` (SQLite / Excel / HTTP implementations) → `presentation/`
(cubits, pages, widgets). **Dependencies only point inwards.** Domain code
imports no Flutter, SQLite or HTTP packages.

## 3.3 Key patterns

| Concern | Choice |
|---------|--------|
| State management | `flutter_bloc` **Cubits**: one per screen, immutable `Equatable` states. App-wide: `LocaleCubit`, `SheetCubit`. |
| Dependency injection | `get_it`, registered in `app/di.dart` only. |
| Repository pattern | Interfaces in `domain/`, SQLite implementations in `data/`. Use-case and cubit tests use in-memory fakes; repository tests use real SQLite (FFI). |
| Writes | Every write goes through `SanadDatabase.write` (one transaction), which also announces the change so the sheet update is scheduled. Changed rows are marked `sheet_state = changed` in the same transaction. |
| Errors | Repositories never throw. They return `Result<T>` with a typed `Failure` (duplicate, validation, business rule, not found, file, sheet, network). Raw messages are never logged. |
| Validation | Pure functions return **codes**; the UI maps them to localised text. The database enforces the same rules again (constraints). |
| Localisation | `gen-l10n`, English + Arabic (RTL). Western digits in both languages. |
| Money | Integer piasters (`Money`), never `double`. |

## 3.4 Google Sheet link

**The script** (`Code.gs`, one file, ES5) answers `POST` requests with JSON:

| Action | What it does |
|---|---|
| `pair` | The first phone gets a random 10-character key (stored in the script's properties); later phones must send the key, shown in the sheet's **سند** menu (`code_required` otherwise). |
| `read` | Returns every sheet's cells: dates as `{d: "yyyy-MM-dd[ HH:mm]"}`, time-only cells as displayed, blanks as `null`. |
| `write` | Applies one operation per sheet: **upserts** (by ID, else by known row, else by phone for customers; `overwrite: false` fills blanks only), **stamps** (write an ID on an existing row), **clears** (empty a deleted record's cells), **appends** (add a name to a list column). Columns are addressed by header text; headers it needs (`طريقة الدفع`, `معرف سند`) are added after the last used column; missing headers are reported back. |

Writes keep the workbook's own conventions: a new visit goes after the last
dated row, reusing pre-numbered rows (`م` is kept, formulas in `اليوم` /
`الشهر` are not overwritten); text that Sheets would turn into a number,
date or formula is written as text (phone numbers keep their leading 0).
Each request reads every sheet it touches **once** (values and formulas) and
then only writes, because reading after writing is slow in Apps Script. A
script lock serialises requests from several phones.

**The app side** (`features/sheet/`):

* `AppsScriptConnector` (data): HTTPS client. Google answers the `POST` with a
  302 redirect to the result, fetched with a `GET` (followed manually on the
  phone; the browser follows it itself). Maps HTTP and script errors to
  `SheetFailure` / `NetworkFailure`.
* `SheetLayoutDetector` (domain, pure): finds the visits sheet (the sheet whose
  header row maps the most known columns, e.g. header row 3 of
  `سجل الزيارات`), the customers sheet and the lists sheet; for an empty
  spreadsheet it uses Sanad's own standard layout, created on first write.
* `ConnectSheet` → `LinkSheet` (domain): pair, read, plan the import with the
  same `ImportPlanner` as Excel import, then either **load** the sheet's data
  (optionally replacing the phone's data) or **keep** the phone's data and
  write all of it into the sheet. Loaded rows are linked to their sheet row
  (`sheet_row`, `sheet_state = linked`): they only get their ID written.
* `SyncSheet` (domain): takes up to 100 waiting rows at a time from
  `LocalSheetStore`, builds the operations (`SheetOpsBuilder`, pure), sends
  them, and marks rows written **only if they did not change again in the
  meantime** (`updated_at` check). If the sheet reports missing headers it
  re-detects the layout once.
* `SheetCubit` (presentation): starts an update 4 s after the last change,
  when the app goes to the background, and when the connection comes back;
  failures are retried with backoff (30 s … 15 min). The dashboard banner and
  the sheet icon show the state.

## 3.5 Excel import and export

* **Import:** `excel` package → `SheetTable` → `ColumnDetector` (header row,
  Arabic/English headers, user can correct) → `ImportPlanner` (pure: parsing,
  deduplication, issues) → preview → one SQLite transaction → batch history
  with rollback. Details: [01-excel-analysis.md](01-excel-analysis.md). The
  Google Sheet link reuses the same detector and planner.
* **Export:** the same filter as the Records screen → `ExcelWorkbookCodec`
  builds Records / Customers / Nurses / Services / Areas sheets with headers,
  number/date formats, column widths, a `SUM` totals row and RTL sheets in
  Arabic. Shared on mobile, downloaded on the web.
* An exported workbook can be imported back (round-trip tested).

## 3.6 Performance

* SQLite indexes on phone, normalised name, record dates, customer and batch.
* Phone search: debounced (250 ms), stale responses dropped, at most 20 results.
* Lists are paginated (30 rows) with infinite scroll; totals come from one
  aggregate query; the dashboard is one query.
* The real workbook (8 sheets, 271 visits) is read and planned in about half a
  second against the local stand-in; the first update (IDs for 271 visits,
  130 customers) is two requests.
