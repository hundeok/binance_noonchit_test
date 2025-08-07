// lib/data/datasources/trade_remote_ds.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../../core/bridge/signal_bus.dart';
import '../../../core/event/app_event.dart';
import '../../../core/network/websocket/trade_ws_client.dart';
import '../../domain/entities/trade.dart';

/// 🎯 바이낸스 선물 실시간 Trade 데이터 소스 (업비트 스타일 브로드캐스트)
/// - 멀티 스트림 지원 (aggTrade, ticker, bookTicker, depth5)
/// - 브로드캐스트로 여러 Repository 동시 구독 가능
/// - 에러 시 자동 폴백으로 안정성 확보
class TradeRemoteDataSource {
  final TradeWsClient _ws;
  final SignalBus _signalBus;
  final bool _useTestData;

  // 🆕 브로드캐스트 시스템
  StreamController<Trade>? _masterController;
  StreamSubscription<Trade>? _wsSub;
  bool _disposed = false;
  List<String>? _currentMarkets; // 현재 구독 중인 마켓들
  int _subscriberCount = 0; // 구독자 수 추적

  // 📊 성능 모니터링
  int _messageCount = 0;
  DateTime? _lastMessageTime;
  Timer? _performanceTimer;

  TradeRemoteDataSource(
    this._ws,
    this._signalBus, {
    bool useTestData = false,
  }) : _useTestData = useTestData {
    _startPerformanceMonitoring();
  }

  /// 🆕 브로드캐스트 스트림 제공 - 여러 Repository가 구독 가능
  Stream<Trade> watch(List<String> markets) {
    if (_useTestData) return _testStream();

    // dispose 후 재사용 가능하도록 초기화
    if (_disposed) {
      debugPrint('TradeRemoteDataSource: resetting after dispose');
      _disposed = false;
    }

    // 🆕 동일한 마켓이면 기존 스트림 재사용
    if (_masterController != null && 
        _currentMarkets != null && 
        _marketsEqual(_currentMarkets!, markets)) {
      debugPrint('TradeRemoteDataSource: reusing existing broadcast stream for ${markets.length} markets');
      return _masterController!.stream;
    }

    // 🆕 새로운 마켓이면 기존 스트림 정리하고 새로 생성
    _cleanupMasterStream();
    _initializeMasterStream(markets);

    return _masterController!.stream;
  }

  /// 🆕 마스터 브로드캐스트 스트림 초기화
  void _initializeMasterStream(List<String> markets) {
    debugPrint('TradeRemoteDataSource: initializing master broadcast stream for ${markets.length} markets');
    
    _currentMarkets = List<String>.from(markets);
    
    _masterController = StreamController<Trade>.broadcast(
      onListen: () {
        _subscriberCount++;
        debugPrint('TradeRemoteDataSource: subscriber added (total: $_subscriberCount)');
        
        // 첫 번째 구독자일 때만 WebSocket 시작
        if (_subscriberCount == 1 && !_disposed) {
          _startWebSocket(markets);
        }
      },
      onCancel: () {
        _subscriberCount--;
        debugPrint('TradeRemoteDataSource: subscriber removed (remaining: $_subscriberCount)');
        
        // 모든 구독자가 떠나면 WebSocket 정리 (5초 지연)
        if (_subscriberCount <= 0) {
          Timer(const Duration(seconds: 5), () {
            if (_subscriberCount <= 0 && !_disposed) {
              debugPrint('TradeRemoteDataSource: no subscribers, cleaning up WebSocket');
              _cleanupWebSocket();
            }
          });
        }
      },
    );
  }

