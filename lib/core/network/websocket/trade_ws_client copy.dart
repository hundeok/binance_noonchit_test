import 'dart:convert';
import 'dart:math';
import '../../config/app_config.dart';
import '../../../domain/entities/trade.dart';
import '../../utils/logger.dart';
import 'base_ws_client.dart';

/// 🎯 바이낸스 선물 멀티 스트림 클라이언트 (백서 100% 준수)
/// aggTrade + ticker + bookTicker + depth5 통합 지원
class TradeWsClient extends BaseWsClient<Trade> {
  
  /// ✅ [추가] 구독할 스트림 구성 설정
  final StreamSubscriptionConfig config;
  final bool enableVerboseLogging;

  TradeWsClient({
    void Function(WsStatus status)? onStatusChange,
    this.enableVerboseLogging = false,
    StreamSubscriptionConfig? config,
  }) : config = config ?? StreamSubscriptionConfig.defaultConfig(),
        super(
          url: AppConfig.streamUrl,
          onStatusChange: onStatusChange,
          pongTimeout: AppConfig.wsPongTimeout,
          // ✅ maxStreams, maxMessagesPerSec 제거 (AppConfig 기본값 자동 사용)
          encodeSubscribe: (markets) => _encodeSubscribeMessage(markets, config ?? StreamSubscriptionConfig.defaultConfig()),
          decode: (json) => _decodeTradeMessage(json, enableVerboseLogging),
        );

  // ===================================================================
  // 📨 멀티 스트림 구독 메시지 인코딩 (바이낸스 백서 준수)
  // ===================================================================

  static String _encodeSubscribeMessage(List<String> markets, StreamSubscriptionConfig config) {
    final params = <String>[];
    
    // 스트림 개수 계산 및 제한 체크
    final totalStreams = _calculateTotalStreams(markets.length, config);
    if (totalStreams > AppConfig.wsMaxStreams) {
      throw ArgumentError('Too many streams: $totalStreams. '
          'Binance limit: ${AppConfig.wsMaxStreams} streams per connection.');
    }

    // ✅ 1. aggTrade 스트림 (상세 거래 데이터)
    if (config.aggTradeCount > 0) {
      final aggTradeMarkets = markets.take(config.aggTradeCount);
      params.addAll(
        aggTradeMarkets.map((symbol) => '${symbol.toLowerCase()}@aggTrade'),
      );
      log.i('[TradeWS] 📈 Added ${aggTradeMarkets.length} aggTrade streams');
    }

    // ✅ 2. ticker 스트림 (24시간 통계)
    if (config.tickerCount > 0) {
      final tickerMarkets = markets.take(config.tickerCount);
      params.addAll(
        tickerMarkets.map((symbol) => '${symbol.toLowerCase()}@ticker'),
      );
      log.i('[TradeWS] 📊 Added ${tickerMarkets.length} ticker streams');
    }

    // ✅ 3. bookTicker 스트림 (최고 호가)
    if (config.bookTickerCount > 0) {
      final bookTickerMarkets = markets.take(config.bookTickerCount);
      params.addAll(
        bookTickerMarkets.map((symbol) => '${symbol.toLowerCase()}@bookTicker'),
      );
      log.i('[TradeWS] 💰 Added ${bookTickerMarkets.length} bookTicker streams');
    }

    // ✅ 4. depth5 스트림 (5단계 호가창)
    if (config.depth5Count > 0) {
      final depth5Markets = markets.take(config.depth5Count);
      params.addAll(
        depth5Markets.map((symbol) => '${symbol.toLowerCase()}@depth5'),
      );
      log.i('[TradeWS] 📋 Added ${depth5Markets.length} depth5 streams');
    }

    final messageId = _generateUniqueMessageId();
    final subscribeMessage = {
      'method': 'SUBSCRIBE',
      'params': params,
      'id': messageId,
    };

    final jsonMessage = jsonEncode(subscribeMessage);

    log.i('[TradeWS] 🎯 총 ${params.length}개 스트림 구독 (Markets: ${markets.length})');
    log.d('[TradeWS] Subscription message: $jsonMessage');

    return jsonMessage;
  }

  /// 총 스트림 개수 계산
  static int _calculateTotalStreams(int marketCount, StreamSubscriptionConfig config) {
    return [
      config.aggTradeCount,
      config.tickerCount,
      config.bookTickerCount,
      config.depth5Count,
    ].map((count) => count > marketCount ? marketCount : count).fold(0, (a, b) => a + b);
  }

