// ===================================================================
// lib/core/bridge/signal_bus.dart
// 바이낸스 선물 전용 이벤트 버스 - 에러 처리 중심 설계
// ===================================================================

import 'dart:async';
import 'dart:convert';
import '../event/app_event.dart';
import '../error/app_exception.dart';
import '../extensions/result.dart';

typedef Json = Map<String, dynamic>;

// ===================================================================
// 바이낸스 이벤트 타입 정의
// ===================================================================

enum BinanceEventType {
  aggTrade('aggTrade'),
  markPrice('markPrice'),
  kline('kline'),
  miniTicker('24hrMiniTicker'),
  ticker('24hrTicker'),
  bookTicker('bookTicker'),
  forceOrder('forceOrder'),
  depthUpdate('depthUpdate'),
  depthPartial('depthPartial'),
  depth5('depth5'), // ✅ 추가: depth5 전용 타입
  accountUpdate('ACCOUNT_UPDATE'),
  orderUpdate('ORDER_TRADE_UPDATE'),
  accountConfigUpdate('ACCOUNT_CONFIG_UPDATE'),
  unknown('unknown');

  const BinanceEventType(this.value);
  final String value;

  static BinanceEventType fromString(String eventType) {
    for (final type in BinanceEventType.values) {
      if (type.value == eventType) return type;
    }
    return BinanceEventType.unknown;
  }

  static BinanceEventType fromStreamName(String streamName) {
    final lower = streamName.toLowerCase();
    
    if (lower.contains('@aggtrade')) return aggTrade;
    if (lower.contains('@markprice')) return markPrice;
    if (lower.contains('@kline')) return kline;
    if (lower.contains('@miniticker')) return miniTicker;
    if (lower.contains('@ticker')) return ticker;
    if (lower.contains('@bookticker')) return bookTicker;
    if (lower.contains('@forceorder')) return forceOrder;
    if (lower.contains('@depth5')) return depth5; // ✅ 추가: depth5 스트림 감지
    if (lower.contains('@depth@')) return depthUpdate;
    if (lower.contains('@depth')) return depthPartial;
    
    return unknown;
  }
}

// ===================================================================
// SignalBus 메인 클래스
// ===================================================================

class SignalBus {
  SignalBus._();
  static final SignalBus _instance = SignalBus._();
  factory SignalBus() => _instance;

  // 스트림 컨트롤러들
  final StreamController<AppEvent> _globalController = 
      StreamController<AppEvent>.broadcast();
  
  final Map<BinanceEventType, StreamController<AppEvent>> _typeControllers = {};
  final Map<String, StreamController<AppEvent>> _symbolControllers = {};
  
  // 에러 스트림
  final StreamController<AppException> _errorController = 
      StreamController<AppException>.broadcast();

  // 성능 모니터링
  int _messageCount = 0;
  DateTime _lastResetTime = DateTime.now();
  static const int _maxMessagesPerSecond = 1000;

  // ===================================================================
  // 공개 스트림 접근자
  // ===================================================================

  Stream<AppEvent> get events => _globalController.stream;
  Stream<AppException> get errors => _errorController.stream;

  Stream<AppEvent> eventsOfType(BinanceEventType type) =>
      _typeControllers.putIfAbsent(type, () =>
          StreamController<AppEvent>.broadcast()).stream;

  Stream<AppEvent> eventsOfSymbol(String symbol) =>
      _symbolControllers.putIfAbsent(symbol.toUpperCase(), () =>
          StreamController<AppEvent>.broadcast()).stream;

  // ===================================================================
  // 바이낸스 이벤트 발생 메서드들
  // ===================================================================

  void fireAggTrade(Json data) => _fire(BinanceEventType.aggTrade, data);
  void fireMarkPrice(Json data) => _fire(BinanceEventType.markPrice, data);
  void fireKline(Json data) => _fire(BinanceEventType.kline, data);
  void fireMiniTicker(Json data) => _fire(BinanceEventType.miniTicker, data);
  void fireTicker(Json data) => _fire(BinanceEventType.ticker, data);
  void fireBookTicker(Json data) => _fire(BinanceEventType.bookTicker, data);
  void fireDepth5(Json data) => _fire(BinanceEventType.depth5, data); // ✅ 수정: depth5 전용 타입 사용
  void fireForceOrder(Json data) => _fire(BinanceEventType.forceOrder, data);
  void fireDepthUpdate(Json data) => _fire(BinanceEventType.depthUpdate, data);
  void fireDepthPartial(Json data) => _fire(BinanceEventType.depthPartial, data);

