import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failure.dart';
import '../../../core/files/file_gateway.dart';
import '../domain/entities/sheet_table.dart';
import '../domain/excel_usecases.dart';
import '../domain/import/column_mapping.dart';
import '../domain/import/import_plan.dart';

enum ImportStep { start, reading, columns, preparing, preview, committing, done }

class ImportState extends Equatable {
  const ImportState({
    this.step = ImportStep.start,
    this.workbook,
    this.sheetName,
    this.mapping,
    this.plan,
    this.result,
    this.failure,
    this.batches = const [],
    this.batchesLoading = true,
    this.rollingBack,
  });

  final ImportStep step;
  final OpenedWorkbook? workbook;
  final String? sheetName;
  final ColumnMapping? mapping;
  final ImportPlan? plan;
  final ImportResult? result;
  final Failure? failure;
  final List<ImportBatch> batches;
  final bool batchesLoading;

  /// Batch id currently being rolled back.
  final String? rollingBack;

  SheetTable? get sheet => workbook?.sheets.where((s) => s.name == sheetName).firstOrNull;

  ImportState copyWith({
    ImportStep? step,
    OpenedWorkbook? workbook,
    String? sheetName,
    ColumnMapping? mapping,
    bool clearMapping = false,
    ImportPlan? plan,
    ImportResult? result,
    Failure? failure,
    bool clearFailure = false,
    List<ImportBatch>? batches,
    bool? batchesLoading,
    String? rollingBack,
    bool clearRollingBack = false,
  }) => ImportState(
    step: step ?? this.step,
    workbook: workbook ?? this.workbook,
    sheetName: sheetName ?? this.sheetName,
    mapping: clearMapping ? null : mapping ?? this.mapping,
    plan: plan ?? this.plan,
    result: result ?? this.result,
    failure: clearFailure ? null : failure ?? this.failure,
    batches: batches ?? this.batches,
    batchesLoading: batchesLoading ?? this.batchesLoading,
    rollingBack: clearRollingBack ? null : rollingBack ?? this.rollingBack,
  );

  @override
  List<Object?> get props => [
    step,
    workbook?.sha256,
    sheetName,
    mapping,
    plan,
    result,
    failure,
    batches,
    batchesLoading,
    rollingBack,
  ];
}

/// Guided, reversible import: pick file → check columns → preview → commit.
/// Nothing touches the database before the explicit commit.
class ImportCubit extends Cubit<ImportState> {
  ImportCubit({
    required FileGateway files,
    required OpenWorkbook openWorkbook,
    required PrepareImport prepareImport,
    required CommitImport commitImport,
    required ListImportBatches listBatches,
    required RollbackImport rollback,
    ColumnDetector detector = const ColumnDetector(),
  }) : _files = files,
       _open = openWorkbook,
       _prepare = prepareImport,
       _commit = commitImport,
       _listBatches = listBatches,
       _rollback = rollback,
       _detector = detector,
       super(const ImportState());

  final FileGateway _files;
  final OpenWorkbook _open;
  final PrepareImport _prepare;
  final CommitImport _commit;
  final ListImportBatches _listBatches;
  final RollbackImport _rollback;
  final ColumnDetector _detector;

  Future<void> loadBatches() async {
    emit(state.copyWith(batchesLoading: true));
    final result = await _listBatches();
    if (isClosed) return;
    emit(state.copyWith(batchesLoading: false, batches: result.valueOrNull ?? state.batches));
  }

  Future<void> pickFile() async {
    final picked = await _files.pickExcel();
    if (picked == null || isClosed) return;
    await openBytes(picked);
  }

  Future<void> openBytes(PickedFile file) async {
    emit(state.copyWith(step: ImportStep.reading, clearFailure: true));
    // Let the "reading" state paint before the synchronous decode.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final result = _open(fileName: file.name, bytes: file.bytes);
    if (isClosed) return;
    result.fold((f) => emit(ImportState(failure: f, batches: state.batches, batchesLoading: false)), (workbook) {
      final sheet = workbook.bestSheet ?? workbook.sheets.first;
      emit(
        state.copyWith(
          step: ImportStep.columns,
          workbook: workbook,
          sheetName: sheet.name,
          mapping: workbook.mappings[sheet.name],
          clearMapping: workbook.mappings[sheet.name] == null,
        ),
      );
    });
  }

  void selectSheet(String name) {
    final workbook = state.workbook;
    if (workbook == null) return;
    final sheet = workbook.sheets.firstWhere((s) => s.name == name);
    final mapping = workbook.mappings[name] ?? (sheet.rows.isEmpty ? null : _detector.mapRow(sheet, 0));
    emit(state.copyWith(sheetName: name, mapping: mapping, clearMapping: mapping == null, clearFailure: true));
  }

  void setColumn(ImportField field, int? column) {
    final mapping = state.mapping;
    if (mapping == null) return;
    emit(state.copyWith(mapping: mapping.withColumn(field, column), clearFailure: true));
  }

  Future<void> buildPreview({required String unspecifiedLabel}) async {
    final sheet = state.sheet;
    final mapping = state.mapping;
    if (sheet == null || mapping == null) return;
    emit(state.copyWith(step: ImportStep.preparing, clearFailure: true));
    final result = await _prepare(sheet, mapping, unspecifiedLabel: unspecifiedLabel);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => state.copyWith(step: ImportStep.columns, failure: f),
        (plan) => state.copyWith(step: ImportStep.preview, plan: plan),
      ),
    );
  }

  void backToColumns() => emit(state.copyWith(step: ImportStep.columns, clearFailure: true));

  Future<void> commit() async {
    final plan = state.plan;
    final workbook = state.workbook;
    if (plan == null || workbook == null || state.step == ImportStep.committing) return;
    emit(state.copyWith(step: ImportStep.committing, clearFailure: true));
    final result = await _commit(plan, workbook);
    if (isClosed) return;
    emit(
      result.fold(
        (f) => state.copyWith(step: ImportStep.preview, failure: f),
        (r) => state.copyWith(step: ImportStep.done, result: r),
      ),
    );
    if (result.isSuccess) await loadBatches();
  }

  Future<Failure?> rollback(String batchId) async {
    emit(state.copyWith(rollingBack: batchId));
    final result = await _rollback(batchId);
    if (isClosed) return null;
    emit(state.copyWith(clearRollingBack: true));
    await loadBatches();
    return result.failureOrNull;
  }

  void reset() => emit(ImportState(batches: state.batches, batchesLoading: false));
}
