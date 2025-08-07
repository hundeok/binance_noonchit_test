// lib/core/error/app_exception.dart

/// 🎯 애플리케이션 전용 예외 클래스
/// 바이낸스 거래 시스템에서 발생할 수 있는 모든 예외를 구조화
class AppException implements Exception {
  final String message;
  final String? code;
  final Map<String, dynamic>? details;
  final DateTime timestamp;

  AppException(
    this.message, {
    this.code,
    this.details,
  }) : timestamp = DateTime.now();

  /// 네트워크 관련 예외
  factory AppException.network(String message, {String? code}) {
    return AppException(
      message,
      code: code ?? 'NETWORK_ERROR',
      details: {'type': 'network'},
    );
  }

  /// WebSocket 관련 예외
  factory AppException.websocket(String message, {String? code}) {
    return AppException(
      message,
      code: code ?? 'WEBSOCKET_ERROR',
      details: {'type': 'websocket'},
    );
  }

  /// 데이터 파싱 관련 예외
  factory AppException.parsing(String message, {Map<String, dynamic>? rawData}) {
    return AppException(
      message,
      code: 'PARSING_ERROR',
      details: {'type': 'parsing', 'rawData': rawData},
    );
  }

  /// 비즈니스 로직 관련 예외
  factory AppException.business(String message, {String? code}) {
    return AppException(
      message,
      code: code ?? 'BUSINESS_ERROR',
      details: {'type': 'business'},
    );
  }

  /// 바이낸스 API 관련 예외
  factory AppException.binanceApi(String message, int? errorCode) {
    return AppException(
      message,
      code: 'BINANCE_API_ERROR',
      details: {'type': 'binance_api', 'errorCode': errorCode},
    );
  }

  /// 설정/구성 관련 예외
  factory AppException.config(String message) {
    return AppException(
      message,
      code: 'CONFIG_ERROR',
      details: {'type': 'config'},
    );
  }

  @override
  String toString() {
    final buffer = StringBuffer('AppException: $message');
    if (code != null) buffer.write(' (Code: $code)');
    if (details != null) buffer.write(' Details: $details');
    return buffer.toString();
  }

  /// JSON 직렬화
  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'code': code,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// JSON 역직렬화
  factory AppException.fromJson(Map<String, dynamic> json) {
    return AppException(
      json['message'] as String,
      code: json['code'] as String?,
      details: json['details'] as Map<String, dynamic>?,
    );
  }
}