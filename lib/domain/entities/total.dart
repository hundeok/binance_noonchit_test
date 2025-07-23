import 'package:equatable/equatable.dart';

/// 🚀 바이낸스 Futures 모든 스트림 타입 (백서 100% 커버)
enum BinanceStreamType {
  // === 거래 데이터 ===
  aggTrade,          // 집계 거래 (100ms)
  trade,             // 개별 거래 (실시간)
  
  // === 24시간 통계 ===
  ticker,            // 24시간 전체 통계 (1000ms)
  miniTicker,        // 24시간 간소 통계 (1000ms)
  
  // === 호가 데이터 ===
  bookTicker,        // 최고 호가 (실시간)
  depth5,            // 5단계 호가창 (1000ms)
  depth10,           // 10단계 호가창 (1000ms) 
  depth20,           // 20단계 호가창 (1000ms)
  depth,             // 전체 호가창 diff (1000ms)
  depthSpeed,        // 고속 호가창 diff (100ms)
  
  // === 캔들스틱 ===
  kline,             // 일반 캔들 (250ms)
  continuousKline,   // 연속 계약 캔들 (250ms)
  indexKline,        // 지수 가격 캔들 (250ms)
  markKline,         // 마크 가격 캔들 (250ms)
  
  // === Futures 전용 ===
  markPrice,         // 마크 가격 (3000ms or 1000ms)
  indexPrice,        // 지수 가격 (3000ms)
  fundingRate,       // 펀딩 비율 (실시간)
  
  // === 특수 데이터 ===
  liquidation,       // 강제청산 (실시간)
  compositeIndex,    // 복합 지수 (1000ms)
  
  // === BLVT (레버리지 토큰) ===
  blvtNav,           // BLVT NAV (1000ms)
  blvtKline,         // BLVT 캔들 (250ms)
  
  // === 전체 시장 ===
  allMarketTicker,   // 전체 24h 통계 (!ticker@arr)
  allMarketMini,     // 전체 간소 통계 (!miniTicker@arr)
  allBookTicker,     // 전체 호가 (!bookTicker@arr)
  allMarkPrice,      // 전체 마크가격 (!markPrice@arr)
  allLiquidation,    // 전체 강제청산 (!forceOrder@arr)
}

/// 🎯 바이낸스 Futures 토탈 패키지 Trade 엔티티
class Trade extends Equatable {
  /// 심볼 (e.g., BTCUSDT)
  final String market;
  
  /// 체결/현재 가격
  final double price;
  
  /// 체결 수량 또는 관련 수량
  final double quantity;
  
  /// 총 체결액 또는 관련 값
  final double totalValue;
  
  /// 매수 체결 여부 (방향성 없는 스트림은 기본값)
  final bool isBuy;
  
  /// 체결/이벤트 시각 (milliseconds from epoch)
  final int timestamp;
  
  /// 거래/이벤트 고유 ID
  final String tradeId;
  
  /// 스트림 타입 구분
  final BinanceStreamType streamType;
  
  /// 원본 JSON 데이터 (확장성/디버깅용)
  final Map<String, dynamic>? rawData;

  const Trade({
    required this.market,
    required this.price,
    required this.quantity,
    required this.totalValue,
    required this.isBuy,
    required this.timestamp,
    required this.tradeId,
    this.streamType = BinanceStreamType.aggTrade,
    this.rawData,
  });

  /// UI에서 사용하기 편한 DateTime 객체
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  // ===================================================================
  // 🎯 거래 데이터 팩토리 메서드들
  // ===================================================================

