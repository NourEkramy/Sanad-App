# 9. Security & privacy

Sanad stores health-related customer data (names, phone numbers, addresses,
services received). It is treated as sensitive.

| Area | Measure |
|------|---------|
| **Where data lives** | Only on the phone (app-private SQLite database) and, if the user connects one, in **their own** Google Sheet. There is no Sanad server and nothing is published. |
| **Google access** | The app never signs in to Google and never sees a Google password. The Sanad script runs inside the owner's spreadsheet as the owner (*Execute as: Me*) and is limited to that one spreadsheet (`@OnlyCurrentDoc`). |
| **Who can write to the sheet** | The Web app link is unguessable, and every read and write also needs the **pairing key**: the first phone receives it when it connects; any other phone needs the connection code from the sheet's **سند** menu. **سند → رمز ربط جديد** replaces the key and locks out every phone until it connects again. Treat the link and the code like a password. |
| **Sharing** | The spreadsheet is private until the owner shares it from Google Sheets. Exported workbooks are shared only through the phone's share sheet, by the user. |
| **Data integrity** | Constraints in the database (unique phone and names, valid references, price ≥ 0, required fields, legacy-only values) and transactions for every write and import. A row is marked as written to the sheet only if it did not change again meanwhile, so no change is lost. Requests from several phones are serialised by a script lock. |
| **The workbook** | Sanad writes only to its visits, customers and lists sheets, only in the columns it knows by header, and adds its own columns after the last used column, never over existing cells. Other sheets and formulas are never touched. |
| **History** | Records keep a snapshot of price, nurse, service, area and address. Archiving instead of deleting customers and records; imports are reversible. Google Sheets keeps the spreadsheet's version history (*File → Version history*). |
| **Data at rest on the device** | The database is in the app's private storage (not readable by other apps). Form drafts, preferences and the sheet link with its key use the platform keystore (`flutter_secure_storage`). Android `allowBackup=false` keeps data out of Android's own device backups. |
| **Losing the phone** | Use a screen lock on the phone. In the sheet, **سند → رمز ربط جديد**; on the new phone connect with the new code and load the sheet's data. |
| **Logging** | Errors are reduced to a type and a stable code. Messages that can contain customer data are never logged. |
| **Validation** | On the client (for feedback) **and** in the database (for enforcement). Search input is always passed as a query parameter, never concatenated into SQL; LIKE wildcards are escaped. Text written to the sheet that looks like a formula is written as plain text. |
| **Imports** | One transaction, duplicate-file protection, every source row kept for audit, reversible. |
| **Repository hygiene** | The real workbook and its data are not committed. Test fixtures are synthetic. No keys or secrets are in the source; the signing key and `key.properties` stay outside the repository. |

## Recommended practices

* Turn on 2-step verification for the Google account that holds the sheet.
* Share the spreadsheet with specific people rather than "anyone with the
  link", and never share the Web app link or the connection code.
* Keep exported workbooks in access-controlled places. They contain customer
  data.
