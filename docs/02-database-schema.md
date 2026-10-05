# 2. Database schema

SQLite on the device. Source: [`app/lib/core/database/sanad_database.dart`](../app/lib/core/database/sanad_database.dart)
(schema, seed, transactions, backup dump/restore). Foreign keys are enforced
(`PRAGMA foreign_keys = ON`).

Storage formats: ids are UUID text; money is **integer piasters**; dates are
`yyyy-MM-dd`; times `HH:mm:ss`; timestamps UTC ISO 8601; booleans 0/1.

## 2.1 Entities and relationships

```mermaid
erDiagram
    areas ||--o{ customers : "lives in"
    areas ||--o{ service_records : "area at time of visit"
    customers ||--o{ service_records : "has"
    nurses ||--o{ service_records : "provided by"
    services ||--o{ service_records : "service"
    import_batches ||--o{ import_rows : "audit"
    import_batches ||--o{ service_records : "imported"
    import_batches ||--o{ customers : "imported"

    areas {
        text id PK
        text name
        text name_normalized UK
        int is_active
    }
    nurses {
        text id PK
        text name
        text name_normalized UK
        text phone
        int is_active
    }
    services {
        text id PK
        text name
        text name_normalized UK
        int default_price "piasters, NULL = variable"
        int is_active
    }
    customers {
        text id PK
        text full_name
        text name_normalized
        text phone UK "01XXXXXXXXX"
        text address
        text area_id FK
        int needs_review
        text deleted_at "archive"
    }
    service_records {
        text id PK
        text customer_id FK
        text nurse_id FK
        text service_id FK
        text area_id FK
        text patient_name
        int price "piasters, actual price"
        text payment_method "cash | electronic | unspecified"
        text service_date
        text service_time
        text notes
        text "*_snapshot" "history"
        text deleted_at "archive"
    }
```

Supporting tables: `import_batches` (one per import, reversible) and
`import_rows` (every source row and what happened to it).

## 2.2 Tables

| Table | Purpose | Key rules |
|-------|---------|-----------|
| `areas` | Living areas | `name_normalized` is unique, so `الهانوفيل` and ` الهانوفيل ` (or `أ`/`ا` variants) cannot both exist. Deactivate instead of delete. |
| `nurses` | Nurses / technicians | Unique normalised name, optional phone, `is_active`. |
| `services` | Service catalogue | `default_price` is only a suggestion (NULL means variable). Seeded with the 51 services of the legacy price list. |
| `customers` | Customers | **`phone` is unique** and stored normalised (`01012345678`). Required: name, area and phone, except imported customers without a valid phone, which are allowed **only** with `needs_review = 1`. Archived with `deleted_at`. |
| `service_records` | One service/visit | Belongs to exactly one customer. Required: nurse, service, price ≥ 0, payment method, date, time. Imported rows may lack a time or payment method (`unspecified`); new rows may not (`CHECK`). |
| `import_batches` | Each Excel import | `file_sha256` is unique among committed batches (no double import). |
| `import_rows` | Copy of every imported or skipped row | Raw cell text plus warnings/errors. |

Nine areas and the service price list from the workbook's `قوائم` sheet are
inserted when the database is created.

### Why records keep snapshots

A historical record must never change when the customer moves, an area is
renamed, a nurse's details change, or a service price changes. Records store:

* `price`: the amount actually charged (never derived from `services.default_price`);
* `area_id` + `area_name_snapshot`, `address_snapshot`: where the visit took place;
* `nurse_name_snapshot`, `service_name_snapshot`, `customer_name_snapshot`,
  `customer_phone_snapshot`.

The record repository writes the snapshot in the same transaction as the
record and checks that the nurse and service are active and the customer is
not archived. Customer *identity* (name and phone) in lists and exports comes
from the live customer row.

## 2.3 Indexes

| Index | Serves |
|-------|--------|
| `customers.phone` (unique) | Duplicate prevention, exact lookup, prefix/contains search |
| `customers_name_idx` | Name search |
| `service_records_customer_idx` (customer, date, time) | Customer history |
| `service_records_date_idx` (date, time) | Records list, today's stats, date filters |
| `service_records_batch_idx` | Import rollback |
| `*.name_normalized` (unique) | Unique reference names |
| `import_batches_file_committed_key` | One committed import per file |

## 2.4 Queries

| Where | What |
|-------|------|
| `LocalCustomerRepository.search` | Phone-first search: digits → phone prefix, then "contains" from 4 digits; text → normalised name. Arabic-Indic digits and `+20` accepted. LIKE wildcards escaped. |
| `RecordMapper.where` | **Single definition** of record filtering (date range, nurse, service, area, payment, customer, name/phone query), used by the list, the totals and the export |
| `LocalDashboardRepository` | All dashboard numbers in one query |
| `LocalImportRepository.commit / rollback` | Atomic import; rollback removes only what the batch created and nothing used since |
| `SanadDatabase.dump / restore` | Full backup (all tables) and restore in one transaction |

## 2.5 Tests

`app/test/core/database/local_repositories_test.dart` runs every repository
against a real in-memory SQLite database: seed data, unique names with
spelling variants, duplicate phone (use case and constraint), phone and name
search, archived customers, visit counts, record snapshot and frozen history
after renames / moves / price changes, double save, inactive nurse and
archived customer, ordering, filters + totals, record correction, dashboard,
Excel import (matching, review flags, revenue), duplicate-file refusal,
rollback keeping used data, re-import, export, and backup dump/restore.
