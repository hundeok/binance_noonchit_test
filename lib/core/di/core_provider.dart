// ===================================================================
// lib/core/providers/trade_providers.dart
// Repository 배치 처리 활용 - TradeCacheNotifier 제거하고 Repository 직접 사용
// ===================================================================

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bridge/signal_bus.dart';
import '../../data/datasources/trade_remote_ds.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../common/time_frame_types.dart';
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';
import 'websocket_provider.dart';

// ===================================================================
// 1. Foundational Service & Data Layer Providers
// ===================================================================

/// SignalBus 인스턴스 제공 (싱글톤)
final signalBusProvider = Provider((ref) {
  final bus = SignalBus();
  ref.onDispose(() => bus.dispose());
  return bus;
});

/// API 클라이언트 인스턴스를 제공합니다. (Result 패턴 적용)
final apiClientProvider = Provider((ref) {
  final client = ApiClient(
    apiKey: null, // 공개 API만 사용
    secretKey: null,
  );
  ref.onDispose(() => client.dispose());
  return client;
});

/// SignalBus를 포함한 원격 데이터 소스 제공
final tradeRemoteDSProvider = Provider((ref) {
  final ws = ref.watch(wsClientProvider);
  final signalBus = ref.watch(signalBusProvider);
  final ds = TradeRemoteDataSource(ws, signalBus);
  ref.onDispose(() => ds.dispose());
  return ds;
});

/// 🎯 핵심: 거래 데이터 Repository (배치 처리 담당)
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  final repo = TradeRepositoryImpl(ref.watch(tradeRemoteDSProvider));
  ref.onDispose(() => repo.dispose());
  return repo;
});

// ===================================================================
// 2. Market Info & Configuration Providers
// ===================================================================

/// 바이낸스 API에서 거래량 상위 종목 목록을 가져옵니다.
final marketsProvider = FutureProvider<List<String>>((ref) async {
  log.d('[marketsProvider] Fetching top volume markets from Binance Futures...');
  final client = ref.watch(apiClientProvider);
  
  try {
    // Result 패턴으로 API 호출
    final result = await client.get(
      '/fapi/v1/ticker/24hr',
      cacheDur: const Duration(minutes: 5), // 5분 캐시
      weight: 40, // 전체 ticker 조회 weight
    );
    
    return result.when(
      ok: (data) {
        final tickers = data as List<dynamic>;
        
        // USDT 페어만 필터링
        tickers.removeWhere((t) => !(t['symbol'] as String).endsWith('USDT'));
        
        // 거래량으로 정렬
        tickers.sort((a, b) {
          final volumeA = double.tryParse(a['quoteVolume']?.toString() ?? '0') ?? 0;
          final volumeB = double.tryParse(b['quoteVolume']?.toString() ?? '0') ?? 0;
          return volumeB.compareTo(volumeA);
        });

        final markets = tickers
            .map((t) => t['symbol'] as String)
            .take(AppConfig.wsMaxSubscriptions)
            .toList();
                           
        log.i('[marketsProvider] Fetched ${markets.length} markets, sorted by volume.');
        return markets;
      },
      err: (error) {
        log.e('[marketsProvider] API error: $error');
        
        // 에러 시 기본 주요 종목 반환
        final fallbackMarkets = [
          'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'ADAUSDT', 'SOLUSDT',
          'XRPUSDT', 'DOTUSDT', 'LINKUSDT', 'LTCUSDT', 'MATICUSDT',
          'AVAXUSDT', 'ATOMUSDT', 'ALGOUSDT', 'VETUSDT', 'ICPUSDT',
        ].take(AppConfig.wsMaxSubscriptions).toList();
        
        log.w('[marketsProvider] Using fallback markets: ${fallbackMarkets.length}');
        return fallbackMarkets;
      },
    );
  } catch (e, st) {
    log.e('[marketsProvider] Unexpected error', e, st);
    
    // 예외 발생 시에도 기본값 반환
    return [
      'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'ADAUSDT', 'SOLUSDT',
    ];
  }
});

