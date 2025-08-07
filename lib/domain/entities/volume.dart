// lib/domain/entities/volume.dart

import 'package:equatable/equatable.dart';
import '../../core/common/time_frame_types.dart';

/// 🎯 바이낸스 Futures 마켓별 실시간 거래량 정보 엔티티
/// 
/// 바이낸스 공식 문서 기준:
/// - aggTrade 스트림의 실제 체결 거래량만 집계
/// - USDT 기준 거래대금(quoteVolume) 계산
/// - 시간 프레임별 누적 집계 지원
class Volume extends Equatable {
  /// 마켓 심볼 (e.g., "BTCUSDT", "ETHUSDT")
  final String market;
  
  /// 해당 시간 프레임 동안의 누적 거래대금 (단위: USDT)
  /// 바이낸스 aggTrade 스트림의 p * q 값들을 누적 합계
  final double totalValue;
  
  /// 해당 시간 프레임 동안의 누적 거래량 (단위: base asset)
  /// 바이낸스 aggTrade 스트림의 q 값들을 누적 합계  
  final double totalQuantity;
  
  /// 해당 시간 프레임 동안의 총 거래 건수
  /// 바이낸스 aggTrade 스트림 메시지 개수
  final int tradeCount;
  
  /// 마지막 업데이트 시각 (milliseconds since epoch)
  final int lastUpdated;
  
  /// 데이터 집계 기준 시간 프레임
  final TimeFrame timeFrame;
  
  /// 현재 시간 프레임(봉)이 시작된 시각 (milliseconds since epoch)
  /// TimeFrameUtils.getTimeFrameStart()로 계산된 정확한 시작 시간
  final int timeFrameStart;
  
  /// 해당 시간 프레임에서의 최고가 (USDT)
  final double? highPrice;
  
  /// 해당 시간 프레임에서의 최저가 (USDT)  
  final double? lowPrice;
  
  /// 해당 시간 프레임의 첫 거래 가격 (USDT)
  final double? openPrice;
  
  /// 해당 시간 프레임의 마지막 거래 가격 (USDT)
  final double? closePrice;

  const Volume({
    required this.market,
    required this.totalValue,
    required this.totalQuantity,
    required this.tradeCount,
    required this.lastUpdated,
    required this.timeFrame,
    required this.timeFrameStart,
    this.highPrice,
    this.lowPrice,
    this.openPrice,
    this.closePrice,
  });
  
  // ===================================================================
  // 🎯 바이낸스 aggTrade 기반 팩토리 메서드
  // ===================================================================
  
  /// 바이낸스 aggTrade 데이터로부터 Volume 생성 (초기 생성)
  factory Volume.fromAggTrade({
    required String market,
    required double price,
    required double quantity,
    required TimeFrame timeFrame,
    required int timeFrameStart,
    int? timestamp,
  }) {
    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final totalValue = price * quantity;
    
    return Volume(
      market: market,
      totalValue: totalValue,
      totalQuantity: quantity,
      tradeCount: 1,
      lastUpdated: now,
      timeFrame: timeFrame,
      timeFrameStart: timeFrameStart,
      highPrice: price,
      lowPrice: price,
      openPrice: price,
      closePrice: price,
    );
  }
  
  /// 기존 Volume에 새로운 aggTrade 데이터 누적
  Volume addAggTrade({
    required double price,
    required double quantity,
    int? timestamp,
  }) {
    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final tradeValue = price * quantity;
    
    return copyWith(
      totalValue: totalValue + tradeValue,
      totalQuantity: totalQuantity + quantity,
      tradeCount: tradeCount + 1,
      lastUpdated: now,
      highPrice: highPrice != null ? 
          (price > highPrice! ? price : highPrice) : price,
      lowPrice: lowPrice != null ? 
          (price < lowPrice! ? price : lowPrice) : price,
      closePrice: price, // 항상 최신 가격으로 업데이트
      // openPrice는 유지 (첫 거래 가격)
    );
  }
  
  // ===================================================================
  // 🔢 계산된 속성들
  // ===================================================================
  
  /// 코인 티커만 추출 (e.g., "BTCUSDT" -> "BTC")
  String get ticker => market.replaceAll('USDT', '');
  
  /// 현재 시간 프레임(봉)이 끝나는 예정 시각
  DateTime get timeFrameEnd => 
      DateTime.fromMillisecondsSinceEpoch(timeFrameStart).add(timeFrame.duration);
  
  /// 현재 시간 프레임 시작 시각 (DateTime)
  DateTime get timeFrameStartTime => 
      DateTime.fromMillisecondsSinceEpoch(timeFrameStart);
  
