# Sanad · سند

**Customer & service-records management for home-care teams.**
Search a customer by phone, confirm, add the visit, save. Every service is kept in
a cloud database with full history, Excel import/export and role-based access.
Arabic and English.

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
| **App** (`app/`) | Flutter 3.47 · feature-first clean architecture (domain / data / presentation) · Cubit state management · get_it · go_router · Material 3 design system in Sanad blue · Arabic (RTL) + English · Android, iOS, Web |
| **Backend** (`supabase/`) | Supabase: PostgreSQL with Row Level Security, phone-indexed search, historical snapshots, audit log, atomic + reversible Excel import, invite-user Edge Function |
| **Docs** (`docs/`) | Workbook analysis, schema, architecture, user flows, design system, screen specs, testing, deployment, security |
| **Tests** | 106 Flutter unit/cubit/widget tests + SQL test suite (constraints, RLS, import/rollback), run in CI |

## Features

* **Phone-first search** (partial numbers, Arabic digits, `+20`, or name). Results show name, phone and area together.
* **Customers**: unique phone (duplicates are shown, never created), searchable areas with inline "Add new area", profile with full service history.
* **Service records**: nurse, service (default price suggested; actual price stored), Cash/Electronic, date/time defaulting to now, notes, patient name for family members.
* **History never changes**: price, nurse, service, area and address are frozen per record.
* **Records**: search, filters (date range, nurse, service, area, payment), sorting, live totals.
* **Nurses, services, areas, users**: managed in-app; deactivate instead of delete.
* **Dashboard**: today's services and revenue (cash / electronic), totals, review alerts.
* **Excel import**: auto-mapped columns, preview with row-level warnings, one transaction, rollback.
* **Excel export**: formatted workbook (Records with customer details, Customers, Nurses, Services, Areas).
* **Offline safety net**: records saved without a connection are queued on the device (encrypted) and synced automatically. Form drafts survive app restarts.
* **Security**: admin/staff roles, RLS on every table, no hard deletes, secure session storage.

## Quick start

```bash
npx supabase start                              # local backend (Docker), applies migrations + seed
cp app/env/local.example.json app/env/local.json  # add the publishable key printed above
cd app && flutter pub get
flutter run --dart-define-from-file=env/local.json
```

Create the first admin as described in [docs/08-deployment.md](docs/08-deployment.md).

Tests:

```bash
cd app && flutter analyze && flutter test
supabase/tests/run.sh          # database tests (needs a local PostgreSQL)
```

## Documentation

1. [Excel workbook analysis & migration strategy](docs/01-excel-analysis.md)
2. [Database schema](docs/02-database-schema.md)
3. [Architecture & backend choice](docs/03-architecture.md)
4. [User flows](docs/04-user-flows.md)
5. [Design system](docs/05-design-system.md)
6. [Screen specifications](docs/06-screens.md)
7. [Testing strategy](docs/07-testing.md)
8. [Deployment](docs/08-deployment.md)
9. [Security & privacy](docs/09-security.md)

## Repository layout

```
app/                      Flutter application
  lib/app/                composition root: DI, router, shell
  lib/core/               theme, widgets, errors, utils, storage
  lib/features/<feature>/ domain · data · presentation
  lib/l10n/               English & Arabic strings
  test/                   unit, cubit and widget tests
supabase/
  migrations/             schema, RLS, functions
  seed.sql                areas & service price list from the legacy workbook
  functions/invite-user/  admin-only account creation
  tests/                  SQL tests + runner
docs/                     project documentation
```

The Cairo font is bundled under the SIL Open Font License.
