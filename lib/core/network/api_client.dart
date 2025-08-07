// ===================================================================
// lib/core/network/api_client.dart
// 바이낸스 선물 REST API 클라이언트 - 공식 백서 100% 준수
// ===================================================================

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import '../config/app_config.dart';
import '../error/app_exception.dart';
import '../extensions/result.dart';
import '../utils/logger.dart';

typedef Json = Map<String, dynamic>;

// ===================================================================
// 바이낸스 선물 Rate Limiter - 공식 백서 기준
// ===================================================================

/// 바이낸스 선물 Rate Limit 정보
class BinanceRateLimit {
  final String rateLimitType; // REQUEST_WEIGHT, ORDER, RAW_REQUEST
  final String interval;      // SECOND, MINUTE
  final int intervalNum;      // 1, 10, etc
  final int limit;           // 제한값

  const BinanceRateLimit({
    required this.rateLimitType,
    required this.interval,
    required this.intervalNum,
    required this.limit,
  });

  factory BinanceRateLimit.fromJson(Json json) {
    return BinanceRateLimit(
      rateLimitType: json['rateLimitType'] as String,
      interval: json['interval'] as String,
      intervalNum: json['intervalNum'] as int,
      limit: json['limit'] as int,
    );
  }

  Duration get duration {
    switch (interval) {
      case 'SECOND':
        return Duration(seconds: intervalNum);
      case 'MINUTE':
        return Duration(minutes: intervalNum);
      case 'HOUR':
        return Duration(hours: intervalNum);
      case 'DAY':
        return Duration(days: intervalNum);
      default:
        return Duration(seconds: intervalNum);
    }
  }

  @override
  String toString() => '$rateLimitType: $limit/$intervalNum$interval';
}

/// 바이낸스 선물 전용 Rate Limiter
class BinanceFuturesRateLimiter {
  final Map<String, Queue<DateTime>> _requestTimes = {};
  final Map<String, BinanceRateLimit> _limits = {};
  
  // 서버에서 받은 사용량 정보
  int _currentWeight = 0;
  int _currentOrderCount = 0;
  DateTime _lastUpdateTime = DateTime.now();

  /// exchangeInfo에서 받은 rate limit 정보 설정
  void updateLimits(List<BinanceRateLimit> limits) {
    _limits.clear();
    for (final limit in limits) {
      final key = '${limit.rateLimitType}_${limit.interval}_${limit.intervalNum}';
      _limits[key] = limit;
    }
    log.i('Rate limits updated: ${_limits.length} rules');
  }

  /// 응답 헤더에서 사용량 정보 업데이트
  void updateFromHeaders(Map<String, List<String>> headers) {
    try {
      // X-MBX-USED-WEIGHT-1M 형태의 헤더 파싱
      for (final entry in headers.entries) {
        final key = entry.key.toLowerCase();
        final value = entry.value.isNotEmpty ? entry.value.first : '';
        
        if (key.startsWith('x-mbx-used-weight') && value.isNotEmpty) {
          _currentWeight = int.tryParse(value) ?? _currentWeight;
        } else if (key.startsWith('x-mbx-order-count') && value.isNotEmpty) {
          _currentOrderCount = int.tryParse(value) ?? _currentOrderCount;
        }
      }
      
      _lastUpdateTime = DateTime.now();
    } catch (e) {
      log.w('Failed to parse rate limit headers: $e');
    }
  }

  /// Rate limit 체크 및 대기
  Future<void> throttle({
    required String endpoint,
    required int weight,
    bool isOrder = false,
  }) async {
    final now = DateTime.now();
    
    // REQUEST_WEIGHT 체크 (1분당 2400)
    await _throttleByType('REQUEST_WEIGHT_MINUTE_1', weight, now);
    
    // ORDER 제한 체크 (필요시)
    if (isOrder) {
      await _throttleByType('ORDERS_SECOND_10', 1, now);
      await _throttleByType('ORDERS_MINUTE_1', 1, now);
    }
    
    // RAW_REQUEST 체크 (초당 제한)
    await _throttleByType('RAW_REQUEST_SECOND_1', 1, now);
  }

