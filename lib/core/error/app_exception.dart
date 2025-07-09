// lib/core/error/app_exception.dart

import 'package:dio/dio.dart';

/// 최상위 앱 예외
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => 'AppException: $message';
}

/// 네트워크 예외
class NetworkException extends AppException {
  const NetworkException(String message) : super(message);

  factory NetworkException.fromDio(DioException dioError) {
    return NetworkException(dioError.message ?? 'Network error occurred');
  }
}