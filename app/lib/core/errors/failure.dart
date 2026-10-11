import 'package:equatable/equatable.dart';

/// Expected failures, expressed without any UI text. The presentation layer
/// maps each one to a localized, user-facing message
/// (see `core/widgets/failure_message.dart`).
abstract class Failure extends Equatable {
  const Failure();

  @override
  List<Object?> get props => const [];
}

/// The device is offline or the Google Sheet could not be reached.
final class NetworkFailure extends Failure {
  const NetworkFailure();
}

/// The Google Sheet's script answered with an unexpected error.
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

enum FileFailureReason { unreadable, noSheets, headerNotFound, empty, writeFailed }

/// The connected Google Sheet could not be used.
final class SheetFailure extends Failure {
  const SheetFailure(this.reason, [this.detail]);
  final SheetFailureReason reason;

  /// Extra information shown to the user (e.g. the script's error message);
  /// it is never logged.
  final String? detail;

  @override
  List<Object?> get props => [reason, detail];
}

enum SheetFailureReason {
  /// Not a Sanad Web app link (or the script is not deployed there).
  invalidLink,

  /// The deployment is not open to "Anyone" (Google asked to sign in).
  accessDenied,

  /// The sheet is already paired with another phone: its code is needed.
  codeRequired,

  /// The connection code was changed in the sheet: connect again.
  notPaired,

  /// The visits sheet was deleted or renamed.
  sheetMissing,

  /// The script reported an error.
  scriptError,
}

final class UnexpectedFailure extends Failure {
  const UnexpectedFailure();
}
