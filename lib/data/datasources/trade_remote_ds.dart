// lib/data/datasources/trade_remote_ds.dart

import '../../core/network/websocket/trade_ws_client.dart';
import '../../domain/entities/trade.dart';

/// 원격 WebSocket으로부터 실시간 Trade 데이터를 수신하는 데이터 소스
class TradeRemoteDataSource {
  final TradeWsClient _wsClient;

  TradeRemoteDataSource(this._wsClient);

  /// WebSocket 클라이언트에 마켓 구독을 요청하고,
  /// 반환되는 순수 Trade 스트림을 그대로 전달합니다.
  Stream<Trade> watchTrades(List<String> markets) {
    _wsClient.connect(markets);
    return _wsClient.stream;
  }
}