/// UI에서 사용자가 선택한 거래대금 필터 값을 관리합니다.
final tradeFilterProvider = StateProvider<TradeFilter>((ref) => TradeFilter.usdt50k);

// ===================================================================
// 3. 🎯 Repository 배치 처리 기반 스트림 Providers (핵심!)
// ===================================================================

/// 🚀 필터링된 거래 목록 - Repository의 배치 처리 직접 활용
final filteredTradesProvider = StreamProvider.autoDispose<List<Trade>>((ref) async* {
  log.d('[filteredTradesProvider] Initializing with Repository batch processing...');
  
  // UI 필터 값 감시
  final filter = ref.watch(tradeFilterProvider);
  final threshold = filter.value;
  
  // 마켓 목록 가져오기
  final marketsAsync = ref.watch(marketsProvider);
  
  yield* marketsAsync.when(
    data: (markets) async* {
      log.i('[filteredTradesProvider] Starting filtered stream for ${markets.length} markets '
            'with threshold: ${threshold.toStringAsFixed(0)}');
      
      final repository = ref.watch(tradeRepositoryProvider);
      
      try {
        // 🎯 핵심: Repository의 배치 처리된 필터링 스트림 직접 사용
        await for (final filteredTrades in repository.watchFilteredTrades(threshold, markets)) {
          yield filteredTrades;
          log.d('[filteredTradesProvider] Yielded ${filteredTrades.length} filtered trades');
        }
      } catch (e, st) {
        log.e('[filteredTradesProvider] Filtered stream error', e, st);
        rethrow;
      }
    },
    loading: () async* {
      log.d('[filteredTradesProvider] Loading markets...');
      // 로딩 중에는 빈 리스트 방출
      yield <Trade>[];
    },
    error: (e, st) async* {
      log.e('[filteredTradesProvider] Markets fetch error', e, st);
      // 에러 시에도 빈 리스트 방출하여 UI 안정성 확보
      yield <Trade>[];
    },
  );
});

/// 🚀 집계된 거래 스트림 - Repository의 배치 처리 직접 활용
final aggregatedTradesProvider = StreamProvider.autoDispose<Trade>((ref) async* {
  log.d('[aggregatedTradesProvider] Initializing with Repository batch processing...');
  
  final repository = ref.watch(tradeRepositoryProvider);
  
  try {
    // 🎯 핵심: Repository의 배치 처리된 집계 스트림 직접 사용
    await for (final aggregatedTrade in repository.watchAggregatedTrades()) {
      yield aggregatedTrade;
      log.d('[aggregatedTradesProvider] Yielded aggregated trade: ${aggregatedTrade.market}');
    }
  } catch (e, st) {
    log.e('[aggregatedTradesProvider] Aggregated stream error', e, st);
    rethrow;
  }
});

/// 🚀 원시 거래 스트림 - Repository의 마스터 스트림 직접 활용
final rawTradesProvider = StreamProvider.autoDispose<Trade>((ref) async* {
  log.d('[rawTradesProvider] Initializing with Repository master stream...');
  
  // 마켓 목록 가져오기
  final marketsAsync = ref.watch(marketsProvider);
  
  yield* marketsAsync.when(
    data: (markets) async* {
      log.i('[rawTradesProvider] Starting raw stream for ${markets.length} markets');
      
      final repository = ref.watch(tradeRepositoryProvider);
      
      try {
        // 🎯 핵심: Repository의 마스터 스트림 직접 사용
        await for (final trade in repository.watchTrades(markets)) {
          yield trade;
        }
      } catch (e, st) {
        log.e('[rawTradesProvider] Raw stream error', e, st);
        rethrow;
      }
    },
    loading: () async* {
      log.d('[rawTradesProvider] Loading markets...');
      // 로딩 중에는 아무것도 emit하지 않음
    },
    error: (e, st) async* {
      log.e('[rawTradesProvider] Markets fetch error', e, st);
      throw e;
    },
  );
});

// ===================================================================
// 4. 스트림 타입별 필터링된 스트림들 (옵션)
// ===================================================================

