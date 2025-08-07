// lib/data/processors/trade_aggregator.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/entities/trade.dart';
import '../../core/config/app_config.dart';
import '../../core/utils/logger.dart';

/// 🎯 바이낸스 전용 실시간 거래 집계기 (업비트 스타일 개선)
/// - 멀티 스트림 지원 (aggTrade, ticker, bookTicker, depth5)
/// - 스트림별 다른 병합 전략 적용
/// - 가중 평균 가격 계산으로 정확도 향상
/// - 에러 처리 및 성능 모니터링 추가
class TradeAggregator {
  final Map<String, Trade> _pendingTrades = {};
  final StreamController<Trade> _controller = StreamController<Trade>.broadcast();
  Timer? _flushTimer;
  
  // 📊 성능 모니터링
  int _processedCount = 0;
  int _mergedCount = 0;
  int _flushedCount = 0;
  DateTime? _lastActivityTime;

  /// 집계 처리된 거래 데이터 스트림
  Stream<Trade> get stream => _controller.stream;

  /// 스트림별 병합 창 설정 (밀리초)
  int get mergeWindowMs => AppConfig.mergeWindowMs;

  TradeAggregator() {
    // ✅ [개선] AppConfig 기반 flush 주기 설정
    final flushInterval = Duration(milliseconds: AppConfig.aggregatorFlushIntervalMs);
    _flushTimer = Timer.periodic(flushInterval, (_) => _flush());
    log.i('[TradeAggregator] Initialized with ${mergeWindowMs}ms merge window, '
          '${AppConfig.aggregatorFlushIntervalMs}ms flush interval');
  }

  /// 🎯 새로운 거래를 받아 스트림별 집계 로직 처리
  void process(Trade trade) {
    try {
      // ✅ [추가] 데이터 검증
      if (!trade.isValidData) {
        if (kDebugMode) {
          log.w('[TradeAggregator] Invalid trade data: ${trade.market}');
        }
        return;
      }

      _processedCount++;
      _lastActivityTime = DateTime.now();

      // ✅ [개선] AppConfig 기반 스트림별 처리 분기
      final shouldProcessImmediately = AppConfig.shouldProcessImmediately(trade.streamType.name);
      final streamMergeWindow = AppConfig.getMergeWindowForStream(trade.streamType.name);

      switch (trade.streamType) {
        case BinanceStreamType.aggTrade:
          _processAggTrade(trade, streamMergeWindow);
          break;
        case BinanceStreamType.ticker:
          _processTicker(trade, shouldProcessImmediately);
          break;
        case BinanceStreamType.bookTicker:
          _processBookTicker(trade, shouldProcessImmediately);
          break;
        case BinanceStreamType.depth5:
          _processDepth5(trade, shouldProcessImmediately);
          break;
      }

    } catch (e, st) {
      log.e('[TradeAggregator] Process error for ${trade.market}', e, st);
    }
  }

  /// ✅ [신규] aggTrade 전용 처리 (거래량 가중 평균)
  void _processAggTrade(Trade trade, int mergeWindow) {
    final existing = _pendingTrades[trade.market];

    // 해당 마켓에 대기 중인 거래가 없다면 새로 추가하고 즉시 방출
    if (existing == null) {
      _pendingTrades[trade.market] = trade;
      _controller.add(trade); // ✅ [개선] 첫 거래 즉시 반영
      if (kDebugMode) {
        log.d('[TradeAggregator] New aggTrade: ${trade.market} ${trade.price} × ${trade.quantity}');
      }
      return;
    }

    // ✅ [개선] 같은 스트림 타입만 병합
    if (existing.streamType != BinanceStreamType.aggTrade) {
      _pendingTrades[trade.market] = trade;
      _controller.add(trade);
      return;
    }

    // 시간 창 내의 거래라면 가중 평균으로 병합
    if (trade.timestamp - existing.timestamp <= mergeWindow) {
      final totalQuantity = existing.quantity + trade.quantity;
      final totalValue = existing.totalValue + trade.totalValue;
      
      // ✅ [핵심] AppConfig 설정 기반 가격 계산
      final newPrice = AppConfig.useWeightedAverage() 
          ? totalValue / totalQuantity  // 가중 평균
          : trade.price;                // 최신 가격

      final mergedTrade = trade.copyWith(
        price: newPrice,
        quantity: totalQuantity,
        totalValue: totalValue,
        timestamp: trade.timestamp, // 최신 시간 사용
      );

      _pendingTrades[trade.market] = mergedTrade;
      _mergedCount++;

      if (kDebugMode && AppConfig.enableMergeLogging) {
        log.d('[TradeAggregator] Merged aggTrade: ${trade.market} '
              'price: ${newPrice.toStringAsFixed(2)}, '
              'total: ${totalQuantity.toStringAsFixed(4)}');
      }
    } else {
      // 시간 창을 벗어나면, 기존 거래는 방출하고 새 거래를 대기
      _controller.add(existing);
      _pendingTrades[trade.market] = trade;
      _controller.add(trade); // 새 거래도 즉시 방출
    }
  }