  /// 🆕 WebSocket 연결 시작
  void _startWebSocket(List<String> markets) {
    if (_disposed) return;

    try {
      debugPrint('TradeRemoteDataSource: starting WebSocket for ${markets.length} markets');
      
      _ws.connect(markets);
      
      // ✅ Trade 스트림을 직접 구독
      _wsSub = _ws.stream.listen(
        (trade) {
          // controller가 닫혔거나 disposed면 처리 안함
          if (_disposed || _masterController == null || _masterController!.isClosed) {
            debugPrint('TradeRemoteDataSource: skipping data - disposed or closed');
            return;
          }

          // ✅ 데이터 검증
          if (!trade.isValidData) {
            debugPrint('TradeRemoteDataSource: invalid trade data for ${trade.market}');
            return;
          }

          // 🎯 성능 카운터 업데이트
          _messageCount++;
          _lastMessageTime = DateTime.now();

          // 🆕 마스터 컨트롤러에 브로드캐스트
          if (!_disposed && _masterController != null && !_masterController!.isClosed) {
            _masterController!.add(trade);
          }

          // 🎯 스트림 타입별 이벤트 발생 (SignalBus 활용)
          _fireSignalBusEvent(trade);
        },
        onError: (error, stackTrace) {
          debugPrint('WebSocket error: $error');
          // ✅ 에러 시 폴백 스트림으로 전환
          if (!_disposed && _masterController != null && !_masterController!.isClosed) {
            debugPrint('TradeRemoteDataSource: switching to fallback stream');
            _masterController!.addStream(_testStream());
          }
        },
        onDone: () {
          debugPrint('WebSocket done - connection closed');
          // ✅ 연결 종료 시 폴백 스트림으로 전환
          if (!_disposed && _masterController != null && !_masterController!.isClosed) {
            debugPrint('TradeRemoteDataSource: switching to fallback stream');
            _masterController!.addStream(_testStream());
          }
        },
        cancelOnError: false, // 에러가 나도 스트림 유지
      );
      
      debugPrint('TradeRemoteDataSource: WebSocket stream subscription established');
      
    } catch (e, st) {
      debugPrint('WS connection failed: $e');
      debugPrint('Stack trace: $st');
      
      // ✅ 연결 실패 시 즉시 폴백 스트림으로 전환
      if (!_disposed && _masterController != null && !_masterController!.isClosed) {
        debugPrint('TradeRemoteDataSource: connection failed, using fallback stream');
        _masterController!.addStream(_testStream());
      }
    }
  }

  /// 🎯 스트림 타입별 SignalBus 이벤트 발생
  void _fireSignalBusEvent(Trade trade) {
    try {
      // Trade 객체를 JSON으로 변환
      final tradeData = trade.toDebugMap();
      
      // 스트림 타입별로 다른 이벤트 발생
      switch (trade.streamType) {
        case BinanceStreamType.aggTrade:
          _signalBus.fireAggTrade(tradeData);
          break;
        case BinanceStreamType.ticker:
          _signalBus.fireTicker(tradeData);
          break;
        case BinanceStreamType.bookTicker:
          _signalBus.fireBookTicker(tradeData);
          break;
        case BinanceStreamType.depth5:
          _signalBus.fireDepth5(tradeData);
          break;
      }
      
      // ✅ 기존 호환성을 위한 일반 trade 이벤트도 발생
      final appEvent = AppEvent.now(tradeData);
      _signalBus.fireTradeEvent(appEvent);
      
    } catch (e) {
      debugPrint('SignalBus event firing failed: $e');
    }
  }

  /// 🆕 WebSocket만 정리 (컨트롤러는 유지)
  void _cleanupWebSocket() {
    debugPrint('TradeRemoteDataSource: cleaning up WebSocket');
    _wsSub?.cancel();
    _wsSub = null;
  }

  /// 🆕 마스터 스트림 완전 정리
  void _cleanupMasterStream() {
    debugPrint('TradeRemoteDataSource: cleaning up master stream');
    
    _cleanupWebSocket();
    
    if (_masterController != null && !_masterController!.isClosed) {
      _masterController!.close();
    }
    _masterController = null;
    _currentMarkets = null;
    _subscriberCount = 0;
  }

