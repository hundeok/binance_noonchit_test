import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/trade_remote_ds.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../domain/entities/trade.dart';
import '../../domain/repositories/trade_repository.dart';
import '../common/time_frame_types.dart'; // TradeFilter enum이 정의된 경로
import '../config/app_config.dart';
import '../network/api_client.dart';
import '../utils/logger.dart';
import 'websocket_provider.dart';

// ===================================================================
// 0. Configuration Constants
// ===================================================================

class TradeConfig {
  static const int maxSeenIdsCacheSize = 10000;
  static const int maxTradesPerFilter = 100;
}

// ===================================================================
// 1. Foundational Service & Data Layer Providers
// ===================================================================

/// API 클라이언트 인스턴스를 제공합니다.
final apiClientProvider = Provider((_) => ApiClient());

/// 원격 데이터 소스(WebSocket)를 제공합니다.
final tradeRemoteDSProvider = Provider((ref) {
  return TradeRemoteDataSource(ref.watch(wsClientProvider));
});

/// 거래 데이터 Repository를 제공합니다.
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  final repo = TradeRepositoryImpl(ref.watch(tradeRemoteDSProvider));
  ref.onDispose(() => repo.dispose());
  return repo;
});

// ===================================================================
// 2. Market Info & Raw Data Stream Providers
// ===================================================================

/// 바이낸스 API에서 거래량 상위 종목 목록을 가져옵니다.
/// ✅ [수정] .autoDispose를 제거하여, 앱 세션 동안 종목 리스트를 단 한 번만 가져오도록 최적화합니다.
final marketsProvider = FutureProvider<List<String>>((ref) async {
  log.d('[marketsProvider] Fetching top volume markets from Binance...');
  final client = ref.watch(apiClientProvider);
  try {
    final List<dynamic> tickers = await client.get('/fapi/v1/ticker/24hr');
    
    tickers.removeWhere((t) => !(t['symbol'] as String).endsWith('USDT'));
    tickers.sort((a, b) {
      final volumeA = double.tryParse(a['quoteVolume'].toString()) ?? 0;
      final volumeB = double.tryParse(b['quoteVolume'].toString()) ?? 0;
      return volumeB.compareTo(volumeA);
    });

    final markets = tickers.map((t) => t['symbol'] as String)
                           .take(AppConfig.wsMaxSubscriptions)
                           .toList();
                           
    log.i('[marketsProvider] Fetched ${markets.length} markets, sorted by volume.');
    return markets;
  } catch (e, st) {
    log.e('[marketsProvider] Failed to fetch Binance markets', e, st);
    throw Exception('Failed to fetch markets: $e');
  }
});

/// WebSocket 클라이언트로부터 들어오는 가공되지 않은 '거래' 데이터 스트림을 제공합니다.
final rawTradeStreamProvider = StreamProvider.autoDispose<Trade>((ref) {
  final client = ref.watch(wsClientProvider);
  return client.stream;
});


// ===================================================================
// 3. Filtered Data & UI State Providers
// ===================================================================

/// UI에서 사용자가 선택한 거래대금 필터 값을 관리합니다.
final tradeFilterProvider = StateProvider<TradeFilter>((ref) => TradeFilter.usdt50k);

/// 최종적으로 필터링된 거래 목록을 UI에 제공합니다.
final filteredTradesProvider = Provider.autoDispose<List<Trade>>((ref) {
  final filter = ref.watch(tradeFilterProvider);
  final filteredList = ref.watch(tradeCacheProvider.select((cache) => cache[filter]));
  return filteredList ?? const [];
});

/// 거래 데이터를 필터별로 캐싱하고 관리하는 핵심 로직을 담당합니다.
final tradeCacheProvider = StateNotifierProvider.autoDispose<
    TradeCacheNotifier, Map<TradeFilter, List<Trade>>>((ref) {
  return TradeCacheNotifier(ref);
});

class TradeCacheNotifier extends StateNotifier<Map<TradeFilter, List<Trade>>> {
  final Ref _ref;
  final Queue<String> _seenIds = Queue();
  ProviderSubscription? _sub;

  TradeCacheNotifier(this._ref)
      : super({for (var filter in TradeFilter.values) filter: const []}) {
    _sub = _ref.listen<AsyncValue<Trade>>(
      rawTradeStreamProvider,
      (_, next) => next.whenData(_processTrade),
    );
  }
  
  void _processTrade(Trade trade) {
    if (_seenIds.contains(trade.tradeId)) return;

    _seenIds.addLast(trade.tradeId);
    if (_seenIds.length > TradeConfig.maxSeenIdsCacheSize) {
      _seenIds.removeFirst();
    }
    
    final newState = Map.of(state); 
    bool needsUpdate = false;

    for (final filter in TradeFilter.values) {
      if (trade.totalValue >= filter.value) {
        final oldList = newState[filter]!;
        final newList = [trade, ...oldList];
        
        newState[filter] = newList.length > TradeConfig.maxTradesPerFilter 
            ? newList.sublist(0, TradeConfig.maxTradesPerFilter) 
            : newList;
            
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      state = newState;
    }
  }
  
  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}