  // 기존 호환성을 위한 일반 trade 이벤트
  void fireTradeEvent(AppEvent event) {
    try {
      if (!_globalController.isClosed) {
        _globalController.add(event);
      }
    } catch (e, stackTrace) {
      _fireError(AppException.business(
        'Failed to fire trade event: $e\nStack: ${stackTrace.toString()}'
      ));
    }
  }

  void fireUserDataUpdate(Json data) {
    final eventType = data['e'] as String?;
    switch (eventType) {
      case 'ACCOUNT_UPDATE':
        _fire(BinanceEventType.accountUpdate, data);
        break;
      case 'ORDER_TRADE_UPDATE':
        _fire(BinanceEventType.orderUpdate, data);
        break;
      case 'ACCOUNT_CONFIG_UPDATE':
        _fire(BinanceEventType.accountConfigUpdate, data);
        break;
      default:
        _fireError(AppException.parsing(
          'Unknown user data event type: $eventType'
        ));
    }
  }

  // ===================================================================
  // 웹소켓 메시지 처리
  // ===================================================================

  Result<void, AppException> processWebSocketMessage(String message, {String? streamName}) {
    try {
      if (_shouldDropMessage()) {
        return Err(AppException.business('Message rate limit exceeded'));
      }

      final data = jsonDecode(message) as Json;
      
      // Combined stream 처리
      if (data.containsKey('stream') && data.containsKey('data')) {
        final actualStreamName = data['stream'] as String;
        final actualData = data['data'] as Json;
        return _processMessage(actualData, streamName: actualStreamName);
      }
      
      // Raw stream 처리
      return _processMessage(data, streamName: streamName);
      
    } catch (e, stackTrace) {
      final exception = AppException.parsing(
        'Failed to parse WebSocket message: $e\nStack: ${stackTrace.toString()}'
      );
      _fireError(exception);
      return Err(exception);
    }
  }

  Result<void, AppException> _processMessage(Json data, {String? streamName}) {
    try {
      final eventType = _determineEventType(data, streamName);
      
      if (eventType == BinanceEventType.unknown) {
        final exception = AppException.parsing(
          'Unknown event type for message'
        );
        _fireError(exception);
        return Err(exception);
      }

      _fire(eventType, data);
      return const Ok(null);
      
    } catch (e, stackTrace) {
      final exception = AppException.business(
        'Failed to process message: $e\nStack: ${stackTrace.toString()}'
      );
      _fireError(exception);
      return Err(exception);
    }
  }

  BinanceEventType _determineEventType(Json data, String? streamName) {
    // 1. 스트림 이름으로 타입 감지
    if (streamName != null) {
      return BinanceEventType.fromStreamName(streamName);
    }
    
    // 2. 이벤트 타입 필드로 감지
    if (data.containsKey('e')) {
      final eventType = data['e'] as String;
      // ✅ 추가: depthUpdate 이벤트는 depth5로 처리 (depth5 스트림에서 오는 경우)
      if (eventType == 'depthUpdate' && _isDepth5Data(data)) {
        return BinanceEventType.depth5;
      }
      return BinanceEventType.fromString(eventType);
    }
    
    // 3. 데이터 구조로 추론
    return _inferEventTypeFromData(data);
  }

  // ✅ 추가: depth5 데이터인지 확인하는 헬퍼 메서드
  bool _isDepth5Data(Json data) {
    // depth5는 보통 b, a 필드를 가지고 있고, 5개 레벨의 호가를 제공
    if (data.containsKey('b') && data.containsKey('a')) {
      final bids = data['b'];
      final asks = data['a'];
      if (bids is List && asks is List) {
        // depth5는 최대 5개 레벨
        return bids.length <= 5 && asks.length <= 5;
      }
    }
    return false;
  }

