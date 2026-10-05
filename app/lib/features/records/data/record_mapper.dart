import '../../../core/database/sql.dart';
import '../../../core/utils/dates.dart';
import '../../../core/utils/local_time.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/text_normalizer.dart';
import '../domain/entities/record_filter.dart';
import '../domain/entities/service_record.dart';

/// Converts between [ServiceRecord] and database rows, and turns a
/// [RecordFilter] into SQL (the single place records are filtered: list
/// screen, totals and export).
abstract final class RecordMapper {
  /// A record with the customer's current name/phone and the snapshot of
  /// everything else as it was when the record was saved.
  static const details = '''
    SELECT r.*, c.full_name AS customer_name, c.phone AS customer_phone,
           r.address_snapshot AS customer_address, r.area_name_snapshot AS area_name,
           r.nurse_name_snapshot AS nurse_name, r.service_name_snapshot AS service_name
      FROM service_records r
      JOIN customers c ON c.id = r.customer_id''';

  static ServiceRecord fromRow(Map<String, Object?> row) => ServiceRecord(
    id: row['id']! as String,
    customerId: row['customer_id']! as String,
    customerName: row['customer_name'] as String? ?? '',
    customerPhone: row['customer_phone'] as String?,
    customerAddress: row['customer_address'] as String?,
    areaName: row['area_name'] as String?,
    patientName: row['patient_name'] as String?,
    nurseId: row['nurse_id']! as String,
    nurseName: row['nurse_name'] as String? ?? '',
    serviceId: row['service_id']! as String,
    serviceName: row['service_name'] as String? ?? '',
    price: Money.piasters(row['price']! as int),
    paymentMethod: PaymentMethod.fromJson(row['payment_method'] as String?),
    serviceDate: Dates.tryParseIso(row['service_date'] as String?) ?? Dates.today(),
    serviceTime: LocalTime.tryParse(row['service_time'] as String?),
    notes: row['notes'] as String?,
    legacyRef: row['legacy_ref'] as String?,
    isImported: row['import_batch_id'] != null,
    isArchived: row['deleted_at'] != null,
    createdAt: DateTime.parse(row['created_at']! as String).toLocal(),
  );

  /// `WHERE …` for [filter] (columns of [details]) and its arguments.
  static (String, List<Object?>) where(RecordFilter filter, {String? customerId}) {
    final conditions = ['r.deleted_at IS NULL'];
    final args = <Object?>[];
    void add(String condition, Object? value) {
      if (value == null) return;
      conditions.add(condition);
      args.add(value);
    }

    add('r.service_date >= ?', filter.from == null ? null : Dates.toJson(filter.from!));
    add('r.service_date <= ?', filter.to == null ? null : Dates.toJson(filter.to!));
    add('r.nurse_id = ?', filter.nurseId);
    add('r.service_id = ?', filter.serviceId);
    add('r.area_id = ?', filter.areaId);
    add('r.payment_method = ?', filter.paymentMethod?.toJson());
    add('r.customer_id = ?', customerId);

    // Digits match the phone; anything else the customer or patient name.
    final query = filter.query.trim();
    if (query.isNotEmpty) {
      final digits = Sql.phoneQuery(query);
      if (digits != null) {
        add('c.phone LIKE ?', '%$digits%');
      } else {
        final pattern = Sql.contains(TextNormalizer.key(query));
        conditions.add("(c.name_normalized LIKE ? ESCAPE '\\' OR r.patient_name_normalized LIKE ? ESCAPE '\\')");
        args.addAll([pattern, pattern]);
      }
    }
    return ('WHERE ${conditions.join(' AND ')}', args);
  }

  static String orderBy(RecordSort sort) => switch (sort) {
    RecordSort.newest => 'r.service_date DESC, r.service_time DESC, r.created_at DESC',
    RecordSort.oldest => 'r.service_date, r.service_time, r.created_at',
    RecordSort.priceHigh => 'r.price DESC, r.service_date DESC',
    RecordSort.priceLow => 'r.price, r.service_date DESC',
  };
}
