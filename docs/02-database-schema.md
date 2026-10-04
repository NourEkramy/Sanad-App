# 2. Database schema

PostgreSQL (Supabase). Source: [`supabase/migrations/20261004000000_initial_schema.sql`](../supabase/migrations/20261004000000_initial_schema.sql).

## 2.1 Entities and relationships

```mermaid
erDiagram
    profiles ||--o{ customers : "created_by"
    profiles ||--o{ service_records : "created_by"
    areas ||--o{ customers : "lives in"
    areas ||--o{ service_records : "area at time of visit"
    customers ||--o{ service_records : "has"
    nurses ||--o{ service_records : "provided by"
    services ||--o{ service_records : "service"
    import_batches ||--o{ import_rows : "audit"
    import_batches ||--o{ service_records : "imported"
    import_batches ||--o{ customers : "imported"

    profiles {
        uuid id PK "= auth.users.id"
        text full_name
        text email
        app_role role "admin | staff"
        bool is_active
    }
    areas {
        uuid id PK
        text name
        text name_normalized UK "generated"
        bool is_active
    }
    nurses {
        uuid id PK
        text name
        text name_normalized UK "generated"
        text phone
        bool is_active
    }
    services {
        uuid id PK
        text name
        text name_normalized UK "generated"
        numeric default_price "NULL = variable"
        bool is_active
    }
    customers {
        uuid id PK
        text full_name
        text phone UK "01XXXXXXXXX"
        text address
        uuid area_id FK
        bool needs_review
        timestamptz deleted_at "soft delete"
    }
    service_records {
        uuid id PK "client-generated"
        uuid customer_id FK
        uuid nurse_id FK
        uuid service_id FK
        uuid area_id FK
        text patient_name
        numeric price "actual price"
        payment_method payment_method
        date service_date
        time service_time
        text notes
        text "*_snapshot" "history"
        timestamptz deleted_at "soft delete"
    }
```

Supporting tables: `import_batches` (one per import, reversible), `import_rows`
(every source row and its outcome) and `audit_log` (old and new values for every
update or delete of customers and records).

## 2.2 Tables

| Table | Purpose | Key rules |
|-------|---------|-----------|
| `profiles` | App user (1:1 with `auth.users`) | Created by trigger as `staff`. Only admins change roles or activation, and an admin cannot demote or deactivate themselves. |
| `areas` | Living areas | `name_normalized` is unique, so `الهانوفيل` and ` الهانوفيل ` cannot both exist. Deactivate instead of delete. |
| `nurses` | Nurses / technicians | Unique normalised name, optional phone, `is_active`. |
| `services` | Service catalogue | `default_price` is only a suggestion (NULL means variable). |
| `customers` | Customers | **`phone` is unique** (partial unique index). It is stored normalised (`01012345678`). Required: name, phone, area. Imported customers without a valid phone are allowed **only** with `needs_review = true`. Soft-deleted with `deleted_at`. |
| `service_records` | One service/visit | Belongs to exactly one customer. Required: nurse, service, price ≥ 0, payment method, date, time. Imported rows may lack a time or payment method (`unspecified`); new rows may not (check constraints). |
| `import_batches` | Each Excel import | `file_sha256` is unique among committed batches (no double import). |
| `import_rows` | Audit copy of every imported or skipped row | Raw cell text plus warnings/errors. |
| `audit_log` | Change history | Written by triggers. Admin-readable only. |

### Why records keep snapshots

The brief requires that a historical record never changes when the customer
moves, an area is renamed, a nurse's details change, or a service price
changes. Records therefore store:

* `price`: the amount actually charged (never derived from `services.default_price`);
* `area_id` + `area_name_snapshot`, `address_snapshot`: where the visit took place;
* `nurse_name_snapshot`, `service_name_snapshot`, `customer_name_snapshot`,
  `customer_phone_snapshot`.

The snapshots are written **by a database trigger**, so clients cannot forge
them. The foreign keys (`customer_id`, `nurse_id`, `service_id`, `area_id`)
are kept for relational queries and filtering, so data is not otherwise
duplicated. Customer *identity* (name and phone) in lists and exports comes
from the live customer row. The snapshot keeps the original values for audit.

## 2.3 Indexes

| Index | Serves |
|-------|--------|
| `customers_phone_key` (unique, partial) | Duplicate prevention and exact phone lookup |
| `customers_phone_prefix_idx` (`text_pattern_ops`) | **Prefix search** while typing (`01012…`) |
| `customers_phone_trgm_idx` (GIN trigram) | "Contains" search (`…5678`, 4+ digits) |
| `customers_name_trgm_idx` (GIN trigram on normalised name) | Name search |
| `service_records_customer_idx` (customer, date desc, time desc), partial on not-deleted | Customer history |
| `service_records_date_idx` (date desc, time desc), partial on not-deleted | Records list, today's stats, date filters |
| `service_records_nurse_idx`, `_service_idx`, `_area_idx` | Filters |
| `*_name_normalized_key` | Unique reference names |
| `import_batches_file_committed_key` | One committed import per file |

## 2.4 Views and functions (API)

| Object | Purpose |
|--------|---------|
| `customer_overview` (view) | Customer + area name + record count + last visit |
| `service_record_details` (view) | Record + customer name/phone + snapshots |
| `search_customers(query, max_results)` | Phone-first search (digits → prefix/contains; text → normalised name). Arabic-Indic digits and `+20` are accepted. |
| `filter_service_records(...)` | **Single definition** of record filtering, used by the list, the totals and the export |
| `record_totals(...)` | Count and revenue (cash / electronic) for a filter |
| `dashboard_stats(day)` | Dashboard numbers in one round trip |
| `archive_service_record(id)`, `set_customer_archived(id, bool)` | Soft delete / restore (admin) |
| `import_legacy_batch(payload)` | Atomic import (admin) |
| `rollback_import_batch(id)` | Reverse an import (admin) |
| `sanad_normalize(text)`, `sanad_is_valid_phone(text)` | Shared rules, mirrored in Dart |

All views use `security_invoker`, so the caller's RLS applies.

## 2.5 Row Level Security

RLS is enabled on every table. The API roles get **no `DELETE` grant** on
any table and `anon` gets nothing at all.

| Table | Staff | Admin |
|-------|-------|-------|
| customers | read, create | + edit, archive |
| service_records | read, create (as themselves) | + edit, archive |
| areas / nurses / services | read, create | + edit, (de)activate |
| profiles | own row (name only) | all rows, roles, activation |
| import_batches / import_rows / audit_log | — | read; writes only through the import RPCs |

`is_staff()` and `is_admin()` look at `profiles.is_active`, so a deactivated
user immediately loses access even with a valid token.

## 2.6 Tests

`supabase/tests/run.sh` starts a temporary PostgreSQL, applies a Supabase stub,
the migration and the seed (twice, to check idempotency), then runs
`01_schema_test.sql`. That file covers normalisation, phone validation,
duplicate phone/area, required fields, staff/admin permissions (including
"no DELETE"), search (prefix, contains, Arabic digits, `+20`, name), frozen
history after renames and price changes, inactive-nurse protection, soft
delete + audit log, filters and totals, and import → duplicate refusal →
rollback (keeping customers used later) → re-import.
