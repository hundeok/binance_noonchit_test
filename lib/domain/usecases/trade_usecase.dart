// lib/domain/usecases/trade_usecase.dart

import 'dart:async';
import '../../core/error/app_exception.dart';
import '../../core/extensions/result.dart';
import '../../core/utils/logger.dart';
import '../entities/trade.dart';
import '../repositories/trade_repository.dart';

/// 🎯 바이낸스 거래 관련 비즈니스 로직을 제공하는 UseCase
/// - 멀티 스트림 지원 (aggTrade, ticker, bookTicker, depth5)
/// - Result 패턴으로 타입 안전한 에러 처리
/// - 스트림별 차별화된 비즈니스 로직 적용
/// - 실시간 필터링 및 집계 기능
class TradeUsecase {
  final TradeRepository _repository;
  
  // 📊 내부 상태 관리
  double _currentThreshold = 50000.0; // 기본 임계값: 50K USDT
  List<String> _currentMarkets = [];
  
  // 🔄 스트림 구독 관리
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  
  TradeUsecase(this._repository);

  // ===================================================================
  // 핵심 비즈니스 로직 메서드들
  // ===================================================================

  /// 🎯 원시 거래 스트림 (모든 스트림 타입 포함)
  /// 실시간 거래 데이터를 Result 패턴으로 안전하게 제공
  /// 
  /// [markets] 구독할 마켓 목록
  /// Returns: Result로 래핑된 Trade 스트림
  Stream<Result<Trade, AppException>> watchRawTrades(List<String> markets) {
    log.d('[TradeUsecase] Starting raw trades stream for ${markets.length} markets');
    
    _currentMarkets = List<String>.from(markets);
    
    return _repository
        .watchTrades(markets)
        .transform(_wrapStream<Trade>('Raw trades stream failed'));
  }

  /// 📊 필터링된 거래 리스트 (비즈니스 로직 적용)
  /// threshold와 markets를 기준으로 필터링된 거래 목록을 Result 패턴으로 제공
  /// 
  /// [threshold] 최소 거래대금 임계값 (USDT)
  /// [markets] 구독할 마켓 목록  
  /// Returns: Result로 래핑된 필터링된 Trade 리스트 스트림
  Stream<Result<List<Trade>, AppException>> filterTrades(
    double threshold,
    List<String> markets,
  ) {
    log.i('[TradeUsecase] Starting filtered trades: threshold=${threshold.toStringAsFixed(0)}, markets=${markets.length}');
    
    // ✅ 비즈니스 로직: 임계값 검증
    if (threshold < 0) {
      return Stream.value(Err(AppException.business('Invalid threshold: $threshold. Must be >= 0')));
    }
    
    if (markets.isEmpty) {
      return Stream.value(Err(AppException.business('Markets list cannot be empty')));
    }
    
    _currentThreshold = threshold;
    _currentMarkets = List<String>.from(markets);
    
    return _repository
        .watchFilteredTrades(threshold, markets)
        .transform(_wrapStream<List<Trade>>('Filter trades failed'))
        .map((result) => result.map(_applyBusinessLogicToList));
  }

  /// 🔄 집계된 거래 스트림 (스트림별 분리)
  /// TradeAggregator를 통해 병합/집계된 거래 데이터를 Result 패턴으로 제공
  /// 
  /// Returns: Result로 래핑된 집계 Trade 스트림
  Stream<Result<Trade, AppException>> aggregateTrades() {
    log.d('[TradeUsecase] Starting aggregated trades stream');
    
    return _repository
        .watchAggregatedTrades()
        .transform(_wrapStream<Trade>('Aggregate trades failed'))
        .map((result) => result.map(_applyBusinessLogicToTrade));
  }

  /// ✅ [추가] 스트림별 특화된 거래 스트림들

  /// aggTrade만 필터링한 스트림
  Stream<Result<Trade, AppException>> watchAggTrades(List<String> markets) {
    return watchRawTrades(markets)
        .map((result) => result.mapWhere(
          (trade) => trade.streamType == BinanceStreamType.aggTrade,
          fallback: () => Err(AppException.business('No aggTrade data available')),
        ));
  }

  /// ticker만 필터링한 스트림  
  Stream<Result<Trade, AppException>> watchTickers(List<String> markets) {
    return watchRawTrades(markets)
        .map((result) => result.mapWhere(
          (trade) => trade.streamType == BinanceStreamType.ticker,
          fallback: () => Err(AppException.business('No ticker data available')),
        ));
  }

  /// bookTicker만 필터링한 스트림
  Stream<Result<Trade, AppException>> watchBookTickers(List<String> markets) {
    return watchRawTrades(markets)
        .map((result) => result.mapWhere(
          (trade) => trade.streamType == BinanceStreamType.bookTicker,
          fallback: () => Err(AppException.business('No bookTicker data available')),
        ));
  }

  // ===================================================================
  // 비즈니스 로직 헬퍼 메서드들
  // ===================================================================

