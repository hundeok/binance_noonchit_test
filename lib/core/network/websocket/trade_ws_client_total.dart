
// TODO: 임시 비활성화
/*

import 'dart:convert';
import 'dart:math';
import '../../config/app_config.dart';
import '../../../domain/entities/trade.dart';
import '../../utils/logger.dart';
import 'base_ws_client.dart';

/// 🚀 바이낸스 Futures 토탈 완전체 WebSocket 클라이언트
/// 25개 모든 스트림 타입 지원 + 고르게 분배 전략
class TradeWsClient extends BaseWsClient<Trade> {
  
  /// 구독할 스트림 구성 설정 (토탈 완전체)
  final TotalStreamSubscriptionConfig config;
  final bool enableVerboseLogging;

  TradeWsClient({
    void Function(WsStatus status)? onStatusChange,
    this.enableVerboseLogging = false,
    TotalStreamSubscriptionConfig? config,
  }) : config = config ?? TotalStreamSubscriptionConfig.totalBalanced(),
        super(
          url: AppConfig.streamUrl,
          onStatusChange: onStatusChange,
          pongTimeout: AppConfig.wsPongTimeout,
          encodeSubscribe: (markets) => _encodeSubscribeMessage(markets, config ?? TotalStreamSubscriptionConfig.totalBalanced()),
          decode: (json) => _decodeTradeMessage(json, enableVerboseLogging),
        );

  // ===================================================================
  // 📨 토탈 멀티 스트림 구독 메시지 인코딩 (25개 스트림 지원)
  // ===================================================================

  static String _encodeSubscribeMessage(List<String> markets, TotalStreamSubscriptionConfig config) {
    final params = <String>[];
    
    // 스트림 개수 계산 및 제한 체크
    final totalStreams = _calculateTotalStreams(markets.length, config);
    if (totalStreams > AppConfig.wsMaxStreams) {
      throw ArgumentError('Too many streams: $totalStreams. '
          'Binance limit: ${AppConfig.wsMaxStreams} streams per connection.');
    }

    // ===================================================================
    // 🎯 거래 데이터 스트림들
    // ===================================================================
    
    if (config.aggTradeCount > 0) {
      final symbols = markets.take(config.aggTradeCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@aggTrade'));
      log.i('[TradeWS] 📈 Added ${symbols.length} aggTrade streams');
    }

    if (config.tradeCount > 0) {
      final symbols = markets.take(config.tradeCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@trade'));
      log.i('[TradeWS] 💱 Added ${symbols.length} trade streams');
    }

    // ===================================================================
    // 📊 24시간 통계 스트림들
    // ===================================================================
    
    if (config.tickerCount > 0) {
      final symbols = markets.take(config.tickerCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@ticker'));
      log.i('[TradeWS] 📊 Added ${symbols.length} ticker streams');
    }

    if (config.miniTickerCount > 0) {
      final symbols = markets.take(config.miniTickerCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@miniTicker'));
      log.i('[TradeWS] 📈 Added ${symbols.length} miniTicker streams');
    }

    // ===================================================================
    // 💰 호가 데이터 스트림들
    // ===================================================================
    
    if (config.bookTickerCount > 0) {
      final symbols = markets.take(config.bookTickerCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@bookTicker'));
      log.i('[TradeWS] 💰 Added ${symbols.length} bookTicker streams');
    }

    if (config.depth5Count > 0) {
      final symbols = markets.take(config.depth5Count);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@depth5'));
      log.i('[TradeWS] 📋 Added ${symbols.length} depth5 streams');
    }

    if (config.depth10Count > 0) {
      final symbols = markets.take(config.depth10Count);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@depth10'));
      log.i('[TradeWS] 📋 Added ${symbols.length} depth10 streams');
    }

    if (config.depth20Count > 0) {
      final symbols = markets.take(config.depth20Count);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@depth20'));
      log.i('[TradeWS] 📋 Added ${symbols.length} depth20 streams');
    }

    if (config.depthCount > 0) {
      final symbols = markets.take(config.depthCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@depth'));
      log.i('[TradeWS] ⚡ Added ${symbols.length} depth (full) streams');
    }

    if (config.depthSpeedCount > 0) {
      final symbols = markets.take(config.depthSpeedCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@depth@100ms'));
      log.i('[TradeWS] 🚨 Added ${symbols.length} depth@100ms streams (HIGH VOLUME!)');
    }

    // ===================================================================
    // 🕯️ 캔들스틱 스트림들
    // ===================================================================
    
    if (config.klineCount > 0) {
      final symbols = markets.take(config.klineCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@kline_1m')); // 기본 1분봉
      log.i('[TradeWS] 🕯️ Added ${symbols.length} kline streams');
    }

    if (config.continuousKlineCount > 0) {
      final symbols = markets.take(config.continuousKlineCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}_PERP@continuousKline_1m'));
      log.i('[TradeWS] 🔄 Added ${symbols.length} continuousKline streams');
    }

    // ===================================================================
    // ⚡ Futures 전용 스트림들
    // ===================================================================
    
    if (config.markPriceCount > 0) {
      final symbols = markets.take(config.markPriceCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@markPrice'));
      log.i('[TradeWS] ⚡ Added ${symbols.length} markPrice streams');
    }

    if (config.fundingRateCount > 0) {
      final symbols = markets.take(config.fundingRateCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@markPrice@1s')); // 1초 마크가격으로 펀딩 추적
      log.i('[TradeWS] 💸 Added ${symbols.length} fundingRate streams');
    }

    // ===================================================================
    // 🚨 특수 데이터 스트림들
    // ===================================================================
    
    if (config.liquidationCount > 0) {
      final symbols = markets.take(config.liquidationCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@forceOrder'));
      log.i('[TradeWS] 🚨 Added ${symbols.length} liquidation streams');
    }

    if (config.compositeIndexCount > 0) {
      final symbols = markets.take(config.compositeIndexCount);
      params.addAll(symbols.map((s) => '${s.toLowerCase()}@compositeIndex'));
      log.i('[TradeWS] 📈 Added ${symbols.length} compositeIndex streams');
    }

    // ===================================================================
    // 🎯 BLVT 스트림들
    // ===================================================================
    
    if (config.blvtNavCount > 0) {
      // BLVT는 특별한 네이밍 (예: BTCUP, BTCDOWN)
      final blvtSymbols = markets.where((s) => s.endsWith('UP') || s.endsWith('DOWN')).take(config.blvtNavCount);
      params.addAll(blvtSymbols.map((s) => '${s.toLowerCase()}@tokenNav'));
      log.i('[TradeWS] 🎯 Added ${blvtSymbols.length} BLVT NAV streams');
    }

    if (config.blvtKlineCount > 0) {
      final blvtSymbols = markets.where((s) => s.endsWith('UP') || s.endsWith('DOWN')).take(config.blvtKlineCount);
      params.addAll(blvtSymbols.map((s) => '${s.toLowerCase()}@nav_kline_1m'));
      log.i('[TradeWS] 🎯 Added ${blvtSymbols.length} BLVT Kline streams');
    }

    // ===================================================================
    // 🌐 전체 시장 스트림들 (심볼 무관)
    // ===================================================================
    
    if (config.allMarketTickerCount > 0) {
      params.add('!ticker@arr');
      log.i('[TradeWS] 🌐 Added all market ticker stream');
    }

    if (config.allMarketMiniCount > 0) {
      params.add('!miniTicker@arr');
      log.i('[TradeWS] 🌐 Added all market miniTicker stream');
    }

    if (config.allBookTickerCount > 0) {
      params.add('!bookTicker@arr');
      log.i('[TradeWS] 🌐 Added all market bookTicker stream');
    }

    if (config.allMarkPriceCount > 0) {
      params.add('!markPrice@arr');
      log.i('[TradeWS] 🌐 Added all market markPrice stream');
    }

    if (config.allLiquidationCount > 0) {
      params.add('!forceOrder@arr');
      log.i('[TradeWS] 🌐 Added all market liquidation stream');
    }

    final messageId = _generateUniqueMessageId();
    final subscribeMessage = {
      'method': 'SUBSCRIBE',
      'params': params,
      'id': messageId,
    };

    final jsonMessage = jsonEncode(subscribeMessage);

    log.i('[TradeWS] 🚀 총 ${params.length}개 스트림 구독 완료! (Markets: ${markets.length})');
    log.d('[TradeWS] Subscription message: $jsonMessage');

    return jsonMessage;
  }

  /// 총 스트림 개수 계산
  static int _calculateTotalStreams(int marketCount, TotalStreamSubscriptionConfig config) {
    final symbolBasedStreams = [
      config.aggTradeCount,
      config.tradeCount,
      config.tickerCount,
      config.miniTickerCount,
      config.bookTickerCount,
      config.depth5Count,
      config.depth10Count,
      config.depth20Count,
      config.depthCount,
      config.depthSpeedCount,
      config.klineCount,
      config.continuousKlineCount,
      config.markPriceCount,
      config.fundingRateCount,
      config.liquidationCount,
      config.compositeIndexCount,
      config.blvtNavCount,
      config.blvtKlineCount,
    ].map((count) => count > marketCount ? marketCount : count).fold(0, (a, b) => a + b);

    final globalStreams = config.allMarketTickerCount +
                         config.allMarketMiniCount +
                         config.allBookTickerCount +
                         config.allMarkPriceCount +
                         config.allLiquidationCount;

    return symbolBasedStreams + globalStreams;
  }

  /// 바이낸스 호환 고유 메시지 ID 생성
  static String _generateUniqueMessageId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = Random().nextInt(99999).toString().padLeft(5, '0');
    return '$timestamp$randomPart';
  }

  // ===================================================================
  // 📥 토탈 멀티 스트림 메시지 디코딩 (25개 스트림 처리)
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

      if (streamName == null || data == null) return null;
      return _parseStreamData(streamName, data, verboseLogging);
    }

    // Direct Stream 메시지 처리
    if (json.containsKey('e')) {
      final eventType = json['e'] as String;
      return _parseDirectStreamData(eventType, json, verboseLogging);
    }

    // 전체 시장 배열 데이터 처리
    if (json.containsKey('data') && json['data'] is List) {
      return _parseAllMarketArrayData(json, verboseLogging);
    }

    if (verboseLogging) {
      log.w('[TradeWS] Unknown message type: ${json.keys.join(', ')}');
    }
    return null;
  }

  /// Combined Stream 데이터 파싱 (25개 스트림 타입 지원)
  static Trade? _parseStreamData(String streamName, dynamic data, bool verboseLogging) {
    try {
      if (data is! Map<String, dynamic>) return null;

      // 스트림 타입 판별 및 파싱
      if (streamName.endsWith('@aggTrade')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.aggTrade);
      } else if (streamName.endsWith('@trade')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.trade);
      } else if (streamName.endsWith('@ticker')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.ticker);
      } else if (streamName.endsWith('@miniTicker')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.miniTicker);
      } else if (streamName.endsWith('@bookTicker')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.bookTicker);
      } else if (streamName.endsWith('@depth5')) {
        final symbol = _extractSymbolFromStreamName(streamName);
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.depth5, symbol: symbol, levels: 5);
      } else if (streamName.endsWith('@depth10')) {
        final symbol = _extractSymbolFromStreamName(streamName);
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.depth10, symbol: symbol, levels: 10);
      } else if (streamName.endsWith('@depth20')) {
        final symbol = _extractSymbolFromStreamName(streamName);
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.depth20, symbol: symbol, levels: 20);
      } else if (streamName.endsWith('@depth@100ms')) {
        final symbol = _extractSymbolFromStreamName(streamName);
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.depthSpeed, symbol: symbol);
      } else if (streamName.endsWith('@depth')) {
        final symbol = _extractSymbolFromStreamName(streamName);
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.depth, symbol: symbol);
      } else if (streamName.contains('@kline_')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.kline);
      } else if (streamName.contains('@continuousKline_')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.continuousKline);
      } else if (streamName.endsWith('@markPrice') || streamName.endsWith('@markPrice@1s')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.markPrice);
      } else if (streamName.endsWith('@forceOrder')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.liquidation);
      } else if (streamName.endsWith('@compositeIndex')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.compositeIndex);
      } else if (streamName.endsWith('@tokenNav')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.blvtNav);
      } else if (streamName.contains('@nav_kline_')) {
        return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.blvtKline);
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

  /// Direct Stream 데이터 파싱
  static Trade? _parseDirectStreamData(String eventType, Map<String, dynamic> data, bool verboseLogging) {
    try {
      switch (eventType) {
        case 'aggTrade':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.aggTrade);
        case 'trade':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.trade);
        case '24hrTicker':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.ticker);
        case '24hrMiniTicker':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.miniTicker);
        case 'kline':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.kline);
        case 'continuous_kline':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.continuousKline);
        case 'markPriceUpdate':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.markPrice);
        case 'forceOrder':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.liquidation);
        case 'compositeIndex':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.compositeIndex);
        case 'nav':
          return Trade.fromBinanceStream(json: data, streamType: BinanceStreamType.blvtNav);
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

  /// 전체 시장 배열 데이터 파싱 (첫 번째 항목만 반환)
  static Trade? _parseAllMarketArrayData(Map<String, dynamic> json, bool verboseLogging) {
    try {
      final data = json['data'] as List;
      if (data.isEmpty) return null;

      // 스트림 이름으로 타입 판별
      final stream = json['stream'] as String?;
      if (stream == null) return null;

      BinanceStreamType streamType;
      if (stream.contains('ticker@arr')) {
        streamType = BinanceStreamType.allMarketTicker;
      } else if (stream.contains('miniTicker@arr')) {
        streamType = BinanceStreamType.allMarketMini;
      } else if (stream.contains('bookTicker@arr')) {
        streamType = BinanceStreamType.allBookTicker;
      } else if (stream.contains('markPrice@arr')) {
        streamType = BinanceStreamType.allMarkPrice;
      } else if (stream.contains('forceOrder@arr')) {
        streamType = BinanceStreamType.allLiquidation;
      } else {
        return null;
      }

      // 첫 번째 항목만 반환 (전체 시장 데이터는 매우 클 수 있음)
      final firstItem = data[0] as Map<String, dynamic>;
      return Trade.fromBinanceStream(json: firstItem, streamType: streamType);
    } catch (e, st) {
      log.e('[TradeWS] All market array parsing failed', e, st);
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
      'totalStreamTypes': 25,
      'isSafeConfiguration': config.isSafeConfiguration(),
    };
  }

  /// 예상 메시지 속도 계산
  int _estimateMessageRate() {
    return config.aggTradeCount * 50 +       // aggTrade
           config.tradeCount * 100 +         // trade (매우 빠름)
           config.tickerCount * 1 +          // ticker
           config.miniTickerCount * 1 +      // miniTicker
           config.bookTickerCount * 10 +     // bookTicker
           config.depth5Count * 10 +         // depth5
           config.depth10Count * 10 +        // depth10
           config.depth20Count * 10 +        // depth20
           config.depthCount * 100 +         // depth (빠름)
           config.depthSpeedCount * 500 +    // depth@100ms (매우 빠름)
           config.klineCount * 4 +           // kline
           config.continuousKlineCount * 4 + // continuousKline
           config.markPriceCount * 1 +       // markPrice
           config.fundingRateCount * 1 +     // fundingRate
           config.liquidationCount * 5 +     // liquidation
           config.compositeIndexCount * 1 +  // compositeIndex
           config.blvtNavCount * 1 +         // blvtNav
           config.blvtKlineCount * 4 +       // blvtKline
           config.allMarketTickerCount * 200 +   // 전체 시장 (많은 심볼)
           config.allMarketMiniCount * 200 +     // 전체 시장
           config.allBookTickerCount * 2000 +    // 전체 시장 (매우 빠름)
           config.allMarkPriceCount * 200 +      // 전체 시장
           config.allLiquidationCount * 100;     // 전체 시장
  }
}

// ===================================================================
// 🎯 토탈 스트림 구독 설정 클래스 (25개 스트림 지원)
// ===================================================================

class TotalStreamSubscriptionConfig {
  // === 거래 데이터 ===
  final int aggTradeCount;        // 집계 거래
  final int tradeCount;           // 개별 거래
  
  // === 24시간 통계 ===
  final int tickerCount;          // 24시간 전체 통계
  final int miniTickerCount;      // 24시간 간소 통계
  
  // === 호가 데이터 ===
  final int bookTickerCount;      // 최고 호가
  final int depth5Count;          // 5단계 호가창
  final int depth10Count;         // 10단계 호가창
  final int depth20Count;         // 20단계 호가창
  final int depthCount;           // 전체 호가창
  final int depthSpeedCount;      // 고속 호가창 (100ms)
  
  // === 캔들스틱 ===
  final int klineCount;           // 일반 캔들
  final int continuousKlineCount; // 연속 계약 캔들
  
  // === Futures 전용 ===
  final int markPriceCount;       // 마크 가격
  final int fundingRateCount;     // 펀딩 비율
  
  // === 특수 데이터 ===
  final int liquidationCount;     // 강제청산
  final int compositeIndexCount;  // 복합 지수
  
  // === BLVT ===
  final int blvtNavCount;         // BLVT NAV
  final int blvtKlineCount;       // BLVT 캔들
  
  // === 전체 시장 ===
  final int allMarketTickerCount;    // 전체 24h 통계
  final int allMarketMiniCount;      // 전체 간소 통계
  final int allBookTickerCount;      // 전체 호가
  final int allMarkPriceCount;       // 전체 마크가격
  final int allLiquidationCount;     // 전체 강제청산

  const TotalStreamSubscriptionConfig({
    this.aggTradeCount = 0,
    this.tradeCount = 0,
    this.tickerCount = 0,
    this.miniTickerCount = 0,
    this.bookTickerCount = 0,
    this.depth5Count = 0,
    this.depth10Count = 0,
    this.depth20Count = 0,
    this.depthCount = 0,
    this.depthSpeedCount = 0,
    this.klineCount = 0,
    this.continuousKlineCount = 0,
    this.markPriceCount = 0,
    this.fundingRateCount = 0,
    this.liquidationCount = 0,
    this.compositeIndexCount = 0,
    this.blvtNavCount = 0,
    this.blvtKlineCount = 0,
    this.allMarketTickerCount = 0,
    this.allMarketMiniCount = 0,
    this.allBookTickerCount = 0,
    this.allMarkPriceCount = 0,
    this.allLiquidationCount = 0,
  });

  /// 🚀 토탈 밸런스 설정 (745개 스트림, 고르게 분배)
  factory TotalStreamSubscriptionConfig.totalBalanced() {
    return const TotalStreamSubscriptionConfig(
      // === 거래 데이터 (60개) ===
      aggTradeCount: 30,       // 집계 거래
      tradeCount: 30,          // 개별 거래
      
      // === 24시간 통계 (60개) ===  
      tickerCount: 30,         // 전체 통계
      miniTickerCount: 30,     // 간소 통계
      
      // === 호가 데이터 (120개) ===
      bookTickerCount: 30,     // 최고 호가
      depth5Count: 30,         // 5단계 호가
      depth10Count: 30,        // 10단계 호가
      depth20Count: 30,        // 20단계 호가
      
      // === 캔들스틱 (60개) ===
      klineCount: 30,          // 일반 캔들
      continuousKlineCount: 30, // 연속 계약 캔들
      
      // === Futures 전용 (60개) ===
      markPriceCount: 30,      // 마크 가격
      fundingRateCount: 30,    // 펀딩 비율
      
      // === 특수 데이터 (60개) ===
      liquidationCount: 30,    // 강제청산
      compositeIndexCount: 30, // 복합 지수
      
      // === BLVT (60개) ===
      blvtNavCount: 30,        // BLVT NAV
      blvtKlineCount: 30,      // BLVT 캔들
      
      // === 전체 시장 (5개) ===
      allMarketTickerCount: 1,     // 전체 티커
      allMarketMiniCount: 1,       // 전체 미니
      allBookTickerCount: 1,       // 전체 북티커
      allMarkPriceCount: 1,        // 전체 마크가격
      allLiquidationCount: 1,      // 전체 청산
      
      // === 위험 스트림 (0개) ===
      depthCount: 0,           // 전체 호가 (빠름)
      depthSpeedCount: 0,      // 100ms 호가 (매우 위험)
    );
  }

  /// 보수적 설정 (안전한 스트림들만)
  factory TotalStreamSubscriptionConfig.conservative() {
    return const TotalStreamSubscriptionConfig(
      aggTradeCount: 20,
      tickerCount: 20,
      bookTickerCount: 20,
      depth5Count: 20,
      markPriceCount: 20,
      klineCount: 10,
      liquidationCount: 10,
      // 위험한 스트림들은 0
      tradeCount: 0,
      depthCount: 0,
      depthSpeedCount: 0,
      allBookTickerCount: 0,
    );
  }

  /// 거래 중심 설정 (트레이딩용)
  factory TotalStreamSubscriptionConfig.tradingFocused() {
    return const TotalStreamSubscriptionConfig(
      aggTradeCount: 50,       // 거래 데이터 중심
      bookTickerCount: 50,     // 호가 데이터
      depth5Count: 30,         // 호가창
      markPriceCount: 30,      // 마크가격
      tickerCount: 20,         // 기본 통계
      liquidationCount: 20,    // 청산 모니터링
    );
  }

  /// 분석 중심 설정 (리서치용)
  factory TotalStreamSubscriptionConfig.analysisFocused() {
    return const TotalStreamSubscriptionConfig(
      tickerCount: 50,         // 통계 데이터
      klineCount: 50,          // 캔들 데이터
      markPriceCount: 30,      // 가격 데이터
      liquidationCount: 30,    // 시장 동향
      compositeIndexCount: 20, // 지수 분석
      allMarketTickerCount: 1, // 전체 시장
      allMarkPriceCount: 1,    // 전체 마크가격
    );
  }

  /// 기존 호환용 (aggTrade만)
  factory TotalStreamSubscriptionConfig.aggTradeOnly(int count) {
    return TotalStreamSubscriptionConfig(aggTradeCount: count);
  }

  /// 총 스트림 개수
  int get totalCount {
    return aggTradeCount + tradeCount + tickerCount + miniTickerCount +
           bookTickerCount + depth5Count + depth10Count + depth20Count +
           depthCount + depthSpeedCount + klineCount + continuousKlineCount +
           markPriceCount + fundingRateCount + liquidationCount + compositeIndexCount +
           blvtNavCount + blvtKlineCount + allMarketTickerCount + allMarketMiniCount +
           allBookTickerCount + allMarkPriceCount + allLiquidationCount;
  }

  /// 위험한 스트림 개수
  int get highVolumeStreamCount {
    return tradeCount + depthCount + depthSpeedCount + allBookTickerCount;
  }

  /// 안전한 구성인지 확인
  bool isSafeConfiguration() {
    final hasHighVolumeStreams = highVolumeStreamCount > 0;
    final totalStreams = totalCount;
    
    return !hasHighVolumeStreams && 
           totalStreams <= AppConfig.wsMaxStreams * 0.8; // 80% 이하
  }

  /// 예상 메시지 속도 (간단 계산)
  int get estimatedMessageRate {
    return aggTradeCount * 50 + tradeCount * 100 + tickerCount * 1 +
           miniTickerCount * 1 + bookTickerCount * 10 + depth5Count * 10 +
           depth10Count * 10 + depth20Count * 10 + depthCount * 100 +
           depthSpeedCount * 500 + klineCount * 4 + continuousKlineCount * 4 +
           markPriceCount * 1 + fundingRateCount * 1 + liquidationCount * 5 +
           compositeIndexCount * 1 + blvtNavCount * 1 + blvtKlineCount * 4 +
           allMarketTickerCount * 200 + allMarketMiniCount * 200 +
           allBookTickerCount * 2000 + allMarkPriceCount * 200 +
           allLiquidationCount * 100;
  }

  /// 맵으로 변환
  Map<String, dynamic> toMap() {
    return {
      // 거래 데이터
      'aggTradeCount': aggTradeCount,
      'tradeCount': tradeCount,
      
      // 24시간 통계
      'tickerCount': tickerCount,
      'miniTickerCount': miniTickerCount,
      
      // 호가 데이터
      'bookTickerCount': bookTickerCount,
      'depth5Count': depth5Count,
      'depth10Count': depth10Count,
      'depth20Count': depth20Count,
      'depthCount': depthCount,
      'depthSpeedCount': depthSpeedCount,
      
      // 캔들스틱
      'klineCount': klineCount,
      'continuousKlineCount': continuousKlineCount,
      
      // Futures 전용
      'markPriceCount': markPriceCount,
      'fundingRateCount': fundingRateCount,
      
      // 특수 데이터
      'liquidationCount': liquidationCount,
      'compositeIndexCount': compositeIndexCount,
      
      // BLVT
      'blvtNavCount': blvtNavCount,
      'blvtKlineCount': blvtKlineCount,
      
      // 전체 시장
      'allMarketTickerCount': allMarketTickerCount,
      'allMarketMiniCount': allMarketMiniCount,
      'allBookTickerCount': allBookTickerCount,
      'allMarkPriceCount': allMarkPriceCount,
      'allLiquidationCount': allLiquidationCount,
      
      // 요약 정보
      'totalCount': totalCount,
      'highVolumeStreamCount': highVolumeStreamCount,
      'estimatedMessageRate': estimatedMessageRate,
      'isSafe': isSafeConfiguration(),
    };
  }

  /// 스트림 카테고리별 개수
  Map<String, int> getCategoryBreakdown() {
    return {
      'Trade Data': aggTradeCount + tradeCount,
      '24h Statistics': tickerCount + miniTickerCount,
      'Order Book': bookTickerCount + depth5Count + depth10Count + depth20Count + depthCount + depthSpeedCount,
      'Candlestick': klineCount + continuousKlineCount,
      'Futures Price': markPriceCount + fundingRateCount,
      'Special Data': liquidationCount + compositeIndexCount,
      'BLVT': blvtNavCount + blvtKlineCount,
      'All Market': allMarketTickerCount + allMarketMiniCount + allBookTickerCount + allMarkPriceCount + allLiquidationCount,
    };
  }

  @override
  String toString() {
    return 'TotalStreamConfig(총 ${totalCount}개 스트림, 예상 ${estimatedMessageRate}msg/sec, 안전성: ${isSafeConfiguration() ? "안전" : "주의"})';
  }
}

// 전체 코드가 여기에...
*/