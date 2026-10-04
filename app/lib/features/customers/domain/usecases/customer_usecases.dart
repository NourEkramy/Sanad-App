import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/validation/validators.dart';
import '../entities/customer.dart';
import '../repositories/customer_repository.dart';

/// Thrown (as a failure) when the phone already belongs to a customer.
/// Carries that customer so the UI can show it instead of creating a duplicate.
final class CustomerExistsFailure extends Failure {
  const CustomerExistsFailure(this.existing);
  final Customer existing;

  @override
  List<Object?> get props => [existing];
}

Map<String, String> validateCustomerDraft(CustomerDraft draft) => {
      'fullName': ?Validators.requiredText(draft.fullName, maxLength: 160),
      'phone': ?Validators.phone(draft.phone),
      'areaId': ?Validators.required(draft.areaId),
      'address': ?Validators.optionalText(draft.address, maxLength: 500),
      'notes': ?Validators.optionalText(draft.notes, maxLength: 2000),
    };

String? _optional(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();

class SearchCustomers {
  const SearchCustomers(this._repository);
  final CustomerRepository _repository;

  /// Returns an empty list for blank queries and for digit queries shorter
  /// than 3 characters (too broad to be useful).
  Future<Result<List<Customer>>> call(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const Result.success([]);
    if (PhoneNumber.looksLikeDigits(q)) {
      final digits = PhoneNumber.normalize(q);
      if (digits.length < 3) return const Result.success([]);
      return _repository.search(digits);
    }
    if (q.length < 2) return const Result.success([]);
    return _repository.search(q);
  }
}

class CreateCustomer {
  const CreateCustomer(this._repository);
  final CustomerRepository _repository;

  /// Validates, checks the phone is not already registered, and creates the
  /// customer. If the phone exists, fails with [CustomerExistsFailure].
  Future<Result<Customer>> call(CustomerDraft draft) async {
    final errors = validateCustomerDraft(draft);
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));

    final phone = PhoneNumber.normalize(draft.phone);
    final existing = await _repository.findByPhone(phone);
    switch (existing) {
      case Err(:final failure):
        return Result.failure(failure);
      case Success(value: final customer?):
        return Result.failure(CustomerExistsFailure(customer));
      case Success():
        break;
    }

    final created = await _repository.create(
      fullName: TextNormalizer.clean(draft.fullName),
      phone: phone,
      areaId: draft.areaId!,
      address: _optional(draft.address),
      notes: _optional(draft.notes),
    );
    // Lost a race with another device: surface the customer that won.
    if (created.failureOrNull case DuplicateFailure(field: 'phone')) {
      final winner = await _repository.findByPhone(phone);
      if (winner.valueOrNull case final customer?) {
        return Result.failure(CustomerExistsFailure(customer));
      }
    }
    return created;
  }
}

class UpdateCustomer {
  const UpdateCustomer(this._repository);
  final CustomerRepository _repository;

  Future<Result<Customer>> call(String id, CustomerDraft draft) async {
    final errors = validateCustomerDraft(draft);
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    final phone = PhoneNumber.normalize(draft.phone);
    final existing = await _repository.findByPhone(phone);
    if (existing.valueOrNull case final other? when other.id != id) {
      return Result.failure(CustomerExistsFailure(other));
    }
    return _repository.update(
      id,
      fullName: TextNormalizer.clean(draft.fullName),
      phone: phone,
      areaId: draft.areaId!,
      address: _optional(draft.address),
      notes: _optional(draft.notes),
    );
  }
}

class GetCustomer {
  const GetCustomer(this._repository);
  final CustomerRepository _repository;

  Future<Result<Customer>> call(String id) => _repository.getById(id);
}

class ListCustomers {
  const ListCustomers(this._repository);
  final CustomerRepository _repository;

  Future<Result<List<Customer>>> call({int offset = 0, int limit = 30, String? areaId, bool needsReviewOnly = false}) =>
      _repository.list(offset: offset, limit: limit, areaId: areaId, needsReviewOnly: needsReviewOnly);
}

class SetCustomerArchived {
  const SetCustomerArchived(this._repository);
  final CustomerRepository _repository;

  Future<VoidResult> call(String id, {required bool archived}) => _repository.setArchived(id, archived: archived);
}
