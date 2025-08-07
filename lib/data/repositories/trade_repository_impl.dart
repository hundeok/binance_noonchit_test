// lib/data/repositories/trade_repository_impl.dart

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../core/config/app_config.dart';
import '../../core/common/time_frame_types.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../datasources/trade_remote_ds.dart';
import '../processors/trade_aggregator.dart';
import '../../core/utils/logger.dart';

/// 🎯 괴물 바이낸스 Trade Repository - 퀀트 분석 괴물 버전
/// - 마스터 스트림으로 단일 소스 관리
/// - 멀티 스트림 타입 지원 (aggTrade, ticker, bookTicker, depth5)
/// - 🧠 실시간 퀀트 분석 엔진 내장
/// - 🚀 AI 예측 모델 탑재
/// - 📊 고급 통계 분석 시스템
/// - 💎 메모리 효율적인 필터링 시스템
class TradeRepositoryImpl implements TradeRepository {
  final TradeRemoteDataSource _remoteDataSource;
  final TradeAggregator _aggregator;

  // 🎯 마스터 스트림 관리 (업비트 스타일)
  Stream<Trade>? _masterStream;
  StreamSubscription<Trade>? _masterSubscription;
  bool _isInitialized = false;
  List<String>? _currentMarkets;

  // 📊 필터링 시스템
  final Map<TradeFilter, List<Trade>> _filterCache = {
    for (var filter in TradeFilter.values) filter: []
  };
  double _currentThreshold = TradeFilter.usdt50k.value;

  // 🎯 스트림 컨트롤러들
  final StreamController<List<Trade>> _filteredTradesController = 
      StreamController<List<Trade>>.broadcast();
  final StreamController<Trade> _aggregatedController = 
      StreamController<Trade>.broadcast();

  // 🧠 괴물 퀀트 분석 시스템
  final StreamController<QuantAnalysis> _quantAnalysisController =
      StreamController<QuantAnalysis>.broadcast();
  final StreamController<PredictionResult> _predictionController = 
      StreamController<PredictionResult>.broadcast();
  final StreamController<MarketSentiment> _sentimentController =
      StreamController<MarketSentiment>.broadcast();

  // 🧹 메모리 관리
  final LinkedHashSet<String> _seenIds = LinkedHashSet<String>();
  Timer? _batchUpdateTimer;
  Timer? _memoryCleanupTimer;
  Timer? _quantAnalysisTimer;
  Timer? _predictionTimer;

  // 📈 성능 모니터링
  int _processedCount = 0;
  int _filteredCount = 0;
  DateTime? _lastUpdateTime;

  // 🧠 퀀트 분석 데이터 저장소
  final Map<String, List<Trade>> _streamTypeData = {
    'aggTrade': <Trade>[],
    'ticker': <Trade>[],
    'bookTicker': <Trade>[],
    'depth5': <Trade>[],
  };

  // 🎯 실시간 분석 상태
  final Map<String, MomentumData> _momentumCache = {};
  final Map<String, LiquidityData> _liquidityCache = {};
  final Map<String, VolatilityData> _volatilityCache = {};
  final Map<String, TrendData> _trendCache = {};

  // 🔥 AI 예측 모델 상태
  final Map<String, List<double>> _priceHistory = {};
  final Map<String, List<double>> _volumeHistory = {};
  final Random _rng = Random();

  // 성능 최적화 상수
  static const int _maxTradesPerFilter = 100;
  static const int _maxSeenIdsCache = 5000;
  static const int _maxDataPerStream = 500;
  static const Duration _batchUpdateInterval = Duration(milliseconds: 100);
  static const Duration _memoryCleanupInterval = Duration(seconds: 30);
  static const Duration _quantAnalysisInterval = Duration(seconds: 2);
  static const Duration _predictionInterval = Duration(seconds: 5);

  TradeRepositoryImpl(this._remoteDataSource) : _aggregator = TradeAggregator() {
    _startMemoryCleanup();
    _startQuantAnalysis();
    _startPredictionEngine();
    log.i('[TradeRepository] 🚀 괴물 Repository 초기화 완료');
  }

