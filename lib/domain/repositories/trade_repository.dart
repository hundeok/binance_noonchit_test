// lib/domain/repositories/trade_repository.dart

import '../entities/trade.dart';

abstract class TradeRepository {
  /// 필터링된 실시간 체결 리스트 스트림
  Stream<List<Trade>> watchFilteredTrades(List<String> markets);

  /// 집계 처리된 단일 체결 스트림
  Stream<Trade> watchAggregatedTrades(List<String> markets);

  /// 실시간으로 필터 임계값 업데이트
  void updateThreshold(double threshold);
  
  /// 리소스 정리
  void dispose();
}