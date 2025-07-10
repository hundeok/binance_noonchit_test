import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../error/app_exception.dart';
import '../utils/logger.dart';

/// 바이낸스 선물 REST API 통신을 위한 클라이언트
class ApiClient {
  final Dio _dio;

  ApiClient({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.restBaseUrl,
              connectTimeout: AppConfig.restTimeout,
              receiveTimeout: AppConfig.restTimeout,
            ));

  /// GET 요청을 위한 범용 메서드
  Future<dynamic> get(String path) async {
    try {
      log.d('[API] GET: $path');
      final response = await _dio.get(path);
      return response.data;
    } on DioException catch (e, st) {
      // ✅ 에러 로깅 방식을 positional argument로 수정
      log.e('[API] GET failed on path: $path', e, st);
      // DioException을 커스텀 NetworkException으로 변환하여 반환
      throw NetworkException.fromDio(e);
    } catch (e, st) {
      // ✅ 에러 로깅 방식을 positional argument로 수정
      log.e('[API] Unexpected error on path: $path', e, st);
      // 그 외 예외는 일반 AppException으로 처리
      throw AppException(e.toString());
    }
  }
}