/// aggTrade만 필터링된 스트림 (필요시 사용)
final aggTradeStreamProvider = StreamProvider.autoDispose<Trade>((ref) async* {
  final rawStream = ref.watch(rawTradesProvider.stream);
  await for (final trade in rawStream) {
    if (trade.streamType == BinanceStreamType.aggTrade) {
      yield trade;
    }
  }
});

/// ticker만 필터링된 스트림 (필요시 사용)
final tickerStreamProvider = StreamProvider.autoDispose<Trade>((ref) async* {
  final rawStream = ref.watch(rawTradesProvider.stream);
  await for (final trade in rawStream) {
    if (trade.streamType == BinanceStreamType.ticker) {
      yield trade;
    }
  }
});

/// bookTicker만 필터링된 스트림 (필요시 사용)
final bookTickerStreamProvider = StreamProvider.autoDispose<Trade>((ref) async* {
  final rawStream = ref.watch(rawTradesProvider.stream);
  await for (final trade in rawStream) {
    if (trade.streamType == BinanceStreamType.bookTicker) {
      yield trade;
    }
  }
});

// ===================================================================
// 5. 실시간 통계 및 모니터링 Providers
// ===================================================================

/// 🎯 Repository 기반 실시간 성능 통계
final tradeStatsProvider = StateNotifierProvider.autoDispose<
    RepositoryStatsNotifier, Map<String, dynamic>>((ref) {
  return RepositoryStatsNotifier(ref);
});

class RepositoryStatsNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref _ref;
  Timer? _updateTimer;
  int _lastProcessedCount = 0;
  int _lastFilteredCount = 0;
  DateTime _lastUpdateTime = DateTime.now();

  RepositoryStatsNotifier(this._ref) : super({}) {
    // 1초마다 Repository 상태 업데이트
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRepositoryStats();
    });
    _updateRepositoryStats();
  }

  void _updateRepositoryStats() {
    try {
      final repository = _ref.read(tradeRepositoryProvider) as TradeRepositoryImpl;
      final status = repository.getStatus();
      
      final now = DateTime.now();
      final processedCount = status['processedCount'] as int? ?? 0;
      final filteredCount = status['filteredCount'] as int? ?? 0;
      
      // 처리 속도 계산 (초당)
      final timeDiff = now.difference(_lastUpdateTime).inSeconds;
      final processedRate = timeDiff > 0 
          ? (processedCount - _lastProcessedCount) / timeDiff 
          : 0;
      final filteredRate = timeDiff > 0 
          ? (filteredCount - _lastFilteredCount) / timeDiff 
          : 0;

      state = {
        ...status,
        'processedPerSecond': processedRate.toStringAsFixed(1),
        'filteredPerSecond': filteredRate.toStringAsFixed(1),
        'lastStatsUpdate': now.toIso8601String(),
      };

      _lastProcessedCount = processedCount;
      _lastFilteredCount = filteredCount;
      _lastUpdateTime = now;

    } catch (e, st) {
      log.e('[RepositoryStatsNotifier] Stats update error', e, st);
    }
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
}

/// Repository 상태 모니터링
final repositoryStatusProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
  return repository.getStatus();
});

/// 특정 필터의 거래 수 조회
final filterTradeCountProvider = Provider.family.autoDispose<int, TradeFilter>((ref, filter) {
  final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
  return repository.getTradeCountForFilter(filter);
});

// ===================================================================
// 6. SignalBus 이벤트 스트림들 (기존 유지)
// ===================================================================

final signalBusAggTradeProvider = StreamProvider.autoDispose((ref) {
  final signalBus = ref.watch(signalBusProvider);
  return signalBus.eventsOfType(BinanceEventType.aggTrade);
});

final signalBusTickerProvider = StreamProvider.autoDispose((ref) {
  final signalBus = ref.watch(signalBusProvider);
  return signalBus.eventsOfType(BinanceEventType.ticker);
});

final signalBusBookTickerProvider = StreamProvider.autoDispose((ref) {
  final signalBus = ref.watch(signalBusProvider);
  return signalBus.eventsOfType(BinanceEventType.bookTicker);
});