  /// 🆕 마켓 리스트 비교 헬퍼
  bool _marketsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final setA = Set<String>.from(a);
    final setB = Set<String>.from(b);
    return setA.containsAll(setB) && setB.containsAll(setA);
  }

  /// 📊 성능 모니터링 시작
  void _startPerformanceMonitoring() {
    _performanceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_messageCount > 0) {
        final rate = _messageCount / 10; // 초당 메시지 수
        debugPrint('TradeRemoteDataSource: ${rate.toStringAsFixed(1)} msg/sec, '
                  'subscribers: $_subscriberCount, '
                  'last: ${_lastMessageTime?.toString() ?? "none"}');
        _messageCount = 0; // 카운터 리셋
      }
    });
  }

  /// 🎯 개선된 테스트 스트림 (바이낸스 실제 형식)
  Stream<Trade> _testStream() async* {
    final rnd = Random();
    const symbols = [
      'BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'ADAUSDT', 'SOLUSDT',
      'XRPUSDT', 'DOTUSDT', 'LINKUSDT', 'LTCUSDT', 'MATICUSDT',
    ];

    const streamTypes = BinanceStreamType.values;

    while (!_disposed) {
      await Future.delayed(const Duration(milliseconds: 200)); // 5msg/sec
      if (_disposed) break;
      
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final symbol = symbols[rnd.nextInt(symbols.length)];
      final streamType = streamTypes[rnd.nextInt(streamTypes.length)];
      final basePrice = 50000.0 + rnd.nextDouble() * 10000; // 50k-60k 범위
      
      // ✅ 스트림 타입별로 다른 테스트 데이터 생성 (바이낸스 실제 형식)
      late Map<String, dynamic> testData;
      
      switch (streamType) {
        case BinanceStreamType.aggTrade:
          testData = {
            'e': 'aggTrade',
            's': symbol,
            'p': basePrice.toStringAsFixed(2),
            'q': (rnd.nextDouble() * 10).toStringAsFixed(4),
            'T': nowMs,
            'a': rnd.nextInt(1000000),
            'm': rnd.nextBool(),
          };
          break;
        case BinanceStreamType.ticker:
          testData = {
            'e': '24hrTicker',
            's': symbol,
            'c': basePrice.toStringAsFixed(2),
            'P': (rnd.nextDouble() * 10 - 5).toStringAsFixed(2), // -5% ~ +5%
            'h': (basePrice * 1.1).toStringAsFixed(2),
            'l': (basePrice * 0.9).toStringAsFixed(2),
            'v': (rnd.nextDouble() * 1000).toStringAsFixed(2),
            'q': (rnd.nextDouble() * 50000000).toStringAsFixed(2),
            'E': nowMs,
          };
          break;
        case BinanceStreamType.bookTicker:
          testData = {
            's': symbol,
            'b': (basePrice * 0.999).toStringAsFixed(2),
            'a': (basePrice * 1.001).toStringAsFixed(2),
            'B': (rnd.nextDouble() * 100).toStringAsFixed(4),
            'A': (rnd.nextDouble() * 100).toStringAsFixed(4),
            'u': rnd.nextInt(1000000),
          };
          break;
        case BinanceStreamType.depth5:
          // ✅ 수정: 바이낸스 실제 depth5 형식 (b/a 필드)
          testData = {
            'e': 'depthUpdate',
            's': symbol,
            'E': nowMs,
            'T': nowMs,
            'U': rnd.nextInt(1000000),
            'u': rnd.nextInt(1000000) + 1000000,
            'pu': rnd.nextInt(1000000),
            'b': [
              [(basePrice * 0.999).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 0.998).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 0.997).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 0.996).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 0.995).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
            ],
            'a': [
              [(basePrice * 1.001).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 1.002).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 1.003).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 1.004).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
              [(basePrice * 1.005).toStringAsFixed(2), (rnd.nextDouble() * 100).toStringAsFixed(4)],
            ],
            'lastUpdateId': rnd.nextInt(1000000),
          };
          break;
      }
      
      try {
        final trade = Trade.fromBinanceStream(
          json: testData, 
          streamType: streamType,
          symbol: symbol,
        );
        
        yield trade;
        
        // 테스트 데이터도 SignalBus에 발생
        _fireSignalBusEvent(trade);
        
      } catch (e) {
        debugPrint('Test data creation failed: $e');
      }
    }
  }

  /// 📊 현재 상태 정보
  Map<String, dynamic> getStatus() {
    return {
      'isDisposed': _disposed,
      'subscriberCount': _subscriberCount,
      'currentMarkets': _currentMarkets?.length ?? 0,
      'hasMasterController': _masterController != null,
      'hasWebSocketSub': _wsSub != null,
      'messageCount': _messageCount,
      'lastMessageTime': _lastMessageTime?.toIso8601String(),
      'useTestData': _useTestData,
    };
  }

  /// Clean up resources when no longer needed.
  Future<void> dispose() async {
    if (_disposed) return;
    
    _disposed = true;
    
    debugPrint('TradeRemoteDataSource: disposing...');
    
    // 성능 모니터링 타이머 정리
    _performanceTimer?.cancel();
    
    // 모든 리소스 정리
    _cleanupMasterStream();
    
    debugPrint('TradeRemoteDataSource: disposed');
    
    // WebSocket 클라이언트는 공유 리소스이므로 dispose하지 않음
  }
}