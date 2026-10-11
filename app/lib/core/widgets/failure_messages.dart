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
      DuplicateFailure(field: 'phone') => l.failureDuplicatePhone,
      DuplicateFailure(field: 'name') => l.failureDuplicateName,
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
      SheetFailure(:final reason, :final detail) => [
        switch (reason) {
          SheetFailureReason.invalidLink when detail == '/dev' => l.failureSheetDevLink,
          SheetFailureReason.invalidLink => l.failureSheetInvalidLink,
          SheetFailureReason.accessDenied => l.failureSheetAccessDenied,
          SheetFailureReason.codeRequired => l.sheetCodeNeeded,
          SheetFailureReason.notPaired => l.failureSheetNotPaired,
          SheetFailureReason.sheetMissing => l.failureSheetMissing(detail ?? ''),
          SheetFailureReason.scriptError => l.failureSheetScript,
        },
        if (reason == SheetFailureReason.scriptError && detail != null && detail.isNotEmpty) '($detail)',
      ].join('\n'),
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
      'reference_in_use' => l.failureRuleInUse,
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
  ValidationCodes.futureDate => l.validationFutureDate,
  _ => l.failureValidation,
};
