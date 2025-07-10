import '../entities/trade.dart';
import '../entities/volume.dart';

/// 시간대별 거래량 데이터의 집계 및 제공을 담당하는 Repository 인터페이스
abstract class VolumeRepository {
  /// 지정된 시간대의 거래량 순위 스트림을 제공합니다.
  Stream<List<Volume>> watchVolumeRanking(TimeFrame timeFrame, List<String> markets);

  /// 특정 시간대의 누적 거래량을 수동으로 리셋합니다.
  void resetTimeFrame(TimeFrame timeFrame);

  /// 모든 시간대의 누적 거래량을 수동으로 리셋합니다.
  void resetAllTimeFrames();

  /// 리소스를 정리합니다.
  void dispose();
}