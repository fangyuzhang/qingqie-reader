import 'app_error.dart';

/// 轻量 `Result<T>` 类型：Repository 统一返回 `Result<T>`，ViewModel 无需 try/catch。
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(AppError error) = Err<T>;

  R when<R>({required R Function(T value) ok, required R Function(AppError error) err}) {
    return switch (this) {
      Ok<T>(:final value) => ok(value),
      Err<T>(:final error) => err(error),
    };
  }

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  AppError? get errorOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final error) => error,
  };

  bool get isOk => this is Ok<T>;
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.error);
  final AppError error;
}
