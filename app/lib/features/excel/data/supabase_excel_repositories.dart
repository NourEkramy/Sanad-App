import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/text_normalizer.dart';
import '../../areas/data/supabase_area_repository.dart';
import '../../care_services/data/supabase_care_service_repository.dart';
import '../../customers/data/supabase_customer_repository.dart';
import '../../nurses/data/supabase_nurse_repository.dart';
import '../../records/data/record_mapper.dart';
import '../../records/domain/entities/record_filter.dart';
import '../domain/excel_repositories.dart';
import '../domain/export/export_models.dart';
import '../domain/import/import_plan.dart';

/// PostgREST returns at most this many rows per request; larger reads page.
const _page = 1000;

Future<List<Map<String, dynamic>>> _all(Future<List<dynamic>> Function(int from, int to) fetch) async {
  final rows = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += _page) {
    final page = (await fetch(offset, offset + _page - 1)).cast<Map<String, dynamic>>();
    rows.addAll(page);
    if (page.length < _page) return rows;
  }
}

class SupabaseImportRepository implements ImportRepository {
  SupabaseImportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<ExistingData>> existingData() => guard(() async {
    Future<Set<String>> names(String table) async {
      final rows = await _all((a, b) => _client.from(table).select('name').range(a, b));
      return rows.map((r) => TextNormalizer.key(r['name'] as String)).toSet();
    }

    final phones = await _all((a, b) => _client.from('customers').select('phone').not('phone', 'is', null).range(a, b));
    final batches = await _client.from('import_batches').select('id').eq('status', 'committed');
    return ExistingData(
      areaKeys: await names('areas'),
      nurseKeys: await names('nurses'),
      serviceKeys: await names('services'),
      phones: phones.map((r) => r['phone'] as String).toSet(),
      committedImports: batches.length,
    );
  });

  @override
  Future<Result<ImportResult>> commit(ImportPlan plan, {required String fileName, required String fileSha256}) =>
      guard(() async {
        final json = await _client.rpc<Map<String, dynamic>>(
          'import_legacy_batch',
          params: {'payload': plan.toPayload(fileName: fileName, fileSha256: fileSha256)},
        );
        return ImportResult.fromJson(json);
      });

  @override
  Future<Result<List<ImportBatch>>> batches() => guard(() async {
    final rows = await _client
        .from('import_batches')
        .select('id, file_name, sheet_name, created_at, status, summary')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        ImportBatch(
          id: r['id'] as String,
          fileName: r['file_name'] as String,
          sheetName: r['sheet_name'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          isRolledBack: r['status'] == 'rolled_back',
          recordCount: ((r['summary'] as Map?)?['created'] as Map?)?['records'] as int? ?? 0,
        ),
    ];
  });

  @override
  Future<VoidResult> rollback(String batchId) => guard(() async {
    await _client.rpc<Map<String, dynamic>>('rollback_import_batch', params: {'target_batch': batchId});
  });
}

class SupabaseExportRepository implements ExportRepository {
  SupabaseExportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<ExportData>> load(ExportRequest request) => guard(() async {
    final sheets = request.sheets;
    final filter = RecordFilter(from: request.from, to: request.to, sort: RecordSort.oldest);

    final records = sheets.contains(ExportSheet.records)
        ? await _all(
            (a, b) => _client
                .rpc<List<dynamic>>('filter_service_records', params: RecordMapper.filterParams(filter))
                .order('service_date', ascending: true)
                .order('service_time', ascending: true, nullsFirst: true)
                .order('created_at', ascending: true)
                .range(a, b),
          )
        : const <Map<String, dynamic>>[];
    final customers = sheets.contains(ExportSheet.customers)
        ? await _all(
            (a, b) => _client
                .from('customer_overview')
                .select()
                .isFilter('deleted_at', null)
                .order('full_name', ascending: true)
                .range(a, b),
          )
        : const <Map<String, dynamic>>[];
    final nurses = sheets.contains(ExportSheet.nurses)
        ? await _all((a, b) => _client.from('nurses').select().order('name', ascending: true).range(a, b))
        : const <Map<String, dynamic>>[];
    final services = sheets.contains(ExportSheet.services)
        ? await _all((a, b) => _client.from('services').select().order('name', ascending: true).range(a, b))
        : const <Map<String, dynamic>>[];
    final areas = sheets.contains(ExportSheet.areas)
        ? await _all((a, b) => _client.from('areas').select().order('name', ascending: true).range(a, b))
        : const <Map<String, dynamic>>[];

    return ExportData(
      records: records.map(RecordMapper.fromRow).toList(),
      customers: customers.map(SupabaseCustomerRepository.fromRow).toList(),
      nurses: nurses.map(SupabaseNurseRepository.fromRow).toList(),
      services: services.map(SupabaseCareServiceRepository.fromRow).toList(),
      areas: areas.map(SupabaseAreaRepository.fromRow).toList(),
    );
  });
}
