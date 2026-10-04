import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../errors/failure.dart';
import '../validation/validators.dart';
import 'l10n.dart';

/// Maps domain failures and validation codes to localized, user-facing text.
extension FailureMessages on BuildContext {
  String failureMessage(Failure failure) {
    final l = l10n;
    return switch (failure) {
      NetworkFailure() => l.failureNetwork,
      ServerFailure() => l.failureServer,
      SessionExpiredFailure() => l.failureSessionExpired,
      PermissionFailure() => l.failurePermission,
      DuplicateFailure(field: 'phone') => l.failureDuplicatePhone,
      DuplicateFailure(field: 'name') => l.failureDuplicateName,
      DuplicateFailure(field: 'email') => l.failureDuplicateEmail,
      DuplicateFailure(field: 'file') => l.failureDuplicateFile,
      DuplicateFailure() => l.failureDuplicate,
      ValidationFailure() => l.failureValidation,
      NotFoundFailure() => l.failureNotFound,
      FileFailure(:final reason) => switch (reason) {
        FileFailureReason.unreadable => l.failureFileUnreadable,
        FileFailureReason.noSheets => l.failureFileNoSheets,
        FileFailureReason.headerNotFound => l.failureFileHeaderNotFound,
        FileFailureReason.empty => l.failureFileEmpty,
        FileFailureReason.writeFailed => l.failureFileWrite,
      },
      AuthFailure(:final reason) => switch (reason) {
        AuthFailureReason.invalidCredentials => l.failureAuthInvalid,
        AuthFailureReason.accountDisabled => l.failureAuthDisabled,
        AuthFailureReason.emailNotConfirmed => l.failureAuthNotConfirmed,
        AuthFailureReason.weakPassword => l.failureAuthWeakPassword,
        AuthFailureReason.rateLimited => l.failureAuthRateLimited,
        AuthFailureReason.unknown => l.failureAuthUnknown,
      },
      BusinessRuleFailure(:final rule) => ruleMessage(rule),
      _ => l.failureUnexpected,
    };
  }

  String ruleMessage(String rule) {
    final l = l10n;
    return switch (rule) {
      'nurse_inactive' => l.failureRuleNurseInactive,
      'service_inactive' => l.failureRuleServiceInactive,
      'customer_archived' => l.failureRuleCustomerArchived,
      'already_imported' => l.failureRuleAlreadyImported,
      'batch_not_found' => l.failureRuleBatchNotFound,
      'self_demotion' => l.failureRuleSelfDemotion,
      'reference_in_use' => l.failureRuleInUse,
      'permission' => l.failurePermission,
      'validation' => l.failureValidation,
      _ => l.failureServer,
    };
  }

  /// Localized message for a validation [code], or null.
  String? validationMessage(String? code) => code == null ? null : _validation(l10n, code);

  /// Field error for [field] from a [ValidationFailure], if any.
  String? fieldError(Failure? failure, String field) =>
      failure is ValidationFailure ? validationMessage(failure.fields[field]) : null;
}

String _validation(AppLocalizations l, String code) => switch (code) {
  ValidationCodes.required => l.validationRequired,
  ValidationCodes.tooLong => l.validationTooLong,
  ValidationCodes.invalidPhone => l.validationInvalidPhone,
  ValidationCodes.invalidPrice => l.validationInvalidPrice,
  ValidationCodes.negativePrice => l.validationNegativePrice,
  ValidationCodes.priceTooHigh => l.validationPriceTooHigh,
  ValidationCodes.invalidEmail => l.validationInvalidEmail,
  ValidationCodes.passwordTooShort => l.validationPasswordTooShort,
  ValidationCodes.passwordsDoNotMatch => l.validationPasswordsDoNotMatch,
  ValidationCodes.futureDate => l.validationFutureDate,
  _ => l.failureValidation,
};
