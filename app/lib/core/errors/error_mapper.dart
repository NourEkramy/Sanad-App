import 'dart:async';
import 'dart:io' show SocketException, HttpException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../result/result.dart';
import 'failure.dart';

/// Translates infrastructure exceptions into domain [Failure]s.
///
/// Only the failure *type* and stable codes cross this boundary; raw server
/// messages (which can contain customer data) are never shown or logged.
class ErrorMapper {
  const ErrorMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is AuthException) return _auth(error);
    if (error is PostgrestException) return _postgrest(error);
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException ||
        error is ClientException) {
      return const NetworkFailure();
    }
    if (error is FunctionException) {
      return switch (error.status) {
        401 => const SessionExpiredFailure(),
        403 => const PermissionFailure(),
        409 => const DuplicateFailure('email'),
        _ => const ServerFailure('function'),
      };
    }
    return const UnexpectedFailure();
  }

  static Failure _postgrest(PostgrestException e) {
    final code = e.code ?? '';
    switch (code) {
      case '23505':
        return DuplicateFailure(_duplicateField(e));
      case '42501':
        return const PermissionFailure();
      case '23514':
      case '23502':
      case '22P02':
        return const ValidationFailure({});
      case '23503':
        return const BusinessRuleFailure('reference_in_use');
      case 'P0001':
        return BusinessRuleFailure(e.hint ?? 'rule');
      case 'PGRST301':
      case 'PGRST302':
        return const SessionExpiredFailure();
      case 'PGRST116':
        return const NotFoundFailure();
    }
    if (e.message.toLowerCase().contains('jwt expired')) {
      return const SessionExpiredFailure();
    }
    return ServerFailure(code.isEmpty ? null : code);
  }

  static String _duplicateField(PostgrestException e) {
    final detail = '${e.message} ${e.details ?? ''}';
    if (detail.contains('phone')) return 'phone';
    if (detail.contains('name')) return 'name';
    if (detail.contains('file_sha256')) return 'file';
    return 'value';
  }

  static Failure _auth(AuthException e) {
    if (e is AuthRetryableFetchException) return const NetworkFailure();
    if (e is AuthSessionMissingException) return const SessionExpiredFailure();
    if (e is AuthWeakPasswordException) return const AuthFailure(AuthFailureReason.weakPassword);
    final code = e.code ?? '';
    return switch (code) {
      'invalid_credentials' => const AuthFailure(AuthFailureReason.invalidCredentials),
      'user_banned' => const AuthFailure(AuthFailureReason.accountDisabled),
      'email_not_confirmed' => const AuthFailure(AuthFailureReason.emailNotConfirmed),
      'over_request_rate_limit' || 'over_email_send_rate_limit' =>
        const AuthFailure(AuthFailureReason.rateLimited),
      'session_expired' || 'refresh_token_not_found' || 'session_not_found' =>
        const SessionExpiredFailure(),
      _ => e.statusCode == '400'
          ? const AuthFailure(AuthFailureReason.invalidCredentials)
          : const AuthFailure(AuthFailureReason.unknown),
    };
  }
}

/// Runs [body] and converts any thrown error into a [Result].
Future<Result<T>> guard<T>(Future<T> Function() body) async {
  try {
    return Result.success(await body());
  } catch (error, stack) {
    final failure = ErrorMapper.map(error);
    if (failure is UnexpectedFailure || failure is ServerFailure) {
      // Type only — never the message, which may echo customer data.
      debugPrint('Sanad: ${error.runtimeType} mapped to ${failure.runtimeType}');
      if (kDebugMode) debugPrintStack(stackTrace: stack, maxFrames: 8);
    }
    return Result.failure(failure);
  }
}
