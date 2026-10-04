import 'package:equatable/equatable.dart';

/// Expected failures, expressed without any UI text. The presentation layer
/// maps each one to a localized, user-facing message
/// (see `core/widgets/failure_message.dart`).
abstract class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

/// The device is offline or the server could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The server answered with an unexpected error.
final class ServerFailure extends Failure {
  const ServerFailure([this.code]);
  final String? code;

  @override
  List<Object?> get props => [code];
}

/// Wrong e-mail/password or another authentication problem.
final class AuthFailure extends Failure {
  const AuthFailure(this.reason);
  final AuthFailureReason reason;

  @override
  List<Object?> get props => [reason];
}

enum AuthFailureReason { invalidCredentials, accountDisabled, emailNotConfirmed, weakPassword, rateLimited, unknown }

/// The session expired and the user must sign in again.
final class SessionExpiredFailure extends Failure {
  const SessionExpiredFailure();
}

/// The signed-in user is not allowed to perform the action.
final class PermissionFailure extends Failure {
  const PermissionFailure();
}

/// A unique value already exists (e.g. phone number, area name).
/// Not final: features may add context (see `CustomerExistsFailure`).
class DuplicateFailure extends Failure {
  const DuplicateFailure(this.field);
  final String field;

  @override
  List<Object?> get props => [field];
}

/// A business rule enforced by the server was violated.
/// [rule] is a stable identifier such as `nurse_inactive`.
final class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure(this.rule);
  final String rule;

  @override
  List<Object?> get props => [rule];
}

/// Input failed validation; [fields] maps a field name to an error code.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.fields);
  final Map<String, String> fields;

  /// The same failure without [field]'s error, or null when none remain.
  ValidationFailure? without(String field) {
    if (!fields.containsKey(field)) return this;
    final rest = Map<String, String>.from(fields)..remove(field);
    return rest.isEmpty ? null : ValidationFailure(rest);
  }

  @override
  List<Object?> get props => [fields];
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure();
}

/// A file (Excel import) could not be read or does not have the expected shape.
final class FileFailure extends Failure {
  const FileFailure(this.reason);
  final FileFailureReason reason;

  @override
  List<Object?> get props => [reason];
}

enum FileFailureReason { unreadable, noSheets, headerNotFound, empty, writeFailed }

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