final signalBusErrorProvider = StreamProvider.autoDispose((ref) {
  final signalBus = ref.watch(signalBusProvider);
  return signalBus.errors;
});

// ===================================================================
// 7. API Providers (기존 유지)
// ===================================================================

/// 특정 심볼의 24시간 통계 정보
final marketInfoProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, symbol) async {
  log.d('[marketInfoProvider] Fetching info for $symbol');
  
  final client = ref.watch(apiClientProvider);
  
  try {
    final result = await client.get(
      '/fapi/v1/ticker/24hr',
      query: {'symbol': symbol},
      cacheDur: const Duration(seconds: 30),
      weight: 1,
    );
    
    return result.when(
      ok: (data) {
        log.d('[marketInfoProvider] Got info for $symbol');
        return data as Map<String, dynamic>;
      },
      err: (error) {
        log.e('[marketInfoProvider] Failed to get info for $symbol: $error');
        return null;
      },
    );
    
  } catch (e, stackTrace) {
    log.e('[marketInfoProvider] Error for $symbol', e, stackTrace);
    return null;
  }
});

/// 바이낸스 선물 거래소 정보
final exchangeInfoProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  log.d('[exchangeInfoProvider] Fetching exchange info...');
  
  final client = ref.watch(apiClientProvider);
  
  try {
    final result = await client.get(
      '/fapi/v1/exchangeInfo',
      cacheDur: const Duration(hours: 1),
      weight: 1,
    );
    
    return result.when(
      ok: (data) {
        log.i('[exchangeInfoProvider] Exchange info loaded successfully');
        return data as Map<String, dynamic>;
      },
      err: (error) {
        log.e('[exchangeInfoProvider] Failed to get exchange info: $error');
        return null;
      },
    );
    
  } catch (e, stackTrace) {
    log.e('[exchangeInfoProvider] Error getting exchange info', e, stackTrace);
    return null;
  }
});

/// API 클라이언트 상태 정보
final apiStatusProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final client = ref.watch(apiClientProvider);
  return client.getStatus();
});

/// Rate limit 사용률 정보
final rateLimitStatusProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final client = ref.watch(apiClientProvider);
  final status = client.getStatus();
  return status['rateLimiter'] as Map<String, dynamic>? ?? {};
});

// ===================================================================
// 8. 헬퍼 및 유틸리티 Providers
// ===================================================================

/// 필터 변경 헬퍼
final tradeFilterController = Provider((ref) => TradeFilterController(ref));

class TradeFilterController {
  final Ref _ref;
  TradeFilterController(this._ref);

  /// 필터 변경 및 Repository 업데이트
  void updateFilter(TradeFilter newFilter) {
    final currentFilter = _ref.read(tradeFilterProvider);
    if (currentFilter == newFilter) return;

    log.i('[TradeFilterController] Filter updated: ${currentFilter.displayName} → ${newFilter.displayName}');
    
    // UI 필터 상태 업데이트
    _ref.read(tradeFilterProvider.notifier).state = newFilter;
    
    // Repository에도 임계값 업데이트 전달
    final repository = _ref.read(tradeRepositoryProvider);
    repository.updateThreshold(newFilter.value);
  }

  TradeFilter get currentFilter => _ref.read(tradeFilterProvider);
  List<TradeFilter> get availableFilters => TradeFilter.values;
}

/// 디버그 정보 종합 Provider
final debugInfoProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final repositoryStatus = ref.watch(repositoryStatusProvider);
  final apiStatus = ref.watch(apiStatusProvider);
  final currentFilter = ref.watch(tradeFilterProvider);
  
  return {
    'timestamp': DateTime.now().toIso8601String(),
    'currentFilter': currentFilter.displayName,
    'repository': repositoryStatus,
    'api': apiStatus,
    'providers': {
      'marketsProvider': ref.watch(marketsProvider).hasValue,
      'filteredTradesProvider': 'streaming',
      'aggregatedTradesProvider': 'streaming',
    },
  };
});