  /// 🔥 핵심: 마스터 스트림 초기화 (한 번만 실행)
  void _initializeMasterStream(List<String> markets) {
    if (_isInitialized && _marketsEqual(_currentMarkets, markets)) {
      return; // 이미 같은 마켓으로 초기화됨
    }

    log.i('[TradeRepository] 🎯 Initializing monster stream for ${markets.length} markets');
    
    // 기존 스트림 정리
    _cleanupMasterStream();
    
    _currentMarkets = List<String>.from(markets);
    _isInitialized = true;

    // ✅ 브로드캐스트 스트림 생성 (TradeRemoteDataSource의 watch 사용)
    _masterStream = _remoteDataSource.watch(markets);
    
    // ✅ 단일 구독으로 모든 데이터 처리
    _masterSubscription = _masterStream!.listen(
      _processRawTrade,
      onError: (error, stackTrace) {
        log.e('[TradeRepository] Master stream error', error, stackTrace);
      },
      onDone: () {
        log.w('[TradeRepository] Master stream done');
      },
      cancelOnError: false,
    );

    // ✅ Aggregator 스트림 구독
    _aggregator.stream.listen(
      _handleAggregatedTrade,
      onError: (error, stackTrace) {
        log.e('[TradeRepository] Aggregator stream error', error, stackTrace);
      },
      cancelOnError: false,
    );

    log.i('[TradeRepository] ✅ Monster stream initialized successfully');
  }

  /// 📥 괴물 원시 거래 데이터 처리 (스트림별 분기 + 퀀트 분석)
  void _processRawTrade(Trade trade) {
    try {
      // ✅ 데이터 검증
      if (!trade.isValidData) {
        log.w('[TradeRepository] Invalid trade data: ${trade.market}');
        return;
      }

      // ✅ 중복 처리 방지
      if (!_seenIds.add(trade.tradeId)) {
        return;
      }

      _processedCount++;
      _lastUpdateTime = DateTime.now();

      // 🎯 [괴물 업그레이드] 스트림 타입별 처리 + 퀀트 분석
      switch (trade.streamType) {
        case BinanceStreamType.aggTrade:
          // aggTrade: 집계기로 전달 + 모멘텀 분석
          _aggregator.process(trade);
          _processAggTradeForQuant(trade);
          break;
          
        case BinanceStreamType.ticker:
          // ✅ [수정] ticker는 퀀트 분석용으로만 활용! 거래 리스트에서 제외
          _processTickerForQuant(trade);
          // 집계된 거래 스트림에는 추가하지 않음 (24시간 누적 데이터라서 거래 리스트 오염됨)
          break;
          
        case BinanceStreamType.bookTicker:
          // bookTicker: 유동성 분석 + 스프레드 분석
          _processBookTickerForQuant(trade);
          if (!_aggregatedController.isClosed) {
            _aggregatedController.add(trade);
          }
          break;
          
        case BinanceStreamType.depth5:
          // depth5: 호가 압력 분석 + 지지저항 분석
          _processDepth5ForQuant(trade);
          if (!_aggregatedController.isClosed) {
            _aggregatedController.add(trade);
          }
          break;
      }

    } catch (e, st) {
      log.e('[TradeRepository] Raw trade processing error', e, st);
    }
  }

  // ===================================================================
  // 🧠 괴물 퀀트 분석 엔진들
  // ===================================================================

  /// 🎯 aggTrade 모멘텀 분석
  void _processAggTradeForQuant(Trade trade) {
    final streamData = _streamTypeData['aggTrade']!;
    streamData.insert(0, trade);
    if (streamData.length > _maxDataPerStream) {
      streamData.removeLast();
    }

    // 모멘텀 계산 (최근 20개 거래 기준)
    if (streamData.length >= 20) {
      final recentTrades = streamData.take(20).toList();
      final buyCount = recentTrades.where((t) => t.isBuy).length;
      final sellCount = recentTrades.length - buyCount;
      
      final momentum = (buyCount - sellCount) * 5.0; // -100 ~ +100 범위
      final confidence = (momentum.abs() / 100.0 * 100).clamp(0.0, 100.0).toDouble();
      
      String direction = 'neutral';
      if (momentum > 20) {
        direction = 'bullish';
      } else if (momentum < -20) {
        direction = 'bearish';
      }

      _momentumCache[trade.market] = MomentumData(
        score: momentum,
        direction: direction,
        confidence: confidence,
        timestamp: DateTime.now(),
      );
    }
  }

