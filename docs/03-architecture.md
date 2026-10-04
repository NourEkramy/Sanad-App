# 3. Architecture

```
┌──────────────────────────── Flutter app (Android · iOS · Web) ───────────────────────────┐
│  Presentation   pages · widgets · Cubits (flutter_bloc) · go_router · l10n (ar/en)        │
│        │  calls                                                                         │
│  Domain         entities · value objects · repository interfaces · use cases (pure Dart)  │
│        │  implemented by                                                                │
│  Data           Supabase repositories · Excel codec · secure local stores                 │
└────────┼──────────────────────────────────────────────┼──────────────────────────────────┘
         │ HTTPS (PostgREST / GoTrue / Functions)         │ Keychain / Keystore
┌────────▼──────────────────────────┐          ┌──────────▼─────────────┐
│ Supabase                           │          │ Device                 │
│  Auth (GoTrue) · PostgreSQL + RLS  │          │  session · offline     │
│  RPC functions · Edge Function     │          │  queue · form drafts   │
│  Backups (PITR) · Studio           │          └────────────────────────┘
└────────────────────────────────────┘
```

## 3.1 Backend choice: Supabase (PostgreSQL)

Firebase/Firestore and Supabase were both considered. Supabase was chosen
because of the data and requirements, not popularity:

| Requirement | Why PostgreSQL/Supabase fits | Firestore trade-off |
|-------------|------------------------------|---------------------|
| **Relational data** (customer → records ← nurse/service/area) | Foreign keys, joins and views. A record can't point at a missing nurse. | No joins or FK integrity. Data must be denormalised by hand. |
| **Unique phone, unique area names** | `UNIQUE` indexes enforced by the database, safe under concurrency. | Needs a separate "index document" and transactions for every write. |
| **Phone search, including partial** | B-tree prefix + trigram indexes. One query handles prefix, "contains" and name. | Prefix only. "Contains" search needs an external search service. |
| **History must not change** | Snapshots written by triggers, check constraints, an audit-log trigger. | Must be enforced in every client. |
| **Totals and reports** (revenue per filter, dashboard) | `SUM`/`COUNT` in SQL functions, done on the server. | Aggregations are limited and billed per document read. |
| **Excel import** (all or nothing, reversible) | One SQL function runs in a single transaction. Rollback by batch. | Batched writes are capped (500 operations), so 271+ rows need several batches, which loses atomicity. |
| **Authentication and roles** | Built-in Auth + Row Level Security policies in SQL, testable with plain SQL. | Security rules are a separate DSL. Roles need custom claims. |
| **Scalability** | Comfortably handles millions of rows. Indexes cover every screen. | Scales well too. |
| **Data security and ownership** | Standard Postgres: `pg_dump` backups, point-in-time recovery, portable (self-hostable). | Vendor lock-in. Exports are less convenient. |
| **Cost predictability** | Fixed tiers. Reads are not billed per document. | Per-read billing grows with every list and search. |

Firestore's main advantage is built-in offline sync. Sanad covers that need
for its primary workflow with an explicit offline queue (see 3.6).

## 3.2 Flutter project structure (feature-first clean architecture)

```
app/lib/
├── main.dart                  bootstrap
├── app/                       composition root
│   ├── app.dart               MaterialApp, providers, theme, locales
│   ├── di.dart                get_it registrations (only place that knows implementations)
│   ├── router.dart            go_router, auth redirects, permission guards
│   ├── routes.dart            route paths
│   └── shell.dart             bottom navigation (Home · Customers · Records · More)
├── core/
│   ├── config/env.dart        --dart-define configuration
│   ├── errors/                Failure types + exception → failure mapping
│   ├── files/                 file picking / sharing gateway
│   ├── network/               connectivity
│   ├── result/                Result<T> (Success / Err)
│   ├── storage/               secure key-value store, Supabase session storage
│   ├── theme/                 design tokens + Material 3 theme
│   ├── utils/                 Money, PhoneNumber, LocalTime, Dates, TextNormalizer
│   ├── validation/            validators + error codes
│   └── widgets/               design-system components, failure messages, l10n helpers
├── features/
│   ├── auth/                  login, password reset, session, roles & permissions
│   ├── dashboard/             statistics + quick actions
│   ├── customers/             search, list, create/edit (duplicate guard), profile
│   ├── records/               add/edit, details, list + filters, offline queue & sync
│   ├── nurses/ care_services/ areas/   reference data
│   ├── excel/                 import (detector, parsers, planner) and export
│   ├── users/                 admin user management
│   └── settings/              More, settings, profile, generic catalogue screens
└── l10n/                      app_en.arb, app_ar.arb (+ generated classes)
```

