// lib/data/processors/trade_aggregator.dart

import 'dart:async';
import '../../domain/entities/trade.dart';
import '../../core/utils/logger.dart';

/// 실시간 거래를 병합하여 UI 업데이트 빈도를 조절하는 거래 집계기
class TradeAggregator {
  final Map<String, Trade> _pendingTrades = {};
  final _controller = StreamController<Trade>.broadcast();
  Timer? _flushTimer;

  /// 집계 처리된 거래 데이터 스트림
  Stream<Trade> get stream => _controller.stream;

  TradeAggregator() {
    // 1초마다 대기 중인 거래들을 방출(flush)하여 항상 최신 데이터가 반영되도록 함
    _flushTimer = Timer.periodic(const Duration(seconds: 1), (_) => _flush());
  }

  /// 새로운 거래를 받아 집계 로직 처리
  void process(Trade trade) {
    final existing = _pendingTrades[trade.market];

    // 해당 마켓에 대기 중인 거래가 없다면 새로 추가
    if (existing == null) {
      _pendingTrades[trade.market] = trade;
      return;
    }

    // 시간 창(500ms) 내의 거래라면 병합
    if (trade.timestamp - existing.timestamp <= 500) {
      final newQuantity = existing.quantity + trade.quantity;
      _pendingTrades[trade.market] = Trade(
        market: trade.market,
        price: trade.price, // 가격은 최신 거래의 것을 따름
        quantity: newQuantity,
        totalValue: existing.totalValue + trade.totalValue,
        isBuy: trade.isBuy, // 방향도 최신 거래의 것을 따름
        timestamp: trade.timestamp,
        tradeId: trade.tradeId,
      );
    } else {
      // 시간 창을 벗어나면, 기존 거래는 방출하고 새 거래를 대기
      _controller.add(existing);
      _pendingTrades[trade.market] = trade;
    }
  }

  /// 대기 중인 모든 거래를 방출
  void _flush() {
    if (_pendingTrades.isEmpty) return;
    _pendingTrades.values.forEach(_controller.add);
    _pendingTrades.clear();
  }

  void dispose() {
    _flushTimer?.cancel();
    _controller.close();
    log.i('[Aggregator] Disposed.');
  }
}