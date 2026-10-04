import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/validation/validators.dart';
import '../entities/area.dart';
import '../repositories/area_repository.dart';

class GetAreas {
  const GetAreas(this._repository);
  final AreaRepository _repository;

  Future<Result<List<Area>>> call({bool includeInactive = false}) =>
      _repository.getAreas(includeInactive: includeInactive);
}

/// Creates an area unless one with the same (normalised) name exists, in
/// which case the existing area is returned — so the "Add new area" shortcut
/// in the customer form can never produce duplicates.
class CreateArea {
  const CreateArea(this._repository);
  final AreaRepository _repository;

  Future<Result<Area>> call(String name, {List<Area>? known}) async {
    if (Validators.requiredText(name, maxLength: 80) case final e?) {
      return Result.failure(ValidationFailure({'name': e}));
    }
    final cleaned = TextNormalizer.clean(name);
    final existing = (known ?? const <Area>[])
        .where((a) => TextNormalizer.sameName(a.name, cleaned))
        .firstOrNull;
    if (existing != null) return Result.success(existing);

    final created = await _repository.createArea(cleaned);
    if (created.failureOrNull is DuplicateFailure) {
      // Created concurrently by someone else: return that one.
      final all = await _repository.getAreas(includeInactive: true);
      final match = all.valueOrNull?.where((a) => TextNormalizer.sameName(a.name, cleaned)).firstOrNull;
      if (match != null) return Result.success(match);
    }
    return created;
  }
}

class UpdateArea {
  const UpdateArea(this._repository);
  final AreaRepository _repository;

  Future<Result<Area>> call(Area area) async {
    if (Validators.requiredText(area.name, maxLength: 80) case final e?) {
      return Result.failure(ValidationFailure({'name': e}));
    }
    return _repository.updateArea(area.copyWith(name: TextNormalizer.clean(area.name)));
  }
}
