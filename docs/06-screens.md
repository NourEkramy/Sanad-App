# 6. Screen specifications

Route → implementation. Every screen supports English and Arabic (RTL). Screenshots: [`docs/screenshots`](screenshots).

| # | Screen | Route | Purpose · content · actions |
|---|--------|-------|-----------------------------|
| 1 | **Dashboard** | `/home` | Greeting and date; Google Drive status icon (up to date / waiting / failed); **search bar** (one tap to phone search); banners (*Back up to Google Drive* when not connected, backup failed, *N customers need review*); quick actions (**Add service record** highlighted, Search customer, Add customer, Export); today: services, revenue, cash, electronic; overview: customers, records, this month, active nurses · services. Pull to refresh. |
| 2 | **Customers** | `/customers` | Search entry, *Needs review* filter, paginated customer list (name, phone, area, visits, badges), FAB *Add customer*. |
| 3 | **Search customer** | `/search` (`?for=record`) | Auto-focused phone keypad (toggle to name keyboard). Results as you type with highlighted digits; count; *Customer not found* + **Add new customer** (phone pre-filled). In "for record" mode, tapping a result opens *Add record*. |
| 4 | **Add / edit customer** | `/customers/new`, `/customers/:id/edit` | Name, phone (✓ when valid), living area (searchable, **+ Add new area**), address, notes. Duplicate phone → existing-customer sheet. Errors clear as fields are fixed. |
| 4a | Customer saved | `/customers/:id/saved` | Success state: **Add service record**, View customer, Back to home. |
| 5 | **Customer profile** | `/customers/:id` | Contact card (copy phone), area, address, notes; stats (visits, total paid, last visit); *needs review* / archived banners; **service history** grouped by month; FAB **Add new record**; edit, archive/restore. |
| 6 | **Add / edit service record** | `/customers/:id/records/new`, `/records/:id/edit` | Customer confirmation card; nurse, service (default price shown); price (EGP); payment **Cash / Electronic**; date (today) & time (now); optional patient name and notes. Restored-draft banner. |
| 7 | **Record details** | `/records/:id` | Service, price, payment, imported badge; customer (open profile), patient, nurse, date/time, area & address at visit, notes, created, Excel row. Edit, archive. |
| 8 | **All records** | `/records` | Search (name/phone), filter button with active-count badge, sort menu, totals bar (count · revenue), infinite list (customer name **and** phone on every card), FAB add. |
| 9 | **Record filters** | sheet | Date presets + custom range, nurse, service, area, payment method, *Clear all*, *Show results*. |
| 10 | **Nurses** | `/more/nurses` | List (phone, active state), show inactive, FAB add. |
| 11 | Add / edit nurse | sheet | Name, phone, notes, active switch (deactivation confirmed). |
| 12 | **Services** | `/more/services` | List with default price or "Variable price". |
| 13 | Add / edit service | sheet | Name, default price (optional; helper explains history is unaffected), active switch. |
| 14 | **Areas** | `/more/areas` | List, show inactive, add. |
| 15 | Add / edit area | sheet | Name (normalised duplicate check), active switch. |
| 16 | **Excel import** | `/more/import` | Stepper: File → Columns (sheet picker, header row, field ↔ column mapping) → Preview (stats, warnings/errors with row numbers, new names) → confirm → result. Import history with **Roll back**. |
| 17 | **Excel export** | `/more/export` | Period chips, sheet checkboxes, *Create Excel file* → share/download, result card. |
| 18 | **Google Drive backup** | `/more/backup` | Not connected: explanation + **Connect Google Drive**. Connected: state (up to date / changes waiting / failed + reason), Google account, last backup, **Back up now**, **Restore from Google Drive**, **Disconnect**. Found-backup card after connecting (Restore / Keep this phone's data). Web: notice + Export. |
| 19 | **Settings** | `/more/settings` | Language (system / English / العربية), about, privacy note. |
| 20 | More | `/more` | Manage (nurses, services, areas), Data (Google Drive backup with a warning badge on failure, export, import), App (settings). |

## Navigation

```
Bottom navigation:  Home | Customers | Records | More
Full-screen flows (above the tab bar): Search · Add customer · Add/Edit record · Record details
```

Tapping the active tab returns to its first screen. Web refreshes keep the
requested screen. After a restore from Google Drive the app returns to Home.
