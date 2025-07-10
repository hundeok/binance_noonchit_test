import 'dart:async';
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
// 1. Service & Data Layer Providers
// ===================================================================

final apiClientProvider = Provider((_) => ApiClient());
final tradeRemoteDSProvider = Provider((ref) => TradeRemoteDataSource(ref.watch(wsClientProvider)));
final tradeRepositoryProvider = Provider<TradeRepository>((ref) {
  final repo = TradeRepositoryImpl(ref.watch(tradeRemoteDSProvider));
  // ✅ Provider가 소멸될 때 Repository의 dispose 메서드 호출
  ref.onDispose(() => repo.dispose());
  return repo;
});


// ===================================================================
// 2. Market Info & Raw Data Stream Providers
// ===================================================================

final marketsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  log.d('Fetching top volume markets from Binance...');
  final client = ref.watch(apiClientProvider);
  try {
    final List<dynamic> tickers = await client.get('/fapi/v1/ticker/24hr');
    
    tickers.removeWhere((t) => !(t['symbol'] as String).endsWith('USDT'));
    tickers.sort((a, b) {
      final volumeA = double.tryParse(a['quoteVolume'].toString()) ?? 0;
      final volumeB = double.tryParse(b['quoteVolume'].toString()) ?? 0;
      return volumeB.compareTo(volumeA);
    });

    final markets = tickers.map((t) => t['symbol'] as String).take(AppConfig.wsMaxSubscriptions).toList();
    log.i('Fetched ${markets.length} markets, sorted by volume.');
    return markets;
  } catch (e, st) {
    log.e('Failed to fetch Binance markets', e, st);
    return ['BTCUSDT', 'ETHUSDT', 'SOLUSDT'];
  }
});

final rawTradeStreamProvider = StreamProvider.autoDispose<Trade>((ref) {
  final repo = ref.watch(tradeRepositoryProvider);
  final marketsAsyncValue = ref.watch(marketsProvider);

  return marketsAsyncValue.when(
    // ✅ 수정된 부분: Repository 인터페이스에 정의된 `watchAggregatedTrades`를 사용
    data: (markets) => markets.isEmpty ? const Stream.empty() : repo.watchAggregatedTrades(markets),
    loading: () => const Stream.empty(),
    error: (e, st) => Stream.error(e, st),
  );
});


// ===================================================================
// 3. Filtered Data & UI State Providers
// ===================================================================

final tradeFilterProvider = StateProvider<TradeFilter>((ref) => TradeFilter.usdt50k);

final filteredTradesProvider = Provider.autoDispose<List<Trade>>((ref) {
  final cache = ref.watch(_tradeCacheProvider);
  final filter = ref.watch(tradeFilterProvider);
  return cache[filter] ?? [];
});

final _tradeCacheProvider = StateNotifierProvider.autoDispose<TradeCacheNotifier, Map<TradeFilter, List<Trade>>>((ref) {
  return TradeCacheNotifier(ref);
});

class TradeCacheNotifier extends StateNotifier<Map<TradeFilter, List<Trade>>> {
  final Ref _ref;
  final _seenIds = LinkedHashSet<String>();
  ProviderSubscription? _sub;

  TradeCacheNotifier(this._ref)
      : super({ for (var filter in TradeFilter.values) filter: [] }) {
    _sub = _ref.listen<AsyncValue<Trade>>(
      rawTradeStreamProvider,
      (previous, next) {
        next.whenData(_processTrade);
      },
      fireImmediately: true,
    );
  }
  
  void _processTrade(Trade trade) {
    if (!_seenIds.add(trade.tradeId)) return;
    if (_seenIds.length > TradeConfig.maxSeenIdsCacheSize) {
      _seenIds.remove(_seenIds.first);
    }
    
    final currentCache = Map.of(state);
    bool needsUpdate = false;

    for (final filter in TradeFilter.values) {
      if (trade.totalValue >= filter.value) {
        final list = currentCache[filter]!;
        list.insert(0, trade);
        if (list.length > TradeConfig.maxTradesPerFilter) {
          currentCache[filter] = list.sublist(0, TradeConfig.maxTradesPerFilter);
        }
        needsUpdate = true;
      }
    }
    
    if (needsUpdate) {
      state = currentCache;
    }
  }
  
  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }
}