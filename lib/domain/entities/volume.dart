import 'package:equatable/equatable.dart';

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

  Duration get duration => Duration(minutes: minutes);
}


/// 마켓별, 시간대별 누적 거래량 정보를 담는 데이터 모델
class Volume extends Equatable {
  /// 마켓 심볼 (e.g., "BTCUSDT")
  final String market;
  
  /// 해당 시간대 누적 거래대금 (단위: USDT)
  final double totalValue;
  
  /// 마지막 업데이트 시각 (milliseconds from epoch)
  final int lastUpdated;
  
  /// 데이터 집계 기준 시간대
  final TimeFrame timeFrame;
  
  /// 현재 시간대(봉)가 시작된 시각 (milliseconds from epoch)
  final int timeFrameStart;

  const Volume({
    required this.market,
    required this.totalValue,
    required this.lastUpdated,
    required this.timeFrame,
    required this.timeFrameStart,
  });
  
  /// 코인 티커만 추출 (e.g., "BTCUSDT" -> "BTC")
  String get ticker => market.replaceAll('USDT', '');

  /// 현재 시간대(봉)가 끝나는 예정 시각
  DateTime get timeFrameEnd =>
      DateTime.fromMillisecondsSinceEpoch(timeFrameStart).add(timeFrame.duration);

  /// 현재 시간대 남은 시간 (초)
  int get remainingSeconds {
    final remaining = timeFrameEnd.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
  
  @override
  List<Object> get props => [market, timeFrame];
}