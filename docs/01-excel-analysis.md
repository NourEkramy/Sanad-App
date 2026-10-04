# 1. Analysis of the existing Excel workbook

**Source:** `sanad_v9.2 (3).xlsx` (SharePoint, shared as *view-only, download disabled*).
The workbook was inspected through the Excel Online viewer: every cell of
every sheet was read from the viewer's grid data and analysed. The numbers
below are from that analysis. No customer data from the workbook is stored in
this repository; examples are masked.

## 1.1 Sheets

| # | Sheet | Purpose | Used rows | Role for Sanad |
|---|-------|---------|-----------|----------------|
| 1 | **داشبورد** (Dashboard) | Formulas: revenue, expenses, profit, per-nurse and per-area statistics | ~60 | Replaced by the app dashboard. Not imported. |
| 2 | **الملخص المالي الشهري** (Monthly financial summary) | Formulas per month: visits, revenue, expenses, profit | 17 | Derived data. Not imported. |
| 3 | **بيانات الحالات** (Cases / customers) | Customer master list: name, phone, address, area | 130 rows (102 customers) | Cross-checked. Customers are rebuilt from the visits log (see 1.4). |
| 4 | **سجل الزيارات** (Visits log) | **One row per visit/service.** The operational data. | 271 records (row 4–274; rows up to 564 hold only the running number) | **Main import source → customers + service records.** |
| 5 | Sheet1 | Scratch table counting which nurse did each visit for two patients | 4 | Not imported. |
| 6 | **المصروفات التفصيلية** (Detailed expenses) | Company expenses: date, item, category, amount, payment method | ~100 | Out of scope for v1 (no expense module requested). Kept in Excel. |
| 7 | **اسعار الخدمات** (Service prices) | Printable price list grouped by category | 41 | Same data as the lists sheet. |
| 8 | **قوائم** (Lists) | Drop-down sources: services + price, nurses, areas | 53 services, 15 nurses, 9 areas | **Seeds services and areas** (`supabase/seed.sql`). |

## 1.2 Columns of the visits log (`سجل الزيارات`)

Rows 1–2 are a title and an instruction line. Row 3 holds the headers.
The first data row is row 4.

| Col | Header (Arabic) | Meaning | Type / format found | Maps to |
|-----|-----------------|---------|---------------------|---------|
| A | م | Running number | Integer 1…561 (pre-filled even on empty rows) | `service_records.legacy_ref` |
| B | تاريخ الزيارة | Visit date | ISO date, all 271 valid (2026‑05‑09 → 2026‑09‑25) | `service_date` |
| C | اليوم | Weekday | Derived from B (always consistent) | ignored |
| D | وقت الزيارة | Visit time | **Free text**: `9م`, `11.30م`, `5.30 ص`, `12ص`, `**` … | `service_time` (parsed) |
| E | اسم المريض / الحالة | Patient / case name | Free text | `customers.full_name` / `patient_name` |
| F | رقم التليفون | Phone | 11-digit mobile in 264 rows; `0`, `**`, `***`, `****`, `*****` in 7 | `customers.phone` |
| G | العنوان التفصيلي | Detailed address | Free text, sometimes `**` / `...` | `customers.address` + `address_snapshot` |
| H | المنطقة | Area | 8 distinct values, all from the lists sheet | `areas` |
| I | اسم الممرض / الفني | Nurse / technician | 21 distinct spellings | `nurses` |
| J | الخدمة المُقدَّمة | Service provided | 42 distinct values | `services` |
| K | ثمن الزيارة (ج.م) | Price (EGP) | Currency-formatted number. One cell is the text `45ج` | `price` |
| L | حالة الاستلام | Receipt status | Always `تم الاستلام` ("received") | audit copy only |
| M | ملاحظات | Notes | Free text in 60 rows | `notes` |
| N | الشهر (تلقائي) | Month | Derived from B | ignored |
| S | كود الحالة | Case code (e.g. `AMH-01`) | Header only, never filled | ignored |

**There is no payment-method column** in the visits log. The expenses sheet
records `نقدي` (cash) / `محفظة إلكترونية` (e-wallet) for *expenses* only.

## 1.3 The data

* **271 visit records**, May–September 2026 (May 1 · June 23 · July 79 · August 111 · September 57).
* **Total revenue 60,282 EGP.** The workbook's own dashboard shows 60,237 EGP
  because its `SUM` skips the one price typed as text (`45ج`). The import
  recovers it and flags it.
* **122 distinct valid phone numbers.** With the rows lacking a phone, this gives
  **129 customers**: 122 identified by phone and 7 flagged *needs review*.
* **8 areas** used (الهانوفيل 122 visits, أكتوبر 43, البيطاش 33, أبو يوسف 28,
  الحديد والصلب 27, الكيلو 21 8, بيانكى 8, بوابة 8 2). الدخيلة exists in the
  lists sheet but has no visits.
* **Prices** range from 0 to 4,750 EGP; most fall between 50 and 400.

## 1.4 Relationships inferred

```
Customer (identified by phone) 1 ──── * Visit ──── 1 Nurse
                                          └──────── 1 Service
Customer * ──── 1 Area
```

* The visits log **repeats** the customer's name, phone, address and area on
  every row. The cases sheet is a partial master list (it is missing 36 names
  that appear in the visits log). The visits log is therefore the source of
  truth for customers.
* Service and nurse names in the visits log come from the lists sheet's
  drop-downs, with spelling drift (see below).
* The price on each visit is **the amount actually charged**. It often differs
  from the list price because of discounts, extra medication and so on, and the
  notes often explain why. This confirms the requirement that a record stores
  its own price.