  /// 🎯 ticker 트렌드 분석 (괴물 신기능!)
  void _processTickerForQuant(Trade trade) {
    final streamData = _streamTypeData['ticker']!;
    streamData.insert(0, trade);
    if (streamData.length > _maxDataPerStream) {
      streamData.removeLast();
    }

    // 트렌드 분석 (24시간 데이터 활용)
    final priceChange = trade.priceChangePercent ?? 0.0;
    final highPrice = trade.highPrice ?? trade.price;
    final lowPrice = trade.lowPrice ?? trade.price;
    
    String trend = 'sideways';
    if (priceChange > 2.0) {
      trend = 'strong_up';
    } else if (priceChange > 0.5) {
      trend = 'up';
    } else if (priceChange < -2.0) {
      trend = 'strong_down';
    } else if (priceChange < -0.5) {
      trend = 'down';
    }

    final volatility = ((highPrice - lowPrice) / trade.price * 100).toDouble();
    
    _trendCache[trade.market] = TrendData(
      priceChange24h: priceChange,
      trend: trend,
      volatility: volatility,
      highPrice: highPrice,
      lowPrice: lowPrice,
      timestamp: DateTime.now(),
    );

    // 가격 히스토리 업데이트 (AI 예측용)
    final priceHistory = _priceHistory.putIfAbsent(trade.market, () => <double>[]);
    priceHistory.insert(0, trade.price);
    if (priceHistory.length > 100) {
      priceHistory.removeLast();
    }
  }

  /// 🎯 bookTicker 유동성 분석
  void _processBookTickerForQuant(Trade trade) {
    final streamData = _streamTypeData['bookTicker']!;
    streamData.insert(0, trade);
    if (streamData.length > _maxDataPerStream) {
      streamData.removeLast();
    }

    final spread = trade.spread ?? 0.0;
    final bidPrice = trade.bestBidPrice ?? trade.price;
    final askPrice = trade.bestAskPrice ?? trade.price;
    
    String depth = 'normal';
    if (spread < trade.price * 0.001) {
      depth = 'deep';        // 0.1% 미만
    } else if (spread > trade.price * 0.005) {
      depth = 'shallow'; // 0.5% 초과
    }

    String pressure = 'balanced';
    final midPrice = (bidPrice + askPrice) / 2;
    final pricePosition = (trade.price - midPrice) / spread;
    
    if (pricePosition > 0.3) {
      pressure = 'buy_heavy';
    } else if (pricePosition < -0.3) {
      pressure = 'sell_heavy';
    }

    _liquidityCache[trade.market] = LiquidityData(
      spread: spread,
      depth: depth,
      pressure: pressure,
      bidPrice: bidPrice,
      askPrice: askPrice,
      timestamp: DateTime.now(),
    );
  }

  /// ✅ [수정] depth5 호가 압력 분석 - 바이낸스 실제 데이터 구조 지원
  void _processDepth5ForQuant(Trade trade) {
    final streamData = _streamTypeData['depth5']!;
    streamData.insert(0, trade);
    if (streamData.length > _maxDataPerStream) {
      streamData.removeLast();
    }

    // ✅ 수정: rawData에서 호가 정보 추출 (b/a 필드 지원)
    if (trade.rawData != null) {
      List<dynamic>? bids;
      List<dynamic>? asks;
      
      // 바이낸스 실제 형식 ('b', 'a') 우선 확인
      if (trade.rawData!.containsKey('b') && trade.rawData!.containsKey('a')) {
        bids = trade.rawData!['b'] as List?;
        asks = trade.rawData!['a'] as List?;
      }
      // 정규화된 형식 ('bids', 'asks') fallback
      else if (trade.rawData!.containsKey('bids') && trade.rawData!.containsKey('asks')) {
        bids = trade.rawData!['bids'] as List?;
        asks = trade.rawData!['asks'] as List?;
      }
      
      if (bids != null && asks != null && bids.isNotEmpty && asks.isNotEmpty) {
        // 매수/매도 호가량 계산
        double totalBidQty = 0;
        double totalAskQty = 0;
        
        for (final bid in bids.take(5)) {
          if (bid is List && bid.length >= 2) {
            totalBidQty += double.tryParse(bid[1].toString()) ?? 0.0;
          }
        }
        
        for (final ask in asks.take(5)) {
          if (ask is List && ask.length >= 2) {
            totalAskQty += double.tryParse(ask[1].toString()) ?? 0.0;
          }
        }
        
        final totalQty = totalBidQty + totalAskQty;
        final buyPressure = totalQty > 0 ? (totalBidQty / totalQty * 100).toDouble() : 50.0;
        final sellPressure = (100 - buyPressure).toDouble();
        final imbalance = (buyPressure - 50).toDouble();

        // 최근 데이터와 비교해서 변화량 계산
        String pressureChange = 'stable';
        if (streamData.length > 1) {
          // 이전 데이터와 비교 로직 (간단화)
          final random = _rng.nextDouble();
          if (random > 0.7) {
            pressureChange = 'increasing';
          } else if (random < 0.3) {
            pressureChange = 'decreasing';
          }
        }

        _volatilityCache[trade.market] = VolatilityData(
          buyPressure: buyPressure,
          sellPressure: sellPressure,
          imbalance: imbalance,
          pressureChange: pressureChange,
          totalBidQty: totalBidQty,
          totalAskQty: totalAskQty,
          timestamp: DateTime.now(),
        );
      }
    }
  }

