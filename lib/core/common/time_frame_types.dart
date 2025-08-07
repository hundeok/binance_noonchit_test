import 'package:flutter/foundation.dart';

// ===================================================================
// 거래 필터 관련 정의
// ===================================================================

/// 거래 필터 Enum (단위: USDT)
///
/// 바이낸스 환경에 맞춰 거래대금 필터의 기준을 USDT로 변경합니다.
enum TradeFilter {
  usdt30k(30000, '30K'),  
  usdt50k(50000, '50K'),
  usdt100k(100000, '100K'),
  usdt300k(300000, '300K'),
  usdt500k(500000, '500K'),
  usdt1m(1000000, '1M'),
  usdt5m(5000000, '5M'),
  usdt10m(10000000, '10M');

  const TradeFilter(this.value, this.displayName);
  final double value;
  final String displayName;
  
  static List<TradeFilter> get supportedFilters => values.toList();
  
  /// USDT 단위 포맷팅된 표시명
  String get formattedDisplayName => '$displayName USDT';
}

/// 거래 모드 Enum (거래소 무관)
enum TradeMode {
  accumulated('누적'),
  range('구간');

  const TradeMode(this.displayName);
  final String displayName;
  
  bool get isAccumulated => this == TradeMode.accumulated;
}

// ===================================================================
// 시간 프레임 관련 정의 (볼륨라인용)
// ===================================================================

/// 거래량 데이터를 집계할 시간대(TimeFrame)를 정의하는 Enum
enum TimeFrame {
  min1(1, '1m'),
  min3(3, '3m'), 
  min5(5, '5m'),
  min15(15, '15m'),
  min30(30, '30m'),
  hour1(60, '1h'),
  hour2(120, '2h'),
  hour4(240, '4h'),
  hour6(360, '6h'),
  hour12(720, '12h'),
  day1(1440, '1d'),
  week1(10080, '1w');

  const TimeFrame(this.minutes, this.displayName);
  final int minutes;
  final String displayName;

  /// 시간 프레임의 Duration
  Duration get duration => Duration(minutes: minutes);
  
  /// 시간 프레임을 밀리초로 반환
  int get durationMs => duration.inMilliseconds;
  
  /// 사용자 친화적인 이름
  String get friendlyName {
    if (minutes < 60) {
      return '${minutes}분';
    } else if (minutes < 1440) {
      final hours = minutes ~/ 60;
      return '${hours}시간';
    } else if (minutes < 10080) {
      final days = minutes ~/ 1440;
      return '${days}일';
    } else {
      return '1주';
    }
  }
  
  /// 짧은 시간 프레임인지 확인 (5분 이하)
  bool get isShortTerm => minutes <= 5;
  
  /// 긴 시간 프레임인지 확인 (1일 이상)
  bool get isLongTerm => minutes >= 1440;
}

// ===================================================================
// 거래 관련 설정
// ===================================================================

/// 거래 관련 설정 (거래소 무관)
class TradeConfig {
  /// 필터별로 UI에 표시할 최대 거래 내역 개수
  static const int maxTradesPerFilter = 200;
  
  /// 중복 체결 ID를 걸러내기 위한 캐시 사이즈
  static const int maxSeenIdsCacheSize = 1000;
  
  /// 볼륨 순위에서 표시할 기본 개수
  static const int defaultVolumeRankingCount = 50;
  
  /// 볼륨 순위에서 표시할 최대 개수
  static const int maxVolumeRankingCount = 100;
  
  /// 볼륨 데이터 배치 업데이트 간격 (밀리초)
  static const int volumeBatchUpdateIntervalMs = 500;
  
  /// 볼륨 데이터 자동 리셋 체크 간격 (초)
  static const int volumeResetCheckIntervalSec = 15;
}

// ===================================================================
// 마켓 정보 관련 정의
// ===================================================================

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
  
  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'pair': pair,
      'status': status,
      'baseAsset': baseAsset,
      'quoteAsset': quoteAsset,
      'pricePrecision': pricePrecision,
      'quantityPrecision': quantityPrecision,
    };
  }
  
  /// 코인 티커 (USDT 제거)
  String get ticker => symbol.replaceAll('USDT', '');
  
  /// 거래 중인 마켓인지 확인
  bool get isTrading => status.toUpperCase() == 'TRADING';
  
  /// USDT 페어인지 확인
  bool get isUsdtPair => quoteAsset.toUpperCase() == 'USDT';
  
  @override
  String toString() => 'MarketInfo($symbol, $status)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarketInfo &&
          runtimeType == other.runtimeType &&
          symbol == other.symbol;

  @override
  int get hashCode => symbol.hashCode;
}

// ===================================================================
// 유틸리티 함수들
// ===================================================================

/// TimeFrame 관련 유틸리티
class TimeFrameUtils {
  /// 현재 시간을 기준으로 TimeFrame의 시작 시간 계산
  static DateTime getTimeFrameStart(TimeFrame timeFrame, [DateTime? now]) {
    now ??= DateTime.now();
    
    switch (timeFrame) {
      case TimeFrame.min1:
      case TimeFrame.min3:
      case TimeFrame.min5:
      case TimeFrame.min15:
      case TimeFrame.min30:
        // 분 단위: 해당 분의 시작으로 정렬
        final minutes = timeFrame.minutes;
        final alignedMinute = (now.minute ~/ minutes) * minutes;
        return DateTime(now.year, now.month, now.day, now.hour, alignedMinute);
        
      case TimeFrame.hour1:
      case TimeFrame.hour2:
      case TimeFrame.hour4:
      case TimeFrame.hour6:
      case TimeFrame.hour12:
        // 시간 단위: 해당 시간의 시작으로 정렬
        final hours = timeFrame.minutes ~/ 60;
        final alignedHour = (now.hour ~/ hours) * hours;
        return DateTime(now.year, now.month, now.day, alignedHour);
        
      case TimeFrame.day1:
        // 일 단위: 해당 일의 시작 (00:00)
        return DateTime(now.year, now.month, now.day);
        
      case TimeFrame.week1:
        // 주 단위: 해당 주의 월요일 00:00
        final monday = now.subtract(Duration(days: now.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
    }
  }
  
  /// TimeFrame이 리셋되어야 하는지 확인
  static bool shouldReset(TimeFrame timeFrame, DateTime startTime, [DateTime? now]) {
    now ??= DateTime.now();
    return now.difference(startTime) >= timeFrame.duration;
  }
  
  /// TimeFrame의 다음 시작 시간 계산
  static DateTime getNextTimeFrameStart(TimeFrame timeFrame, [DateTime? now]) {
    final currentStart = getTimeFrameStart(timeFrame, now);
    return currentStart.add(timeFrame.duration);
  }
  
  /// TimeFrame의 종료까지 남은 시간 (초)
  static int getRemainingSeconds(TimeFrame timeFrame, DateTime startTime, [DateTime? now]) {
    now ??= DateTime.now();
    final endTime = startTime.add(timeFrame.duration);
    final remaining = endTime.difference(now).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
}

/// TradeFilter 관련 유틸리티
class TradeFilterUtils {
  /// 값에 따른 적절한 TradeFilter 추천
  static TradeFilter getRecommendedFilter(double value) {
    for (final filter in TradeFilter.values.reversed) {
      if (value >= filter.value) {
        return filter;
      }
    }
    return TradeFilter.usdt30k; // 기본값
  }
  
  /// 필터 값을 포맷팅된 문자열로 변환
  static String formatFilterValue(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    } else {
      return value.toStringAsFixed(0);
    }
  }
}