  /// 마지막 업데이트 시각 (DateTime)
  DateTime get lastUpdatedTime => 
      DateTime.fromMillisecondsSinceEpoch(lastUpdated);
  
  /// 현재 시간 프레임 남은 시간 (초)
  int get remainingSeconds {
    final remaining = timeFrameEnd.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
  
  /// 평균 거래 가격 (VWAP - Volume Weighted Average Price)
  double get averagePrice => totalQuantity > 0 ? totalValue / totalQuantity : 0.0;
  
  /// 가격 변동률 (%) - open 대비 close
  double? get priceChangePercent {
    if (openPrice == null || closePrice == null || openPrice == 0) return null;
    return ((closePrice! - openPrice!) / openPrice!) * 100;
  }
  
  /// 가격 변동폭 (절댓값)
  double? get priceRange {
    if (highPrice == null || lowPrice == null) return null;
    return highPrice! - lowPrice!;
  }
  
  /// 거래 활발도 점수 (거래건수 / 분)
  double get activityScore {
    if (timeFrame.minutes == 0) return 0.0;
    return tradeCount / timeFrame.minutes;
  }
  
  /// 시간 프레임 진행률 (0.0 ~ 1.0)
  double get progressRatio {
    final elapsed = DateTime.now().difference(timeFrameStartTime);
    final total = timeFrame.duration;
    final ratio = elapsed.inMilliseconds / total.inMilliseconds;
    return ratio.clamp(0.0, 1.0);
  }
  
  // ===================================================================
  // 🔧 유틸리티 메서드들
  // ===================================================================
  
  /// 데이터 유효성 검증
  bool get isValidData => 
      market.isNotEmpty && 
      totalValue >= 0 && 
      totalQuantity >= 0 && 
      tradeCount >= 0 &&
      lastUpdated > 0 &&
      timeFrameStart > 0;
  
  /// 시간 프레임이 만료되었는지 확인
  bool get isExpired => remainingSeconds <= 0;
  
  /// 활발한 거래량인지 확인 (임계값 기준)
  bool isActiveVolume(double threshold) => totalValue >= threshold;
  
  /// 상위 랭킹 대상인지 확인 (최소 조건)
  bool get isRankingEligible => 
      isValidData && 
      totalValue > 0 && 
      tradeCount >= 3; // 최소 3건 이상 거래
  
  /// 복사 메서드 (불변 객체 수정용)
  Volume copyWith({
    String? market,
    double? totalValue,
    double? totalQuantity,
    int? tradeCount,
    int? lastUpdated,
    TimeFrame? timeFrame,
    int? timeFrameStart,
    double? highPrice,
    double? lowPrice,
    double? openPrice,
    double? closePrice,
  }) {
    return Volume(
      market: market ?? this.market,
      totalValue: totalValue ?? this.totalValue,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      tradeCount: tradeCount ?? this.tradeCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      timeFrame: timeFrame ?? this.timeFrame,
      timeFrameStart: timeFrameStart ?? this.timeFrameStart,
      highPrice: highPrice ?? this.highPrice,
      lowPrice: lowPrice ?? this.lowPrice,
      openPrice: openPrice ?? this.openPrice,
      closePrice: closePrice ?? this.closePrice,
    );
  }
  
  /// 디버그용 상세 정보
  Map<String, dynamic> toDebugMap() {
    return {
      'market': market,
      'ticker': ticker,
      'totalValue': totalValue,
      'totalQuantity': totalQuantity,
      'tradeCount': tradeCount,
      'averagePrice': averagePrice,
      'priceChangePercent': priceChangePercent,
      'priceRange': priceRange,
      'activityScore': activityScore,
      'progressRatio': progressRatio,
      'remainingSeconds': remainingSeconds,
      'timeFrame': timeFrame.displayName,
      'timeFrameStartTime': timeFrameStartTime.toIso8601String(),
      'lastUpdatedTime': lastUpdatedTime.toIso8601String(),
      'isValidData': isValidData,
      'isExpired': isExpired,
      'isRankingEligible': isRankingEligible,
    };
  }
  
  /// JSON 직렬화 (필요시 저장/로드용)
  Map<String, dynamic> toJson() {
    return {
      'market': market,
      'totalValue': totalValue,
      'totalQuantity': totalQuantity,
      'tradeCount': tradeCount,
      'lastUpdated': lastUpdated,
      'timeFrame': timeFrame.displayName,
      'timeFrameStart': timeFrameStart,
      'highPrice': highPrice,
      'lowPrice': lowPrice,
      'openPrice': openPrice,
      'closePrice': closePrice,
    };
  }
  
  /// JSON에서 Volume 객체 생성
  factory Volume.fromJson(Map<String, dynamic> json) {
    // TimeFrame 찾기
    final timeFrameName = json['timeFrame'] as String;
    final timeFrame = TimeFrame.values.firstWhere(
      (tf) => tf.displayName == timeFrameName,
      orElse: () => TimeFrame.min5, // 기본값
    );
    
    return Volume(
      market: json['market'] as String,
      totalValue: (json['totalValue'] as num).toDouble(),
      totalQuantity: (json['totalQuantity'] as num).toDouble(),
      tradeCount: json['tradeCount'] as int,
      lastUpdated: json['lastUpdated'] as int,
      timeFrame: timeFrame,
      timeFrameStart: json['timeFrameStart'] as int,
      highPrice: json['highPrice'] != null ? (json['highPrice'] as num).toDouble() : null,
      lowPrice: json['lowPrice'] != null ? (json['lowPrice'] as num).toDouble() : null,
      openPrice: json['openPrice'] != null ? (json['openPrice'] as num).toDouble() : null,
      closePrice: json['closePrice'] != null ? (json['closePrice'] as num).toDouble() : null,
    );
  }
  
  /// Equatable을 위한 설정 (market + timeFrame으로 고유성 판단)
  @override
  List<Object?> get props => [market, timeFrame, timeFrameStart];
  
  @override
  String toString() => 
      'Volume($market: \$${totalValue.toStringAsFixed(0)} over ${timeFrame.displayName}, ${tradeCount} trades)';
}

// ===================================================================
// 🔧 Volume 관련 유틸리티 클래스
// ===================================================================

/// Volume 데이터 조작을 위한 유틸리티
class VolumeUtils {
  /// Volume 리스트를 거래대금 순으로 정렬
  static List<Volume> sortByValue(List<Volume> volumes, {bool descending = true}) {
    final sorted = volumes.where((v) => v.isRankingEligible).toList();
    sorted.sort((a, b) => descending 
        ? b.totalValue.compareTo(a.totalValue)
        : a.totalValue.compareTo(b.totalValue));
    return sorted;
  }
  