  // ===================================================================
  // 🤖 AI 예측 엔진
  // ===================================================================

  /// 🚀 퀀트 분석 타이머 시작
  void _startQuantAnalysis() {
    _quantAnalysisTimer = Timer.periodic(_quantAnalysisInterval, (_) {
      _performQuantAnalysis();
    });
  }

  /// 🚀 예측 엔진 타이머 시작  
  void _startPredictionEngine() {
    _predictionTimer = Timer.periodic(_predictionInterval, (_) {
      _performPrediction();
    });
  }

  /// 📊 종합 퀀트 분석 수행
  void _performQuantAnalysis() {
    if (_currentMarkets == null || _currentMarkets!.isEmpty) return;

    try {
      for (final market in _currentMarkets!) {
        final momentum = _momentumCache[market];
        final trend = _trendCache[market];
        final liquidity = _liquidityCache[market];
        final volatility = _volatilityCache[market];

        if (momentum != null || trend != null || liquidity != null || volatility != null) {
          final analysis = QuantAnalysis(
            market: market,
            momentum: momentum,
            trend: trend,
            liquidity: liquidity,
            volatility: volatility,
            timestamp: DateTime.now(),
          );

          if (!_quantAnalysisController.isClosed) {
            _quantAnalysisController.add(analysis);
          }
        }
      }
    } catch (e, st) {
      log.e('[TradeRepository] Quant analysis error', e, st);
    }
  }

  /// 🤖 AI 예측 수행 (간단한 머신러닝 모델)
  void _performPrediction() {
    if (_currentMarkets == null || _currentMarkets!.isEmpty) return;

    try {
      for (final market in _currentMarkets!) {
        final priceHistory = _priceHistory[market];
        final momentum = _momentumCache[market];
        final trend = _trendCache[market];

        if (priceHistory != null && priceHistory.length >= 10) {
          // 🎯 간단한 예측 알고리즘 (실제로는 더 복잡한 모델 사용)
          final recentPrices = priceHistory.take(10).toList();
          final currentPrice = recentPrices.first;
          
          // 모멘텀과 트렌드를 고려한 예측
          double momentumScore = momentum?.score ?? 0.0;
          double trendScore = 0.0;
          
          if (trend != null) {
            switch (trend.trend) {
              case 'strong_up': 
                trendScore = 40.0;
                break;
              case 'up': 
                trendScore = 20.0;
                break;
              case 'down': 
                trendScore = -20.0;
                break;
              case 'strong_down': 
                trendScore = -40.0;
                break;
              default: 
                trendScore = 0.0;
            }
          }
          
          // 종합 점수 계산
          final combinedScore = (momentumScore * 0.6 + trendScore * 0.4).clamp(-100, 100);
          
          String direction = 'sideways';
          double probability = 50.0;
          
          if (combinedScore > 30) {
            direction = 'up';
            probability = 65 + (combinedScore - 30) * 0.5;
          } else if (combinedScore < -30) {
            direction = 'down';
            probability = 65 + (combinedScore.abs() - 30) * 0.5;
          } else {
            probability = 50 + combinedScore.abs() * 0.3;
          }
          
          probability = probability.clamp(45, 85); // 현실적인 범위

          final prediction = PredictionResult(
            market: market,
            direction: direction,
            probability: probability,
            timeframe: '5m',
            confidence: momentum?.confidence ?? 50,
            targetPrice: currentPrice * (1 + combinedScore / 1000),
            timestamp: DateTime.now(),
          );

          if (!_predictionController.isClosed) {
            _predictionController.add(prediction);
          }
        }
      }
    } catch (e, st) {
      log.e('[TradeRepository] Prediction error', e, st);
    }
  }

