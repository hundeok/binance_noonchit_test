// lib/data/repositories/trade_repository_impl.dart

import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/common/time_frame_types.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../datasources/trade_remote_ds.dart';
import '../processors/trade_aggregator.dart';
import '../../core/utils/logger.dart';

class TradeRepositoryImpl implements TradeRepository {
  final TradeRemoteDataSource _remoteDataSource;
  final TradeAggregator _aggregator;
  
  // 데이터 스트림 컨트롤러
  final _filteredTradesController = StreamController<List<Trade>>.broadcast();
  
  // 내부 상태
  StreamSubscription? _rawTradeSub;
  StreamSubscription? _aggregatedTradeSub;
  double _currentThreshold = TradeFilter.usdt50k.value; // 기본 임계값
  final Map<TradeFilter, List<Trade>> _filterCache = {
    for (var filter in TradeFilter.values) filter: []
  };
  final _seenIds = LinkedHashSet<String>();
  Timer? _batchUpdateTimer;
  bool _isInitialized = false;

  TradeRepositoryImpl(this._remoteDataSource) : _aggregator = TradeAggregator();

  void _initialize(List<String> markets) {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. 원격 데이터 소스의 스트림을 구독
    final rawTradeStream = _remoteDataSource.watchTrades(markets);
    _rawTradeSub = rawTradeStream.listen(_processRawTrade);

    // 2. 집계기(Aggregator)의 스트림을 구독
    _aggregatedTradeSub = _aggregator.stream.listen(_handleAggregatedTrade);
    
    log.i('[Repository] Initialized with ${markets.length} markets.');
  }

  /// 1. 원시 데이터 처리: 중복 확인 후 집계기로 전달
  void _processRawTrade(Trade trade) {
    if (!_seenIds.add(trade.tradeId)) return;
    if (_seenIds.length > TradeConfig.maxSeenIdsCacheSize) {
      _seenIds.remove(_seenIds.first);
    }
    _aggregator.process(trade);
  }

  /// 2. 집계된 데이터 처리: 필터별 캐시에 저장
  void _handleAggregatedTrade(Trade trade) {
    for (final filter in TradeFilter.values) {
      if (trade.totalValue >= filter.value) {
        final list = _filterCache[filter]!;
        list.insert(0, trade);
        if (list.length > TradeConfig.maxTradesPerFilter) {
          list.removeLast();
        }
      }
    }
    // UI 업데이트는 바로 하지 않고, 배치 스케줄링
    _scheduleBatchUpdate();
  }
  
  /// 3. 배치 업데이트 스케줄링: 100ms 이내의 변경사항은 한 번에 모아서 UI 업데이트
  void _scheduleBatchUpdate() {
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 100), _performBatchUpdate);
  }
  
  /// 4. 실제 UI 업데이트 수행: 현재 임계값에 맞는 최종 리스트를 스트림에 전달
  void _performBatchUpdate() {
    final list = _filterCache[
      TradeFilter.values.firstWhere(
        (f) => f.value == _currentThreshold,
        orElse: () => TradeFilter.usdt50k,
      )
    ] ?? [];
    
    _filteredTradesController.add(List.from(list));
  }

  @override
  Stream<List<Trade>> watchFilteredTrades(List<String> markets) {
    _initialize(markets);
    return _filteredTradesController.stream;
  }

  @override
  Stream<Trade> watchAggregatedTrades(List<String> markets) {
    _initialize(markets);
    return _aggregator.stream;
  }
  
  @override
  void updateThreshold(double threshold) {
    if (_currentThreshold == threshold) return;
    _currentThreshold = threshold;
    log.d('[Repository] Threshold updated to: $threshold');
    // 임계값 변경 시 즉시 UI 업데이트 수행
    _performBatchUpdate();
  }

  @override
  void dispose() {
    _rawTradeSub?.cancel();
    _aggregatedTradeSub?.cancel();
    _batchUpdateTimer?.cancel();
    _aggregator.dispose();
    _filteredTradesController.close();
    _isInitialized = false;
    log.i('[Repository] Disposed.');
  }
}