  /// 🎯 바이낸스 호환 고유 메시지 ID 생성 (String 반환)
  static String _generateUniqueMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = Random().nextInt(99999).toString().padLeft(5, '0');
    return '$timestamp$randomPart';
  }

  // ===================================================================
  // 📥 멀티 스트림 메시지 디코딩 (바이낸스 Combined Stream 처리)
  // ===================================================================

  static Trade? _decodeTradeMessage(Map<String, dynamic> json, bool verboseLogging) {
    if (json.isEmpty) {
      if (verboseLogging) log.w('[TradeWS] Empty message received');
      return null;
    }

    // 구독 확인 메시지 처리
    if (json.containsKey('result')) {
      if (json['result'] == null) {
        log.i('[TradeWS] ✅ Subscription confirmed: ${json['id']}');
      } else if (json['result'] is List) {
        final subscriptions = json['result'] as List;
        log.i('[TradeWS] 📋 Active subscriptions: ${subscriptions.length}');
        if (verboseLogging) {
          log.d('[TradeWS] Subscriptions: $subscriptions');
        }
      }
      return null;
    }

    // Combined Stream 메시지 처리
    if (json.containsKey('stream') && json.containsKey('data')) {
      final streamName = json['stream'] as String?;
      final data = json['data'];

      if (streamName == null || data == null) {
        return null;
      }

      return _parseStreamData(streamName, data, verboseLogging);
    }

    // Direct Stream 메시지 처리 (Combined 아닌 경우)
    if (json.containsKey('e')) {
      final eventType = json['e'] as String;
      return _parseDirectStreamData(eventType, json, verboseLogging);
    }

    if (verboseLogging) {
      log.w('[TradeWS] Unknown message type: ${json.keys.join(', ')}');
    }
    return null;
  }

  /// ✅ Combined Stream 데이터 파싱
  static Trade? _parseStreamData(String streamName, dynamic data, bool verboseLogging) {
    try {
      if (data is! Map<String, dynamic>) {
        return null;
      }

      // 스트림 타입 판별
      if (streamName.endsWith('@aggTrade')) {
        return _parseAggTradeData(data, streamName, verboseLogging);
      } else if (streamName.endsWith('@ticker')) {
        return _parseTickerData(data, streamName, verboseLogging);
      } else if (streamName.endsWith('@bookTicker')) {
        return _parseBookTickerData(data, streamName, verboseLogging);
      } else if (streamName.endsWith('@depth5')) {
        return _parseDepth5Data(data, streamName, verboseLogging);
      }

      if (verboseLogging) {
        log.w('[TradeWS] Unsupported stream type: $streamName');
      }
      return null;
    } catch (e, st) {
      log.e('[TradeWS] Stream parsing failed ($streamName)', e, st);
      return null;
    }
  }

  /// ✅ Direct Stream 데이터 파싱
  static Trade? _parseDirectStreamData(String eventType, Map<String, dynamic> data, bool verboseLogging) {
    try {
      switch (eventType) {
        case 'aggTrade':
          return _parseAggTradeData(data, 'direct', verboseLogging);
        case '24hrTicker':
          return _parseTickerData(data, 'direct', verboseLogging);
        default:
          if (verboseLogging) {
            log.w('[TradeWS] Unsupported event type: $eventType');
          }
          return null;
      }
    } catch (e, st) {
      log.e('[TradeWS] Direct stream parsing failed ($eventType)', e, st);
      return null;
    }
  }

  /// 🎯 aggTrade 데이터 파싱
  static Trade? _parseAggTradeData(Map<String, dynamic> data, String streamInfo, bool verboseLogging) {
    if (data['e'] != 'aggTrade') return null;

    final trade = Trade.fromAggTrade(data);

    if (verboseLogging) {
      final symbol = data['s'] as String? ?? 'UNKNOWN';
      final price = data['p'] as String? ?? '0';
      final quantity = data['q'] as String? ?? '0';
      log.d('[TradeWS] 💰 $symbol: $price × $quantity (aggTrade: $streamInfo)');
    }

    return trade;
  }

  /// ✅ ticker 데이터 파싱
  static Trade? _parseTickerData(Map<String, dynamic> data, String streamInfo, bool verboseLogging) {
    if (data['e'] != '24hrTicker') return null;

    final trade = Trade.fromTicker(data);

    if (verboseLogging) {
      final symbol = data['s'] as String? ?? 'UNKNOWN';
      final price = data['c'] as String? ?? '0';
      final change = data['P'] as String? ?? '0';
      log.d('[TradeWS] 📊 $symbol: $price ($change%) (ticker: $streamInfo)');
    }

    return trade;
  }

  /// ✅ bookTicker 데이터 파싱
  static Trade? _parseBookTickerData(Map<String, dynamic> data, String streamInfo, bool verboseLogging) {
    // bookTicker에는 'e' 필드가 없음
    if (!data.containsKey('u') || !data.containsKey('s')) return null;

    final trade = Trade.fromBookTicker(data);

    if (verboseLogging) {
      final symbol = data['s'] as String? ?? 'UNKNOWN';
      final bidPrice = data['b'] as String? ?? '0';
      final askPrice = data['a'] as String? ?? '0';
      log.d('[TradeWS] 💰 $symbol: bid $bidPrice / ask $askPrice (bookTicker: $streamInfo)');
    }

    return trade;
  }

  /// ✅ depth5 데이터 파싱
  static Trade? _parseDepth5Data(Map<String, dynamic> data, String streamInfo, bool verboseLogging) {
    if (!data.containsKey('bids') || !data.containsKey('asks')) return null;

    // streamInfo에서 심볼 추출
    final symbol = _extractSymbolFromStreamName(streamInfo);
    final trade = Trade.fromDepth5(data, symbol);

    if (verboseLogging) {
      final bids = data['bids'] as List;
      final asks = data['asks'] as List;
      final bestBid = bids.isNotEmpty ? bids[0][0] : '0';
      final bestAsk = asks.isNotEmpty ? asks[0][0] : '0';
      log.d('[TradeWS] 📋 $symbol: bid $bestBid / ask $bestAsk (depth5: $streamInfo)');
    }

    return trade;
  }

  /// 스트림 이름에서 심볼 추출
  static String _extractSymbolFromStreamName(String streamName) {
    if (streamName.contains('@')) {
      return streamName.split('@')[0].toUpperCase();
    }
    return 'UNKNOWN';
  }

  // ===================================================================
  // 📊 디버그 및 모니터링
  // ===================================================================

  /// 현재 구독 설정 정보
  Map<String, dynamic> getSubscriptionInfo() {
    return {
      'config': config.toMap(),
      'estimatedStreams': _calculateTotalStreams(100, config), // 가정: 100개 마켓
      'estimatedMessageRate': _estimateMessageRate(),
      'verboseLogging': enableVerboseLogging,
    };
  }

  /// 예상 메시지 속도 계산
  int _estimateMessageRate() {
    return config.aggTradeCount * 50 +    // aggTrade: ~50/초
           config.tickerCount * 1 +       // ticker: ~1/초
           config.bookTickerCount * 10 +  // bookTicker: ~10/초
           config.depth5Count * 10;       // depth5: ~10/초
  }
}

