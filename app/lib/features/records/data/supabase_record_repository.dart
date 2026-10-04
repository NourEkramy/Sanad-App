import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/result/result.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/local_time.dart';
import '../../../core/utils/money.dart';
import '../domain/entities/record_draft.dart';
import '../domain/entities/record_filter.dart';
import '../domain/entities/service_record.dart';
import '../domain/repositories/record_repository.dart';
import 'record_mapper.dart';

class SupabaseRecordRepository implements RecordRepository {
  SupabaseRecordRepository(this._client);

  final SupabaseClient _client;

  static const _view = 'service_record_details';

  @override
  Future<VoidResult> add(NewServiceRecord record) => guard(() async {
        // ON CONFLICT (id) DO NOTHING: retrying a save can never duplicate.
        await _client.from('service_records').upsert(
          {
            'id': record.id,
            'customer_id': record.customerId,
            'nurse_id': record.nurseId,
            'service_id': record.serviceId,
            'patient_name': record.patientName,
            'price': record.price.toJson(),
            'payment_method': record.paymentMethod.toJson(),
            'service_date': Dates.toJson(record.serviceDate),
            'service_time': record.serviceTime.toJson(),
            'notes': record.notes,
          },
          onConflict: 'id',
          ignoreDuplicates: true,
        );
      });

  @override
  Future<Result<ServiceRecord>> getById(String id) => guard(() async {
        final row = await _client.from(_view).select().eq('id', id).single();
        return RecordMapper.fromRow(row);
      });

  @override
  Future<Result<List<ServiceRecord>>> customerHistory(String customerId) => guard(() async {
        final rows = await _client
            .from(_view)
            .select()
            .eq('customer_id', customerId)
            .isFilter('deleted_at', null)
            .order('service_date', ascending: false)
            .order('service_time', ascending: false, nullsFirst: false)
            .order('created_at', ascending: false);
        return rows.map(RecordMapper.fromRow).toList();
      });

  @override
  Future<Result<List<ServiceRecord>>> list(RecordFilter filter, {int offset = 0, int limit = 30}) =>
      guard(() async {
        final query = _client.rpc<List<dynamic>>('filter_service_records', params: RecordMapper.filterParams(filter));
        final ascending = filter.sort == RecordSort.oldest || filter.sort == RecordSort.priceLow;
        final ordered = switch (filter.sort) {
          RecordSort.newest || RecordSort.oldest => query
              .order('service_date', ascending: ascending)
              .order('service_time', ascending: ascending, nullsFirst: ascending)
              .order('created_at', ascending: ascending),
          RecordSort.priceHigh || RecordSort.priceLow =>
            query.order('price', ascending: ascending).order('service_date', ascending: false),
        };
        final rows = await ordered.range(offset, offset + limit - 1);
        return rows.cast<Map<String, dynamic>>().map(RecordMapper.fromRow).toList();
      });

  @override
  Future<Result<RecordTotals>> totals(RecordFilter filter) => guard(() async {
        final json = await _client.rpc<Map<String, dynamic>>('record_totals', params: RecordMapper.filterParams(filter));
        return RecordTotals(
          count: (json['count'] as num).toInt(),
          revenuePiasters: Money.fromJson(json['revenue']).piasters,
        );
      });

  @override
  Future<Result<ServiceRecord>> update(
    String id, {
    required String nurseId,
    required String serviceId,
    required Money price,
    required PaymentMethod paymentMethod,
    required DateTime serviceDate,
    required LocalTime serviceTime,
    String? patientName,
    String? notes,
  }) =>
      guard(() async {
        await _client
            .from('service_records')
            .update({
              'nurse_id': nurseId,
              'service_id': serviceId,
              'price': price.toJson(),
              'payment_method': paymentMethod.toJson(),
              'service_date': Dates.toJson(serviceDate),
              'service_time': serviceTime.toJson(),
              'patient_name': patientName,
              'notes': notes,
            })
            .eq('id', id)
            .select('id')
            .single();
        return RecordMapper.fromRow(await _client.from(_view).select().eq('id', id).single());
      });

  @override
  Future<VoidResult> archive(String id) => guard(() async {
        await _client.rpc<void>('archive_service_record', params: {'record_id': id});
      });
}
