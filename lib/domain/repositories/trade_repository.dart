// lib/domain/repositories/trade_repository.dart

import '../entities/trade.dart';

/// 🎯 바이낸스 거래 데이터 Repository 인터페이스
/// - 멀티 스트림 지원 (aggTrade, ticker, bookTicker, depth5)
/// - 효율적인 필터링 및 집계 시스템
/// - 실시간 임계값 업데이트 지원
abstract class TradeRepository {
  
  /// 🎯 원시 거래 스트림 제공
  /// 모든 스트림 타입(aggTrade, ticker, bookTicker, depth5)을 포함한 실시간 데이터
  /// 
  /// [markets] 구독할 마켓 목록 (예: ['BTCUSDT', 'ETHUSDT'])
  /// Returns: Trade 객체의 실시간 스트림
  Stream<Trade> watchTrades(List<String> markets);

  /// 📊 필터링된 거래 리스트 스트림
  /// 지정된 임계값 이상의 거래만 필터링하여 리스트로 제공
  /// 
  /// [threshold] 최소 거래대금 임계값 (USDT 기준)
  /// [markets] 구독할 마켓 목록
  /// Returns: 필터링된 Trade 리스트의 실시간 스트림
  Stream<List<Trade>> watchFilteredTrades(double threshold, List<String> markets);

  /// 🔄 집계 처리된 거래 스트림
  /// TradeAggregator를 통해 병합/집계된 거래 데이터 제공
  /// 
  /// Returns: 집계된 Trade 객체의 실시간 스트림
  Stream<Trade> watchAggregatedTrades();

  /// ⚙️ 실시간 필터 임계값 업데이트
  /// UI에서 필터 값이 변경될 때 호출하여 즉시 필터링 결과 업데이트
  /// 
  /// [threshold] 새로운 임계값 (USDT 기준)
  void updateThreshold(double threshold);

  /// 🧹 리소스 정리
  /// WebSocket 연결, 스트림 구독, 메모리 캐시 등 모든 리소스 해제
  Future<void> dispose();
}