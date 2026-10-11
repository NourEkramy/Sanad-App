import 'package:equatable/equatable.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../excel/domain/excel_repositories.dart';
import '../../excel/domain/import/import_plan.dart';
import '../../excel/domain/import/import_planner.dart';
import 'layout_detector.dart';
import 'sheet_link.dart';
import 'sheet_ops.dart';
import 'sheet_sync.dart';

typedef Clock = DateTime Function();

/// Checks a pasted link: a script Web app URL ending in `/exec` (a local
/// development server is accepted too).
Result<Uri> parseSheetLink(String text) {
  final uri = Uri.tryParse(text.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return const Result.failure(SheetFailure(SheetFailureReason.invalidLink));
  }
  if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
    return Result.success(Uri(scheme: uri.scheme, host: uri.host, port: uri.port, path: uri.path));
  }
  if (uri.scheme != 'https' || uri.host != 'script.google.com' || !uri.path.contains('/macros/')) {
    return const Result.failure(SheetFailure(SheetFailureReason.invalidLink));
  }
  if (uri.path.endsWith('/dev')) return const Result.failure(SheetFailure(SheetFailureReason.invalidLink, '/dev'));
  return Result.success(Uri(scheme: 'https', host: uri.host, path: uri.path));
}

/// A spreadsheet being connected: what it contains and what this phone has.
class SheetConnection extends Equatable {
  const SheetConnection({
    required this.url,
    required this.pairing,
    required this.snapshot,
    required this.detected,
    required this.phoneHasData,
    this.plan,
  });

  final Uri url;
  final SheetPairing pairing;
  final SheetSnapshot snapshot;
  final DetectedSheet detected;

  /// The visits found in the sheet, ready to load (null when there are none).
  final ImportPlan? plan;
  final bool phoneHasData;

  bool get sheetHasData => (plan?.records.isNotEmpty ?? false) || detected.extras.customers.isNotEmpty;

  /// Customers in the visits and customers sheets, each counted once.
  int get customerCount => {
    for (final c in plan?.customers ?? const <PlannedCustomer>[]) c.phone ?? c.key,
    for (final (_, phone, _, _) in detected.extras.customers) phone,
  }.length;

  @override
  List<Object?> get props => [url, pairing, snapshot, detected, plan, phoneHasData];
}

/// Pairs with the spreadsheet's connector and reads it.
class ConnectSheet {
  const ConnectSheet(this._connector, this._store, this._imports, [this._detector = const SheetLayoutDetector()]);

  final SheetConnector _connector;
  final SheetStore _store;
  final ImportRepository _imports;
  final SheetLayoutDetector _detector;

  Future<Result<SheetConnection>> call(String link, {String? code, required String unspecifiedLabel}) async {
    final url = parseSheetLink(link);
    if (url case Err(:final failure)) return Result.failure(failure);
    return connect(url.valueOrNull!, code: code, unspecifiedLabel: unspecifiedLabel);
  }

  Future<Result<SheetConnection>> connect(Uri url, {String? code, required String unspecifiedLabel}) async {
    final pairing = await _connector.pair(url, code: code);
    if (pairing case Err(:final failure)) return Result.failure(failure);
    final key = pairing.valueOrNull!;
    final snapshot = await _connector.read(url, key.key);
    if (snapshot case Err(:final failure)) return Result.failure(failure);
    final detected = _detector.detect(snapshot.valueOrNull!);

    ImportPlan? plan;
    final table = detected.visitsTable;
    final mapping = detected.visitsMapping;
    if (table != null && mapping != null && mapping.isUsable && detected.visitRows > 0) {
      final existing = await _imports.existingData();
      if (existing case Err(:final failure)) return Result.failure(failure);
      plan = ImportPlanner(unspecifiedLabel: unspecifiedLabel).plan(table, mapping, existing: existing.valueOrNull!);
    }
    final hasData = await _store.hasOwnData();
    if (hasData case Err(:final failure)) return Result.failure(failure);
    return Result.success(
      SheetConnection(
        url: url,
        pairing: key,
        snapshot: snapshot.valueOrNull!,
        detected: detected,
        plan: plan,
        phoneHasData: hasData.valueOrNull!,
      ),
    );
  }
}

