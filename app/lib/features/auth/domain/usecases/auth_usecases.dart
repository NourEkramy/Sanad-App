import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../core/validation/validators.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  const SignIn(this._repository);
  final AuthRepository _repository;

  Future<Result<AppUser>> call({required String email, required String password}) async {
    final errors = <String, String>{
      'email': ?Validators.email(email),
      if (password.isEmpty) 'password': ValidationCodes.required,
    };
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    return _repository.signIn(email: email.trim().toLowerCase(), password: password);
  }
}

class SendPasswordReset {
  const SendPasswordReset(this._repository);
  final AuthRepository _repository;

  Future<VoidResult> call(String email) async {
    if (Validators.email(email) case final e?) {
      return Result.failure(ValidationFailure({'email': e}));
    }
    return _repository.sendPasswordReset(email.trim().toLowerCase());
  }
}

class UpdatePassword {
  const UpdatePassword(this._repository);
  final AuthRepository _repository;

  Future<VoidResult> call({required String password, required String confirmation}) async {
    final errors = <String, String>{
      'password': ?Validators.password(password),
      if (password != confirmation) 'confirmation': ValidationCodes.passwordsDoNotMatch,
    };
    if (errors.isNotEmpty) return Result.failure(ValidationFailure(errors));
    return _repository.updatePassword(password);
  }
}
