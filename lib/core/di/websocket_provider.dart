import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/websocket/base_ws_client.dart';
import '../network/websocket/trade_ws_client.dart';
import '../utils/logger.dart';
import 'core_provider.dart';

@immutable
class WebSocketState {
  final WsStatus status;
  final List<String> subscribedSymbols;
  final DateTime? lastConnectedAt;

  const WebSocketState({
    this.status = WsStatus.disconnected,
    this.subscribedSymbols = const [],
    this.lastConnectedAt,
  });

  WebSocketState copyWith({
    WsStatus? status,
    List<String>? subscribedSymbols,
    DateTime? lastConnectedAt,
  }) {
    return WebSocketState(
      status: status ?? this.status,
      subscribedSymbols: subscribedSymbols ?? this.subscribedSymbols,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
  
    return other is WebSocketState &&
      other.status == status &&
      listEquals(other.subscribedSymbols, subscribedSymbols) &&
      other.lastConnectedAt == lastConnectedAt;
  }

  @override
  int get hashCode => status.hashCode ^ subscribedSymbols.hashCode ^ lastConnectedAt.hashCode;
}

final wsClientProvider = Provider.autoDispose<TradeWsClient>((ref) {
  final client = TradeWsClient();
  ref.onDispose(client.dispose);
  return client;
});

final webSocketManagerProvider =
    StateNotifierProvider.autoDispose<WebSocketManager, WebSocketState>(
  (ref) => WebSocketManager(ref),
);

class WebSocketManager extends StateNotifier<WebSocketState> {
  final Ref _ref;

  WebSocketManager(this._ref) : super(const WebSocketState()) {
    // ✅ 이제 이 코드는 정상적으로 동작합니다.
    _ref.read(wsClientProvider).onStatusChange = (newStatus) {
      if (state.status != newStatus) {
        state = state.copyWith(
          status: newStatus,
          lastConnectedAt: newStatus == WsStatus.connected ? DateTime.now() : state.lastConnectedAt,
        );
      }
    };
  }

  Future<void> connect() async {
    if (state.status == WsStatus.connecting || state.status == WsStatus.connected) {
      log.w('[WebSocketManager] Already connected or connecting.');
      return;
    }

    state = state.copyWith(status: WsStatus.connecting);

    try {
      final markets = await _ref.read(marketsProvider.future);
      if (markets.isEmpty) {
        throw Exception('Cannot connect without markets.');
      }
      
      _ref.read(wsClientProvider).connect(markets);
      
      state = state.copyWith(subscribedSymbols: markets);
      log.i('[WebSocketManager] Connect command issued with ${markets.length} markets.');

    } catch (e, st) {
      log.e('[WebSocketManager] Connection failed.', e, st);
      state = state.copyWith(status: WsStatus.disconnected);
    }
  }

  void disconnect() {
    log.i('[WebSocketManager] Disconnect command issued.');
    _ref.read(wsClientProvider).dispose();
    state = const WebSocketState(); 
  }
}