  BinanceEventType _inferEventTypeFromData(Json data) {
    // 집계 거래: a, p, q 필드
    if (data.containsKey('a') && data.containsKey('p') && data.containsKey('q')) {
      return BinanceEventType.aggTrade;
    }
    
    // 마크 프라이스: markPrice 또는 r 필드
    if (data.containsKey('markPrice') || data.containsKey('r')) {
      return BinanceEventType.markPrice;
    }
    
    // K라인: k 객체
    if (data.containsKey('k')) {
      return BinanceEventType.kline;
    }
    
    // 북 티커: b, B, a, A 필드
    if (data.containsKey('b') && data.containsKey('B') && 
        data.containsKey('a') && data.containsKey('A')) {
      return BinanceEventType.bookTicker;
    }
    
    // ✅ 수정: depth5 vs 일반 depth 구분
    if (data.containsKey('b') && data.containsKey('a')) {
      final bids = data['b'];
      final asks = data['a'];
      if (bids is List && asks is List) {
        // 5개 이하 레벨이면 depth5, 그 이상이면 depthUpdate
        return (bids.length <= 5 && asks.length <= 5) 
            ? BinanceEventType.depth5 
            : BinanceEventType.depthUpdate;
      }
    }
    
    // 호가창: bids, asks 배열 (기존 로직)
    if (data.containsKey('bids') && data.containsKey('asks')) {
      return data.containsKey('lastUpdateId') 
          ? BinanceEventType.depthPartial 
          : BinanceEventType.depthUpdate;
    }
    
    return BinanceEventType.unknown;
  }

  // ===================================================================
  // 내부 이벤트 발생 로직
  // ===================================================================

  void _fire(BinanceEventType type, Json data) {
    try {
      final enrichedData = <String, dynamic>{
        ...data,
        'eventType': type.value,
        'platform': 'binance_futures',
      };

      final event = AppEvent.now(enrichedData);
      final symbol = _extractSymbol(data);

      // 글로벌 브로드캐스트
      if (!_globalController.isClosed) {
        _globalController.add(event);
      }

      // 타입별 브로드캐스트
      final typeCtrl = _typeControllers[type];
      if (typeCtrl != null && !typeCtrl.isClosed) {
        typeCtrl.add(event);
      }

      // 심볼별 브로드캐스트
      if (symbol != null) {
        final symbolCtrl = _symbolControllers[symbol];
        if (symbolCtrl != null && !symbolCtrl.isClosed) {
          symbolCtrl.add(event);
        }
      }

      _messageCount++;
      
    } catch (e, stackTrace) {
      _fireError(AppException.business(
        'Failed to fire event: $e\nStack: ${stackTrace.toString()}'
      ));
    }
  }

  void _fireError(AppException error) {
    if (!_errorController.isClosed) {
      _errorController.add(error);
    }
  }

  String? _extractSymbol(Json data) {
    return data['symbol'] as String? ?? 
           data['s'] as String? ?? 
           data['ps'] as String?;
  }

  bool _shouldDropMessage() {
    final now = DateTime.now();
    if (now.difference(_lastResetTime).inSeconds >= 1) {
      _lastResetTime = now;
      _messageCount = 0;
    }

    return _messageCount > _maxMessagesPerSecond;
  }

  // ===================================================================
  // 상태 관리 및 정리
  // ===================================================================

  int get messageCountPerSecond => _messageCount;
  
  int getListenerCount(BinanceEventType type) {
    return _typeControllers[type]?.hasListener == true ? 1 : 0;
  }

  List<BinanceEventType> getActiveStreams() {
    return _typeControllers.keys
        .where((type) => _typeControllers[type]?.hasListener == true)
        .toList();
  }

  void dispose() {
    // 타입별 컨트롤러 정리
    for (final controller in _typeControllers.values) {
      if (!controller.isClosed) controller.close();
    }
    _typeControllers.clear();

    // 심볼별 컨트롤러 정리
    for (final controller in _symbolControllers.values) {
      if (!controller.isClosed) controller.close();
    }
    _symbolControllers.clear();

    // 글로벌 컨트롤러 정리
    if (!_globalController.isClosed) _globalController.close();
    if (!_errorController.isClosed) _errorController.close();

    _messageCount = 0;
  }
}