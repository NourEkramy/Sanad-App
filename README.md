# Sanad · سند

**Customer & service-records app for home care, on your phone.**
Search a customer by phone, confirm, add the visit, save. Every service is kept
with full history on the phone, a copy is kept up to date in your own Google
Drive (`Sanad.xlsx`, ready to open and share), and Excel import/export is built
in. Arabic and English.

<p>
<img src="docs/screenshots/02-dashboard.png" width="200" alt="Dashboard">
<img src="docs/screenshots/03-phone-search.png" width="200" alt="Phone search">
<img src="docs/screenshots/06-add-record.png" width="200" alt="Add service record">
<img src="docs/screenshots/05-customer-profile.png" width="200" alt="Customer profile">
</p>
<p>
<img src="docs/screenshots/07-records.png" width="200" alt="Records with totals">
<img src="docs/screenshots/12-import-preview.png" width="200" alt="Excel import preview">
<img src="docs/screenshots/14-dashboard-ar.png" width="200" alt="Arabic dashboard">
<img src="docs/screenshots/15-profile-ar.png" width="200" alt="Arabic profile">
</p>

*Screenshots use fictional demo data.*

## What's inside

| | |
|---|---|
| **App** (`app/`) | Flutter 3.47 · feature-first clean architecture (domain / data / presentation) · Cubit state management · get_it · go_router · Material 3 design system in Sanad blue · Arabic (RTL) + English · Android (also runs in a browser for a quick look) |
| **Data** | SQLite on the phone (`sqflite`): foreign keys, unique phone and names, frozen history, atomic and reversible Excel import. No server, no account. |
| **Cloud copy** | The user's own Google Drive (`drive.file` scope: Sanad sees only its own files): `Sanad.xlsx` with every sheet + a full backup for restore, updated automatically after changes |
| **Docs** (`docs/`) | Workbook analysis, schema, architecture, user flows, design system, screen specs, testing, setup, security |
| **Tests** | 133 Flutter tests (unit, cubit, widget, and repository tests on real SQLite), run in CI |

## Features

* **Phone-first search** (partial numbers, Arabic digits, `+20`, or name). Results show name, phone and area together.
* **Customers**: unique phone (duplicates are shown, never created), searchable areas with inline "Add new area", profile with full service history.
* **Service records**: nurse, service (default price suggested; actual price stored), Cash/Electronic, date/time defaulting to now, notes, patient name for family members.
* **History never changes**: price, nurse, service, area and address are frozen per record.
* **Records**: search, filters (date range, nurse, service, area, payment), sorting, live totals.
* **Nurses, services, areas**: managed in the app; deactivate instead of delete. The legacy price list and areas are preloaded.
* **Dashboard**: today's services and revenue (cash / electronic), totals, review alerts, backup state.
* **Google Drive backup**: connect once; every change is backed up; restore on a new phone; the Drive copy of `Sanad.xlsx` can be shared like any Drive file.
* **Excel import**: auto-mapped columns, preview with row-level warnings, one transaction, rollback.
* **Excel export**: formatted workbook (Records with customer details, Customers, Nurses, Services, Areas), any period, shared from the phone.
* **Works offline**: everything is on the phone; only the backup needs a connection, and it retries by itself.
* **Privacy**: data stays on the phone and in the owner's Drive; nothing is published.

## Quick start

```bash
cd app
flutter pub get
flutter run              # Android phone or emulator
```

To enable the Google Drive backup, register the app with Google once:
[docs/08-deployment.md › Google Drive setup](docs/08-deployment.md#83-google-drive-setup-once-about-10-minutes).

Tests:

```bash
cd app && flutter analyze && flutter test
```

## Documentation

1. [Excel workbook analysis & migration strategy](docs/01-excel-analysis.md)
2. [Database schema](docs/02-database-schema.md)
3. [Architecture & backend choice](docs/03-architecture.md)
4. [User flows](docs/04-user-flows.md)
5. [Design system](docs/05-design-system.md)
6. [Screen specifications](docs/06-screens.md)
7. [Testing strategy](docs/07-testing.md)
8. [Setup, Google Drive & installing on a phone](docs/08-deployment.md)
9. [Security & privacy](docs/09-security.md)

## Repository layout

```
app/                      Flutter application
  lib/app/                composition root: DI, router, shell
  lib/core/               database, theme, widgets, errors, utils, storage
  lib/features/<feature>/ domain · data · presentation
  lib/l10n/               English & Arabic strings
  test/                   unit, cubit, widget and database tests
docs/                     project documentation
```

The Cairo font is bundled under the SIL Open Font License.
