import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/utils/phone_number.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../../../../core/validation/validators.dart';
import '../entities/nurse.dart';
import '../repositories/nurse_repository.dart';

class GetNurses {
  const GetNurses(this._repository);
  final NurseRepository _repository;

  Future<Result<List<Nurse>>> call({bool includeInactive = false}) =>
      _repository.getNurses(includeInactive: includeInactive);
}

Map<String, String> _validate(String name, String? phone, String? notes) => {
      'name': ?Validators.requiredText(name, maxLength: 120),
      'phone': ?Validators.optionalPhone(phone),
      'notes': ?Validators.optionalText(notes, maxLength: 1000),
    };

String? _phone(String? phone) => (phone ?? '').trim().isEmpty ? null : PhoneNumber.normalize(phone);

class SaveNurse {
  const SaveNurse(this._repository);
  final NurseRepository _repository;

  /// Creates a nurse when [existing] is null, otherwise updates it.
  Future<Result<Nurse>> call({
    Nurse? existing,
    required String name,
    String? phone,
    String? notes,
    bool? isActive,
  }) async {
    final errors = _validate(name, phone, notes);
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    final cleanedNotes = (notes ?? '').trim().isEmpty ? null : notes!.trim();
    if (existing == null) {
      return _repository.createNurse(name: TextNormalizer.clean(name), phone: _phone(phone), notes: cleanedNotes);
    }
    return _repository.updateNurse(
      Nurse(
        id: existing.id,
        name: TextNormalizer.clean(name),
        phone: _phone(phone),
        notes: cleanedNotes,
        isActive: isActive ?? existing.isActive,
      ),
    );
  }
}

class SetNurseActive {
  const SetNurseActive(this._repository);
  final NurseRepository _repository;

  Future<Result<Nurse>> call(Nurse nurse, {required bool active}) =>
      _repository.updateNurse(nurse.copyWith(isActive: active));
}
