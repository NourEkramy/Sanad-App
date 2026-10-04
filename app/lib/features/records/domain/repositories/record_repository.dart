import '../../../../core/result/result.dart';
import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';
import '../entities/record_draft.dart';
import '../entities/record_filter.dart';
import '../entities/service_record.dart';

abstract interface class RecordRepository {
  /// Inserts the record. Idempotent: inserting the same id twice is a no-op.
  Future<VoidResult> add(NewServiceRecord record);

  Future<Result<ServiceRecord>> getById(String id);

  Future<Result<List<ServiceRecord>>> customerHistory(String customerId);

  Future<Result<List<ServiceRecord>>> list(RecordFilter filter, {int offset = 0, int limit = 30});

  Future<Result<RecordTotals>> totals(RecordFilter filter);

  /// Admin correction of an existing record.
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
  });

  Future<VoidResult> archive(String id);
}

/// Device-local queue of records that could not be sent yet (offline).
abstract interface class PendingRecordStore {
  Future<List<ServiceRecord>> all();
  Future<void> put(ServiceRecord record);
  Future<void> remove(String id);
  Stream<int> watchCount();
}

/// Device-local storage for half-filled record forms.
abstract interface class RecordDraftStore {
  Future<RecordDraft?> read(String customerId);
  Future<void> save(String customerId, RecordDraft draft);
  Future<void> clear(String customerId);
}
