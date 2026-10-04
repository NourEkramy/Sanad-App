import '../../../../core/result/result.dart';
import '../../../../core/utils/money.dart';
import '../entities/care_service.dart';

abstract interface class CareServiceRepository {
  Future<Result<List<CareService>>> getServices({bool includeInactive = false});
  Future<Result<CareService>> createService({required String name, Money? defaultPrice});
  Future<Result<CareService>> updateService(CareService service);
}
