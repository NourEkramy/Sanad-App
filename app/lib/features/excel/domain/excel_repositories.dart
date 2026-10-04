import 'dart:typed_data';

import '../../../core/result/result.dart';
import 'entities/sheet_table.dart';
import 'export/export_models.dart';
import 'import/import_plan.dart';

/// Reads and writes .xlsx files (implemented with the `excel` package).
abstract interface class WorkbookCodec {
  /// Fails with `FileFailure` when the bytes are not a readable workbook.
  Result<List<SheetTable>> decode(Uint8List bytes);

  Result<Uint8List> encodeExport(ExportData data, ExportLabels labels, Set<ExportSheet> sheets);
}

abstract interface class ImportRepository {
  Future<Result<ExistingData>> existingData();

  /// Commits the plan in a single database transaction.
  Future<Result<ImportResult>> commit(ImportPlan plan, {required String fileName, required String fileSha256});

  Future<Result<List<ImportBatch>>> batches();

  /// Removes everything the batch created (records added later are kept).
  Future<VoidResult> rollback(String batchId);
}

abstract interface class ExportRepository {
  Future<Result<ExportData>> load(ExportRequest request);
}
