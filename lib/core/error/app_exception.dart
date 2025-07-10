import 'package:dio/dio.dart';

/// 앱의 최상위 커스텀 예외 클래스
class AppException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.stackTrace]);

  @override
  String toString() => 'AppException: $message';
}

/// 네트워크(REST API) 관련 예외
class NetworkException extends AppException {
  final DioException? originalException;

  const NetworkException(String message, {this.originalException, StackTrace? stackTrace})
      : super(message, stackTrace);

  factory NetworkException.fromDio(DioException dioError) {
    final message = dioError.message ?? 'A network error occurred.';
    return NetworkException(
      message,
      originalException: dioError,
      stackTrace: dioError.stackTrace,
    );
  }

  @override
  String toString() => 'NetworkException: $message';
}

/// WebSocket 관련 예외
class WebSocketException extends AppException {
  const WebSocketException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
      
  @override
  String toString() => 'WebSocketException: $message';
}

/// 데이터 파싱(JSON 등) 관련 예외
class DataParsingException extends AppException {
  const DataParsingException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);

  @override
  String toString() => 'DataParsingException: $message';
}