  Future<void> _throttleByType(String limitKey, int cost, DateTime now) async {
    final limit = _limits[limitKey];
    if (limit == null) return;

    final queue = _requestTimes.putIfAbsent(limitKey, () => Queue<DateTime>());
    
    // 오래된 요청 정리
    while (queue.isNotEmpty && 
           now.difference(queue.first) > limit.duration) {
      queue.removeFirst();
    }

    // 현재 사용량 계산
    final currentUsage = queue.length * cost;
    
    // 제한 초과시 대기
    if (currentUsage + cost > limit.limit) {
      final waitTime = limit.duration - now.difference(queue.first);
      if (waitTime > Duration.zero) {
        log.d('Rate limit wait: ${waitTime.inMilliseconds}ms for $limitKey');
        await Future.delayed(waitTime);
      }
      
      // 다시 정리
      final newNow = DateTime.now();
      while (queue.isNotEmpty && 
             newNow.difference(queue.first) > limit.duration) {
        queue.removeFirst();
      }
    }

    // 요청 기록
    queue.addLast(now);
  }

  /// 현재 사용률 정보
  Map<String, dynamic> getUsageInfo() {
    return {
      'currentWeight': _currentWeight,
      'currentOrderCount': _currentOrderCount,
      'lastUpdate': _lastUpdateTime.toIso8601String(),
      'activeLimits': _limits.keys.toList(),
      'requestQueues': {
        for (final entry in _requestTimes.entries)
          entry.key: entry.value.length,
      },
    };
  }

  void dispose() {
    _requestTimes.clear();
    _limits.clear();
  }
}

// ===================================================================
// 바이낸스 선물 인증 처리
// ===================================================================

class BinanceFuturesAuth {
  final String apiKey;
  final String secretKey;

  const BinanceFuturesAuth({
    required this.apiKey,
    required this.secretKey,
  });

  /// HMAC SHA256 서명 생성
  String generateSignature(String queryString) {
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(queryString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  /// 타임스탬프 추가된 쿼리 스트링 생성
  String addTimestamp(String? queryString, {int? recvWindow}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final params = <String>[];
    
    if (queryString != null && queryString.isNotEmpty) {
      params.add(queryString);
    }
    
    if (recvWindow != null) {
      params.add('recvWindow=$recvWindow');
    }
    
    params.add('timestamp=$timestamp');
    
    return params.join('&');
  }
}

// ===================================================================
// 바이낸스 선물 API 클라이언트
// ===================================================================

class ApiClient {
  final Dio _dio;
  final BinanceFuturesRateLimiter _rateLimiter;
  final BinanceFuturesAuth? _auth;
  
  // 캐시
  final Map<String, _CacheEntry> _cache = {};
  static const int _maxCacheSize = 100;
  
  ApiClient({
    Dio? dio,
    String? apiKey,
    String? secretKey,
  }) : _dio = dio ?? Dio(BaseOptions(
          baseUrl: AppConfig.restBaseUrl,
          connectTimeout: AppConfig.restTimeout,
          receiveTimeout: AppConfig.restTimeout,
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        )),
        _rateLimiter = BinanceFuturesRateLimiter(),
        _auth = (apiKey != null && secretKey != null) 
            ? BinanceFuturesAuth(apiKey: apiKey, secretKey: secretKey)
            : null {
    
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // API 키 헤더 추가
          if (_auth != null) {
            options.headers['X-MBX-APIKEY'] = _auth!.apiKey;
          }
          
          handler.next(options);
        },
        onResponse: (response, handler) {
          // Rate limit 정보 업데이트
          _rateLimiter.updateFromHeaders(response.headers.map);
          handler.next(response);
        },
        onError: (error, handler) {
          log.e('API Request failed: ${error.message}');
          handler.next(error);
        },
      ),
    );
    
