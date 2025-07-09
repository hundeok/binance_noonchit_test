// lib/core/network/binance_ws_client.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../domain/entities/trade.dart';
import '../config/binance_config.dart';

class BinanceWsClient {
  final _controller = StreamController<Trade>.broadcast();
  WebSocketChannel? _channel;
  List<String> _markets = [];

  Stream<Trade> get stream => _controller.stream;

  void connect(List<String> markets) {
    _markets = markets;
    _channel?.sink.close(); // 이전 연결 종료

    final url = Uri.parse(BinanceConfig.streamUrl);
    _channel = WebSocketChannel.connect(url);

    final params = _markets.map((m) => '${m.toLowerCase()}@aggTrade').toList();
    final subRequest = {'method': 'SUBSCRIBE', 'params': params, 'id': 1};
    _channel!.sink.add(jsonEncode(subRequest));

    _channel!.stream.listen(
      (message) {
        final Map<String, dynamic> data = jsonDecode(message);
        if (data.containsKey('data')) {
          final trade = Trade.fromBinance(data['data']);
          _controller.add(trade);
        }
      },
      onDone: () => _reconnect(),
      onError: (err) => _reconnect(),
      cancelOnError: true,
    );
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 3), () => connect(_markets));
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}