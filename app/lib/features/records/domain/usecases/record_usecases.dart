import 'dart:async';

import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/dates.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/validation/validators.dart';
import '../../../customers/domain/entities/customer.dart';
import '../entities/record_draft.dart';
import '../entities/record_filter.dart';
import '../entities/service_record.dart';
import '../repositories/record_repository.dart';

typedef IdGenerator = String Function();
typedef Clock = DateTime Function();

/// Validates a record form. Returns field → error code.
Map<String, String> validateRecordDraft(RecordDraft draft, {required DateTime today}) => {
  if (draft.nurseId == null) 'nurse': ValidationCodes.required,
  if (draft.serviceId == null) 'service': ValidationCodes.required,
  'price': ?Validators.price(draft.price),
  if (draft.paymentMethod == null || draft.paymentMethod == PaymentMethod.unspecified)
    'paymentMethod': ValidationCodes.required,
  if (draft.serviceDate == null)
    'serviceDate': ValidationCodes.required
  else if (Dates.dateOnly(draft.serviceDate!).isAfter(today))
    'serviceDate': ValidationCodes.futureDate,
  if (draft.serviceTime == null) 'serviceTime': ValidationCodes.required,
  'patientName': ?Validators.optionalText(draft.patientName, maxLength: 160),
  'notes': ?Validators.optionalText(draft.notes, maxLength: 2000),
};

/// Outcome of saving a record: either stored in the cloud, or kept on the
/// device because the network was unavailable (it will sync automatically).
enum SaveOutcome { saved, queuedOffline }

class AddServiceRecord {
  AddServiceRecord(this._repository, this._pending, this._newId, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final RecordRepository _repository;
  final PendingRecordStore _pending;
  final IdGenerator _newId;
  final Clock _clock;

  Future<Result<(ServiceRecord, SaveOutcome)>> call(Customer customer, RecordDraft draft) async {
    final now = _clock();
    final errors = validateRecordDraft(draft, today: Dates.dateOnly(now));
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));

    final patient = (draft.patientName ?? '').trim();
    final notes = (draft.notes ?? '').trim();
    final record = NewServiceRecord(
      id: _newId(),
      customerId: customer.id,
      customerName: customer.fullName,
      customerPhone: customer.phone,
      customerAddress: customer.address,
      areaName: customer.areaName,
      patientName: patient.isEmpty || patient == customer.fullName ? null : patient,
      nurseId: draft.nurseId!,
      nurseName: draft.nurseName ?? '',
      serviceId: draft.serviceId!,
      serviceName: draft.serviceName ?? '',
      // The price actually charged — never derived from the service default.
      price: Money.tryParse(draft.price)!,
      paymentMethod: draft.paymentMethod!,
      serviceDate: Dates.dateOnly(draft.serviceDate!),
      serviceTime: draft.serviceTime!,
      notes: notes.isEmpty ? null : notes,
      createdAt: now,
    );

    final result = await _repository.add(record);
    switch (result) {
      case Success():
        return Result.success((record.toRecord(), SaveOutcome.saved));
      case Err(failure: NetworkFailure()):
        final queued = record.toRecord(syncState: SyncState.pending);
        await _pending.put(queued);
        return Result.success((queued, SaveOutcome.queuedOffline));
      case Err(:final failure):
        return Result.failure(failure);
    }
  }
}

/// Sends queued offline records. Safe to call repeatedly and concurrently:
/// inserts are idempotent and only one sync runs at a time.
class SyncPendingRecords {
  SyncPendingRecords(this._repository, this._pending);

  final RecordRepository _repository;
  final PendingRecordStore _pending;
  Completer<SyncReport>? _running;

  Future<SyncReport> call() async {
    if (_running != null) return _running!.future;
    final completer = _running = Completer<SyncReport>();
    var sent = 0, failed = 0, remaining = 0;
    try {
      for (final record in await _pending.all()) {
        final result = await _repository.add(_toNew(record));
        switch (result) {
          case Success():
            await _pending.remove(record.id);
            sent++;
          case Err(failure: NetworkFailure() || SessionExpiredFailure()):
            remaining++;
          case Err(:final failure):
            await _pending.put(record.copyWith(syncState: SyncState.failed, syncError: _code(failure)));
            failed++;
        }
      }
      final report = SyncReport(sent: sent, failed: failed, remaining: remaining);
      completer.complete(report);
      return report;
    } catch (e) {
      final report = SyncReport(sent: sent, failed: failed, remaining: remaining + 1);
      completer.complete(report);
      return report;
    } finally {
      _running = null;
    }
  }

