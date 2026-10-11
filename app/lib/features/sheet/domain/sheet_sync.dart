import 'package:equatable/equatable.dart';

import '../../../core/result/result.dart';
import '../../../core/utils/money.dart';
import '../../customers/domain/entities/customer.dart';
import '../../excel/domain/entities/sheet_table.dart';
import '../../records/domain/entities/service_record.dart';

/// The whole spreadsheet as read through the connector.
class SheetSnapshot extends Equatable {
  const SheetSnapshot({required this.title, required this.tables, required this.contentHash});

  final String title;
  final List<SheetTable> tables;

  /// Identifies this content (used as the import's file fingerprint).
  final String contentHash;

  SheetTable? table(String name) => tables.where((t) => t.name == name).firstOrNull;

  @override
  List<Object?> get props => [title, tables, contentHash];
}

class SheetPairing extends Equatable {
  const SheetPairing({required this.key, required this.title});

  final String key;
  final String title;

  @override
  List<Object?> get props => [key, title];
}

/// One write request for one sheet (see the connector script for the format).
class SheetOp extends Equatable {
  const SheetOp({
    required this.sheet,
    required this.headerRow,
    this.create = const [],
    this.ensureHeaders = const [],
    this.anchor,
    this.upserts = const [],
    this.stamps = const [],
    this.clears = const [],
    this.appends = const [],
  });

  final String sheet;
  final int headerRow;
  final List<String> create;
  final List<String> ensureHeaders;

  /// Header of the column that is filled on every used row.
  final String? anchor;
  final List<Map<String, Object?>> upserts;
  final List<Map<String, Object?>> stamps;
  final List<Map<String, Object?>> clears;
  final List<Map<String, Object?>> appends;

  bool get isEmpty => upserts.isEmpty && stamps.isEmpty && clears.isEmpty && appends.isEmpty;

  Map<String, Object?> toJson() => {
    'sheet': sheet,
    'headerRow': headerRow,
    if (create.isNotEmpty) 'create': create,
    if (ensureHeaders.isNotEmpty) 'ensureHeaders': ensureHeaders,
    'anchorCol': ?anchor,
    if (upserts.isNotEmpty) 'upserts': upserts,
    if (stamps.isNotEmpty) 'stamps': stamps,
    if (clears.isNotEmpty) 'clears': clears,
    if (appends.isNotEmpty) 'appends': appends,
  };

  @override
  List<Object?> get props => [sheet, headerRow, create, ensureHeaders, anchor, upserts, stamps, clears, appends];
}

/// What the connector did for one [SheetOp].
class SheetWriteResult extends Equatable {
  const SheetWriteResult({required this.sheet, required this.rows, this.missing = const [], this.error});

  final String sheet;

  /// Row of every written ID (null when cleared).
  final Map<String, int?> rows;

  /// Header names that no longer exist in the sheet.
  final List<String> missing;
  final String? error;

  @override
  List<Object?> get props => [sheet, rows, missing, error];
}

/// Talks to the connector script deployed in the user's spreadsheet.
abstract interface class SheetConnector {
  /// Pairs this phone; [code] is needed when another phone is paired already.
  Future<Result<SheetPairing>> pair(Uri url, {String? code});

  Future<Result<SheetSnapshot>> read(Uri url, String key);

  Future<Result<List<SheetWriteResult>>> write(Uri url, String key, List<SheetOp> ops);
}

// ---------------------------------------------------------------------------
// Local changes waiting to be written to the sheet
// ---------------------------------------------------------------------------

/// Version of a row when it was read (its `updated_at`): a row is marked
/// written only if it did not change again in the meantime.
typedef RowVersion = String;

class PendingRecord extends Equatable {
  const PendingRecord({required this.record, required this.state, required this.version, this.sheetRow});

  final ServiceRecord record;
  final int state;
  final RowVersion version;
  final int? sheetRow;

  @override
  List<Object?> get props => [record, state, version, sheetRow];
}

class PendingCustomer extends Equatable {
  const PendingCustomer({required this.customer, required this.state, required this.version});

  final Customer customer;
  final int state;
  final RowVersion version;

  @override
  List<Object?> get props => [customer, state, version];
}

enum ListKind { service, nurse, area }

class PendingListItem extends Equatable {
  const PendingListItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.state,
    required this.version,
    this.price,
  });

  final ListKind kind;
  final String id;
  final String name;
  final Money? price;
  final int state;
  final RowVersion version;

  @override
  List<Object?> get props => [kind, id, name, price, state, version];
}

class SheetChanges extends Equatable {
  const SheetChanges({
    this.records = const [],
    this.customers = const [],
    this.items = const [],
    this.removals = const [],
  });

  final List<PendingRecord> records;
  final List<PendingCustomer> customers;
  final List<PendingListItem> items;

  /// Records deleted on the phone whose sheet row must be cleared.
  final List<String> removals;

  bool get isEmpty => records.isEmpty && customers.isEmpty && items.isEmpty && removals.isEmpty;
  int get count => records.length + customers.length + items.length + removals.length;

  @override
  List<Object?> get props => [records, customers, items, removals];
}

/// What was written, to be marked as such.
class SheetReceipt extends Equatable {
  const SheetReceipt({
    this.records = const {},
    this.customers = const {},
    this.items = const [],
    this.removals = const [],
  });

  /// id → (version, sheet row).
  final Map<String, (RowVersion, int?)> records;
  final Map<String, (RowVersion, int?)> customers;
  final List<(ListKind, String, RowVersion)> items;
  final List<String> removals;

  @override
  List<Object?> get props => [records, customers, items, removals];
}

/// Customers and list entries found in the spreadsheet's other sheets.
class SheetExtras extends Equatable {
  const SheetExtras({
    this.customers = const [],
    this.services = const [],
    this.hasServicePrices = false,
    this.nurses = const [],
    this.areas = const [],
  });

  /// (name, phone, address, area name)
  final List<(String, String, String?, String?)> customers;

  /// (name, default price or null for a variable price)
  final List<(String, Money?)> services;

  /// The lists sheet has a price column (otherwise prices are unknown).
  final bool hasServicePrices;
  final List<String> nurses;
  final List<String> areas;

  @override
  List<Object?> get props => [customers, services, hasServicePrices, nurses, areas];
}

/// Local data access for the sheet link.
abstract interface class SheetStore {
  /// Emits after every local change.
  Stream<void> get changes;

  Future<Result<SheetChanges>> pending({int limit = 100});

  Future<Result<int>> pendingCount();

  Future<VoidResult> markWritten(SheetReceipt receipt);

  /// True when customers or records have been entered on this phone.
  Future<Result<bool>> hasOwnData();

  /// Deletes all local data (before loading everything from the sheet).
  Future<VoidResult> clearAll();

  /// After loading the visits sheet: links each imported record to its row
  /// ([sheetIdsByRow]: rows that already carry a Sanad ID).
  Future<VoidResult> linkImported(String batchId, Map<int, String> sheetIdsByRow);

  /// Adds customers and list entries that exist only in the other sheets;
  /// list entries already on the phone take the sheet's price and are not
  /// written back.
  Future<VoidResult> addExtras(SheetExtras extras, {required String unspecifiedArea});

  /// Everything will be written to the sheet again (new link, or adding this
  /// phone's data to a sheet).
  Future<VoidResult> markAllChanged();
}
