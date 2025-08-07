import 'package:equatable/equatable.dart';

/// 바이낸스 스트림 타입 열거
enum BinanceStreamType {
  aggTrade,    // 집계 거래 데이터
  ticker,      // 24시간 통계
  bookTicker,  // 최고 호가
  depth5,      // 5단계 호가창
}

class Trade extends Equatable {
  /// 심볼 (e.g., BTCUSDT)
  final String market;
  
  /// 체결 가격
  final double price;
  
  /// 체결 수량 (API 필드명 'q'에 맞춰 volume -> quantity로 변경)
  final double quantity;
  
  /// 총 체결액 (price * quantity)
  final double totalValue; // total -> totalValue로 명확화
  
  /// 매수 체결 여부
  final bool isBuy;
  
  /// 체결 시각 (milliseconds from epoch)
  final int timestamp; // timestampMs -> timestamp로 간소화
  
  /// 거래 고유 ID (Aggregate trade ID)
  final String tradeId; // id -> tradeId로 명확화
  
  /// ✅ [추가] 스트림 타입 구분
  final BinanceStreamType streamType;
  
  /// ✅ [추가] 원본 JSON 데이터 (디버깅/확장용)
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

  /// ✅ [개선] 바이낸스 선물 `aggTrade` 스트림 데이터로부터 Trade 객체 생성
  factory Trade.fromAggTrade(Map<String, dynamic> json) {
    final price = double.parse(json['p'].toString());
    final quantity = double.parse(json['q'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: price,
      quantity: quantity,
      totalValue: price * quantity,
      isBuy: !(json['m'] as bool), // isBuyerMaker(`m`)가 false일 때가 매수
      timestamp: json['T'] as int,
      tradeId: json['a'].toString(),
      streamType: BinanceStreamType.aggTrade,
      rawData: json,
    );
  }

  /// ✅ [추가] 바이낸스 `ticker` 스트림 데이터로부터 Trade 객체 생성
  factory Trade.fromTicker(Map<String, dynamic> json) {
    final lastPrice = double.parse(json['c'].toString());
    final volume = double.parse(json['v'].toString());
    final quoteVolume = double.parse(json['q'].toString());
    
    return Trade(
      market: json['s'] as String,
      price: lastPrice,
      quantity: volume,
      totalValue: quoteVolume,
      isBuy: true, // ticker는 방향성 없음 - 기본값
      timestamp: json['E'] as int, // Event time
      tradeId: 'ticker_${json['s']}_${json['E']}', // 고유 ID 생성
      streamType: BinanceStreamType.ticker,
      rawData: json,
    );
  }

  /// ✅ [추가] 바이낸스 `bookTicker` 스트림 데이터로부터 Trade 객체 생성
  factory Trade.fromBookTicker(Map<String, dynamic> json) {
    final bidPrice = double.parse(json['b'].toString());
    final askPrice = double.parse(json['a'].toString());
    final bidQty = double.parse(json['B'].toString());
    final askQty = double.parse(json['A'].toString());
    
    // 중간가격을 price로 사용
    final midPrice = (bidPrice + askPrice) / 2;
    final avgQty = (bidQty + askQty) / 2;
    
    return Trade(
      market: json['s'] as String,
      price: midPrice,
      quantity: avgQty,
      totalValue: midPrice * avgQty,
      isBuy: true, // bookTicker는 방향성 없음
      timestamp: DateTime.now().millisecondsSinceEpoch, // bookTicker에는 timestamp 없음
      tradeId: 'book_${json['s']}_${json['u']}', // updateId 사용
      streamType: BinanceStreamType.bookTicker,
      rawData: json,
    );
  }

  /// ✅ [수정] 바이낸스 `depth5` 스트림 데이터로부터 Trade 객체 생성 (실제 바이낸스 형식 지원)
  factory Trade.fromDepth5(Map<String, dynamic> json, String symbol) {
    // ✅ 수정: 바이낸스 실제 depth5 데이터는 'b'(bids), 'a'(asks) 필드 사용
    List<dynamic> bids;
    List<dynamic> asks;
    
    // 실제 바이낸스 depth5 형식 ('b', 'a')과 정규화된 형식 ('bids', 'asks') 모두 지원
    if (json.containsKey('b') && json.containsKey('a')) {
      bids = json['b'] as List;
      asks = json['a'] as List;
    } else if (json.containsKey('bids') && json.containsKey('asks')) {
      bids = json['bids'] as List;
      asks = json['asks'] as List;
    } else {
      throw ArgumentError('Missing order book data: expected b/a or bids/asks fields');
    }
    
    if (bids.isEmpty || asks.isEmpty) {
      throw ArgumentError('Empty order book data');
    }
    
    // 최고 매수/매도 호가
    final bestBid = double.parse(bids[0][0].toString());
    final bestAsk = double.parse(asks[0][0].toString());
    final bidQty = double.parse(bids[0][1].toString());
    final askQty = double.parse(asks[0][1].toString());
    
    // 스프레드 중간가격
    final midPrice = (bestBid + bestAsk) / 2;
    final avgQty = (bidQty + askQty) / 2;
    
    // ✅ 수정: updateId 필드 처리 개선
    String updateId = 'unknown';
    if (json.containsKey('u')) {
      // 바이낸스 실제 depth5: 'u' 필드
      updateId = json['u'].toString();
    } else if (json.containsKey('lastUpdateId')) {
      // 정규화된 형식: 'lastUpdateId' 필드
      updateId = json['lastUpdateId'].toString();
    }
    
    // ✅ 개선: timestamp 처리
    int timestamp = DateTime.now().millisecondsSinceEpoch;
    if (json.containsKey('E')) {
      // Event time이 있으면 사용
      timestamp = json['E'] as int;
    } else if (json.containsKey('T')) {
      // Transaction time이 있으면 사용
      timestamp = json['T'] as int;
    }
    
    return Trade(
      market: symbol,
      price: midPrice,
      quantity: avgQty,
      totalValue: midPrice * avgQty,
      isBuy: true, // depth는 방향성 없음
      timestamp: timestamp,
      tradeId: 'depth_${symbol}_$updateId',
      streamType: BinanceStreamType.depth5,
      rawData: json,
    );
  }

  /// ✅ [추가] 스트림 타입에 따른 팩토리 메서드 (통합 인터페이스)
  factory Trade.fromBinanceStream({
    required Map<String, dynamic> json,
    required BinanceStreamType streamType,
    String? symbol, // depth5용
  }) {
    switch (streamType) {
      case BinanceStreamType.aggTrade:
        return Trade.fromAggTrade(json);
      case BinanceStreamType.ticker:
        return Trade.fromTicker(json);
      case BinanceStreamType.bookTicker:
        return Trade.fromBookTicker(json);
      case BinanceStreamType.depth5:
        return Trade.fromDepth5(json, symbol ?? 'UNKNOWN');
    }
  }

  /// ✅ [유지] 기존 호환성을 위한 fromBinance (aggTrade 기본값)
  factory Trade.fromBinance(Map<String, dynamic> json) {
    return Trade.fromAggTrade(json);
  }

  /// ✅ [추가] 스트림별 추가 정보 접근자들
  
  /// ticker 스트림 전용: 24시간 변동률
  double? get priceChangePercent {
    if (streamType != BinanceStreamType.ticker || rawData == null) return null;
    return double.tryParse(rawData!['P']?.toString() ?? '');
  }
  
  /// ticker 스트림 전용: 24시간 고가
  double? get highPrice {
    if (streamType != BinanceStreamType.ticker || rawData == null) return null;
    return double.tryParse(rawData!['h']?.toString() ?? '');
  }
  
  /// ticker 스트림 전용: 24시간 저가
  double? get lowPrice {
    if (streamType != BinanceStreamType.ticker || rawData == null) return null;
    return double.tryParse(rawData!['l']?.toString() ?? '');
  }
  
  /// bookTicker 스트림 전용: 최고 매수 호가
  double? get bestBidPrice {
    if (streamType != BinanceStreamType.bookTicker || rawData == null) return null;
    return double.tryParse(rawData!['b']?.toString() ?? '');
  }
  
  /// bookTicker 스트림 전용: 최고 매도 호가
  double? get bestAskPrice {
    if (streamType != BinanceStreamType.bookTicker || rawData == null) return null;
    return double.tryParse(rawData!['a']?.toString() ?? '');
  }
  
  /// bookTicker 스트림 전용: 스프레드
  double? get spread {
    final bid = bestBidPrice;
    final ask = bestAskPrice;
    if (bid == null || ask == null) return null;
    return ask - bid;
  }

  /// ✅ [추가] depth5 스트림 전용 접근자들
  
  /// depth5 스트림 전용: 최고 매수 호가 (rawData에서 추출)
  double? get depth5BestBid {
    if (streamType != BinanceStreamType.depth5 || rawData == null) return null;
    
    // 'b' 필드에서 추출
    if (rawData!.containsKey('b')) {
      final bids = rawData!['b'] as List?;
      if (bids != null && bids.isNotEmpty) {
        return double.tryParse(bids[0][0].toString());
      }
    }
    
    // 'bids' 필드에서 추출 (fallback)
    if (rawData!.containsKey('bids')) {
      final bids = rawData!['bids'] as List?;
      if (bids != null && bids.isNotEmpty) {
        return double.tryParse(bids[0][0].toString());
      }
    }
    
    return null;
  }
  
  /// depth5 스트림 전용: 최고 매도 호가
  double? get depth5BestAsk {
    if (streamType != BinanceStreamType.depth5 || rawData == null) return null;
    
    // 'a' 필드에서 추출
    if (rawData!.containsKey('a')) {
      final asks = rawData!['a'] as List?;
      if (asks != null && asks.isNotEmpty) {
        return double.tryParse(asks[0][0].toString());
      }
    }
    
    // 'asks' 필드에서 추출 (fallback)
    if (rawData!.containsKey('asks')) {
      final asks = rawData!['asks'] as List?;
      if (asks != null && asks.isNotEmpty) {
        return double.tryParse(asks[0][0].toString());
      }
    }
    
    return null;
  }
  
  /// depth5 스트림 전용: 스프레드
  double? get depth5Spread {
    final bid = depth5BestBid;
    final ask = depth5BestAsk;
    if (bid == null || ask == null) return null;
    return ask - bid;
  }

  /// ✅ [추가] 유틸리티 메서드들
  
  /// 스트림 타입별 표시용 문자열
  String get streamTypeDisplayName {
    switch (streamType) {
      case BinanceStreamType.aggTrade:
        return 'Trade';
      case BinanceStreamType.ticker:
        return '24h Stats';
      case BinanceStreamType.bookTicker:
        return 'Best Bid/Ask';
      case BinanceStreamType.depth5:
        return 'Order Book';
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
      'isValid': isValidData,
      'hasRawData': rawData != null,
      // ✅ 추가: 스트림별 특화 정보
      if (streamType == BinanceStreamType.ticker) ...{
        'priceChangePercent': priceChangePercent,
        'highPrice': highPrice,
        'lowPrice': lowPrice,
      },
      if (streamType == BinanceStreamType.bookTicker) ...{
        'bestBidPrice': bestBidPrice,
        'bestAskPrice': bestAskPrice,
        'spread': spread,
      },
      if (streamType == BinanceStreamType.depth5) ...{
        'depth5BestBid': depth5BestBid,
        'depth5BestAsk': depth5BestAsk,
        'depth5Spread': depth5Spread,
      },
    };
  }

  /// Equatable을 위한 설정. tradeId를 기준으로 객체의 동등성을 비교합니다.
  @override
  List<Object?> get props => [tradeId];
  
  @override
  String toString() => 'Trade($market: $price × $quantity, ${streamType.name})';
}