import '../../../../core/result/result.dart';
import '../entities/customer.dart';

abstract interface class CustomerRepository {
  /// Phone-first search (digits → phone prefix/contains, text → name).
  Future<Result<List<Customer>>> search(String query, {int limit = 20});

  Future<Result<Customer?>> findByPhone(String normalizedPhone);

  Future<Result<Customer>> getById(String id);

  /// Paged list, newest first. [areaId] filters by area.
  Future<Result<List<Customer>>> list({int offset = 0, int limit = 30, String? areaId, bool needsReviewOnly = false});

  /// Fails with `DuplicateFailure('phone')` when the phone already exists.
  Future<Result<Customer>> create({
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  });

  Future<Result<Customer>> update(
    String id, {
    required String fullName,
    required String phone,
    required String areaId,
    String? address,
    String? notes,
  });

  Future<VoidResult> setArchived(String id, {required bool archived});
}