  /// ✅ [신규] ticker 전용 처리 (최신값 우선)
  void _processTicker(Trade trade, bool processImmediately) {
    final existing = _pendingTrades[trade.market];

    // ✅ [개선] AppConfig 설정에 따라 즉시 처리 또는 병합
    if (processImmediately || existing == null || existing.streamType != BinanceStreamType.ticker) {
      _pendingTrades[trade.market] = trade;
      _controller.add(trade);
      return;
    }

    // 짧은 시간 내 연속 ticker는 마지막 것만 유지 (throttling 효과)
    if (trade.timestamp - existing.timestamp <= 1000) { // 1초 내
      _pendingTrades[trade.market] = trade; // 덮어쓰기
    } else {
      _controller.add(existing); // 기존 것 방출
      _pendingTrades[trade.market] = trade;
      _controller.add(trade); // 새 것도 방출
    }
  }

  /// ✅ [신규] bookTicker 전용 처리 (스프레드 중심)
  void _processBookTicker(Trade trade, bool processImmediately) {
    // ✅ [개선] AppConfig 설정 기반 처리
    _pendingTrades[trade.market] = trade;
    if (processImmediately) {
      _controller.add(trade);
    }
    
    if (kDebugMode && AppConfig.enableMergeLogging) {
      final spread = trade.spread;
      log.d('[TradeAggregator] BookTicker: ${trade.market} '
            'spread: ${spread?.toStringAsFixed(4) ?? "N/A"}');
    }
  }

  /// ✅ [신규] depth5 전용 처리 (호가창 업데이트)
  void _processDepth5(Trade trade, bool processImmediately) {
    // ✅ [개선] AppConfig 설정 기반 처리
    _pendingTrades[trade.market] = trade;
    if (processImmediately) {
      _controller.add(trade);
    }
    
    if (kDebugMode && AppConfig.enableMergeLogging) {
      log.d('[TradeAggregator] Depth5: ${trade.market} mid: ${trade.price.toStringAsFixed(2)}');
    }
  }

  /// ✅ [개선] 대기 중인 모든 거래를 방출 (성능 향상)
  void _flush() {
    if (_pendingTrades.isEmpty) return;

    try {
      final trades = _pendingTrades.values.toList();
      _flushedCount += trades.length;
      
      // ✅ [개선] 배치로 한번에 처리
      for (final trade in trades) {
        if (!_controller.isClosed) {
          _controller.add(trade);
        }
      }
      
      _pendingTrades.clear();

      if (kDebugMode && trades.isNotEmpty) {
        log.d('[TradeAggregator] Flushed ${trades.length} pending trades');
      }
    } catch (e, st) {
      log.e('[TradeAggregator] Flush error', e, st);
    }
  }

  /// ✅ [추가] 모든 대기 거래를 즉시 방출 (수동 flush)
  void flushAll() {
    log.i('[TradeAggregator] Manual flush requested');
    _flush();
  }

  /// ✅ [추가] 성능 통계 조회
  Map<String, dynamic> getStats() {
    return {
      'processedCount': _processedCount,
      'mergedCount': _mergedCount,
      'flushedCount': _flushedCount,
      'pendingTrades': _pendingTrades.length,
      'mergeWindowMs': mergeWindowMs,
      'lastActivityTime': _lastActivityTime?.toIso8601String(),
      'isActive': _flushTimer?.isActive ?? false,
    };
  }

  /// ✅ [추가] 특정 마켓의 대기 중인 거래 조회 (디버깅용)
  Trade? getPendingTrade(String market) {
    return _pendingTrades[market];
  }

  /// ✅ [추가] 현재 대기 중인 거래 수
  int get pendingTradesCount => _pendingTrades.length;

  /// ✅ [추가] 처리 통계 초기화 (테스트용)
  void resetStats() {
    _processedCount = 0;
    _mergedCount = 0;
    _flushedCount = 0;
    _lastActivityTime = null;
    log.i('[TradeAggregator] Stats reset');
  }

  /// ✅ [추가] 모든 대기 거래 클리어 (테스트/디버그용)
  void clear() {
    _pendingTrades.clear();
    log.i('[TradeAggregator] All pending trades cleared');
  }

  /// 🧹 리소스 정리
  void dispose() {
    log.i('[TradeAggregator] Disposing... Stats: ${getStats()}');
    
    // 마지막 flush
    _flush();
    
    _flushTimer?.cancel();
    _flushTimer = null;
    
    if (!_controller.isClosed) {
      _controller.close();
    }
    
    _pendingTrades.clear();
    log.i('[TradeAggregator] Disposed');
  }
}