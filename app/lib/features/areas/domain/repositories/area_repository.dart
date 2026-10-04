import '../../../../core/result/result.dart';
import '../entities/area.dart';

abstract interface class AreaRepository {
  Future<Result<List<Area>>> getAreas({bool includeInactive = false});

  /// Fails with `DuplicateFailure('name')` when an area with the same
  /// normalised name already exists.
  Future<Result<Area>> createArea(String name);

  Future<Result<Area>> updateArea(Area area);
}
