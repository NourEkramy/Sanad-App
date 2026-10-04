import '../../../core/utils/dates.dart';
import '../../../core/utils/local_time.dart';
import '../../../core/utils/money.dart';
import '../domain/entities/record_filter.dart';
import '../domain/entities/service_record.dart';

/// Converts between [ServiceRecord] and database rows / local JSON.
abstract final class RecordMapper {
  static ServiceRecord fromRow(Map<String, dynamic> row) => ServiceRecord(
    id: row['id'] as String,
    customerId: row['customer_id'] as String,
    customerName: row['customer_name'] as String? ?? '',
    customerPhone: row['customer_phone'] as String?,
    customerAddress: row['customer_address'] as String?,
    areaName: row['area_name'] as String?,
    patientName: row['patient_name'] as String?,
    nurseId: row['nurse_id'] as String,
    nurseName: row['nurse_name'] as String? ?? '',
    serviceId: row['service_id'] as String,
    serviceName: row['service_name'] as String? ?? '',
    price: Money.fromJson(row['price']),
    paymentMethod: PaymentMethod.fromJson(row['payment_method'] as String?),
    serviceDate: Dates.tryParseIso(row['service_date'] as String?) ?? Dates.today(),
    serviceTime: LocalTime.tryParse(row['service_time'] as String?),
    notes: row['notes'] as String?,
    legacyRef: row['legacy_ref'] as String?,
    isImported: row['import_batch_id'] != null,
    isArchived: row['deleted_at'] != null,
    createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
  );

  /// Local (offline queue) representation — includes display names so a
  /// queued record can be shown without the server.
  static Map<String, Object?> toLocalJson(ServiceRecord r) => {
    'id': r.id,
    'customer_id': r.customerId,
    'customer_name': r.customerName,
    'customer_phone': r.customerPhone,
    'customer_address': r.customerAddress,
    'area_name': r.areaName,
    'patient_name': r.patientName,
    'nurse_id': r.nurseId,
    'nurse_name': r.nurseName,
    'service_id': r.serviceId,
    'service_name': r.serviceName,
    'price': r.price.toJson(),
    'payment_method': r.paymentMethod.toJson(),
    'service_date': Dates.toJson(r.serviceDate),
    'service_time': r.serviceTime?.toJson(),
    'notes': r.notes,
    'created_at': r.createdAt.toUtc().toIso8601String(),
    'sync_state': r.syncState.name,
    'sync_error': r.syncError,
  };

  static ServiceRecord fromLocalJson(Map<String, dynamic> json) {
    final record = fromRow(json);
    return record.copyWith(
      syncState: SyncState.values.firstWhere((s) => s.name == json['sync_state'], orElse: () => SyncState.pending),
      syncError: json['sync_error'] as String?,
    );
  }

  /// Parameters for `filter_service_records` / `record_totals`.
  static Map<String, Object?> filterParams(RecordFilter f, {String? customerId}) => {
    'p_from': f.from == null ? null : Dates.toJson(f.from!),
    'p_to': f.to == null ? null : Dates.toJson(f.to!),
    'p_nurse_id': f.nurseId,
    'p_service_id': f.serviceId,
    'p_area_id': f.areaId,
    'p_payment_method': f.paymentMethod?.toJson(),
    'p_query': f.query.trim().isEmpty ? null : f.query.trim(),
    'p_customer_id': customerId,
  };
}