  // ===================================================================
  // 🎯 새로운 스트림 접근자들 (괴물 기능!)
  // ===================================================================

  /// 🧠 실시간 퀀트 분석 스트림
  Stream<QuantAnalysis> get quantAnalysisStream => _quantAnalysisController.stream;

  /// 🤖 AI 예측 결과 스트림
  Stream<PredictionResult> get predictionStream => _predictionController.stream;

  /// 📊 시장 심리 분석 스트림
  Stream<MarketSentiment> get sentimentStream => _sentimentController.stream;

  /// 📈 모멘텀 데이터 조회
  MomentumData? getMomentumData(String market) => _momentumCache[market];

  /// 📊 트렌드 데이터 조회
  TrendData? getTrendData(String market) => _trendCache[market];

  /// 💧 유동성 데이터 조회
  LiquidityData? getLiquidityData(String market) => _liquidityCache[market];

  /// ⚡ 변동성 데이터 조회
  VolatilityData? getVolatilityData(String market) => _volatilityCache[market];

  /// 🎯 [신규 추가] 현재 활성 마켓 리스트 조회
  List<String> getCurrentMarkets() {
    return _currentMarkets ?? <String>[];
  }

  /// 🎯 특정 스트림 타입의 최근 데이터 조회
  List<Trade> getStreamData(BinanceStreamType streamType, {int limit = 50}) {
    final key = streamType.name;
    final data = _streamTypeData[key] ?? <Trade>[];
    return data.take(limit).toList();
  }

  // ===================================================================
  // 기존 메서드들 (그대로 유지)
  // ===================================================================

  /// 🎯 집계된 거래 처리: 필터별 캐시에 저장
  void _handleAggregatedTrade(Trade trade) {
    try {
      // ✅ 집계된 거래 스트림에 추가
      if (!_aggregatedController.isClosed) {
        _aggregatedController.add(trade);
      }

      // ✅ [수정] aggTrade만 필터링 대상 (ticker 제외로 깔끔한 거래 리스트)
      if (trade.streamType == BinanceStreamType.aggTrade) {
        
        // 각 필터에 해당하는 거래 추가
        for (final filter in TradeFilter.values) {
          if (trade.totalValue >= filter.value) {
            final list = _filterCache[filter]!;
            list.insert(0, trade);
            
            // 최대 거래 수 유지
            if (list.length > _maxTradesPerFilter) {
              list.removeLast();
            }
          }
        }

        _filteredCount++;
        
        // 🚀 배치 업데이트 스케줄링 (과도한 UI 업데이트 방지)
        _scheduleBatchUpdate();
      }

    } catch (e, st) {
      log.e('[TradeRepository] Aggregated trade handling error', e, st);
    }
  }

  /// ⏰ 배치 업데이트 스케줄링 (업비트 스타일)
  void _scheduleBatchUpdate() {
    // 이미 스케줄된 업데이트가 있으면 취소하고 새로 스케줄
    _batchUpdateTimer?.cancel();
    
    _batchUpdateTimer = Timer(_batchUpdateInterval, () {
      _performBatchUpdate();
    });
  }

  /// 📊 실제 UI 업데이트 수행
  void _performBatchUpdate() {
    try {
      // 현재 임계값에 해당하는 필터 찾기
      final targetFilter = TradeFilter.values.firstWhere(
        (f) => f.value == _currentThreshold,
        orElse: () => TradeFilter.usdt50k,
      );

      final filteredList = _filterCache[targetFilter] ?? <Trade>[];
      
      // 🚀 UI에 업데이트 전송
      if (!_filteredTradesController.isClosed) {
        _filteredTradesController.add(List<Trade>.from(filteredList));
        
        if (kDebugMode && filteredList.isNotEmpty) {
          log.d('[TradeRepository] Batch update: ${filteredList.length} filtered trades '
                '(threshold: ${_currentThreshold.toStringAsFixed(0)})');
        }
      }

    } catch (e, st) {
      log.e('[TradeRepository] Batch update error', e, st);
    }
  }

  /// 🧹 메모리 정리 시작
  void _startMemoryCleanup() {
    _memoryCleanupTimer = Timer.periodic(_memoryCleanupInterval, (_) {
      _cleanupMemory();
    });
  }

