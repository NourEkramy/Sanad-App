import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/dates.dart';
import 'entities/sheet_table.dart';
import 'excel_repositories.dart';
import 'export/export_models.dart';
import 'import/column_mapping.dart';
import 'import/import_plan.dart';
import 'import/import_planner.dart';

/// A workbook opened for import: its sheets and, for each, the detected
/// column mapping (null when no header row could be recognised).
class OpenedWorkbook {
  const OpenedWorkbook({required this.fileName, required this.sha256, required this.sheets, required this.mappings});

  final String fileName;
  final String sha256;
  final List<SheetTable> sheets;
  final Map<String, ColumnMapping?> mappings;

  /// The sheet that looks most like a visits/records log.
  SheetTable? get bestSheet {
    SheetTable? best;
    var score = -1;
    for (final sheet in sheets) {
      final m = mappings[sheet.name];
      if (m == null) continue;
      final s = m.columns.length * 1000 + sheet.rows.length;
      if (s > score) {
        best = sheet;
        score = s;
      }
    }
    return best;
  }
}

class OpenWorkbook {
  const OpenWorkbook(this._codec, [this._detector = const ColumnDetector()]);
  final WorkbookCodec _codec;
  final ColumnDetector _detector;

  Result<OpenedWorkbook> call({required String fileName, required Uint8List bytes}) {
    if (bytes.isEmpty) return const Result.failure(FileFailure(FileFailureReason.empty));
    return _codec.decode(bytes).fold(Result.failure, (sheets) {
      if (sheets.isEmpty) return const Result.failure(FileFailure(FileFailureReason.noSheets));
      final mappings = {for (final s in sheets) s.name: _detector.detect(s)};
      if (mappings.values.every((m) => m == null)) {
        return const Result.failure(FileFailure(FileFailureReason.headerNotFound));
      }
      return Result.success(
        OpenedWorkbook(
          fileName: fileName,
          sha256: sha256.convert(bytes).toString(),
          sheets: sheets,
          mappings: mappings,
        ),
      );
    });
  }
}

class PrepareImport {
  const PrepareImport(this._repository);
  final ImportRepository _repository;

  Future<Result<ImportPlan>> call(SheetTable sheet, ColumnMapping mapping, {required String unspecifiedLabel}) async {
    if (!mapping.isUsable) {
      return Result.failure(ValidationFailure({for (final f in mapping.missingRequired) f.name: 'required'}));
    }
    final existing = await _repository.existingData();
    return existing.map(
      (data) => ImportPlanner(unspecifiedLabel: unspecifiedLabel).plan(sheet, mapping, existing: data),
    );
  }
}

class CommitImport {
  const CommitImport(this._repository);
  final ImportRepository _repository;

  Future<Result<ImportResult>> call(ImportPlan plan, OpenedWorkbook workbook) {
    if (plan.records.isEmpty) return Future.value(const Result.failure(FileFailure(FileFailureReason.empty)));
    return _repository.commit(plan, fileName: workbook.fileName, fileSha256: workbook.sha256);
  }
}

class ListImportBatches {
  const ListImportBatches(this._repository);
  final ImportRepository _repository;

  Future<Result<List<ImportBatch>>> call() => _repository.batches();
}

class RollbackImport {
  const RollbackImport(this._repository);
  final ImportRepository _repository;

  Future<VoidResult> call(String batchId) => _repository.rollback(batchId);
}

class ExportWorkbook {
  ExportWorkbook(this._repository, this._codec, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final ExportRepository _repository;
  final WorkbookCodec _codec;
  final DateTime Function() _clock;

  Future<Result<ExportFile>> call(ExportRequest request, ExportLabels labels) async {
    if (request.sheets.isEmpty) {
      return const Result.failure(ValidationFailure({'sheets': 'required'}));
    }
    if (request.from != null && request.to != null && request.to!.isBefore(request.from!)) {
      return const Result.failure(ValidationFailure({'range': 'invalid'}));
    }
    final data = await _repository.load(request);
    switch (data) {
      case Err(:final failure):
        return Result.failure(failure);
      case Success(value: final exportData):
        return _codec
            .encodeExport(exportData, labels, request.sheets)
            .map(
              (bytes) => ExportFile(
                fileName: 'sanad-export-${Dates.toJson(_clock())}.xlsx',
                bytes: bytes,
                recordCount: exportData.records.length,
              ),
            );
    }
  }
}
