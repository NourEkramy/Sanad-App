# 9. Security & privacy

Sanad stores health-related customer data (names, phone numbers, addresses,
services received). It is treated as sensitive.

| Area | Measure |
|------|---------|
| **Where data lives** | Only on the phone (app-private SQLite database) and, if the user connects it, in **their own** Google Drive. There is no Sanad server and nothing is published. |
| **Google access** | Only the `drive.file` scope: Sanad can read and write the files it created, nothing else in the user's Drive. No Google password ever reaches the app (Google's own sign-in screen is used). Disconnecting revokes the permission. |
| **Sharing** | The Drive files are private until the owner shares them from Drive. Exported workbooks are shared only through the phone's share sheet, by the user. |
| **Data integrity** | Constraints in the database (unique phone and names, valid references, price ≥ 0, required fields, legacy-only values) and transactions for every write, import and restore. |
| **History** | Records keep a snapshot of price, nurse, service, area and address. Archiving instead of deleting customers and records; imports are reversible. |
| **Data at rest on the device** | The database is in the app's private storage (not readable by other apps). Form drafts and preferences use the platform keystore (`flutter_secure_storage`). Android `allowBackup=false` keeps data out of Android's own device backups; the Google Drive backup is the one the user controls. |
| **Losing the phone** | Use a screen lock on the phone. Restore on a new phone from Google Drive; then disconnect the old phone from Google Account › Security › Third-party access if needed. |
| **Logging** | Errors are reduced to a type and a stable code. Messages that can contain customer data are never logged or shown. |
| **Validation** | On the client (for feedback) **and** in the database (for enforcement). Search input is always passed as a query parameter, never concatenated into SQL; LIKE wildcards are escaped. |
| **Imports** | One transaction, duplicate-file protection, every source row kept for audit, reversible. |
| **Repository hygiene** | The real workbook and its data are not committed. Test fixtures are synthetic. No keys or client secrets are in the source (the Android OAuth client is identified by package name + signing certificate, configured in Google Cloud). |

## Recommended practices

* Turn on 2-step verification for the Google account that holds the backup.
* Share `Sanad.xlsx` with specific people rather than "anyone with the link".
* Keep exported workbooks in access-controlled places. They contain customer
  data.
