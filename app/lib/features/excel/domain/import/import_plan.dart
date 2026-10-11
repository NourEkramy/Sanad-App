import '../../../../core/utils/dates.dart';
import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../records/domain/entities/service_record.dart';
import 'column_mapping.dart';

/// Names that already exist in the database, used to tell "will be matched"
/// from "will be created" in the preview. Matching itself happens again on
/// the server inside the import transaction.
class ExistingData {
  const ExistingData({
    this.areaKeys = const {},
    this.nurseKeys = const {},
    this.serviceKeys = const {},
    this.phones = const {},
    this.committedImports = 0,
  });

  final Set<String> areaKeys;
  final Set<String> nurseKeys;
  final Set<String> serviceKeys;
  final Set<String> phones;
  final int committedImports;
}

class PlannedEntity {
  const PlannedEntity({required this.key, required this.name, required this.exists, required this.rowCount});

  /// Normalised name (also the key used inside the import payload).
  final String key;
  final String name;
  final bool exists;
  final int rowCount;
}

class PlannedCustomer {
  const PlannedCustomer({
    required this.key,
    required this.fullName,
    required this.phone,
    required this.areaKey,
    required this.address,
    required this.exists,
    required this.needsReview,
    required this.otherNames,
    required this.rowCount,
  });

  final String key;
  final String fullName;
  final String? phone;
  final String areaKey;
  final String? address;
  final bool exists;
  final bool needsReview;

  /// Different names recorded under the same phone (family members).
  final List<String> otherNames;
  final int rowCount;
}

class PlannedRecord {
  const PlannedRecord({
    required this.rowNumber,
    required this.customerKey,
    required this.nurseKey,
    required this.serviceKey,
    required this.price,
    required this.paymentMethod,
    required this.serviceDate,
    required this.raw,
    this.serviceTime,
    this.patientName,
    this.notes,
    this.legacyRef,
    this.address,
    this.areaName,
    this.sheetId,
    this.warnings = const [],
  });

  /// 1-based spreadsheet row number.
  final int rowNumber;

  /// ID written by Sanad in a connected Google Sheet (kept on re-import).
  final String? sheetId;
  final String customerKey;
  final String nurseKey;
  final String serviceKey;
  final Money price;
  final PaymentMethod paymentMethod;
  final DateTime serviceDate;
  final LocalTime? serviceTime;
  final String? patientName;
  final String? notes;
  final String? legacyRef;
  final String? address;
  final String? areaName;
  final Map<String, String> raw;
  final List<String> warnings;
}

class SkippedRow {
  const SkippedRow({required this.rowNumber, required this.raw, required this.issues});

  final int rowNumber;
  final Map<String, String> raw;
  final List<String> issues;
}

/// Everything an import would do, computed locally for review before commit.
class ImportPlan {
  const ImportPlan({
    required this.sheetName,
    required this.mapping,
    required this.areas,
    required this.nurses,
    required this.services,
    required this.customers,
    required this.records,
    required this.skipped,
    required this.committedImports,
  });

  final String sheetName;
  final ColumnMapping mapping;
  final List<PlannedEntity> areas;
  final List<PlannedEntity> nurses;
  final List<PlannedEntity> services;
  final List<PlannedCustomer> customers;
  final List<PlannedRecord> records;
  final List<SkippedRow> skipped;

  /// Imports already committed (a second import may duplicate records).
  final int committedImports;

  int get rowCount => records.length + skipped.length;
  int get newCustomers => customers.where((c) => !c.exists).length;
  int get matchedCustomers => customers.where((c) => c.exists).length;
  int get customersNeedingReview => customers.where((c) => c.needsReview).length;
  int get newAreas => areas.where((a) => !a.exists).length;
  int get newNurses => nurses.where((n) => !n.exists).length;
  int get newServices => services.where((s) => !s.exists).length;
  int get recordsWithoutPayment => records.where((r) => r.paymentMethod == PaymentMethod.unspecified).length;

