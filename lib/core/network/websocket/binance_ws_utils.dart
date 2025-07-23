import 'dart:convert';
import 'dart:math';
import '../../config/app_config.dart';
import '../../utils/logger.dart';

/// 🎯 바이낸스 WebSocket 공통 유틸리티 클래스
class BinanceWsUtils {
  
  // ===================================================================
  // 📨 메시지 생성
  // ===================================================================

  /// 고유한 메시지 ID 생성 (바이낸스 호환)
  static int generateMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(1000);
    return timestamp * 1000 + random;
  }

  /// 바이낸스 구독 메시지 생성
  static String createSubscribeMessage(List<String> params) {
    if (params.length > AppConfig.wsMaxStreams) {
      throw ArgumentError(
        'Too many streams: ${params.length}. '
        'Binance limit: ${AppConfig.wsMaxStreams} streams per connection.'
      );
    }

    final subscribeMessage = {
      'method': 'SUBSCRIBE',
      'params': params,
      'id': generateMessageId(),
    };

    final jsonMessage = jsonEncode(subscribeMessage);
    log.d('[BinanceWS] 📤 Subscribe message: $jsonMessage');
    
    return jsonMessage;
  }

  /// 바이낸스 구독 해제 메시지 생성
  static String createUnsubscribeMessage(List<String> params) {
    final unsubscribeMessage = {
      'method': 'UNSUBSCRIBE',
      'params': params,
      'id': generateMessageId(),
    };

    final jsonMessage = jsonEncode(unsubscribeMessage);
    log.d('[BinanceWS] 📤 Unsubscribe message: $jsonMessage');
    
    return jsonMessage;
  }

  // ===================================================================
  // 📥 메시지 검증
  // ===================================================================

  /// Combined Stream 데이터 추출
  static Map<String, dynamic>? extractCombinedStreamData(
    Map<String, dynamic> json,
    String expectedStreamSuffix,
  ) {
    if (!json.containsKey('stream') || !json.containsKey('data')) {
      return null;
    }

    final streamName = json['stream'] as String?;
    final data = json['data'];

    if (streamName == null || data == null) {
      return null;
    }

    // 스트림 타입 확인
    if (!streamName.contains(expectedStreamSuffix)) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    return null;
  }

  /// Direct Stream 데이터 확인
  static bool isDirectStreamEvent(Map<String, dynamic> json, String eventType) {
    return json.containsKey('e') && json['e'] == eventType;
  }

  // ===================================================================
  // 📊 통계 유틸리티
  // ===================================================================

  /// 기본 통계 정보 생성
  static Map<String, dynamic> createBaseStatistics({
    required String streamType,
    required String updateSpeed,
    required int totalReceived,
    required int totalErrors,
    required int activeStreams,
    required DateTime? firstTime,
    required DateTime? lastTime,
    Map<String, dynamic>? additionalStats,
  }) {
    final now = DateTime.now();
    final sessionDuration = firstTime != null
        ? now.difference(firstTime)
        : Duration.zero;

    final itemsPerMinute = sessionDuration.inMinutes > 0
        ? (totalReceived / sessionDuration.inMinutes).toStringAsFixed(1)
        : '0';

    final errorRate = totalReceived > 0
        ? '${((totalErrors / (totalReceived + totalErrors)) * 100).toStringAsFixed(2)}%'
        : '0%';

    final baseStats = {
      'streamType': streamType,
      'updateSpeed': updateSpeed,
      'totalReceived': totalReceived,
      'totalErrors': totalErrors,
      'activeStreams': activeStreams,
      'sessionDurationMinutes': sessionDuration.inMinutes,
      'itemsPerMinute': itemsPerMinute,
      'errorRate': errorRate,
      'firstTime': firstTime?.toIso8601String(),
      'lastTime': lastTime?.toIso8601String(),
    };

    if (additionalStats != null) {
      baseStats.addAll(additionalStats);
    }

    return baseStats;
  }

  // ===================================================================
  // 🔧 스트림 파라미터 생성기
  // ===================================================================

  /// aggTrade 스트림 파라미터 생성
  static List<String> createAggTradeStreams(List<String> symbols) {
    return symbols.map((symbol) => '${symbol.toLowerCase()}@aggTrade').toList();
  }

  /// depth 스트림 파라미터 생성
  static List<String> createDepthStreams(List<String> symbols, {bool fast = false}) {
    final suffix = fast ? 'depth@100ms' : 'depth';
    return symbols.map((symbol) => '${symbol.toLowerCase()}@$suffix').toList();
  }

  /// bookTicker 스트림 파라미터 생성
  static List<String> createBookTickerStreams(List<String> symbols) {
    return symbols.map((symbol) => '${symbol.toLowerCase()}@bookTicker').toList();
  }

  /// kline 스트림 파라미터 생성
  static List<String> createKlineStreams(List<String> symbols, String interval) {
    return symbols.map((symbol) => '${symbol.toLowerCase()}@kline_$interval').toList();
  }

  /// ticker 스트림 파라미터 생성
  static List<String> createTickerStreams(List<String> symbols, {bool mini = false}) {
    final suffix = mini ? 'miniTicker' : 'ticker';
    return symbols.map((symbol) => '${symbol.toLowerCase()}@$suffix').toList();
  }

  /// 전체 ticker 스트림 파라미터 생성 (모든 심볼)
  static List<String> createAllTickerStreams({bool mini = false}) {
    final suffix = mini ? '!miniTicker@arr' : '!ticker@arr';
    return [suffix];
  }
}