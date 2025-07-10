import 'package:flutter/foundation.dart';

/// 거래 필터 Enum (단위: USDT)
///
/// 바이낸스 환경에 맞춰 거래대금 필터의 기준을 USDT로 변경합니다.
enum TradeFilter {
  usdt10k(10000, '10K USDT'),
  usdt30k(30000, '30K USDT'),
  usdt50k(50000, '50K USDT'),
  usdt100k(100000, '100K USDT'),
  usdt300k(300000, '300K USDT'),
  usdt500k(500000, '500K USDT');

  const TradeFilter(this.value, this.displayName);
  final double value;
  final String displayName;

  static List<TradeFilter> get supportedFilters => values.toList();
}

/// 거래 모드 Enum (거래소 무관)
enum TradeMode {
  accumulated('누적'),
  range('구간');

  const TradeMode(this.displayName);
  final String displayName;

  bool get isAccumulated => this == TradeMode.accumulated;
}

/// 거래 관련 설정 (거래소 무관)
class TradeConfig {
  /// 필터별로 UI에 표시할 최대 거래 내역 개수
  static const int maxTradesPerFilter = 200;
  
  /// 중복 체결 ID를 걸러내기 위한 캐시 사이즈
  static const int maxSeenIdsCacheSize = 1000;
}

/// 바이낸스 마켓 정보 엔티티
///
/// 바이낸스의 `/fapi/v1/exchangeInfo` 엔드포인트 응답을 기반으로 재구성합니다.
@immutable
class MarketInfo {
  final String symbol;
  final String pair;
  final String status;
  final String baseAsset;
  final String quoteAsset;
  final int pricePrecision;
  final int quantityPrecision;

  const MarketInfo({
    required this.symbol,
    required this.pair,
    required this.status,
    required this.baseAsset,
    required this.quoteAsset,
    required this.pricePrecision,
    required this.quantityPrecision,
  });

  factory MarketInfo.fromJson(Map<String, dynamic> json) {
    return MarketInfo(
      symbol: json['symbol'] ?? '',
      pair: json['pair'] ?? '',
      status: json['status'] ?? '',
      baseAsset: json['baseAsset'] ?? '',
      quoteAsset: json['quoteAsset'] ?? '',
      pricePrecision: json['pricePrecision'] ?? 0,
      quantityPrecision: json['quantityPrecision'] ?? 0,
    );
  }
}