  Money get totalRevenue => records.fold(Money.zero, (sum, r) => sum + r.price);

  DateTime? get firstDate =>
      records.isEmpty ? null : records.map((r) => r.serviceDate).reduce((a, b) => a.isBefore(b) ? a : b);
  DateTime? get lastDate =>
      records.isEmpty ? null : records.map((r) => r.serviceDate).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Warning code → number of rows.
  Map<String, int> get warningCounts {
    final counts = <String, int>{};
    for (final r in records) {
      for (final w in r.warnings) {
        counts[w] = (counts[w] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Error code → number of skipped rows.
  Map<String, int> get errorCounts {
    final counts = <String, int>{};
    for (final s in skipped) {
      for (final e in s.issues) {
        counts[e] = (counts[e] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// JSON payload for `public.import_legacy_batch`.
  Map<String, Object?> toPayload({required String fileName, required String fileSha256}) => {
    'file_name': fileName,
    'file_sha256': fileSha256,
    'sheet_name': sheetName,
    'summary': {
      'rows': rowCount,
      'records': records.length,
      'skipped': skipped.length,
      'warnings': warningCounts,
      'errors': errorCounts,
      'revenue': totalRevenue.toJson(),
    },
    'areas': [
      for (final a in areas) {'key': a.key, 'name': a.name},
    ],
    'nurses': [
      for (final n in nurses) {'key': n.key, 'name': n.name},
    ],
    'services': [
      for (final s in services) {'key': s.key, 'name': s.name, 'default_price': null},
    ],
    'customers': [
      for (final c in customers)
        {
          'key': c.key,
          'full_name': c.fullName,
          'phone': c.phone,
          'address': c.address,
          'area_key': c.areaKey,
          'needs_review': c.needsReview,
        },
    ],
    'records': [
      for (final r in records)
        {
          'row_number': r.rowNumber,
          'customer_key': r.customerKey,
          'nurse_key': r.nurseKey,
          'service_key': r.serviceKey,
          'patient_name': r.patientName,
          'price': r.price.toJson(),
          'payment_method': r.paymentMethod.toJson(),
          'service_date': Dates.toJson(r.serviceDate),
          'service_time': r.serviceTime?.toJson(),
          'notes': r.notes,
          'legacy_ref': r.legacyRef,
          'id': r.sheetId,
          'address': r.address,
          'area_key': TextNormalizer.key(r.areaName),
          'area_name': r.areaName,
          'raw': r.raw,
          'messages': r.warnings,
        },
    ],
    'skipped': [
      for (final s in skipped) {'row_number': s.rowNumber, 'raw': s.raw, 'messages': s.issues},
    ],
  };
}

/// Server response after committing an import.
class ImportResult {
  const ImportResult({
    required this.batchId,
    required this.createdRecords,
    required this.createdCustomers,
    required this.matchedCustomers,
    required this.createdAreas,
    required this.createdNurses,
    required this.createdServices,
  });

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    final created = (json['created'] as Map?)?.cast<String, dynamic>() ?? const {};
    int c(String k) => (created[k] as num?)?.toInt() ?? 0;
    return ImportResult(
      batchId: json['batch_id'] as String,
      createdRecords: c('records'),
      createdCustomers: c('customers'),
      matchedCustomers: (json['matched_customers'] as num?)?.toInt() ?? 0,
      createdAreas: c('areas'),
      createdNurses: c('nurses'),
      createdServices: c('services'),
    );
  }

  final String batchId;
  final int createdRecords;
  final int createdCustomers;
  final int matchedCustomers;
  final int createdAreas;
  final int createdNurses;
  final int createdServices;
}

/// A committed (or rolled back) import, for the import history list.
class ImportBatch {
  const ImportBatch({
    required this.id,
    required this.fileName,
    required this.sheetName,
    required this.createdAt,
    required this.isRolledBack,
    required this.recordCount,
  });

  final String id;
  final String fileName;
  final String sheetName;
  final DateTime createdAt;
  final bool isRolledBack;
  final int recordCount;
}
