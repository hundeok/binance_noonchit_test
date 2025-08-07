// lib/core/extensions/result.dart

/// 🎯 함수형 프로그래밍 Result 패턴 (Rust 스타일)
/// 성공(Ok)과 실패(Err)를 타입 안전하게 처리
sealed class Result<T, E> {
  const Result();

  /// 성공 케이스
  bool get isOk => this is Ok<T, E>;
  
  /// 실패 케이스
  bool get isErr => this is Err<T, E>;

  /// 패턴 매칭으로 결과 처리
  R when<R>({
    required R Function(T data) ok,
    required R Function(E error) err,
  }) {
    return switch (this) {
      Ok(value: final data) => ok(data),
      Err(error: final error) => err(error),
    };
  }

  /// 성공 데이터 변환
  Result<R, E> map<R>(R Function(T data) transform) {
    return when(
      ok: (data) => Ok(transform(data)),
      err: (error) => Err(error),
    );
  }

  /// 실패 에러 변환
  Result<T, R> mapError<R>(R Function(E error) transform) {
    return when(
      ok: (data) => Ok(data),
      err: (error) => Err(transform(error)),
    );
  }

  /// 성공 데이터 추출 (실패 시 예외)
  T unwrap() {
    return when(
      ok: (data) => data,
      err: (error) => throw Exception('Called unwrap on Err: $error'),
    );
  }

  /// 성공 데이터 추출 (실패 시 기본값)
  T unwrapOr(T defaultValue) {
    return when(
      ok: (data) => data,
      err: (_) => defaultValue,
    );
  }
}

/// 성공 케이스
final class Ok<T, E> extends Result<T, E> {
  final T value;
  const Ok(this.value);

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ok<T, E> && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// 실패 케이스
final class Err<T, E> extends Result<T, E> {
  final E error;
  const Err(this.error);

  @override
  String toString() => 'Err($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Err<T, E> && error == other.error;

  @override
  int get hashCode => error.hashCode;
}