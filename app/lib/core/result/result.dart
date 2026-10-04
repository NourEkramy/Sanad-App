import '../errors/failure.dart';

/// Outcome of an operation that can fail in an expected way.
///
/// Repositories and use cases return [Result] instead of throwing so that
/// every failure path is visible to (and handled by) the caller.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(Failure failure) = Err<T>;

  bool get isSuccess => this is Success<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(:final value) => value,
        Err<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        Err<T>(:final failure) => failure,
      };

  R fold<R>(R Function(Failure failure) onFailure, R Function(T value) onSuccess) =>
      switch (this) {
        Success<T>(:final value) => onSuccess(value),
        Err<T>(:final failure) => onFailure(failure),
      };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success<T>(:final value) => Success<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };
}

final class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);
  final Failure failure;
}

/// Convenience for operations that have no meaningful return value.
typedef VoidResult = Result<void>;

const VoidResult ok = Success<void>(null);
