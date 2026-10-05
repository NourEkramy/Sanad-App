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

class AddServiceRecord {
  AddServiceRecord(this._repository, this._newId, {Clock? clock}) : _clock = clock ?? DateTime.now;

  final RecordRepository _repository;
  final IdGenerator _newId;
  final Clock _clock;

  Future<Result<ServiceRecord>> call(Customer customer, RecordDraft draft) async {
    final now = _clock();
    final errors = validateRecordDraft(draft, today: Dates.dateOnly(now));
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));

    final patient = (draft.patientName ?? '').trim();
    final notes = (draft.notes ?? '').trim();
    return _repository.add(
      NewServiceRecord(
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
      ),
    );
  }
}

/// A customer's full history, newest first.
class GetCustomerHistory {
  const GetCustomerHistory(this._repository);
  final RecordRepository _repository;

  Future<Result<List<ServiceRecord>>> call(String customerId) => _repository.customerHistory(customerId);
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
  const GetRecord(this._repository);
  final RecordRepository _repository;

  Future<Result<ServiceRecord>> call(String id) => _repository.getById(id);
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