## 1.5 Duplicates, ambiguities and problems

| # | Finding | Rows | Example (masked) | Migration decision |
|---|---------|------|------------------|--------------------|
| 1 | **Same phone, different names**: family members, or "case" placeholders | 7 phones | `0112•••2962` → two different patients at the same address | One customer per phone (most frequent name). Every record whose name differs keeps it as **`patient_name`**, so no information is lost. |
| 2 | **Spelling variants of the same name** | e.g. `أسماء منصور` / `اسماء منصور`; `اشرقة محمد إبراهيم` / `…ابراهيم` | — | Arabic-aware normalisation (alef/yaa/taa-marbuta, whitespace, diacritics) merges them. |
| 3 | **Missing / placeholder phone** (`0`, `**` … `*****`) | 7 rows | "حالة تبع المركز" | Imported. The customer is created **without a phone, flagged `needs_review`**, grouped by name. The dashboard asks an admin to fix them. |
| 4 | **Customer moved / different area across visits** | 11 rows | phone used in الهانوفيل and الكيلو 21 | Customer gets the **latest** address/area. Every record keeps **its own** address and area as a historical snapshot. |
| 5 | **Time written as free text** | all | `11.30م`, `5.30 ص`, `12ص` | Parser for Arabic ص/م (AM/PM), `.`/`:` separators, Arabic digits. |
| 6 | **Time without AM/PM** | 2 rows | `11.3`, `8.3` | **Not guessed.** Imported without a time and flagged. An admin can correct it. |
| 7 | **No time** (`**`) | 3 rows | — | Imported without a time and flagged. |
| 8 | **Price typed as text** | 1 row | `45ج` | Number extracted (45 EGP) and flagged. |
| 9 | **Zero price** | 1 row | first visit of a package | Kept (0 is valid), not treated as an error. |
| 10 | **No payment method anywhere** | 271 rows | — | Imported as **`unspecified`** ("Not recorded"). This value is only allowed on imported rows. New records must be cash or electronic (database constraint). |
| 11 | **Non-person "nurses"**: `باكدج` (package, 24 visits), `تمريض الشركة` (company nursing, 5), `الشركة` (company, 1) | 30 rows | — | Kept **as written**, as nurse entries, so totals per "nurse" still match the old dashboard. An admin can rename or deactivate them later without touching history. |
| 12 | **Nurses not in the lists sheet**: `سلمى`, `أسماء`, `اسماء منصور`, `تمريض الشركة` | — | — | Created during import. |
| 13 | **Services not in the lists sheet** | — | — | Created with *variable price*. |
| 14 | **"Services" that are not services** in the lists sheet: `اللى جايب الحالة` ("the person who brought the case", a referral fee, 200 EGP) and `0` placeholder rows | — | — | Left out of the seed list. If they appear in the visits log they are still imported as written. |
| 15 | **List prices marked `**`** (variable: pharmacy, lab tests, doctor visits, ambulance…) | 9 services | — | `default_price = NULL` ("variable price"). |
| 16 | **Receipt status** always "received" | 271 | — | Not modelled as a field. Kept in the per-row audit copy. |
| 17 | **Notes containing financial splits** (e.g. what the company kept) | ~10 | — | Kept verbatim in `notes`. |
| 18 | **Template rows** pre-numbered up to 561 | 290 | — | Ignored (no date, name, phone, price or service). |

## 1.6 How the workbook maps to the new database

| Workbook | Database |
|----------|----------|
| visits log row | `service_records` (one per row) + `import_rows` (audit copy of the raw row) |
| name + phone (+ address, area) | `customers` (deduplicated by phone) |
| area (H) | `areas` (unique by normalised name) |
| nurse (I) | `nurses` (unique by normalised name) |
| service (J) | `services` (unique by normalised name) |
| price (K) | `service_records.price` (actual price, numeric) |
| — | `service_records.payment_method = 'unspecified'` |
| running number (A) | `service_records.legacy_ref` |
| lists sheet | `supabase/seed.sql` (areas + services with default prices) |
| dashboard / monthly summary | replaced by `dashboard_stats()` and the Records totals |
| expenses sheet | not migrated (outside the requested scope) |

## 1.7 Migration strategy (safe and reversible)

1. **Preview first.** The import screen parses the file *on the device*, maps
   columns automatically (Arabic or English headers) and shows exactly what
   will happen: records, new/matched customers, new areas/nurses/services,
   revenue, date range, and every warning/error with its row numbers. Nothing
   is written yet.
2. **One transaction.** On confirmation, the plan is sent to the
   `import_legacy_batch` database function, which runs as a single
   transaction. Either everything is imported or nothing is.
3. **Never overwrite.** Existing customers (same phone) and existing
   areas/nurses/services (same normalised name) are matched, never modified.
4. **Full audit.** Every source row, imported or skipped, is stored in
   `import_rows` with its original text and messages.
5. **Reversible.** `rollback_import_batch` removes everything the batch
   created. Customers or names that staff have used since are kept. The same file
   (by SHA-256) cannot be imported twice while a committed import of it exists.
6. **Re-import of a corrected file:** roll back the previous batch, fix the
   file, import again. The preview warns when an import already exists.

Dry-run result on the real workbook: **271 / 271 rows importable, 0
skipped.** 129 customers (7 flagged for review), 8 areas, 20 nurses,
42 services, revenue 60,282 EGP. Warnings: 11 customer-details-changed,
7 invalid phones, 7 shared phones, 3 missing times, 2 ambiguous times, 1 price
written as text.