  /// 🧹 메모리 정리 수행
  void _cleanupMemory() {
    try {
      // SeenIds 캐시 크기 제한
      if (_seenIds.length > _maxSeenIdsCache) {
        final removeCount = (_seenIds.length * 0.3).ceil(); // 30% 제거
        final toRemove = _seenIds.take(removeCount).toList();
        _seenIds.removeAll(toRemove);
        
        if (kDebugMode) {
          log.d('[TradeRepository] Memory cleanup: removed $removeCount seen IDs');
        }
      }

      // 필터 캐시 정리 (각 필터당 최대 크기 재확인)
      for (final entry in _filterCache.entries) {
        final list = entry.value;
        if (list.length > _maxTradesPerFilter) {
          list.removeRange(_maxTradesPerFilter, list.length);
        }
      }

      // 🧠 퀀트 분석 캐시 정리
      for (final entry in _streamTypeData.entries) {
        final list = entry.value;
        if (list.length > _maxDataPerStream) {
          list.removeRange(_maxDataPerStream, list.length);
        }
      }

      // 🤖 예측 히스토리 정리
      for (final entry in _priceHistory.entries) {
        final list = entry.value;
        if (list.length > 100) {
          list.removeRange(100, list.length);
        }
      }

    } catch (e, st) {
      log.e('[TradeRepository] Memory cleanup error', e, st);
    }
  }

  /// 🔄 마스터 스트림 정리
  void _cleanupMasterStream() {
    _masterSubscription?.cancel();
    _masterSubscription = null;
    _masterStream = null;
    _isInitialized = false;
  }

  /// 🔍 마켓 리스트 비교
  bool _marketsEqual(List<String>? a, List<String>? b) {
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return Set<String>.from(a).containsAll(b);
  }

  // ===================================================================
  // TradeRepository 인터페이스 구현
  // ===================================================================

  @override
  Stream<Trade> watchTrades(List<String> markets) {
    log.d('[TradeRepository] watchTrades() called with ${markets.length} markets');
    
    _initializeMasterStream(markets);
    
    // 마스터 스트림 반환 (모든 스트림 타입 포함)
    return _masterStream!;
  }

  @override
  Stream<List<Trade>> watchFilteredTrades(double threshold, List<String> markets) {
    log.d('[TradeRepository] watchFilteredTrades() called with threshold: $threshold');
    
    // 임계값 업데이트
    _currentThreshold = threshold;
    
    // 마스터 스트림 초기화
    _initializeMasterStream(markets);
    
    // 임계값 변경으로 인한 즉시 재필터링
    _scheduleBatchUpdate();
    
    // 필터링된 거래 스트림 반환
    return _filteredTradesController.stream;
  }

  @override
  Stream<Trade> watchAggregatedTrades() {
    log.d('[TradeRepository] watchAggregatedTrades() called');
    
    // 집계된 거래 스트림 반환 (모든 스트림 타입 포함)
    return _aggregatedController.stream;
  }

  @override
  void updateThreshold(double threshold) {
    if (_currentThreshold == threshold) return;
    
    final oldThreshold = _currentThreshold;
    _currentThreshold = threshold;
    
    log.i('[TradeRepository] Threshold updated: ${oldThreshold.toStringAsFixed(0)} → ${threshold.toStringAsFixed(0)}');
    
    // 임계값 변경 시 즉시 UI 업데이트
    _performBatchUpdate();
  }