  /// 특정 임계값 이상의 Volume만 필터링
  static List<Volume> filterByThreshold(List<Volume> volumes, double threshold) {
    return volumes.where((v) => v.isActiveVolume(threshold)).toList();
  }
  
  /// Volume 리스트를 활발도 순으로 정렬
  static List<Volume> sortByActivity(List<Volume> volumes, {bool descending = true}) {
    final sorted = volumes.where((v) => v.isRankingEligible).toList();
    sorted.sort((a, b) => descending 
        ? b.activityScore.compareTo(a.activityScore)
        : a.activityScore.compareTo(b.activityScore));
    return sorted;
  }
  
  /// 가격 변동률 기준 정렬
  static List<Volume> sortByPriceChange(List<Volume> volumes, {bool descending = true}) {
    final sorted = volumes
        .where((v) => v.isRankingEligible && v.priceChangePercent != null)
        .toList();
    sorted.sort((a, b) {
      final aChange = a.priceChangePercent!;
      final bChange = b.priceChangePercent!;
      return descending ? bChange.compareTo(aChange) : aChange.compareTo(bChange);
    });
    return sorted;
  }
  
  /// 만료된 Volume 제거
  static List<Volume> removeExpired(List<Volume> volumes) {
    return volumes.where((v) => !v.isExpired).toList();
  }
  
  /// Volume 리스트 통계 계산
  static Map<String, dynamic> calculateStats(List<Volume> volumes) {
    if (volumes.isEmpty) {
      return {
        'totalMarkets': 0,
        'totalValue': 0.0,
        'totalTrades': 0,
        'averageValue': 0.0,
        'averageActivity': 0.0,
      };
    }
    
    final validVolumes = volumes.where((v) => v.isValidData).toList();
    final totalValue = validVolumes.fold<double>(0.0, (sum, v) => sum + v.totalValue);
    final totalTrades = validVolumes.fold<int>(0, (sum, v) => sum + v.tradeCount);
    final totalActivity = validVolumes.fold<double>(0.0, (sum, v) => sum + v.activityScore);
    
    return {
      'totalMarkets': validVolumes.length,
      'totalValue': totalValue,
      'totalTrades': totalTrades,
      'averageValue': totalValue / validVolumes.length,
      'averageActivity': totalActivity / validVolumes.length,
      'topMarket': validVolumes.isNotEmpty 
          ? sortByValue(validVolumes).first.market 
          : null,
    };
  }
}