/// ✅ 스트림 구독 설정 클래스
class StreamSubscriptionConfig {
  final int aggTradeCount;     // aggTrade 스트림 개수
  final int tickerCount;       // ticker 스트림 개수  
  final int bookTickerCount;   // bookTicker 스트림 개수
  final int depth5Count;       // depth5 스트림 개수

  const StreamSubscriptionConfig({
    this.aggTradeCount = 0,
    this.tickerCount = 0,
    this.bookTickerCount = 0,
    this.depth5Count = 0,
  });

  /// 기본 설정 (우리가 계획한 400개 스트림)
  factory StreamSubscriptionConfig.defaultConfig() {
    return const StreamSubscriptionConfig(
      aggTradeCount: 100,    // Trade + Volume용
      tickerCount: 150,      // Surge용
      bookTickerCount: 100,  // 호가용
      depth5Count: 50,       // 세부 호가용
    );
  }

  /// aggTrade만 구독 (기존 방식 호환)
  factory StreamSubscriptionConfig.aggTradeOnly(int count) {
    return StreamSubscriptionConfig(aggTradeCount: count);
  }

  /// 보수적 설정 (적은 스트림)
  factory StreamSubscriptionConfig.conservative() {
    return const StreamSubscriptionConfig(
      aggTradeCount: 30,
      tickerCount: 50,
      bookTickerCount: 30,
      depth5Count: 20,
    );
  }

  /// 총 스트림 개수
  int get totalCount => aggTradeCount + tickerCount + bookTickerCount + depth5Count;

  /// 맵으로 변환
  Map<String, dynamic> toMap() {
    return {
      'aggTradeCount': aggTradeCount,
      'tickerCount': tickerCount,
      'bookTickerCount': bookTickerCount,
      'depth5Count': depth5Count,
      'totalCount': totalCount,
    };
  }

  @override
  String toString() {
    return 'StreamConfig(aggTrade: $aggTradeCount, ticker: $tickerCount, '
           'bookTicker: $bookTickerCount, depth5: $depth5Count, total: $totalCount)';
  }
}