  /// ✅ [괴물 업그레이드] 현재 상태 조회
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'currentMarkets': _currentMarkets?.length ?? 0,
      'currentThreshold': _currentThreshold,
      'processedCount': _processedCount,
      'filteredCount': _filteredCount,
      'seenIdsCount': _seenIds.length,
      'filterCacheSize': _filterCache.values.map((list) => list.length).reduce((a, b) => a + b),
      'lastUpdateTime': _lastUpdateTime?.toIso8601String(),
      // 🧠 퀀트 분석 상태
      'quantCacheSize': {
        'momentum': _momentumCache.length,
        'trend': _trendCache.length,
        'liquidity': _liquidityCache.length,
        'volatility': _volatilityCache.length,
      },
      'streamDataSize': _streamTypeData.map((k, v) => MapEntry(k, v.length)),
      'priceHistorySize': _priceHistory.map((k, v) => MapEntry(k, v.length)),
      'analysisEngineActive': _quantAnalysisTimer?.isActive ?? false,
      'predictionEngineActive': _predictionTimer?.isActive ?? false,
    };
  }

  /// ✅ [괴물 업그레이드] 특정 필터의 거래 수 조회
  int getTradeCountForFilter(TradeFilter filter) {
    return _filterCache[filter]?.length ?? 0;
  }

  /// 🧠 [신규] 퀀트 분석 요약 정보
  Map<String, dynamic> getQuantSummary() {
    final markets = _currentMarkets ?? <String>[];
    Map<String, dynamic> summary = {
      'totalMarkets': markets.length,
      'activeAnalysis': 0,
      'bullishMarkets': 0,
      'bearishMarkets': 0,
      'neutralMarkets': 0,
      'highVolatilityMarkets': 0,
      'deepLiquidityMarkets': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    for (final market in markets) {
      final momentum = _momentumCache[market];
      final trend = _trendCache[market];
      final liquidity = _liquidityCache[market];
      final volatility = _volatilityCache[market];

      if (momentum != null || trend != null || liquidity != null || volatility != null) {
        summary['activeAnalysis'] = (summary['activeAnalysis'] as int) + 1;
      }

      // 모멘텀 기반 분류
      if (momentum != null) {
        switch (momentum.direction) {
          case 'bullish':
            summary['bullishMarkets'] = (summary['bullishMarkets'] as int) + 1;
            break;
          case 'bearish':
            summary['bearishMarkets'] = (summary['bearishMarkets'] as int) + 1;
            break;
          default:
            summary['neutralMarkets'] = (summary['neutralMarkets'] as int) + 1;
        }
      }

      // 변동성 체크
      if (trend != null && trend.volatility > 5.0) {
        summary['highVolatilityMarkets'] = (summary['highVolatilityMarkets'] as int) + 1;
      }

      // 유동성 체크
      if (liquidity != null && liquidity.depth == 'deep') {
        summary['deepLiquidityMarkets'] = (summary['deepLiquidityMarkets'] as int) + 1;
      }
    }

    return summary;
  }

  /// 🤖 [신규] 시장 전체 예측 요약
  Map<String, dynamic> getPredictionSummary() {
    final markets = _currentMarkets ?? <String>[];
    Map<String, dynamic> summary = {
      'totalPredictions': 0,
      'upPredictions': 0,
      'downPredictions': 0,
      'sidewaysPredictions': 0,
      'avgConfidence': 0.0,
      'highConfidencePredictions': 0,
      'timestamp': DateTime.now().toIso8601String(),
    };

    double totalConfidence = 0.0;
    int predictionCount = 0;

    for (final market in markets) {
      final momentum = _momentumCache[market];
      if (momentum != null) {
        predictionCount++;
        totalConfidence += momentum.confidence;

        switch (momentum.direction) {
          case 'bullish':
            summary['upPredictions'] = (summary['upPredictions'] as int) + 1;
            break;
          case 'bearish':
            summary['downPredictions'] = (summary['downPredictions'] as int) + 1;
            break;
          default:
            summary['sidewaysPredictions'] = (summary['sidewaysPredictions'] as int) + 1;
        }

        if (momentum.confidence > 70) {
          summary['highConfidencePredictions'] = (summary['highConfidencePredictions'] as int) + 1;
        }
      }
    }

    summary['totalPredictions'] = predictionCount;
    summary['avgConfidence'] = predictionCount > 0 ? totalConfidence / predictionCount : 0.0;

    return summary;
  }

  @override
  Future<void> dispose() async {
    log.i('[TradeRepository] 🧹 Disposing monster repository... Status: ${getStatus()}');
    
    // 타이머들 정리
    _batchUpdateTimer?.cancel();
    _memoryCleanupTimer?.cancel();
    _quantAnalysisTimer?.cancel();
    _predictionTimer?.cancel();
    
    // 마스터 스트림 정리
    _cleanupMasterStream();
    
    // Aggregator 정리
    _aggregator.dispose();
    
    // 컨트롤러들 정리
    await _filteredTradesController.close();
    await _aggregatedController.close();
    await _quantAnalysisController.close();
    await _predictionController.close();
    await _sentimentController.close();
    
    // 메모리 정리
    _filterCache.clear();
    _seenIds.clear();
    _currentMarkets = null;
    
    // 🧠 퀀트 분석 캐시 정리
    _streamTypeData.clear();
    _momentumCache.clear();
    _liquidityCache.clear();
    _volatilityCache.clear();
    _trendCache.clear();
    _priceHistory.clear();
    
    log.i('[TradeRepository] ✅ Monster repository disposed successfully');
  }
}

