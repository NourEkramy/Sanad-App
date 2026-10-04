import '../../../../core/result/result.dart';
import '../entities/nurse.dart';

abstract interface class NurseRepository {
  Future<Result<List<Nurse>>> getNurses({bool includeInactive = false});
  Future<Result<Nurse>> createNurse({required String name, String? phone, String? notes});
  Future<Result<Nurse>> updateNurse(Nurse nurse);
}
