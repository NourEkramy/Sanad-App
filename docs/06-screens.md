# 6. Screen specifications

Route → implementation. *Admin* = needs an admin permission. Every screen
supports English and Arabic (RTL). Screenshots: [`docs/screenshots`](screenshots).

| # | Screen | Route | Purpose · content · actions |
|---|--------|-------|-----------------------------|
| 1 | **Splash** | `/splash` | Brand gradient, logo, tagline, spinner while the stored session is restored. Remembers the requested deep link. |
| 2 | **Login** | `/login` | Email, password (show/hide), *Forgot password?*, *Sign in*. Banners for expired session and auth errors (invalid credentials, deactivated account, rate limit). |
| 2a | Forgot password | `/forgot-password` | Email → reset link. Neutral confirmation (does not reveal whether an account exists). |
| 2b | Choose new password | `/reset-password` | Opened from the e-mail link. New password + confirmation (min 8). |
| 3 | **Dashboard** | `/home` | Greeting and date; **search bar** (one tap to phone search); banners (waiting to sync / offline / *N customers need review*); quick actions (**Add service record** highlighted, Search customer, Add customer, Export or Records); today: services, revenue, cash, electronic; overview: customers, records, this month, active nurses · services. Pull to refresh. |
| 4 | **Customers** | `/customers` | Search entry, *Needs review* filter (admin), paginated customer list (name, phone, area, visits, badges), FAB *Add customer*. |
| 5 | **Search customer** | `/search` (`?for=record`) | Auto-focused phone keypad (toggle to name keyboard). Results as you type with highlighted digits; count; *Customer not found* + **Add new customer** (phone pre-filled). In "for record" mode, tapping a result opens *Add record*. |
| 6 | **Add / edit customer** | `/customers/new`, `/customers/:id/edit` (admin) | Name, phone (✓ when valid), living area (searchable, **+ Add new area**), address, notes. Duplicate phone → existing-customer sheet. Errors clear as fields are fixed. |
| 6a | Customer saved | `/customers/:id/saved` | Success state: **Add service record**, View customer, Back to home. |
| 7 | **Customer profile** | `/customers/:id` | Contact card (copy phone), area, address, notes; stats (visits, total paid, last visit); *needs review* / archived banners; **service history** grouped by month (pending/failed sync shown); FAB **Add new record**; admin: edit, archive/restore. |
| 8 | **Add / edit service record** | `/customers/:id/records/new`, `/records/:id/edit` (admin) | Customer confirmation card; nurse, service (default price shown); price (EGP); payment **Cash / Electronic**; date (today) & time (now); optional patient name and notes. Restored-draft banner; offline save. |
| 9 | **Record details** | `/records/:id` | Service, price, payment, sync/imported badges; customer (open profile), patient, nurse, date/time, area & address at visit, notes, created, Excel row. Admin: edit, archive. Pending: discard. |
| 10 | **All records** | `/records` | Search (name/phone), filter button with active-count badge, sort menu, totals bar (count · revenue), infinite list (customer name **and** phone on every card), FAB add. |
| 11 | **Record filters** | sheet | Date presets + custom range, nurse, service, area, payment method, *Clear all*, *Show results*. |
| 12 | **Nurses** | `/more/nurses` | List (phone, active state), show inactive, FAB add (staff+). |
| 13 | Add / edit nurse | sheet | Name, phone, notes, active switch (admin; deactivation confirmed). |
| 14 | **Services** | `/more/services` | List with default price or "Variable price". |
| 15 | Add / edit service | sheet | Name, default price (optional; helper explains history is unaffected), active switch. |
| 16 | **Areas** | `/more/areas` | List, show inactive, add. |
| 17 | Add / edit area | sheet | Name (normalised duplicate check), active switch. |
| 18 | **Excel import** (admin) | `/more/import` | Stepper: File → Columns (sheet picker, header row, field ↔ column mapping) → Preview (stats, warnings/errors with row numbers, new names) → confirm → result. Import history with **Roll back**. |
| 19 | **Excel export** (admin) | `/more/export` | Period chips, sheet checkboxes, *Create Excel file* → share/download, result card. |
| 20 | **Settings** | `/more/settings` | Language (system / English / العربية), about, privacy note. |
| 21 | **User profile** | `/more/profile` | Avatar, editable name, email, role, *Change password*, *Sign out*. |
| 22 | Users (admin) | `/more/users` | Users with role/status, invite sheet, promote/demote, (de)activate. |
| 23 | Waiting to sync | `/more/pending` | Records saved offline, *Sync now*, open/discard, failure reasons. |
| 24 | More | `/more` | Account card, Manage (nurses, services, areas, users), Data (export, import, waiting to sync with badge), Account (settings, sign out). Admin-only items hidden for staff. |

## Navigation

```
Bottom navigation:  Home | Customers | Records | More
Full-screen flows (above the tab bar): Search · Add customer · Add/Edit record · Record details
```

Tapping the active tab returns to its first screen. Deep links and web
refreshes keep the requested screen (also through login).
