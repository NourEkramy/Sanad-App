import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

enum FormStatus { idle, submitting, success, failure }

/// Shared state for small single-action forms.
class SubmitState extends Equatable {
  const SubmitState({this.status = FormStatus.idle, this.failure});

  final FormStatus status;
  final Failure? failure;

  bool get submitting => status == FormStatus.submitting;

  @override
  List<Object?> get props => [status, failure];
}

class LoginCubit extends Cubit<SubmitState> {
  LoginCubit(this._signIn) : super(const SubmitState());
  final SignIn _signIn;

  Future<void> submit({required String email, required String password}) async {
    if (state.submitting) return;
    emit(const SubmitState(status: FormStatus.submitting));
    final result = await _signIn(email: email, password: password);
    emit(
      result.fold(
        (f) => SubmitState(status: FormStatus.failure, failure: f),
        // Navigation happens through AuthCubit; the form just stops loading.
        (_) => const SubmitState(status: FormStatus.success),
      ),
    );
  }
}

class ForgotPasswordCubit extends Cubit<SubmitState> {
  ForgotPasswordCubit(this._send) : super(const SubmitState());
  final SendPasswordReset _send;

  Future<void> submit(String email) async {
    if (state.submitting) return;
    emit(const SubmitState(status: FormStatus.submitting));
    final result = await _send(email);
    emit(
      result.fold(
        (f) => SubmitState(status: FormStatus.failure, failure: f),
        (_) => const SubmitState(status: FormStatus.success),
      ),
    );
  }
}

class PasswordCubit extends Cubit<SubmitState> {
  PasswordCubit(this._update) : super(const SubmitState());
  final UpdatePassword _update;

  Future<void> submit({required String password, required String confirmation}) async {
    if (state.submitting) return;
    emit(const SubmitState(status: FormStatus.submitting));
    final result = await _update(password: password, confirmation: confirmation);
    emit(
      result.fold(
        (f) => SubmitState(status: FormStatus.failure, failure: f),
        (_) => const SubmitState(status: FormStatus.success),
      ),
    );
  }
}

class ProfileNameCubit extends Cubit<SubmitState> {
  ProfileNameCubit(this._repository) : super(const SubmitState());
  final AuthRepository _repository;

  Future<void> save(String fullName) async {
    if (fullName.trim().isEmpty) {
      emit(const SubmitState(status: FormStatus.failure, failure: ValidationFailure({'fullName': 'required'})));
      return;
    }
    emit(const SubmitState(status: FormStatus.submitting));
    final result = await _repository.updateProfile(fullName: fullName);
    emit(
      result.fold(
        (f) => SubmitState(status: FormStatus.failure, failure: f),
        (_) => const SubmitState(status: FormStatus.success),
      ),
    );
  }
}
