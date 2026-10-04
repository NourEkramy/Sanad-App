import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/validation/validators.dart';
import '../entities/care_service.dart';
import '../repositories/care_service_repository.dart';

class GetCareServices {
  const GetCareServices(this._repository);
  final CareServiceRepository _repository;

  Future<Result<List<CareService>>> call({bool includeInactive = false}) =>
      _repository.getServices(includeInactive: includeInactive);
}

/// Creates or updates a service. Changing the default price never touches
/// existing records: each record stores the price actually charged.
class SaveCareService {
  const SaveCareService(this._repository);
  final CareServiceRepository _repository;

  Future<Result<CareService>> call({
    CareService? existing,
    required String name,
    String? defaultPrice,
    bool? isActive,
  }) async {
    final errors = <String, String>{
      'name': ?Validators.requiredText(name, maxLength: 160),
      'defaultPrice': ?Validators.optionalPrice(defaultPrice),
    };
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    final price = (defaultPrice ?? '').trim().isEmpty ? null : Money.tryParse(defaultPrice);
    final cleanedName = TextNormalizer.clean(name);
    if (existing == null) {
      return _repository.createService(name: cleanedName, defaultPrice: price);
    }
    return _repository.updateService(
      CareService(id: existing.id, name: cleanedName, defaultPrice: price, isActive: isActive ?? existing.isActive),
    );
  }
}

class SetCareServiceActive {
  const SetCareServiceActive(this._repository);
  final CareServiceRepository _repository;

  Future<Result<CareService>> call(CareService service, {required bool active}) =>
      _repository.updateService(service.copyWith(isActive: active));
}