  static String _code(Failure f) => switch (f) {
    BusinessRuleFailure(:final rule) => rule,
    PermissionFailure() => 'permission',
    ValidationFailure() => 'validation',
    _ => 'server',
  };

  static NewServiceRecord _toNew(ServiceRecord r) => NewServiceRecord(
    id: r.id,
    customerId: r.customerId,
    customerName: r.customerName,
    customerPhone: r.customerPhone,
    customerAddress: r.customerAddress,
    areaName: r.areaName,
    patientName: r.patientName,
    nurseId: r.nurseId,
    nurseName: r.nurseName,
    serviceId: r.serviceId,
    serviceName: r.serviceName,
    price: r.price,
    paymentMethod: r.paymentMethod,
    serviceDate: r.serviceDate,
    serviceTime: r.serviceTime!,
    notes: r.notes,
    createdAt: r.createdAt,
  );
}

class SyncReport {
  const SyncReport({required this.sent, required this.failed, required this.remaining});
  final int sent;
  final int failed;
  final int remaining;
}

/// A customer's full history, including records still waiting to sync,
/// newest first.
class GetCustomerHistory {
  const GetCustomerHistory(this._repository, this._pending);
  final RecordRepository _repository;
  final PendingRecordStore _pending;

  Future<Result<List<ServiceRecord>>> call(String customerId) async {
    final remote = await _repository.customerHistory(customerId);
    final local = (await _pending.all()).where((r) => r.customerId == customerId).toList();
    return remote.map((records) {
      final ids = records.map((r) => r.id).toSet();
      final merged = [...local.where((r) => !ids.contains(r.id)), ...records]
        ..sort((a, b) => b.sortKey.compareTo(a.sortKey));
      return merged;
    });
  }
}

class ListRecords {
  const ListRecords(this._repository);
  final RecordRepository _repository;

  Future<Result<List<ServiceRecord>>> call(RecordFilter filter, {int offset = 0, int limit = 30}) =>
      _repository.list(filter, offset: offset, limit: limit);
}

class GetRecordTotals {
  const GetRecordTotals(this._repository);
  final RecordRepository _repository;

  Future<Result<RecordTotals>> call(RecordFilter filter) => _repository.totals(filter);
}

class GetRecord {
  const GetRecord(this._repository, this._pending);
  final RecordRepository _repository;
  final PendingRecordStore _pending;

  Future<Result<ServiceRecord>> call(String id) async {
    final local = (await _pending.all()).where((r) => r.id == id).firstOrNull;
    if (local != null) return Result.success(local);
    return _repository.getById(id);
  }
}

class UpdateServiceRecord {
  UpdateServiceRecord(this._repository, {Clock? clock}) : _clock = clock ?? DateTime.now;
  final RecordRepository _repository;
  final Clock _clock;

  Future<Result<ServiceRecord>> call(String id, RecordDraft draft) async {
    final errors = validateRecordDraft(draft, today: Dates.dateOnly(_clock()));
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    final notes = (draft.notes ?? '').trim();
    final patient = (draft.patientName ?? '').trim();
    return _repository.update(
      id,
      nurseId: draft.nurseId!,
      serviceId: draft.serviceId!,
      price: Money.tryParse(draft.price)!,
      paymentMethod: draft.paymentMethod!,
      serviceDate: Dates.dateOnly(draft.serviceDate!),
      serviceTime: draft.serviceTime!,
      patientName: patient.isEmpty ? null : patient,
      notes: notes.isEmpty ? null : notes,
    );
  }
}

class ArchiveServiceRecord {
  const ArchiveServiceRecord(this._repository);
  final RecordRepository _repository;

  Future<VoidResult> call(String id) => _repository.archive(id);
}

class DiscardPendingRecord {
  const DiscardPendingRecord(this._pending);
  final PendingRecordStore _pending;

  Future<void> call(String id) => _pending.remove(id);
}
