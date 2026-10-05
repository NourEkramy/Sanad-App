# 3. Architecture

```
┌──────────────────────────── Flutter app (Android · iOS · Web) ───────────────────────────┐
│  Presentation   pages · widgets · Cubits (flutter_bloc) · go_router · l10n (ar/en)        │
│        │  calls                                                                         │
│  Domain         entities · value objects · repository interfaces · use cases (pure Dart)  │
│        │  implemented by                                                                │
│  Data           SQLite repositories · Excel codec · Google Drive client · secure store    │
└────────┼──────────────────────────────────────┼──────────────────────────────────────────┘
         │                                      │ HTTPS, only Sanad's own files (drive.file)
┌────────▼──────────────────────────┐   ┌───────▼─────────────────────────────────┐
│ This phone                         │   │ The user's Google Drive › Sanad          │
│  sanad.db (SQLite, app storage)    │   │  Sanad.xlsx         every sheet, to open │
│  form drafts, preferences          │   │                     and share            │
│  (Keystore-encrypted)              │   │  Sanad-backup.json  full data, restore   │
└────────────────────────────────────┘   └─────────────────────────────────────────┘
```

## 3.1 Storage choice: on-device SQLite + the user's Google Drive

Sanad is used by one person for their own work. The data stays with them:

* **Working copy: SQLite on the phone** (`sqflite`). Every screen reads and
  writes it directly, so the app is fast and works with no connection at all.
  There is no server, no account to create and nothing published.
* **Cloud copy: the user's own Google Drive.** After each change (20 s of
  quiet, when the app goes to the background, or when the connection comes
  back) Sanad replaces two files in a `Sanad` folder:
  * `Sanad.xlsx`: the formatted workbook (Records with customer details,
    Customers, Nurses, Services, Areas), to open in Excel / Google Sheets
    and share like any other Drive file;
  * `Sanad-backup.json`: every row of every table, which **Restore** reads
    back on a new phone.

  Drive keeps earlier versions of both files (version history).

Why this design:

| Need | How it is met |
|------|---------------|
| Private, not published | Data never leaves the phone except to the owner's Drive. The app requests the `drive.file` scope: it can see only the files it created, nothing else in Drive. |
| Data editable in the app | All sheets (customers, records, nurses, services, areas) are edited in the app; the database is the source of truth. |
| Export any time, shareable | **Export to Excel** (any period, any sheets) creates a file to share; the Drive copy of `Sanad.xlsx` is always up to date. |
| Works offline | Everything is local; only the backup needs a connection, and it retries. |
| Relational rules | SQLite with foreign keys, `UNIQUE` phone and names, `CHECK` constraints, transactions. |
| History never changes | Snapshots written by the repository inside the same transaction as the record. |
| Safe Excel import | One transaction, duplicate-file protection, rollback by batch. |
| New phone / lost phone | Connect the same Google account → **Restore from Google Drive**. |

The cloud file is a **copy**: edits made directly in the Excel file are not
read back automatically. To bring edited rows in, use **Import from Excel**
(duplicate-safe and reversible). Two-way live editing of one spreadsheet from
two places would create conflicting versions and lost changes.

The repository interfaces do not depend on SQLite. A shared online database
(e.g. PostgreSQL) can be added later as another implementation without
touching the domain or the screens.

## 3.2 Flutter project structure (feature-first clean architecture)

```
app/lib/
├── main.dart                  bootstrap
├── app/                       composition root
│   ├── app.dart               MaterialApp, app-wide cubits (language, backup), reload after restore
│   ├── di.dart                get_it registrations (only place that knows implementations)
│   ├── router.dart            go_router
│   ├── routes.dart            route paths
│   └── shell.dart             bottom navigation (Home · Customers · Records · More)
├── core/
│   ├── database/              SanadDatabase (schema, seed, transactions, dump/restore), SQL helpers
│   ├── errors/                Failure types + exception → failure mapping
│   ├── files/                 file picking / sharing gateway
│   ├── network/               connectivity (backup retries)
│   ├── result/                Result<T> (Success / Err)
│   ├── storage/               secure key-value store (drafts, preferences)
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
│   ├── backup/                Google Drive backup & restore
│   └── settings/              More, settings, generic catalogue screens
└── l10n/                      app_en.arb, app_ar.arb (+ generated classes)
```

Each feature follows `domain/` (entities, repository interfaces, use cases)
→ `data/` (SQLite / Excel / Drive implementations) → `presentation/`
(cubits, pages, widgets). **Dependencies only point inwards.** Domain code
imports no Flutter, SQLite or Google packages.

## 3.3 Key patterns

| Concern | Choice |
|---------|--------|
| State management | `flutter_bloc` **Cubits**: one per screen, immutable `Equatable` states. App-wide: `LocaleCubit`, `BackupCubit`. |
| Dependency injection | `get_it`, registered in `app/di.dart` only. |
| Repository pattern | Interfaces in `domain/`, SQLite implementations in `data/`. Use-case and cubit tests use in-memory fakes; repository tests use real SQLite (FFI). |
| Writes | Every write goes through `SanadDatabase.write` (one transaction), which also announces the change so a backup is scheduled. |
| Errors | Repositories never throw. They return `Result<T>` with a typed `Failure` (duplicate, validation, business rule, not found, file, backup, network). Raw messages are never shown or logged. |
| Validation | Pure functions return **codes**; the UI maps them to localised text. The database enforces the same rules again (constraints). |
| Localisation | `gen-l10n`, English + Arabic (RTL). Western digits in both languages. |
| Money | Integer piasters (`Money`), never `double`. |

## 3.4 Google Drive backup

* Sign-in and permission: `google_sign_in` (Android Identity
  AuthorizationClient). Only the scope
  `https://www.googleapis.com/auth/drive.file` is requested.
* Upload: Drive v3 REST (`DriveApi`): find or create the `Sanad` folder, then
  create the two files the first time and **replace their content** afterwards
  (same file id, so sharing settings and version history are kept).
* Scheduling (`BackupCubit`): a change marks the data *pending* (stored, so it
  survives a restart) and starts a 20-second timer; the app going to the
  background uploads at once; a network failure is retried when connectivity
  returns. The dashboard and the More menu show the state.
* Connecting to a Drive that already has a backup never overwrites it
  silently: the user chooses **Restore** or **Keep this phone's data**.
* Restore replaces all local data in one transaction, then the app reloads
  every screen.
* Drive backup is available in the Android app. On the web build the screen
  offers Export to Excel instead.

## 3.5 Excel import and export

* **Import:** `excel` package → `SheetTable` → `ColumnDetector` (header row,
  Arabic/English headers, user can correct) → `ImportPlanner` (pure: parsing,
  deduplication, issues) → preview → one SQLite transaction → batch history
  with rollback. Details: [01-excel-analysis.md](01-excel-analysis.md).
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
* The real workbook (271 records, 129 customers) produces a ~0.5 MB JSON
  backup.