Each feature follows `domain/` (entities, repository interfaces, use cases)
→ `data/` (Supabase/Excel implementations) → `presentation/` (cubits, pages,
widgets). **Dependencies only point inwards.** Domain code imports no Flutter
or Supabase, which is why the import planner, validation and the record rules
are unit-tested without a device or a database.

## 3.3 Key patterns

| Concern | Choice |
|---------|--------|
| State management | `flutter_bloc` **Cubits**: one per screen, with immutable `Equatable` states. App-wide: `AuthCubit`, `SyncCubit`, `LocaleCubit`. |
| Dependency injection | `get_it`, registered in `app/di.dart` only. Pages receive cubits via `BlocProvider`, and cubits receive use cases through constructors. |
| Repository pattern | Interfaces in `domain/`, Supabase implementations in `data/`. Tests use in-memory fakes. |
| Use cases | Small callable classes (`CreateCustomer`, `AddServiceRecord`, `PrepareImport`, …) holding the business rules. |
| Errors | Repositories never throw. They return `Result<T>` with a typed `Failure` (network, permission, duplicate, validation, business rule, file, auth, session expired). Raw server messages are never shown or logged. |
| Validation | Pure functions return **codes**. The UI maps codes to localised text. The database enforces the same rules again. |
| Routing | `go_router` with a pure, unit-tested redirect function for auth state, permission guards and deep links. |
| Localisation | `gen-l10n`, English + Arabic (RTL), with a language switch in Settings. Western digits are used in both languages. |
| Money | Integer piasters (`Money`), never `double`. |

## 3.4 Authentication and authorisation

* Supabase Auth (email + password). **Public sign-up is disabled.** Admins
  invite staff through the `invite-user` Edge Function, which holds the
  service-role key server-side.
* Session tokens are kept in the platform keystore (`flutter_secure_storage`),
  not in plain preferences. PKCE is used for password-reset links
  (`com.sanad.sanad://auth-callback`).
* Roles (`admin`, `staff`) live in `profiles`. The app checks **permissions**
  (`Permission.importData`, `editRecords`, …) mapped from roles in one table
  (`RolePermissions`), so adding a role is a one-line change. The database
  enforces the same rules with RLS. The UI hiding a button is a convenience,
  not the security boundary.
* Session expiry: when a refresh fails, the app returns to the login screen
  with an explanation. Unsaved record drafts stay on the device.

## 3.5 Excel import and export

* **Import:** `excel` package → `SheetTable` (plain Dart values) →
  `ColumnDetector` (finds the header row, maps Arabic/English headers; the user
  can correct it) → `ImportPlanner` (pure: parsing, deduplication,
  issues) → preview → `import_legacy_batch` (one transaction) → batch history
  with rollback. Details: [01-excel-analysis.md](01-excel-analysis.md).
* **Export:** `filter_service_records` (the same filter as the Records
  screen) → `ExcelWorkbookCodec` builds Records / Customers / Nurses / Services
  / Areas sheets with branded headers, number/date formats, column widths, a
  `SUM` totals row and RTL sheets in Arabic. The file is shared on mobile and
  downloaded on the web.
* An exported workbook can be imported back (round-trip tested). This makes
  Excel a reliable interchange and backup format, while the database stays
  the source of truth.

## 3.6 Offline strategy

Sanad is **online-first with a safety net for the primary workflow**:

1. **Record IDs are generated on the device** (UUID v4) and inserted with
   `ON CONFLICT DO NOTHING`. Retrying a save can never create a duplicate.
2. If saving a record fails because of the **network**, it is stored in an
   **encrypted on-device queue** and shown immediately in the customer's
   history as *Waiting to sync*. Staff see a banner and a badge.
3. `SyncCubit` sends the queue on start-up, when connectivity returns, every
   2 minutes while items are pending, and on demand. Only one sync runs at a time.
4. **Conflicts:** records are append-only from staff, so there are no edit
   conflicts. If the server rejects a queued record (e.g. the nurse was
   deactivated meanwhile), it is kept as *Sync failed* with the reason, so
   staff can open it and either re-enter or discard it. Nothing is dropped
   silently.
5. **Form drafts** (Add record) are saved on the device as the user types and
   restored when the screen is reopened, even after the app was killed.
6. Creating customers, imports and exports require a connection. Phone
   uniqueness must be checked on the server, and these are not time-critical.

To make the app fully offline later, the repository interfaces allow a
caching decorator (e.g. Drift/SQLite) to be added without touching the domain
or the UI.

## 3.7 Performance

* Phone search: debounced (250 ms), stale responses dropped, index-backed
  prefix/trigram queries, at most 20 results.
* Lists are paginated (30 rows) with infinite scroll. Totals come from one
  aggregate query.
* Dashboard: a single RPC call.