  /// 🎯 개별 거래에 비즈니스 로직 적용
  Trade _applyBusinessLogicToTrade(Trade trade) {
    // ✅ 비즈니스 로직 예시: 거래 검증 및 보강
    
    // 1. 데이터 검증
    if (!trade.isValidData) {
      log.w('[TradeUsecase] Invalid trade data detected: ${trade.market}');
      return trade;
    }
    
    // 2. 스트림별 추가 정보 계산
    switch (trade.streamType) {
      case BinanceStreamType.aggTrade:
        // aggTrade: 거래 크기별 등급 분류 가능
        break;
      case BinanceStreamType.ticker:
        // ticker: 변동률 기반 알림 로직 가능
        break;
      case BinanceStreamType.bookTicker:
        // bookTicker: 스프레드 분석 로직 가능
        break;
      case BinanceStreamType.depth5:
        // depth5: 호가 불균형 분석 가능
        break;
    }
    
    return trade;
  }

  /// 🎯 거래 리스트에 비즈니스 로직 적용
  List<Trade> _applyBusinessLogicToList(List<Trade> trades) {
    if (trades.isEmpty) return trades;
    
    // ✅ 비즈니스 로직 예시들:
    
    // 1. 데이터 품질 검증
    final validTrades = trades.where((trade) => trade.isValidData).toList();
    
    // 2. 중복 제거 (tradeId 기준)
    final seenIds = <String>{};
    final uniqueTrades = validTrades.where((trade) => seenIds.add(trade.tradeId)).toList();
    
    // 3. 시간순 정렬 (최신 순)
    uniqueTrades.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // 4. 임계값 재검증 (Repository 필터링 이후 추가 검증)
    final reFilteredTrades = uniqueTrades
        .where((trade) => trade.totalValue >= _currentThreshold)
        .toList();
    
    log.d('[TradeUsecase] Business logic applied: ${trades.length} → ${reFilteredTrades.length} trades');
    
    return reFilteredTrades;
  }

  // ===================================================================
  // 상태 관리 메서드들
  // ===================================================================

  /// ⚙️ 실시간 필터 임계값 업데이트
  void updateThreshold(double threshold) {
    if (threshold < 0) {
      log.w('[TradeUsecase] Invalid threshold: $threshold. Ignoring update.');
      return;
    }
    
    if (_currentThreshold == threshold) {
      log.d('[TradeUsecase] Threshold unchanged: $threshold');
      return;
    }
    
    final oldThreshold = _currentThreshold;
    _currentThreshold = threshold;
    
    log.i('[TradeUsecase] Threshold updated: ${oldThreshold.toStringAsFixed(0)} → ${threshold.toStringAsFixed(0)}');
    
    // Repository에 업데이트 전달
    _repository.updateThreshold(threshold);
  }

  /// 📊 현재 설정 상태 조회
  Map<String, dynamic> getCurrentState() {
    return {
      'currentThreshold': _currentThreshold,
      'currentMarkets': _currentMarkets,
      'activeSubscriptions': _activeSubscriptions.length,
    };
  }

  /// ✅ [추가] 임계값 사전 검증
  bool isValidThreshold(double threshold) {
    return threshold >= 0 && threshold <= 1000000000; // 10억 USDT 이하
  }

  /// ✅ [추가] 마켓 목록 검증  
  bool areValidMarkets(List<String> markets) {
    return markets.isNotEmpty && 
           markets.every((market) => market.isNotEmpty && market.contains('USDT'));
  }

  // ===================================================================
  // 유틸리티 메서드들
  // ===================================================================

  /// 🎯 스트림을 Result로 래핑하는 StreamTransformer
  StreamTransformer<T, Result<T, AppException>> _wrapStream<T>(String errorMsg) {
    return StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        sink.add(Ok(data));
      },
      handleError: (error, stackTrace, sink) {
        final appException = error is AppException 
            ? error 
            : AppException.network('$errorMsg: $error');
        
        log.e('[TradeUsecase] Stream error: $errorMsg', error, stackTrace);
        sink.add(Err(appException));
      },
    );
  }

  /// 🧹 리소스 정리
  Future<void> dispose() async {
    log.i('[TradeUsecase] Disposing... Current state: ${getCurrentState()}');
    
    // 활성 구독들 정리
    for (final subscription in _activeSubscriptions.values) {
      await subscription.cancel();
    }
    _activeSubscriptions.clear();
    
    // Repository 정리
    await _repository.dispose();
    
    // 상태 초기화
    _currentMarkets.clear();
    
    log.i('[TradeUsecase] Disposed successfully');
  }
}

// ===================================================================
// Result 확장 메서드들 (UseCase 전용)
// ===================================================================

extension ResultTradeExtensions<T, E> on Result<T, E> {
  /// 조건에 맞는 데이터만 필터링
  Result<T, E> mapWhere(bool Function(T) predicate, {required Result<T, E> Function() fallback}) {
    return when(
      ok: (data) => predicate(data) ? Ok(data) : fallback(),
      err: (error) => Err(error),
    );
  }
}