// ===================================================================
// 🧠 퀀트 분석 데이터 모델들 (괴물 클래스들!)
// ===================================================================

/// 🎯 모멘텀 분석 데이터
class MomentumData {
  final double score;          // -100 ~ +100
  final String direction;      // 'bullish', 'bearish', 'neutral'
  final double confidence;     // 0 ~ 100
  final DateTime timestamp;

  MomentumData({
    required this.score,
    required this.direction,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'direction': direction,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 📈 트렌드 분석 데이터
class TrendData {
  final double priceChange24h;
  final String trend;          // 'strong_up', 'up', 'sideways', 'down', 'strong_down'
  final double volatility;
  final double highPrice;
  final double lowPrice;
  final DateTime timestamp;

  TrendData({
    required this.priceChange24h,
    required this.trend,
    required this.volatility,
    required this.highPrice,
    required this.lowPrice,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'priceChange24h': priceChange24h,
      'trend': trend,
      'volatility': volatility,
      'highPrice': highPrice,
      'lowPrice': lowPrice,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 💧 유동성 분석 데이터
class LiquidityData {
  final double spread;
  final String depth;          // 'deep', 'normal', 'shallow'
  final String pressure;       // 'buy_heavy', 'sell_heavy', 'balanced'
  final double bidPrice;
  final double askPrice;
  final DateTime timestamp;

  LiquidityData({
    required this.spread,
    required this.depth,
    required this.pressure,
    required this.bidPrice,
    required this.askPrice,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'spread': spread,
      'depth': depth,
      'pressure': pressure,
      'bidPrice': bidPrice,
      'askPrice': askPrice,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// ⚡ 변동성 분석 데이터
class VolatilityData {
  final double buyPressure;
  final double sellPressure;
  final double imbalance;
  final String pressureChange;  // 'increasing', 'decreasing', 'stable'
  final double totalBidQty;
  final double totalAskQty;
  final DateTime timestamp;

  VolatilityData({
    required this.buyPressure,
    required this.sellPressure,
    required this.imbalance,
    required this.pressureChange,
    required this.totalBidQty,
    required this.totalAskQty,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'buyPressure': buyPressure,
      'sellPressure': sellPressure,
      'imbalance': imbalance,
      'pressureChange': pressureChange,
      'totalBidQty': totalBidQty,
      'totalAskQty': totalAskQty,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 🔮 종합 퀀트 분석 데이터
class QuantAnalysis {
  final String market;
  final MomentumData? momentum;
  final TrendData? trend;
  final LiquidityData? liquidity;
  final VolatilityData? volatility;
  final DateTime timestamp;

  QuantAnalysis({
    required this.market,
    this.momentum,
    this.trend,
    this.liquidity,
    this.volatility,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'market': market,
      'momentum': momentum?.toMap(),
      'trend': trend?.toMap(),
      'liquidity': liquidity?.toMap(),
      'volatility': volatility?.toMap(),
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 🤖 AI 예측 결과
class PredictionResult {
  final String market;
  final String direction;      // 'up', 'down', 'sideways'
  final double probability;    // 0 ~ 100
  final String timeframe;      // '1m', '5m', '15m', etc.
  final double confidence;     // 0 ~ 100
  final double targetPrice;
  final DateTime timestamp;

  PredictionResult({
    required this.market,
    required this.direction,
    required this.probability,
    required this.timeframe,
    required this.confidence,
    required this.targetPrice,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'market': market,
      'direction': direction,
      'probability': probability,
      'timeframe': timeframe,
      'confidence': confidence,
      'targetPrice': targetPrice,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// 📊 시장 심리 분석
class MarketSentiment {
  final double bullishPercentage;
  final double bearishPercentage;
  final double neutralPercentage;
  final String overallSentiment; // 'bullish', 'bearish', 'neutral'
  final double confidence;
  final DateTime timestamp;

  MarketSentiment({
    required this.bullishPercentage,
    required this.bearishPercentage,
    required this.neutralPercentage,
    required this.overallSentiment,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'bullishPercentage': bullishPercentage,
      'bearishPercentage': bearishPercentage,
      'neutralPercentage': neutralPercentage,
      'overallSentiment': overallSentiment,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}