/// Finishes connecting: either loads the sheet's data into the phone, or
/// keeps the phone's data and writes it into the sheet.
class LinkSheet {
  LinkSheet(this._store, this._imports, this._links, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final SheetStore _store;
  final ImportRepository _imports;
  final SheetLinkStore _links;
  final Clock _clock;

  /// Loads everything from the sheet. With [replace], the phone's current
  /// data is deleted first.
  Future<Result<SheetLink>> load(
    SheetConnection connection, {
    required bool replace,
    required String unspecifiedLabel,
  }) async {
    if (replace) {
      final cleared = await _store.clearAll();
      if (cleared case Err(:final failure)) return Result.failure(failure);
    }
    final plan = connection.plan;
    if (plan != null && plan.records.isNotEmpty) {
      final committed = await _imports.commit(
        plan,
        fileName: connection.pairing.title,
        fileSha256: '$sheetImportPrefix${connection.snapshot.contentHash}',
      );
      if (committed case Err(:final failure)) return Result.failure(failure);
      final linked = await _store.linkImported(committed.valueOrNull!.batchId, {
        for (final r in plan.records) r.rowNumber: ?r.sheetId,
      });
      if (linked case Err(:final failure)) return Result.failure(failure);
    }
    final extras = await _store.addExtras(connection.detected.extras, unspecifiedArea: unspecifiedLabel);
    if (extras case Err(:final failure)) return Result.failure(failure);
    return _save(connection);
  }

  /// Keeps the phone's data and writes all of it into the sheet.
  Future<Result<SheetLink>> keepPhoneData(SheetConnection connection) async {
    final marked = await _store.markAllChanged();
    if (marked case Err(:final failure)) return Result.failure(failure);
    return _save(connection);
  }

  Future<Result<SheetLink>> _save(SheetConnection connection) async {
    final link = SheetLink(
      url: connection.url,
      key: connection.pairing.key,
      title: connection.pairing.title,
      layout: connection.detected.layout,
      connectedAt: _clock(),
    );
    await _links.write(link);
    return Result.success(link);
  }
}

/// Writes every local change to the connected sheet.
class SyncSheet {
  SyncSheet(
    this._connector,
    this._store,
    this._links, {
    Clock? clock,
    SheetOpsBuilder builder = const SheetOpsBuilder(),
    SheetLayoutDetector detector = const SheetLayoutDetector(),
  }) : _clock = clock ?? DateTime.now,
       _builder = builder,
       _detector = detector;

  final SheetConnector _connector;
  final SheetStore _store;
  final SheetLinkStore _links;
  final Clock _clock;
  final SheetOpsBuilder _builder;
  final SheetLayoutDetector _detector;

  /// Number of rows written (0 when nothing was waiting or no sheet is linked).
  Future<Result<int>> call({int batchSize = 100}) async {
    var link = await _links.read();
    if (link == null) return const Result.success(0);
    var written = 0;
    var relaid = false;
    for (var round = 0; round < 50; round++) {
      final pending = await _store.pending(limit: batchSize);
      if (pending case Err(:final failure)) return Result.failure(failure);
      final changes = pending.valueOrNull!;
      if (changes.isEmpty) break;

      final batch = _builder.build(link!.layout, changes);
      var results = const <SheetWriteResult>[];
      if (batch.ops.isNotEmpty) {
        final result = await _connector.write(link.url, link.key, batch.ops);
        if (result case Err(:final failure)) return Result.failure(failure);
        results = result.valueOrNull!;
        // Columns were renamed or removed in the sheet: find them again once.
        if (!relaid && results.any((r) => r.missing.isNotEmpty)) {
          relaid = true;
          final snapshot = await _connector.read(link.url, link.key);
          if (snapshot case Err(:final failure)) return Result.failure(failure);
          link = link.copyWith(layout: _detector.detect(snapshot.valueOrNull!).layout);
          await _links.write(link);
          continue;
        }
      }
      final marked = await _store.markWritten(batch.receipt(results));
      if (marked case Err(:final failure)) return Result.failure(failure);
      written += changes.count;
    }
    await _links.write(link!.copyWith(lastSyncAt: _clock()));
    return Result.success(written);
  }
}
