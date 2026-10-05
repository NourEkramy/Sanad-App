import 'dart:async';
import 'dart:io' show SocketException, HttpException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:sqflite/sqflite.dart' show DatabaseException;

import '../result/result.dart';
import 'failure.dart';

/// Translates infrastructure exceptions into domain [Failure]s.
///
/// Only the failure *type* and stable codes cross this boundary; raw
/// messages (which can contain customer data) are never shown or logged.
class ErrorMapper {
  const ErrorMapper._();

  static Failure map(Object error) {
    if (error is Failure) return error;
    if (error is DatabaseException) return _database(error);
    if (error is SocketException || error is TimeoutException || error is HttpException || error is ClientException) {
      return const NetworkFailure();
    }
    return const UnexpectedFailure();
  }

  static Failure _database(DatabaseException e) {
    final message = e.toString();
    if (e.isUniqueConstraintError()) {
      // "UNIQUE constraint failed: customers.phone"
      final column = RegExp(r'UNIQUE constraint failed: \w+\.(\w+)').firstMatch(message)?.group(1);
      return DuplicateFailure(switch (column) {
        'phone' => 'phone',
        'file_sha256' => 'file',
        'name_normalized' => 'name',
        _ => 'value',
      });
    }
    if (message.contains('FOREIGN KEY constraint failed')) return const BusinessRuleFailure('reference_in_use');
    if (message.contains('CHECK constraint failed') || e.isNotNullConstraintError()) {
      return const ValidationFailure({});
    }
    return const UnexpectedFailure();
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
