import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../config/app_config.dart';
import '../../utils/logger.dart';
import 'exponential_backoff.dart'; // ✅ 지수 백오프 import

enum WsStatus { connecting, connected, reconnecting, disconnected }
typedef DecodeFn<T> = T? Function(Map<String, dynamic> json);
typedef EncodeFn = String Function(List<String> symbols);

class BaseWsClient<T> {
  final String url;
  final DecodeFn<T> decode;
  final EncodeFn encodeSubscribe;
  final void Function(WsStatus status)? onStatusChange;
  final Duration unsolicitedPongInterval;
  final Duration pongTimeout;

  WebSocketChannel? _channel;
  final _dataController = StreamController<T>.broadcast();
  List<String> _subscribedSymbols = [];
  bool _isDisposed = false;
  WsStatus _currentStatus = WsStatus.disconnected;

  // ✅ 체크리스트 요구사항을 위한 프로퍼티 추가
  final _backoff = ExponentialBackoff();
  final _rxTimestamps = Queue<DateTime>(); // 수신 속도 제한용
  Timer? _pongTimer;
  Timer? _unsolicitedPongTimer;
  Timer? _sessionRefreshTimer; // 24시간 자동 재연결용

  BaseWsClient({
    required this.url,
    required this.decode,
    required this.encodeSubscribe,
    this.onStatusChange,
    required this.unsolicitedPongInterval,
    required this.pongTimeout,
  });

  Stream<T> get stream => _dataController.stream;

  void connect(List<String> symbols) {
    if (_isDisposed || symbols.isEmpty || _currentStatus == WsStatus.connecting) return;
    _subscribedSymbols = symbols;
    _updateStatus(WsStatus.connecting);
    _cleanupConnection(keepSubscribers: true);

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.sink.add(encodeSubscribe(_subscribedSymbols));
      _channel!.stream.listen(
        _handleMessage,
        onDone: () => _scheduleReconnect(reason: 'Stream done'),
        onError: (e) => _scheduleReconnect(reason: 'Stream error: $e'),
      );
      _backoff.reset(); // 연결 성공 시 백오프 리셋
      _setupTimers();
      _updateStatus(WsStatus.connected);
      log.i('[WS] Connected to $url');
    } catch (e, st) {
      log.e('[WS] Connection attempt failed', e, st);
      _scheduleReconnect(reason: 'Connection exception');
    }
  }

  void _handleMessage(dynamic message) {
    // ✅ 1. 수신 속도 제한 체크 (10 msg/s)
    final now = DateTime.now();
    _rxTimestamps.addLast(now);
    while (now.difference(_rxTimestamps.first) > const Duration(seconds: 1)) {
      _rxTimestamps.removeFirst();
    }
    if (_rxTimestamps.length > AppConfig.wsMaxInMsgPerSec) {
      log.w('[WS] Receive rate limit exceeded. Reconnecting...');
      _scheduleReconnect(reason: 'Rx rate limit');
      return;
    }

    // ✅ 2. Pong 타이머 리셋 (연결 생존 확인)
    _resetPongTimer();

    try {
      final json = jsonDecode(message) as Map<String, dynamic>;
      // ✅ 3. 서버 에러 메시지 처리
      if (json.containsKey('code') && json['code'] != 0) {
        log.e('[WS] Server error received: ${json['msg']} (code: ${json['code']})');
        return;
      }
      final decodedData = decode(json);
      if (decodedData != null) {
        _dataController.add(decodedData);
      }
    } catch (e, st) {
      log.e('[WS] Message decoding error', e, st);
    }
  }

  void _setupTimers() {
    _resetPongTimer();
    _setupUnsolicitedPong();
    _setupSessionRefreshTimer();
  }

  void _resetPongTimer() {
    _pongTimer?.cancel();
    _pongTimer = Timer(pongTimeout, () {
      log.w('[WS] Pong timeout. No message received.');
      _scheduleReconnect(reason: 'Pong timeout');
    });
  }

  /// ✅ 4. Unsolicited Pong 주기적 전송
  void _setupUnsolicitedPong() {
    _unsolicitedPongTimer?.cancel();
    _unsolicitedPongTimer = Timer.periodic(unsolicitedPongInterval, (_) {
      if (_currentStatus == WsStatus.connected) {
        _channel?.sink.add('PONG');
        log.d('[WS] Unsolicited PONG sent.');
      }
    });
  }

  /// ✅ 5. 24시간 세션 자동 갱신 타이머
  void _setupSessionRefreshTimer() {
    _sessionRefreshTimer?.cancel();
    _sessionRefreshTimer = Timer(AppConfig.wsSessionRefresh, () {
      log.i('[WS] Proactively reconnecting to handle 24-hour session limit.');
      _scheduleReconnect(reason: '24h session refresh');
    });
  }

  /// ✅ 6. 지수 백오프를 사용한 재연결 스케줄러
  void _scheduleReconnect({required String reason}) {
    if (_isDisposed || _currentStatus == WsStatus.reconnecting) return;
    _updateStatus(WsStatus.reconnecting);
    log.w('[WS] Disconnected. Reason: $reason. Retrying with exponential backoff...');
    _cleanupConnection(keepSubscribers: true);

    _backoff.attempt(() async {
      if (!_isDisposed) connect(_subscribedSymbols);
    });
  }

  void _updateStatus(WsStatus status) {
    if (_currentStatus == status) return;
    _currentStatus = status;
    try {
      onStatusChange?.call(status);
    } catch (e, st) {
      log.e('[WS] onStatusChange callback error', e, st);
    }
  }

  void _cleanupConnection({bool keepSubscribers = false}) {
    _pongTimer?.cancel();
    _unsolicitedPongTimer?.cancel();
    _sessionRefreshTimer?.cancel();
    _channel?.sink.close();
    if (!keepSubscribers) _subscribedSymbols.clear();
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _cleanupConnection();
    _dataController.close();
    _updateStatus(WsStatus.disconnected);
    log.i('[WS] Client permanently disposed.');
  }
}