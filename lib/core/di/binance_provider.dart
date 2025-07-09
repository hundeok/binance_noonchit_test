// lib/core/di/binance_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/trade.dart';
import '../network/binance_ws_client.dart';

// 1. 웹소켓 클라이언트 프로바이더
final binanceClientProvider = Provider((ref) {
  final client = BinanceWsClient();
  ref.onDispose(() => client.dispose());
  return client;
});

// 2. UI에 직접 데이터를 제공할 최종 프로바이더
final binanceTradesProvider =
    StateNotifierProvider<BinanceTradesNotifier, List<Trade>>((ref) {
  return BinanceTradesNotifier(ref);
});

class BinanceTradesNotifier extends StateNotifier<List<Trade>> {
  final Ref _ref;
  StreamSubscription? _subscription;

  BinanceTradesNotifier(this._ref) : super([]) {
    _connect();
  }

  void _connect() {
    final client = _ref.read(binanceClientProvider);
    
    // 하드코딩된 구독 종목
    client.connect(['BTCUSDT', 'ETHUSDT', 'SOLUSDT', 'XRPUSDT']);

    _subscription?.cancel();
    _subscription = client.stream.listen((trade) {
      // 최신 100개의 체결 데이터만 상태로 관리
      state = [trade, ...state].take(100).toList();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}