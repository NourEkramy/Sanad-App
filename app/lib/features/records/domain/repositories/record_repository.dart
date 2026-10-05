import '../../../../core/result/result.dart';
import '../../../../core/utils/local_time.dart';
import '../../../../core/utils/money.dart';
import '../entities/record_draft.dart';
import '../entities/record_filter.dart';
import '../entities/service_record.dart';

abstract interface class RecordRepository {
  /// Saves the record and returns it as stored (with its snapshot of the
  /// customer, area, nurse and service). Saving the same id twice returns the
  /// existing record instead of creating a duplicate.
  Future<Result<ServiceRecord>> add(NewServiceRecord record);

  Future<Result<ServiceRecord>> getById(String id);

  Future<Result<List<ServiceRecord>>> customerHistory(String customerId);

  Future<Result<List<ServiceRecord>>> list(RecordFilter filter, {int offset = 0, int limit = 30});

  Future<Result<RecordTotals>> totals(RecordFilter filter);

  /// Correction of an existing record.
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

/// Device-local storage for half-filled record forms.
abstract interface class RecordDraftStore {
  Future<RecordDraft?> read(String customerId);
  Future<void> save(String customerId, RecordDraft draft);
  Future<void> clear(String customerId);
}
