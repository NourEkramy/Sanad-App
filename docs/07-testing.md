# 7. Testing strategy

| Layer | Where | What | Run |
|-------|-------|------|-----|
| Domain & value objects | `app/test/core`, `app/test/features/**` | Phone normalisation/validation, money parsing, Arabic name normalisation, validators | `flutter test` |
| Use cases | `app/test/features/customers`, `…/records` | Customer creation, **duplicate phone** (incl. archived and concurrent), search (full, partial, Arabic digits, name, too-short), area de-duplication, **adding records**, required fields, **price handling** (actual price, piasters, invalid/negative), **payment method** rules, future dates, offline queue, idempotent sync, failed sync, history merge (online/offline) | `flutter test` |
| Cubits | `record_form_cubit_test`, `customer_search_test` | Default date/time, **price suggestion vs typed price**, variable price, draft save/restore, failed save keeps input; debounced search, not found | `flutter test` |
| Excel | `app/test/features/excel` | Parsers (Arabic times `9م` `11.30م` `5.30 ص` `12ص`, ambiguous `11.3`, dates incl. serials, prices `45ج`, payment labels); **header detection** on the legacy layout; **import planner** on a synthetic copy of the real sheet (skips, customers by phone, family members, needs-review, snapshots, spelling merge, payload referential integrity); **export** (sheets, headers, formats, totals, RTL, selected sheets); **round-trip** export → import; files written by other tools; unreadable files | `flutter test` |
| Widgets | `customer_search_test`, `record_form_page_test` | Name + phone shown together, *Customer not found* + add, Arabic RTL, **the full add-record flow** (nurse → service → price → payment → save), inline validation | `flutter test` |
| Routing | `app/test/app/router_redirect_test.dart` | Deep links through splash and login, permission guards, recovery flow | `flutter test` |
| Database | `supabase/tests/01_schema_test.sql` | Constraints, RLS for staff/admin (no DELETE), search, **history frozen after renames and price changes**, inactive references, soft delete + audit, filters & totals, **import → duplicate refusal → rollback → re-import**, seed idempotency | `supabase/tests/run.sh` |
| CI | `.github/workflows/ci.yml` | format check, analyze, all Flutter tests, database tests | on push / PR |

**Current result:** 106 Flutter tests and the full SQL suite pass.
`flutter analyze` reports no issues.

## End-to-end verification performed during development

Not part of CI. These need a running Supabase stack.

* Local Supabase (`supabase start`) with the migration and seed. The real
  workbook's 271 rows were imported through the app's own repository and RPC:
  271 records, revenue 60,282 EGP, 129 customers (7 needing review), every row
  in `import_rows`. That data stays local and is never committed.
* Web build driven in headless Chromium at phone size: login, dashboard,
  phone search, *not found* → create customer → inline new area → success
  screen, add record (validation, picker search in Arabic, price suggestion,
  payment), profile history, records list and filters, role-based menus,
  Excel export (downloaded and inspected), import preview → commit →
  duplicate refusal → rollback, Arabic RTL, **offline save → queued →
  automatic sync on reconnect**.

## Manual checklist before a release

1. Sign in as staff and admin. Confirm staff cannot see Import, Export or Users.
2. Primary flow on a real phone (keypad, pickers, date/time pickers).
3. Airplane mode → save a record → reconnect → it syncs and the badge clears.
4. Export → open in Excel (Windows/Mac) and Google Sheets.
5. Password reset e-mail opens the app (Android and iOS deep link).
