// lib/core/network/binance_auth_interceptor.dart

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../config/app_config.dart';

/// 바이낸스 API 요청에 HMAC-SHA256 시그니처를 추가하는 인터셉터
class BinanceAuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // API 키/시크릿이 필요한 private 엔드포인트에만 적용
    if (AppConfig.apiKey.isEmpty || AppConfig.apiSecret.isEmpty) {
      return handler.next(options);
    }
    
    // Public API는 시그니처 불필요
    if (!options.path.contains('/v1/order') && !options.path.contains('/v1/account')) {
        options.headers['X-MBX-APIKEY'] = AppConfig.apiKey;
        return handler.next(options);
    }

    // 타임스탬프 추가
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    options.queryParameters['timestamp'] = timestamp;

    // 쿼리 파라미터를 문자열로 변환
    final query = Uri(queryParameters: options.queryParameters).query;

    // HMAC-SHA256 시그니처 생성
    final key = utf8.encode(AppConfig.apiSecret);
    final bytes = utf8.encode(query);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    
    // 시그니처를 쿼리에 추가
    options.queryParameters['signature'] = digest.toString();
    options.headers['X-MBX-APIKEY'] = AppConfig.apiKey;

    return handler.next(options);
  }
}