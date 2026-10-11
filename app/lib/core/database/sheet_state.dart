/// Whether a row (record, customer, nurse, service, area) still has to be
/// written to the connected Google Sheet.
abstract final class SheetState {
  /// The sheet has the current version.
  static const synced = 0;

  /// New or changed on the phone: write it to the sheet.
  static const changed = 1;

  /// Loaded from the sheet: only link it to its existing row there.
  static const linked = 2;
}