    // 시작 시 rate limit 정보 가져오기
    _initializeRateLimits();
  }

  /// Rate limit 정보 초기화
  Future<void> _initializeRateLimits() async {
    try {
      final result = await get('/fapi/v1/exchangeInfo');
      result.when(
        ok: (data) {
          final rateLimitsJson = data['rateLimits'] as List?;
          if (rateLimitsJson != null) {
            final limits = rateLimitsJson
                .map((json) => BinanceRateLimit.fromJson(json as Json))
                .toList();
            _rateLimiter.updateLimits(limits);
          }
        },
        err: (error) {
          log.w('Failed to fetch rate limits: $error');
          // 기본값 설정
          _rateLimiter.updateLimits([
            const BinanceRateLimit(
              rateLimitType: 'REQUEST_WEIGHT',
              interval: 'MINUTE',
              intervalNum: 1,
              limit: 2400,
            ),
            const BinanceRateLimit(
              rateLimitType: 'ORDERS',
              interval: 'SECOND',
              intervalNum: 10,
              limit: 300,
            ),
            const BinanceRateLimit(
              rateLimitType: 'ORDERS',
              interval: 'MINUTE',
              intervalNum: 1,
              limit: 1200,
            ),
          ]);
        },
      );
    } catch (e) {
      log.w('Rate limit initialization failed: $e');
    }
  }

  /// GET 요청 (공개 API)
  Future<Result<dynamic, AppException>> get(
    String path, {
    Json? query,
    Duration? cacheDur,
    int weight = 1,
  }) async {
    // 캐시 확인
    if (cacheDur != null) {
      final cached = _getFromCache(path, query);
      if (cached != null) {
        return Ok(cached);
      }
    }

    try {
      // Rate limiting
      await _rateLimiter.throttle(
        endpoint: path,
        weight: weight,
        isOrder: false,
      );

      final response = await _dio.get(
        path,
        queryParameters: query,
      );

      final data = response.data;
      
      // 캐시 저장
      if (cacheDur != null && data != null) {
        _putToCache(path, query, data, cacheDur);
      }

      return Ok(data);

    } on DioException catch (e) {
      return Err(_handleDioException(e));
    } catch (e, stackTrace) {
      return Err(AppException.network(
        'Unexpected error: $e\nStack: ${stackTrace.toString()}'
      ));
    }
  }

  /// POST 요청 (인증 필요)
  Future<Result<dynamic, AppException>> post(
    String path, {
    Json? query,
    Json? body,
    int weight = 1,
    bool isOrder = false,
    int? recvWindow,
  }) async {
    if (_auth == null) {
      return Err(AppException.config('API authentication required'));
    }

    try {
      // Rate limiting
      await _rateLimiter.throttle(
        endpoint: path,
        weight: weight,
        isOrder: isOrder,
      );

      // 서명 생성
      final queryString = _buildQueryString(query);
      final bodyString = _buildQueryString(body);
      final allParams = [queryString, bodyString]
          .where((s) => s.isNotEmpty)
          .join('&');
      
      final signedParams = _auth!.addTimestamp(allParams, recvWindow: recvWindow);
      final signature = _auth!.generateSignature(signedParams);
      
      // 최종 데이터 준비
      final finalData = '$signedParams&signature=$signature';

      final response = await _dio.post(
        path,
        data: finalData,
        queryParameters: query,
      );

      return Ok(response.data);

    } on DioException catch (e) {
      return Err(_handleDioException(e));
    } catch (e, stackTrace) {
      return Err(AppException.network(
        'Unexpected error: $e\nStack: ${stackTrace.toString()}'
      ));
    }
  }

  /// DELETE 요청 (주문 취소 등)
  Future<Result<dynamic, AppException>> delete(
    String path, {
    Json? query,
    int weight = 1,
    int? recvWindow,
  }) async {
    if (_auth == null) {
      return Err(AppException.config('API authentication required'));
    }

    try {
      // Rate limiting
      await _rateLimiter.throttle(
        endpoint: path,
        weight: weight,
        isOrder: true,
      );

      // 서명 생성
      final queryString = _buildQueryString(query);
      final signedParams = _auth!.addTimestamp(queryString, recvWindow: recvWindow);
      final signature = _auth!.generateSignature(signedParams);
      
      final response = await _dio.delete(
        '$path?$signedParams&signature=$signature',
      );

      return Ok(response.data);

    } on DioException catch (e) {
      return Err(_handleDioException(e));
    } catch (e, stackTrace) {
      return Err(AppException.network(
        'Unexpected error: $e\nStack: ${stackTrace.toString()}'
      ));
    }
  }

  // ===================================================================
  // 헬퍼 메서드들
  // ===================================================================

  String _buildQueryString(Json? params) {
    if (params == null || params.isEmpty) return '';
    
    return params.entries
        .where((e) => e.value != null)
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  AppException _handleDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException.network(
          'Connection timeout: ${e.message}',
          code: 'TIMEOUT',
        );

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;

        // 바이낸스 API 에러 처리
        if (responseData is Map && responseData.containsKey('code')) {
          return AppException.binanceApi(
            responseData['msg'] ?? 'Binance API error',
            responseData['code'] as int?,
          );
        }

        // HTTP 상태코드별 처리
        switch (statusCode) {
          case 403:
            return AppException.network(
              'WAF Limit violated - IP temporarily banned',
              code: 'WAF_LIMIT',
            );
          case 418:
            return AppException.network(
              'IP auto-banned for rate limit violations',
              code: 'IP_BANNED',
            );
          case 429:
            return AppException.network(
              'Rate limit exceeded - backing off required',
              code: 'RATE_LIMIT',
            );
          case 503:
            return AppException.network(
              'Service unavailable - retry later',
              code: 'SERVICE_UNAVAILABLE',
            );
          default:
            return AppException.network(
              'HTTP Error $statusCode: ${e.message}',
              code: 'HTTP_$statusCode',
            );
        }

      case DioExceptionType.connectionError:
        return AppException.network(
          'Connection error: ${e.message}',
          code: 'CONNECTION_ERROR',
        );

      case DioExceptionType.badCertificate:
        return AppException.network(
          'SSL Certificate error: ${e.message}',
          code: 'SSL_ERROR',
        );

      case DioExceptionType.cancel:
        return AppException.network(
          'Request cancelled: ${e.message}',
          code: 'CANCELLED',
        );

      case DioExceptionType.unknown:
      default:
        return AppException.network(
          'Unknown network error: ${e.message}',
          code: 'UNKNOWN_NETWORK_ERROR',
        );
    }
  }

  // ===================================================================
  // 캐시 관리
  // ===================================================================

  dynamic _getFromCache(String path, Json? query) {
    final key = _cacheKey(path, query);
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.data;
    }
    _cache.remove(key);
    return null;
  }

  void _putToCache(String path, Json? query, dynamic data, Duration duration) {
    final key = _cacheKey(path, query);
    
    // 캐시 크기 제한
    if (_cache.length >= _maxCacheSize) {
      final oldestKey = _cache.keys.first;
      _cache.remove(oldestKey);
    }
    
    _cache[key] = _CacheEntry(data, DateTime.now().add(duration));
  }

  String _cacheKey(String path, Json? query) {
    final queryStr = query?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&') ?? '';
    return '$path?$queryStr';
  }

  // ===================================================================
  // 상태 정보
  // ===================================================================

  /// 현재 API 클라이언트 상태
  Map<String, dynamic> getStatus() {
    return {
      'baseUrl': _dio.options.baseUrl,
      'hasAuth': _auth != null,
      'cacheSize': _cache.length,
      'rateLimiter': _rateLimiter.getUsageInfo(),
    };
  }

  /// 리소스 정리
  void dispose() {
    _rateLimiter.dispose();
    _cache.clear();
    _dio.close();
  }
}

// ===================================================================
// 캐시 엔트리 클래스
// ===================================================================

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry(this.data, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}