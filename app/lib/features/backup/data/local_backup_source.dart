import 'dart:convert';
import 'dart:typed_data';

import '../../../core/database/sanad_database.dart';
import '../../../core/errors/error_mapper.dart';
import '../../../core/errors/failure.dart';
import '../../../core/result/result.dart';
import '../../excel/domain/excel_usecases.dart';
import '../../excel/domain/export/export_models.dart';
import '../domain/backup.dart';

/// Backs up the on-device database: a full JSON dump (for restore) and a
/// formatted Excel workbook with every sheet (for reading and sharing).
class LocalBackupSource implements BackupSource {
  LocalBackupSource(this._db, this._export, this._labels);

  final SanadDatabase _db;
  final ExportWorkbook _export;

  /// Workbook labels in the app's current language.
  final ExportLabels Function() _labels;

  @override
  Future<Result<BackupPayload>> create() async {
    final workbook = await _export(const ExportRequest(), _labels());
    return switch (workbook) {
      Err(:final failure) => Result.failure(failure),
      Success(value: final file) => guard(() async {
        final data = Uint8List.fromList(utf8.encode(jsonEncode(await _db.dump())));
        return BackupPayload(workbook: Uint8List.fromList(file.bytes), data: data);
      }),
    };
  }

  @override
  Future<VoidResult> restore(Uint8List data) => guard(() async {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(data));
    } on FormatException {
      throw const FileFailure(FileFailureReason.notABackup);
    }
    if (json is! Map<String, dynamic>) throw const FileFailure(FileFailureReason.notABackup);
    await _db.restore(json);
  });

  @override
  Stream<void> get changes => _db.changes;
}