  /// aggTrade 스트림 (집계 거래)
  factory Trade.fromAggTrade(Map<String, dynamic> json) {
    final price = double.parse(json['p'].toString());
    final quantity = double.parse(json['q'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: price,
      quantity: quantity,
      totalValue: price * quantity,
      isBuy: !(json['m'] as bool), // isBuyerMaker가 false일 때가 매수
      timestamp: json['T'] as int,
      tradeId: json['a'].toString(),
      streamType: BinanceStreamType.aggTrade,
      rawData: json,
    );
  }

  /// trade 스트림 (개별 거래)
  factory Trade.fromTrade(Map<String, dynamic> json) {
    final price = double.parse(json['p'].toString());
    final quantity = double.parse(json['q'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: price,
      quantity: quantity,
      totalValue: price * quantity,
      isBuy: !(json['m'] as bool),
      timestamp: json['T'] as int,
      tradeId: json['t'].toString(),
      streamType: BinanceStreamType.trade,
      rawData: json,
    );
  }

  // ===================================================================
  // 📊 24시간 통계 팩토리 메서드들
  // ===================================================================

  /// ticker 스트림 (24시간 전체 통계)
  factory Trade.fromTicker(Map<String, dynamic> json) {
    final lastPrice = double.parse(json['c'].toString());
    final volume = double.parse(json['v'].toString());
    final quoteVolume = double.parse(json['q'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: lastPrice,
      quantity: volume,
      totalValue: quoteVolume,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'ticker_${json['s']}_${json['E']}',
      streamType: BinanceStreamType.ticker,
      rawData: json,
    );
  }

  /// miniTicker 스트림 (24시간 간소 통계)
  factory Trade.fromMiniTicker(Map<String, dynamic> json) {
    final closePrice = double.parse(json['c'].toString());
    final volume = double.parse(json['v'].toString());
    final quoteVolume = double.parse(json['q'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: closePrice,
      quantity: volume,
      totalValue: quoteVolume,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'mini_${json['s']}_${json['E']}',
      streamType: BinanceStreamType.miniTicker,
      rawData: json,
    );
  }

  // ===================================================================
  // 💰 호가 데이터 팩토리 메서드들
  // ===================================================================

  /// bookTicker 스트림 (최고 호가)
  factory Trade.fromBookTicker(Map<String, dynamic> json) {
    final bidPrice = double.parse(json['b'].toString());
    final askPrice = double.parse(json['a'].toString());
    final bidQty = double.parse(json['B'].toString());
    final askQty = double.parse(json['A'].toString());
    
    final midPrice = (bidPrice + askPrice) / 2;
    final avgQty = (bidQty + askQty) / 2;
    
    return Trade(
      market: json['s'] as String,
      price: midPrice,
      quantity: avgQty,
      totalValue: midPrice * avgQty,
      isBuy: true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      tradeId: 'book_${json['s']}_${json['u']}',
      streamType: BinanceStreamType.bookTicker,
      rawData: json,
    );
  }

  /// depth 스트림 (호가창 - 5/10/20/전체)
  factory Trade.fromDepth(Map<String, dynamic> json, String symbol, {int levels = 5}) {
    final bids = json['bids'] as List;
    final asks = json['asks'] as List;
    
    if (bids.isEmpty || asks.isEmpty) {
      throw ArgumentError('Empty order book data');
    }
    
    final bestBid = double.parse(bids[0][0].toString());
    final bestAsk = double.parse(asks[0][0].toString());
    final bidQty = double.parse(bids[0][1].toString());
    final askQty = double.parse(asks[0][1].toString());
    
    final midPrice = (bestBid + bestAsk) / 2;
    final avgQty = (bidQty + askQty) / 2;
    
    BinanceStreamType streamType;
    switch (levels) {
      case 5: streamType = BinanceStreamType.depth5; break;
      case 10: streamType = BinanceStreamType.depth10; break;
      case 20: streamType = BinanceStreamType.depth20; break;
      default: streamType = BinanceStreamType.depth; break;
    }
    
    return Trade(
      market: symbol,
      price: midPrice,
      quantity: avgQty,
      totalValue: midPrice * avgQty,
      isBuy: true,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      tradeId: 'depth${levels}_${symbol}_${json['lastUpdateId']}',
      streamType: streamType,
      rawData: json,
    );
  }

  // ===================================================================
  // 🕯️ 캔들스틱 팩토리 메서드들
  // ===================================================================

  /// kline 스트림 (일반 캔들)
  factory Trade.fromKline(Map<String, dynamic> json) {
    final klineData = json['k'] as Map<String, dynamic>;
    final closePrice = double.parse(klineData['c'].toString());
    final volume = double.parse(klineData['v'].toString());
    final quoteVolume = double.parse(klineData['q'].toString());
    
    return Trade(
      market: klineData['s'] as String,
      price: closePrice,
      quantity: volume,
      totalValue: quoteVolume,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'kline_${klineData['s']}_${klineData['t']}',
      streamType: BinanceStreamType.kline,
      rawData: json,
    );
  }

  /// continuousKline 스트림 (연속 계약 캔들)
  factory Trade.fromContinuousKline(Map<String, dynamic> json) {
    final klineData = json['k'] as Map<String, dynamic>;
    final closePrice = double.parse(klineData['c'].toString());
    final volume = double.parse(klineData['v'].toString());
    final quoteVolume = double.parse(klineData['q'].toString());
    
    return Trade(
      market: klineData['ps'] as String, // pair symbol
      price: closePrice,
      quantity: volume,
      totalValue: quoteVolume,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'cont_kline_${klineData['ps']}_${klineData['t']}',
      streamType: BinanceStreamType.continuousKline,
      rawData: json,
    );
  }

  // ===================================================================
  // ⚡ Futures 전용 팩토리 메서드들
  // ===================================================================

  /// markPrice 스트림 (마크 가격)
  factory Trade.fromMarkPrice(Map<String, dynamic> json) {
    final markPrice = double.parse(json['p'].toString());
    final indexPrice = double.parse(json['i'].toString());
    final fundingRate = double.parse((json['r'] ?? '0').toString());
    
    return Trade(
      market: json['s'] as String,
      price: markPrice,
      quantity: fundingRate, // quantity 필드에 펀딩 비율 저장
      totalValue: indexPrice, // totalValue 필드에 지수 가격 저장
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'mark_${json['s']}_${json['E']}',
      streamType: BinanceStreamType.markPrice,
      rawData: json,
    );
  }

  /// liquidation 스트림 (강제청산)
  factory Trade.fromLiquidation(Map<String, dynamic> json) {
    final orderData = json['o'] as Map<String, dynamic>;
    final price = double.parse(orderData['p'].toString());
    final quantity = double.parse(orderData['q'].toString());
    
    return Trade(
      market: orderData['s'] as String,
      price: price,
      quantity: quantity,
      totalValue: price * quantity,
      isBuy: orderData['S'] == 'BUY',
      timestamp: json['E'] as int,
      tradeId: 'liq_${orderData['s']}_${json['E']}',
      streamType: BinanceStreamType.liquidation,
      rawData: json,
    );
  }

  /// compositeIndex 스트림 (복합 지수)
  factory Trade.fromCompositeIndex(Map<String, dynamic> json) {
    final price = double.parse(json['p'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: price,
      quantity: 0, // 지수는 수량 개념 없음
      totalValue: price,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'comp_${json['s']}_${json['E']}',
      streamType: BinanceStreamType.compositeIndex,
      rawData: json,
    );
  }

  // ===================================================================
  // 🎯 BLVT 팩토리 메서드들
  // ===================================================================

  /// BLVT NAV 스트림
  factory Trade.fromBlvtNav(Map<String, dynamic> json) {
    final nav = double.parse(json['n'].toString());
    final realLeverage = double.parse(json['l'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: nav,
      quantity: realLeverage,
      totalValue: nav * realLeverage,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'blvt_${json['s']}_${json['E']}',
      streamType: BinanceStreamType.blvtNav,
      rawData: json,
    );
  }

  /// BLVT Kline 스트림
  factory Trade.fromBlvtKline(Map<String, dynamic> json) {
    final klineData = json['k'] as Map<String, dynamic>;
    final closePrice = double.parse(klineData['c'].toString());
    final volume = double.parse(klineData['v'].toString());
    
    return Trade(
      market: klineData['s'] as String,
      price: closePrice,
      quantity: volume,
      totalValue: closePrice * volume,
      isBuy: true,
      timestamp: json['E'] as int,
      tradeId: 'blvt_kline_${klineData['s']}_${klineData['t']}',
      streamType: BinanceStreamType.blvtKline,
      rawData: json,
    );
  }

  // ===================================================================
  // 🌐 전체 시장 팩토리 메서드들
  // ===================================================================

  /// 전체 시장 데이터에서 개별 Trade 객체들 생성
  static List<Trade> fromAllMarketData(Map<String, dynamic> json, BinanceStreamType streamType) {
    final data = json['data'] as List;
    
    return data.map((item) {
      switch (streamType) {
        case BinanceStreamType.allMarketTicker:
          return Trade.fromTicker(item as Map<String, dynamic>);
        case BinanceStreamType.allMarketMini:
          return Trade.fromMiniTicker(item as Map<String, dynamic>);
        case BinanceStreamType.allBookTicker:
          return Trade.fromBookTicker(item as Map<String, dynamic>);
        case BinanceStreamType.allMarkPrice:
          return Trade.fromMarkPrice(item as Map<String, dynamic>);
        case BinanceStreamType.allLiquidation:
          return Trade.fromLiquidation(item as Map<String, dynamic>);
        default:
          throw ArgumentError('Unsupported all market stream type: $streamType');
      }
    }).toList();
  }

  // ===================================================================
  // 🎯 통합 팩토리 메서드 (자동 타입 감지)
  // ===================================================================

  /// 스트림 타입과 JSON으로부터 자동 생성
  factory Trade.fromBinanceStream({
    required Map<String, dynamic> json,
    required BinanceStreamType streamType,
    String? symbol, // depth 스트림용
    int? levels,    // depth 레벨 지정용
  }) {
    switch (streamType) {
      case BinanceStreamType.aggTrade:
        return Trade.fromAggTrade(json);
      case BinanceStreamType.trade:
        return Trade.fromTrade(json);
      case BinanceStreamType.ticker:
        return Trade.fromTicker(json);
      case BinanceStreamType.miniTicker:
        return Trade.fromMiniTicker(json);
      case BinanceStreamType.bookTicker:
        return Trade.fromBookTicker(json);
      case BinanceStreamType.depth5:
      case BinanceStreamType.depth10:
      case BinanceStreamType.depth20:
      case BinanceStreamType.depth:
        return Trade.fromDepth(json, symbol ?? 'UNKNOWN', levels: levels ?? 5);
      case BinanceStreamType.kline:
        return Trade.fromKline(json);
      case BinanceStreamType.continuousKline:
        return Trade.fromContinuousKline(json);
      case BinanceStreamType.markPrice:
        return Trade.fromMarkPrice(json);
      case BinanceStreamType.liquidation:
        return Trade.fromLiquidation(json);
      case BinanceStreamType.compositeIndex:
        return Trade.fromCompositeIndex(json);
      case BinanceStreamType.blvtNav:
        return Trade.fromBlvtNav(json);
      case BinanceStreamType.blvtKline:
        return Trade.fromBlvtKline(json);
      default:
        throw ArgumentError('Unsupported stream type: $streamType');
    }
  }

  /// 기존 호환성을 위한 fromBinance (aggTrade 기본값)
  factory Trade.fromBinance(Map<String, dynamic> json) {
    return Trade.fromAggTrade(json);
  }

  // ===================================================================
  // 📊 스트림별 전용 접근자들
  // ===================================================================

  /// ticker 전용: 24시간 변동률
  double? get priceChangePercent {
    if (!_isTickerStream || rawData == null) return null;
    return double.tryParse(rawData!['P']?.toString() ?? '');
  }
  
  /// ticker 전용: 24시간 고가
  double? get highPrice {
    if (!_isTickerStream || rawData == null) return null;
    return double.tryParse(rawData!['h']?.toString() ?? '');
  }
  
  /// ticker 전용: 24시간 저가
  double? get lowPrice {
    if (!_isTickerStream || rawData == null) return null;
    return double.tryParse(rawData!['l']?.toString() ?? '');
  }
  
  /// bookTicker 전용: 최고 매수 호가
  double? get bestBidPrice {
    if (streamType != BinanceStreamType.bookTicker || rawData == null) return null;
    return double.tryParse(rawData!['b']?.toString() ?? '');
  }
  
  /// bookTicker 전용: 최고 매도 호가
  double? get bestAskPrice {
    if (streamType != BinanceStreamType.bookTicker || rawData == null) return null;
    return double.tryParse(rawData!['a']?.toString() ?? '');
  }
  
  /// bookTicker 전용: 스프레드
  double? get spread {
    final bid = bestBidPrice;
    final ask = bestAskPrice;
    if (bid == null || ask == null) return null;
    return ask - bid;
  }

  /// markPrice 전용: 지수 가격 (totalValue 필드에서)
  double? get indexPrice {
    if (streamType != BinanceStreamType.markPrice) return null;
    return totalValue;
  }

  /// markPrice 전용: 펀딩 비율 (quantity 필드에서)
  double? get fundingRate {
    if (streamType != BinanceStreamType.markPrice) return null;
    return quantity;
  }

  /// kline 전용: OHLCV 데이터
  Map<String, double>? get ohlcv {
    if (!_isKlineStream || rawData == null) return null;
    final k = rawData!['k'] as Map<String, dynamic>?;
    if (k == null) return null;
    
    return {
      'open': double.parse(k['o'].toString()),
      'high': double.parse(k['h'].toString()),
      'low': double.parse(k['l'].toString()),
      'close': double.parse(k['c'].toString()),
      'volume': double.parse(k['v'].toString()),
    };
  }

  /// liquidation 전용: 주문 타입
  String? get liquidationSide {
    if (streamType != BinanceStreamType.liquidation || rawData == null) return null;
    final o = rawData!['o'] as Map<String, dynamic>?;
    return o?['S'] as String?;
  }

  // ===================================================================
  // 🛠️ 유틸리티 메서드들
  // ===================================================================

  /// 스트림 타입별 표시용 문자열
  String get streamTypeDisplayName {
    switch (streamType) {
      case BinanceStreamType.aggTrade: return 'Agg Trade';
      case BinanceStreamType.trade: return 'Trade';
      case BinanceStreamType.ticker: return '24h Ticker';
      case BinanceStreamType.miniTicker: return '24h Mini';
      case BinanceStreamType.bookTicker: return 'Book Ticker';
      case BinanceStreamType.depth5: return 'Depth 5';
      case BinanceStreamType.depth10: return 'Depth 10';
      case BinanceStreamType.depth20: return 'Depth 20';
      case BinanceStreamType.depth: return 'Depth Full';
      case BinanceStreamType.depthSpeed: return 'Depth 100ms';
      case BinanceStreamType.kline: return 'Kline';
      case BinanceStreamType.continuousKline: return 'Continuous Kline';
      case BinanceStreamType.indexKline: return 'Index Kline';
      case BinanceStreamType.markKline: return 'Mark Kline';
      case BinanceStreamType.markPrice: return 'Mark Price';
      case BinanceStreamType.indexPrice: return 'Index Price';
      case BinanceStreamType.fundingRate: return 'Funding Rate';
      case BinanceStreamType.liquidation: return 'Liquidation';
      case BinanceStreamType.compositeIndex: return 'Composite Index';
      case BinanceStreamType.blvtNav: return 'BLVT NAV';
      case BinanceStreamType.blvtKline: return 'BLVT Kline';
      case BinanceStreamType.allMarketTicker: return 'All Market Ticker';
      case BinanceStreamType.allMarketMini: return 'All Market Mini';
      case BinanceStreamType.allBookTicker: return 'All Book Ticker';
      case BinanceStreamType.allMarkPrice: return 'All Mark Price';
      case BinanceStreamType.allLiquidation: return 'All Liquidation';
    }
  }
  
  /// 데이터 품질 확인
  bool get isValidData {
    return market.isNotEmpty && 
           price > 0 && 
           quantity >= 0 && 
           timestamp > 0 &&
           tradeId.isNotEmpty;
  }

  /// 스트림 카테고리 분류
  String get streamCategory {
    switch (streamType) {
      case BinanceStreamType.aggTrade:
      case BinanceStreamType.trade:
        return 'Trade Data';
      case BinanceStreamType.ticker:
      case BinanceStreamType.miniTicker:
        return '24h Statistics';
      case BinanceStreamType.bookTicker:
      case BinanceStreamType.depth5:
      case BinanceStreamType.depth10:
      case BinanceStreamType.depth20:
      case BinanceStreamType.depth:
      case BinanceStreamType.depthSpeed:
        return 'Order Book';
      case BinanceStreamType.kline:
      case BinanceStreamType.continuousKline:
      case BinanceStreamType.indexKline:
      case BinanceStreamType.markKline:
        return 'Candlestick';
      case BinanceStreamType.markPrice:
      case BinanceStreamType.indexPrice:
      case BinanceStreamType.fundingRate:
        return 'Futures Price';
      case BinanceStreamType.liquidation:
        return 'Liquidation';
      case BinanceStreamType.compositeIndex:
        return 'Index';
      case BinanceStreamType.blvtNav:
      case BinanceStreamType.blvtKline:
        return 'BLVT';
      default:
        return 'All Market';
    }
  }

  /// Helper: ticker 관련 스트림 체크
  bool get _isTickerStream => streamType == BinanceStreamType.ticker || 
                             streamType == BinanceStreamType.miniTicker;

  /// Helper: kline 관련 스트림 체크
  bool get _isKlineStream => [
    BinanceStreamType.kline,
    BinanceStreamType.continuousKline,
    BinanceStreamType.indexKline,
    BinanceStreamType.markKline,
    BinanceStreamType.blvtKline,
  ].contains(streamType);
  
  /// 복사 메서드 (불변 객체 수정용)
  Trade copyWith({
    String? market,
    double? price,
    double? quantity,
    double? totalValue,
    bool? isBuy,
    int? timestamp,
    String? tradeId,
    BinanceStreamType? streamType,
    Map<String, dynamic>? rawData,
  }) {
    return Trade(
      market: market ?? this.market,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      totalValue: totalValue ?? this.totalValue,
      isBuy: isBuy ?? this.isBuy,
      timestamp: timestamp ?? this.timestamp,
      tradeId: tradeId ?? this.tradeId,
      streamType: streamType ?? this.streamType,
      rawData: rawData ?? this.rawData,
    );
  }

  /// 디버그용 상세 정보
  Map<String, dynamic> toDebugMap() {
    return {
      'market': market,
      'price': price,
      'quantity': quantity,
      'totalValue': totalValue,
      'isBuy': isBuy,
      'timestamp': timestamp,
      'dateTime': dateTime.toIso8601String(),
      'tradeId': tradeId,
      'streamType': streamType.name,
      'streamCategory': streamCategory,
      'displayName': streamTypeDisplayName,
      'isValid': isValidData,
      'hasRawData': rawData != null,
      'specialFields': _getSpecialFields(),
    };
  }

  /// 스트림별 특수 필드들 추출
  Map<String, dynamic> _getSpecialFields() {
    final special = <String, dynamic>{};
    
    switch (streamType) {
      case BinanceStreamType.ticker:
      case BinanceStreamType.miniTicker:
        special['priceChangePercent'] = priceChangePercent;
        special['highPrice'] = highPrice;
        special['lowPrice'] = lowPrice;
        break;
      case BinanceStreamType.bookTicker:
        special['bestBidPrice'] = bestBidPrice;
        special['bestAskPrice'] = bestAskPrice;
        special['spread'] = spread;
        break;
      case BinanceStreamType.markPrice:
        special['indexPrice'] = indexPrice;
        special['fundingRate'] = fundingRate;
        break;
      case BinanceStreamType.kline:
      case BinanceStreamType.continuousKline:
      case BinanceStreamType.indexKline:
      case BinanceStreamType.markKline:
      case BinanceStreamType.blvtKline:
        special['ohlcv'] = ohlcv;
        break;
      case BinanceStreamType.liquidation:
        special['liquidationSide'] = liquidationSide;
        break;
      default:
        break;
    }
    
    return special;
  }

  /// JSON으로 변환 (API 응답용)
  Map<String, dynamic> toJson() {
    return {
      'market': market,
      'price': price,
      'quantity': quantity,
      'totalValue': totalValue,
      'isBuy': isBuy,
      'timestamp': timestamp,
      'tradeId': tradeId,
      'streamType': streamType.name,
      'streamCategory': streamCategory,
    };
  }

  /// Equatable을 위한 설정. tradeId를 기준으로 객체의 동등성을 비교합니다.
  @override
  List<Object?> get props => [tradeId];
  
  @override
  String toString() => 'Trade($market: $price × $quantity, ${streamType.name})';
}

// ===================================================================
// 🎯 바이낸스 Futures 스트림 정보 유틸리티
// ===================================================================

/// 바이낸스 Futures 스트림 정보 및 유틸리티
class BinanceStreamInfo {
  static const Map<BinanceStreamType, String> streamNames = {
    BinanceStreamType.aggTrade: '@aggTrade',
    BinanceStreamType.trade: '@trade',
    BinanceStreamType.ticker: '@ticker',
    BinanceStreamType.miniTicker: '@miniTicker',
    BinanceStreamType.bookTicker: '@bookTicker',
    BinanceStreamType.depth5: '@depth5',
    BinanceStreamType.depth10: '@depth10',
    BinanceStreamType.depth20: '@depth20',
    BinanceStreamType.depth: '@depth',
    BinanceStreamType.depthSpeed: '@depth@100ms',
    BinanceStreamType.kline: '@kline_', // + interval
    BinanceStreamType.continuousKline: '@continuousKline_', // + interval
    BinanceStreamType.markPrice: '@markPrice',
    BinanceStreamType.indexPrice: '@indexPrice',
    BinanceStreamType.liquidation: '@forceOrder',
    BinanceStreamType.compositeIndex: '@compositeIndex',
    BinanceStreamType.blvtNav: '@tokenNav',
    BinanceStreamType.blvtKline: '@nav_kline_', // + interval
    BinanceStreamType.allMarketTicker: '!ticker@arr',
    BinanceStreamType.allMarketMini: '!miniTicker@arr',
    BinanceStreamType.allBookTicker: '!bookTicker@arr',
    BinanceStreamType.allMarkPrice: '!markPrice@arr',
    BinanceStreamType.allLiquidation: '!forceOrder@arr',
  };

  /// 스트림별 예상 메시지 빈도 (초당)
  static const Map<BinanceStreamType, int> messageRates = {
    BinanceStreamType.aggTrade: 50,       // 매우 빠름
    BinanceStreamType.trade: 100,         // 극도로 빠름
    BinanceStreamType.ticker: 1,          // 1초마다
    BinanceStreamType.miniTicker: 1,      // 1초마다
    BinanceStreamType.bookTicker: 10,     // 실시간
    BinanceStreamType.depth5: 10,         // 1초마다
    BinanceStreamType.depth10: 10,        // 1초마다
    BinanceStreamType.depth20: 10,        // 1초마다
    BinanceStreamType.depth: 100,         // 매우 빠름
    BinanceStreamType.depthSpeed: 500,    // 극도로 빠름 (100ms)
    BinanceStreamType.kline: 4,           // 250ms
    BinanceStreamType.continuousKline: 4, // 250ms
    BinanceStreamType.markPrice: 1,       // 1-3초마다
    BinanceStreamType.indexPrice: 1,      // 3초마다
    BinanceStreamType.liquidation: 5,     // 가변적
    BinanceStreamType.compositeIndex: 1,  // 1초마다
    BinanceStreamType.blvtNav: 1,         // 1초마다
    BinanceStreamType.blvtKline: 4,       // 250ms
    BinanceStreamType.allMarketTicker: 1, // 1초마다 (많은 심볼)
    BinanceStreamType.allMarketMini: 1,   // 1초마다 (많은 심볼)
    BinanceStreamType.allBookTicker: 10,  // 실시간 (많은 심볼)
    BinanceStreamType.allMarkPrice: 1,    // 1-3초마다 (많은 심볼)
    BinanceStreamType.allLiquidation: 5,  // 가변적 (많은 심볼)
  };

  /// 위험 스트림 (높은 메시지 빈도)
  static const Set<BinanceStreamType> highVolumeStreams = {
    BinanceStreamType.trade,
    BinanceStreamType.depth,
    BinanceStreamType.depthSpeed,
    BinanceStreamType.allBookTicker,
  };

  /// 안전 스트림 (낮은 메시지 빈도)
  static const Set<BinanceStreamType> safeStreams = {
    BinanceStreamType.ticker,
    BinanceStreamType.miniTicker,
    BinanceStreamType.markPrice,
    BinanceStreamType.indexPrice,
    BinanceStreamType.compositeIndex,
  };

  /// 스트림 이름 생성
  static String generateStreamName(String symbol, BinanceStreamType streamType, {String? interval}) {
    final streamSuffix = streamNames[streamType] ?? '@unknown';
    
    // 전체 시장 스트림은 심볼 불필요
    if (streamType.name.startsWith('allMarket') || streamType.name.startsWith('all')) {
      return streamSuffix;
    }
    
    // 인터벌이 필요한 스트림들
    if (streamSuffix.endsWith('_')) {
      return '${symbol.toLowerCase()}${streamSuffix}${interval ?? '1m'}';
    }
    
    return '${symbol.toLowerCase()}$streamSuffix';
  }

  /// 스트림 타입 자동 감지
  static BinanceStreamType? detectStreamType(String streamName) {
    for (final entry in streamNames.entries) {
      final suffix = entry.value;
      if (suffix.endsWith('_')) {
        // 인터벌이 있는 스트림 (kline 등)
        if (streamName.contains(suffix)) {
          return entry.key;
        }
      } else {
        // 일반 스트림
        if (streamName.endsWith(suffix)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// 예상 메시지 속도 계산
  static int estimateMessageRate(List<BinanceStreamType> streamTypes) {
    return streamTypes.fold(0, (total, type) {
      return total + (messageRates[type] ?? 1);
    });
  }

  /// 스트림 안전성 체크
  static bool isSafeStreams(List<BinanceStreamType> streamTypes) {
    final hasHighVolume = streamTypes.any(highVolumeStreams.contains);
    final estimatedRate = estimateMessageRate(streamTypes);
    
    return !hasHighVolume && estimatedRate <= 1000; // 초당 1000개 이하
  }

  /// 스트림 조합 추천
  static Map<String, List<BinanceStreamType>> getRecommendedCombinations() {
    return {
      'basic': [
        BinanceStreamType.aggTrade,
        BinanceStreamType.ticker,
        BinanceStreamType.bookTicker,
      ],
      'trading': [
        BinanceStreamType.aggTrade,
        BinanceStreamType.bookTicker,
        BinanceStreamType.depth5,
        BinanceStreamType.markPrice,
      ],
      'analysis': [
        BinanceStreamType.ticker,
        BinanceStreamType.kline,
        BinanceStreamType.markPrice,
        BinanceStreamType.liquidation,
      ],
      'comprehensive': [
        BinanceStreamType.aggTrade,
        BinanceStreamType.ticker,
        BinanceStreamType.bookTicker,
        BinanceStreamType.depth5,
        BinanceStreamType.markPrice,
        BinanceStreamType.kline,
      ],
      'market_overview': [
        BinanceStreamType.allMarketTicker,
        BinanceStreamType.allMarkPrice,
        BinanceStreamType.allLiquidation,
      ],
    };
  }
}