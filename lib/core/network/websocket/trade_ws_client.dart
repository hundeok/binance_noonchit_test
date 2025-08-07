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
  // 📨 계층적 멀티 스트림 구독 메시지 인코딩 (중복 방지)
  // ===================================================================

  static String _encodeSubscribeMessage(List<String> markets, StreamSubscriptionConfig config) {
    final params = <String>[];
    
    // 스트림 개수 계산 및 제한 체크
    final totalStreams = _calculateTotalStreams(markets.length, config);
    if (totalStreams > AppConfig.wsMaxStreams) {
      throw ArgumentError('Too many streams: $totalStreams. '
          'Binance limit: ${AppConfig.wsMaxStreams} streams per connection.');
    }

    // ===================================================================
    // 🎯 계층적 구독 전략 (Tiered Subscription)
    // ===================================================================
    
    // 상위 심볼들: 모든 스트림으로 완전 분석
    final coreSymbols = markets.take(config.aggTradeCount);
    final coreSymbolsList = coreSymbols.toList();
    
    log.i('[TradeWS] 🎯 Core symbols (완전 분석): ${coreSymbolsList.length}개');
    
    // ✅ 1. aggTrade 스트림 (상위 심볼만 - 상세 거래 데이터)
    if (config.aggTradeCount > 0) {
      params.addAll(
        coreSymbolsList.map((symbol) => '${symbol.toLowerCase()}@aggTrade'),
      );
      log.i('[TradeWS] 📈 Added ${coreSymbolsList.length} aggTrade streams (Core tier)');
    }

    // ✅ 2. ticker 스트림 (상위 + 중위 심볼들)
    if (config.tickerCount > 0) {
      final tickerSymbols = markets.take(config.tickerCount).toList();
      params.addAll(
        tickerSymbols.map((symbol) => '${symbol.toLowerCase()}@ticker'),
      );
      log.i('[TradeWS] 📊 Added ${tickerSymbols.length} ticker streams (Core + Mid tier)');
    }

    // ✅ 3. bookTicker 스트림 (상위 심볼만 - 정밀 호가 데이터)
    if (config.bookTickerCount > 0) {
      final bookTickerSymbols = coreSymbolsList.take(config.bookTickerCount).toList();
      params.addAll(
        bookTickerSymbols.map((symbol) => '${symbol.toLowerCase()}@bookTicker'),
      );
      log.i('[TradeWS] 💰 Added ${bookTickerSymbols.length} bookTicker streams (Core tier only)');
    }

    // ✅ 4. depth5 스트림 (상위 심볼만 - 세부 호가창)
    if (config.depth5Count > 0) {
      final depth5Symbols = coreSymbolsList.take(config.depth5Count).toList();
      params.addAll(
        depth5Symbols.map((symbol) => '${symbol.toLowerCase()}@depth5'),
      );
      log.i('[TradeWS] 📋 Added ${depth5Symbols.length} depth5 streams (Core tier only)');
    }

    final messageId = _generateUniqueMessageId();
    final subscribeMessage = {
      'method': 'SUBSCRIBE',
      'params': params,
      'id': messageId,
    };

    final jsonMessage = jsonEncode(subscribeMessage);

    log.i('[TradeWS] 🎯 계층적 구독 완료 - 총 ${params.length}개 스트림');
    log.i('[TradeWS] - Core tier (${coreSymbolsList.length}개): 모든 스트림으로 완전 분석');
    log.i('[TradeWS] - Mid tier (${config.tickerCount - coreSymbolsList.length}개): ticker로 기본 모니터링');
    log.d('[TradeWS] Subscription message: $jsonMessage');

    return jsonMessage;
  }

  /// 총 스트림 개수 계산 (계층적 구독 고려)
  static int _calculateTotalStreams(int marketCount, StreamSubscriptionConfig config) {
    // Core tier: aggTrade 개수만큼의 심볼이 모든 스트림 구독
    final coreSymbolCount = config.aggTradeCount > marketCount ? marketCount : config.aggTradeCount;
    final coreStreams = coreSymbolCount * 4; // aggTrade + ticker + bookTicker + depth5
    
    // Mid tier: ticker만 추가 구독 (core tier 제외)
    final midSymbolCount = (config.tickerCount - coreSymbolCount).clamp(0, marketCount - coreSymbolCount);
    final midStreams = midSymbolCount; // ticker만
    
    return coreStreams + midStreams;
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
        case 'depthUpdate':
          // depth5/depth 이벤트 직접 처리
          return _parseDepth5Data(data, 'direct', verboseLogging);
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

  /// ✅ depth5 데이터 파싱 (수정된 버전 - 바이낸스 필드명 지원)
  static Trade? _parseDepth5Data(Map<String, dynamic> data, String streamInfo, bool verboseLogging) {
    if (verboseLogging) {
      print('🔍 [TradeWS] Depth5 parsing attempt');
      print('🔍 [TradeWS] Stream info: $streamInfo');
      print('🔍 [TradeWS] Data keys: ${data.keys.toList()}');
    }
    
    // ✅ 수정: 바이낸스는 'b'(bids)와 'a'(asks) 필드를 사용
    if (!data.containsKey('b') || !data.containsKey('a')) {
      if (verboseLogging) {
        print('🚨 [TradeWS] Missing b/a fields in depth5 data');
        print('🚨 [TradeWS] Available keys: ${data.keys.join(', ')}');
      }
      return null;
    }

    try {
      // streamInfo에서 심볼 추출
      final symbol = _extractSymbolFromStreamName(streamInfo);
      
      // 심볼이 데이터에 있으면 우선 사용
      if (data.containsKey('s')) {
        final dataSymbol = data['s'] as String;
        if (dataSymbol.isNotEmpty) {
          final trade = Trade.fromDepth5(data, dataSymbol);
          
          if (verboseLogging) {
            final bids = data['b'] as List;
            final asks = data['a'] as List;
            final bestBid = bids.isNotEmpty ? bids[0][0] : '0';
            final bestAsk = asks.isNotEmpty ? asks[0][0] : '0';
            log.d('[TradeWS] 📋 $dataSymbol: bid $bestBid / ask $bestAsk (depth5: $streamInfo)');
            print('✅ [TradeWS] Depth5 trade created successfully: ${trade.market}');
          }

          return trade;
        }
      }
      
      // fallback: streamInfo에서 추출한 심볼 사용
      if (symbol != 'UNKNOWN') {
        final trade = Trade.fromDepth5(data, symbol);
        
        if (verboseLogging) {
          final bids = data['b'] as List;
          final asks = data['a'] as List;
          final bestBid = bids.isNotEmpty ? bids[0][0] : '0';
          final bestAsk = asks.isNotEmpty ? asks[0][0] : '0';
          log.d('[TradeWS] 📋 $symbol: bid $bestBid / ask $bestAsk (depth5: $streamInfo)');
          print('✅ [TradeWS] Depth5 trade created successfully: ${trade.market}');
        }

        return trade;
      }
      
      if (verboseLogging) {
        print('🚨 [TradeWS] No valid symbol found for depth5 data');
      }
      return null;
      
    } catch (e, st) {
      if (verboseLogging) {
        print('🚨 [TradeWS] Depth5 parsing error: $e');
        print('🚨 [TradeWS] Stack trace: $st');
        print('🚨 [TradeWS] Raw data that caused error: $data');
      }
      log.e('[TradeWS] Depth5 parsing failed ($streamInfo)', e, st);
      return null;
    }
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

/// ✅ 계층적 스트림 구독 설정 클래스
class StreamSubscriptionConfig {
  final int aggTradeCount;     // Core tier 심볼 수 (모든 스트림 구독)
  final int tickerCount;       // Core + Mid tier 심볼 수 (ticker 구독)  
  final int bookTickerCount;   // Core tier에서 bookTicker 구독할 심볼 수
  final int depth5Count;       // Core tier에서 depth5 구독할 심볼 수

  const StreamSubscriptionConfig({
    this.aggTradeCount = 0,
    this.tickerCount = 0,
    this.bookTickerCount = 0,
    this.depth5Count = 0,
  });

  /// 🎯 계층적 기본 설정 (Core 1개 완전분석 + Mid 0개 기본모니터링)
  factory StreamSubscriptionConfig.defaultConfig() {
    return const StreamSubscriptionConfig(
      aggTradeCount: 1,     // Core: 1개 심볼
      tickerCount: 1,       // Core 1개 심볼 (ticker 포함)
      bookTickerCount: 1,   // Core 1개 심볼 (bookTicker 포함)
      depth5Count: 1,       // Core 1개 심볼 (depth5 포함)
    );
    // 총 스트림: 1 * 4 = 4개
  }

  /// 보수적 설정 (Core 20개 + Mid 30개)
  factory StreamSubscriptionConfig.conservative() {
    return const StreamSubscriptionConfig(
      aggTradeCount: 20,    // Core: 상위 20개만
      tickerCount: 50,      // Core 20개 + Mid 30개
      bookTickerCount: 20,  // Core 20개만
      depth5Count: 20,      // Core 20개만
    );
    // 총 스트림: (20 * 4) + (30 * 1) = 110개
  }

  /// 집중 분석 설정 (Core 50개 완전분석)
  factory StreamSubscriptionConfig.intensive() {
    return const StreamSubscriptionConfig(
      aggTradeCount: 50,    // Core: 상위 50개 심볼
      tickerCount: 100,     // Core 50개 + Mid 50개
      bookTickerCount: 50,  // Core 50개 전체
      depth5Count: 50,      // Core 50개 전체  
    );
    // 총 스트림: (50 * 4) + (50 * 1) = 250개
  }

  /// aggTrade만 구독 (기존 호환)
  factory StreamSubscriptionConfig.aggTradeOnly(int count) {
    return StreamSubscriptionConfig(
      aggTradeCount: count,
      tickerCount: count,    // aggTrade와 같은 심볼에 ticker도 추가
      bookTickerCount: 0,
      depth5Count: 0,
    );
  }

  /// Core tier 심볼 개수 (모든 스트림 구독)
  int get coreSymbolCount => aggTradeCount;
  
  /// Mid tier 심볼 개수 (ticker만 구독)
  int get midSymbolCount => (tickerCount - aggTradeCount).clamp(0, double.infinity).toInt();

  /// 총 구독 심볼 개수
  int get totalSymbolCount => tickerCount;

  /// 총 스트림 개수 (계층적 계산)
  int get totalStreamCount {
    final coreStreams = coreSymbolCount * 4; // 4개 스트림씩
    final midStreams = midSymbolCount * 1;   // 1개 스트림씩
    return coreStreams + midStreams;
  }

  /// 계층별 구성 정보
  Map<String, dynamic> getTierBreakdown() {
    return {
      'core': {
        'symbolCount': coreSymbolCount,
        'streams': ['aggTrade', 'ticker', 'bookTicker', 'depth5'],
        'streamCount': coreSymbolCount * 4,
        'description': '완전 분석 (모든 스트림)',
      },
      'mid': {
        'symbolCount': midSymbolCount,
        'streams': ['ticker'],
        'streamCount': midSymbolCount * 1,
        'description': '기본 모니터링 (ticker만)',
      },
    };
  }

  /// 맵으로 변환
  Map<String, dynamic> toMap() {
    return {
      'aggTradeCount': aggTradeCount,
      'tickerCount': tickerCount,
      'bookTickerCount': bookTickerCount,
      'depth5Count': depth5Count,
      'coreSymbolCount': coreSymbolCount,
      'midSymbolCount': midSymbolCount,
      'totalSymbolCount': totalSymbolCount,
      'totalStreamCount': totalStreamCount,
      'tierBreakdown': getTierBreakdown(),
    };
  }

  @override
  String toString() {
    return 'StreamConfig(Core: ${coreSymbolCount}개 완전분석, Mid: ${midSymbolCount}개 기본모니터링, 총 ${totalStreamCount}개 스트림)';
  }
}