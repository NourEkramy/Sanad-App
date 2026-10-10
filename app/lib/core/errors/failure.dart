import 'package:equatable/equatable.dart';

/// Expected failures, expressed without any UI text. The presentation layer
/// maps each one to a localized, user-facing message
/// (see `core/widgets/failure_message.dart`).
abstract class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

/// The device is offline or Google Drive could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// A remote service (Google Drive) answered with an unexpected error.
final class ServerFailure extends Failure {
  const ServerFailure([this.code]);
  final String? code;

  @override
  List<Object?> get props => [code];
}

/// A unique value already exists (e.g. phone number, area name).
/// Not final: features may add context (see `CustomerExistsFailure`).
class DuplicateFailure extends Failure {
  const DuplicateFailure(this.field);
  final String field;

  @override
  List<Object?> get props => [field];
}

/// A business rule was violated.
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

enum FileFailureReason { unreadable, noSheets, headerNotFound, empty, writeFailed, notABackup }

/// Google Drive backup could not be used.
final class BackupFailure extends Failure {
  const BackupFailure(this.reason, [this.detail]);
  final BackupFailureReason reason;

  /// Google's own error code/text, shown to help fix setup problems.
  /// (Never contains customer data.)
  final String? detail;

  @override
  List<Object?> get props => [reason, detail];
}

enum BackupFailureReason {
  /// The person closed the Google account / permission screen.
  canceled,

  /// Drive access was not granted, or was revoked.
  notAuthorized,

  /// The app's Google Cloud registration is missing or wrong (setup issue).
  notConfigured,

  /// Google sign-in failed for another reason (see the detail).
  signInFailed,

  /// There is no Sanad backup in this Google Drive.
  noBackup,

  /// Drive backup is not available on this platform.
  unsupported,
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
