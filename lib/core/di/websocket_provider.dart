// ===================================================================
// lib/core/providers/websocket_provider.dart
// 바이낸스 WebSocket 백서 100% 준수 + Provider 패턴 최적화
// ===================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/websocket/base_ws_client.dart';
import '../network/websocket/trade_ws_client.dart';
import '../utils/logger.dart';
import 'core_provider.dart';

// ===================================================================
// 📊 WebSocket 상태 관리 (확장된 상태 정보)
// ===================================================================

@immutable
class WebSocketState {
  final WsStatus status;
  final List<String> subscribedSymbols;
  final DateTime? lastConnectedAt;
  
  // 🎯 [추가] 바이낸스 백서 기반 확장 정보
  final DateTime? sessionStartTime;
  final int reconnectionAttempts;
  final Duration? sessionDuration;
  final bool isHealthy;
  final Map<String, dynamic> diagnostics;

  const WebSocketState({
    this.status = WsStatus.disconnected,
    this.subscribedSymbols = const [],
    this.lastConnectedAt,
    this.sessionStartTime,
    this.reconnectionAttempts = 0,
    this.sessionDuration,
    this.isHealthy = false,
    this.diagnostics = const {},
  });

  WebSocketState copyWith({
    WsStatus? status,
    List<String>? subscribedSymbols,
    DateTime? lastConnectedAt,
    DateTime? sessionStartTime,
    int? reconnectionAttempts,
    Duration? sessionDuration,
    bool? isHealthy,
    Map<String, dynamic>? diagnostics,
  }) {
    return WebSocketState(
      status: status ?? this.status,
      subscribedSymbols: subscribedSymbols ?? this.subscribedSymbols,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      sessionStartTime: sessionStartTime ?? this.sessionStartTime,
      reconnectionAttempts: reconnectionAttempts ?? this.reconnectionAttempts,
      sessionDuration: sessionDuration ?? this.sessionDuration,
      isHealthy: isHealthy ?? this.isHealthy,
      diagnostics: diagnostics ?? this.diagnostics,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WebSocketState &&
        other.status == status &&
        listEquals(other.subscribedSymbols, subscribedSymbols) &&
        other.lastConnectedAt == lastConnectedAt &&
        other.sessionStartTime == sessionStartTime &&
        other.reconnectionAttempts == reconnectionAttempts &&
        other.isHealthy == isHealthy;
  }

  @override
  int get hashCode => 
      status.hashCode ^ 
      subscribedSymbols.hashCode ^ 
      lastConnectedAt.hashCode ^
      sessionStartTime.hashCode ^
      reconnectionAttempts.hashCode ^
      isHealthy.hashCode;
}

// ===================================================================
// 🎯 WebSocket 클라이언트 Provider (메모리 관리 강화)
// ===================================================================

final wsClientProvider = Provider.autoDispose<TradeWsClient>((ref) {
  log.d('[wsClientProvider] Creating TradeWsClient instance...');
  
  final client = TradeWsClient();
  
  // 🎯 [개선] 상태 변경 콜백에서 Manager와 연동
  client.onStatusChange = (WsStatus newStatus) {
    // Manager가 있다면 상태 업데이트
    try {
      final manager = ref.read(webSocketManagerProvider.notifier);
      manager._handleClientStatusChange(newStatus);
    } catch (e) {
      // Manager가 아직 초기화되지 않았을 수 있음
      log.d('[wsClientProvider] Manager not ready yet: $e');
    }
  };

  // 🧹 [개선] dispose 시 완전한 정리
  ref.onDispose(() async {
    log.i('[wsClientProvider] Disposing WebSocket client...');
    try {
      await client.dispose();
      log.d('[wsClientProvider] ✅ Client disposed successfully');
    } catch (e, st) {
      log.e('[wsClientProvider] Error during client disposal', e, st);
    }
  });

  return client;
});

// ===================================================================
// 🎯 WebSocket Manager Provider (바이낸스 백서 준수 강화)
// ===================================================================

final webSocketManagerProvider =
    StateNotifierProvider.autoDispose<WebSocketManager, WebSocketState>(
  (ref) => WebSocketManager(ref),
);

class WebSocketManager extends StateNotifier<WebSocketState> {
  final Ref _ref;
  
  // 🎯 [추가] 타이머들 - 바이낸스 백서 준수
  Timer? _healthCheckTimer;
  Timer? _sessionMonitorTimer;
  Timer? _diagnosticsTimer;
  
  // 🎯 [추가] 세션 관리
  DateTime? _connectionStartTime;
  bool _isDisposed = false;

  WebSocketManager(this._ref) : super(const WebSocketState()) {
    log.d('[WebSocketManager] Initializing manager...');
    _startMonitoring();
  }

  // ===================================================================
  // 🚀 연결 관리 (개선된 로직)
  // ===================================================================

  /// 🎯 [개선] 안전한 연결 로직 - markets 대기 및 상태 검증
  Future<void> connect() async {
    if (_isDisposed) {
      log.w('[WebSocketManager] Cannot connect - manager disposed');
      return;
    }

    if (state.status == WsStatus.connecting || state.status == WsStatus.connected) {
      log.w('[WebSocketManager] Already connected or connecting (${state.status})');
      return;
    }

    log.i('[WebSocketManager] 🚀 Starting connection process...');
    
    try {
      // 🎯 [개선] 연결 상태 즉시 업데이트
      _updateConnectionState(WsStatus.connecting, DateTime.now());

      // 🎯 [핵심] Markets 데이터 대기 - Provider에서 가져오기
      final markets = await _ref.read(marketsProvider.future);
      
      // Empty 체크
      if (markets.isEmpty) {
        throw Exception('Cannot connect without markets - received empty list');
      }
      log.i('[WebSocketManager] 📊 Markets loaded: ${markets.length} symbols');

      // 🎯 [개선] 클라이언트 연결 요청
      final client = _ref.read(wsClientProvider);
      client.connect(markets);

      // 🎯 [개선] 구독 심볼 목록 업데이트
      state = state.copyWith(
        subscribedSymbols: markets,
        sessionStartTime: DateTime.now(),
      );

      log.i('[WebSocketManager] ✅ Connection command issued with ${markets.length} markets');
      
    } catch (e, st) {
      log.e('[WebSocketManager] 💥 Connection failed', e, st);
      
      // 🎯 [개선] 실패 시 재시도 카운트 증가
      state = state.copyWith(
        status: WsStatus.disconnected,
        reconnectionAttempts: state.reconnectionAttempts + 1,
        isHealthy: false,
      );
      
      // 🎯 [추가] 실패 시 자동 재시도 (조건부)
      if (state.reconnectionAttempts < 3) {
        log.i('[WebSocketManager] 🔄 Scheduling retry in ${state.reconnectionAttempts * 2} seconds...');
        Timer(Duration(seconds: state.reconnectionAttempts * 2), () {
          if (!_isDisposed) {
            connect();
          }
        });
      }
    }
  }

  /// 🎯 [개선] 안전한 연결 해제
  Future<void> disconnect() async {
    log.i('[WebSocketManager] 🔌 Disconnect command issued');
    
    try {
      final client = _ref.read(wsClientProvider);
      await client.dispose();
      
      // 🎯 [개선] 상태 완전 초기화
      state = const WebSocketState();
      log.i('[WebSocketManager] ✅ Disconnected successfully');
      
    } catch (e, st) {
      log.e('[WebSocketManager] Error during disconnect', e, st);
      // 에러가 있어도 상태는 초기화
      state = const WebSocketState();
    }
  }

  /// 🎯 [개선] 강제 재연결 (세션 갱신용)
  Future<void> reconnect({String reason = 'Manual reconnect'}) async {
    log.i('[WebSocketManager] 🔄 Reconnecting: $reason');
    
    await disconnect();
    
    // 짧은 대기 후 재연결
    await Future.delayed(const Duration(seconds: 2));
    
    if (!_isDisposed) {
      await connect();
    }
  }

  // ===================================================================
  // 🔍 상태 관리 및 모니터링 (바이낸스 백서 기반)
  // ===================================================================

  /// 🎯 [추가] 클라이언트 상태 변경 핸들러
  void _handleClientStatusChange(WsStatus newStatus) {
    if (state.status == newStatus) return;

    log.i('[WebSocketManager] 📊 Status change: ${state.status} → $newStatus');

    final now = DateTime.now();
    
    // 🎯 [핵심] 상태별 처리
    switch (newStatus) {
      case WsStatus.connected:
        _connectionStartTime = now;
        state = state.copyWith(
          status: newStatus,
          lastConnectedAt: now,
          sessionStartTime: _connectionStartTime,
          reconnectionAttempts: 0, // 성공 시 재시도 카운트 리셋
          isHealthy: true,
        );
        break;

      case WsStatus.disconnected:
      case WsStatus.pongTimeout:
      case WsStatus.serverError:
        state = state.copyWith(
          status: newStatus,
          isHealthy: false,
        );
        
        // 🎯 [추가] 특정 에러 상황에서 자동 재연결
        if (newStatus == WsStatus.pongTimeout || newStatus == WsStatus.serverError) {
          log.w('[WebSocketManager] ⚠️ Auto-reconnecting due to: $newStatus');
          Timer(const Duration(seconds: 5), () {
            if (!_isDisposed && state.status != WsStatus.connected) {
              connect();
            }
          });
        }
        break;

      case WsStatus.reconnecting:
        state = state.copyWith(
          status: newStatus,
          reconnectionAttempts: state.reconnectionAttempts + 1,
          isHealthy: false,
        );
        break;

      default:
        state = state.copyWith(status: newStatus);
    }
  }

  /// 🎯 [추가] 연결 상태 업데이트 헬퍼
  void _updateConnectionState(WsStatus status, DateTime timestamp) {
    state = state.copyWith(
      status: status,
      lastConnectedAt: status == WsStatus.connected ? timestamp : state.lastConnectedAt,
    );
  }

  /// 🎯 [추가] 모니터링 시작 - 바이낸스 백서 권장사항 준수
  void _startMonitoring() {
    // 🔍 헬스 체크 (30초마다)
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performHealthCheck();
    });

    // 📊 세션 모니터링 (5분마다)
    _sessionMonitorTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _checkSessionHealth();
    });

    // 📈 진단 정보 업데이트 (10초마다)
    _diagnosticsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateDiagnostics();
    });

    log.d('[WebSocketManager] 🔍 Monitoring started');
  }

  /// 🎯 [추가] 헬스 체크 - 바이낸스 백서 기반
  void _performHealthCheck() {
    if (_isDisposed) return;

    try {
      final client = _ref.read(wsClientProvider);
      final isClientHealthy = client.isHealthy;
      
      // 🎯 바이낸스 백서: 24시간 세션 제한 체크
      final sessionDuration = _connectionStartTime != null 
          ? DateTime.now().difference(_connectionStartTime!)
          : null;
      
      final isSessionValid = sessionDuration == null || 
          sessionDuration.inHours < 23; // 24시간 전에 미리 갱신

      final overallHealth = isClientHealthy && isSessionValid && 
          (state.status == WsStatus.connected);

      // 🎯 [개선] 세션 만료 임박 시 자동 갱신
      if (sessionDuration != null && sessionDuration.inHours >= 23) {
        log.w('[WebSocketManager] 🕐 Session approaching 24h limit - scheduling refresh');
        Timer(const Duration(minutes: 5), () {
          if (!_isDisposed) {
            reconnect(reason: '24h session refresh');
          }
        });
      }

      state = state.copyWith(
        isHealthy: overallHealth,
        sessionDuration: sessionDuration,
      );

      if (!overallHealth && state.status == WsStatus.connected) {
        log.w('[WebSocketManager] ⚠️ Health check failed - client may need reconnection');
      }

    } catch (e, st) {
      log.e('[WebSocketManager] Health check error', e, st);
      state = state.copyWith(isHealthy: false);
    }
  }

  /// 🎯 [추가] 세션 건강성 체크
  void _checkSessionHealth() {
    if (_isDisposed || state.status != WsStatus.connected) return;

    try {
      final client = _ref.read(wsClientProvider);
      final debugInfo = client.getDebugInfo();
      
      // 🎯 바이낸스 백서: Rate limit 체크
      final incomingRate = debugInfo['incomingMsgRate'] as int? ?? 0;
      final outgoingRate = debugInfo['outgoingMsgRate'] as int? ?? 0;
      
      if (incomingRate > 4 || outgoingRate > 4) { // 5개 제한의 80% 임계값
        log.w('[WebSocketManager] ⚠️ High message rate detected: in=$incomingRate, out=$outgoingRate');
      }

      // 🎯 메모리 사용량 체크
      final memoryFootprint = debugInfo['memoryFootprint'] as int? ?? 0;
      if (memoryFootprint > 1000) { // 임계값
        log.w('[WebSocketManager] ⚠️ High memory footprint: $memoryFootprint');
      }

    } catch (e, st) {
      log.e('[WebSocketManager] Session health check error', e, st);
    }
  }

  /// 🎯 [추가] 진단 정보 업데이트
  void _updateDiagnostics() {
    if (_isDisposed) return;

    try {
      final client = _ref.read(wsClientProvider);
      final diagnostics = client.getDebugInfo();
      
      state = state.copyWith(diagnostics: diagnostics);
      
    } catch (e) {
      // 진단 정보 업데이트 실패는 치명적이지 않음
      log.d('[WebSocketManager] Diagnostics update failed: $e');
    }
  }

  // ===================================================================
  // 🧹 정리 및 해제
  // ===================================================================

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;

    log.i('[WebSocketManager] 🧹 Disposing manager...');

    // 타이머 정리
    _healthCheckTimer?.cancel();
    _sessionMonitorTimer?.cancel();
    _diagnosticsTimer?.cancel();

    // 최종 상태 로그
    if (state.sessionDuration != null) {
      log.i('[WebSocketManager] 📊 Final session stats: '
            'Duration: ${state.sessionDuration!.inMinutes}min, '
            'Reconnects: ${state.reconnectionAttempts}, '
            'Symbols: ${state.subscribedSymbols.length}');
    }

    super.dispose();
    log.d('[WebSocketManager] ✅ Manager disposed');
  }
}

// ===================================================================
// 🎯 WebSocket 상태 모니터링 Providers
// ===================================================================

/// WebSocket 연결 상태 간단 조회
final webSocketStatusProvider = Provider.autoDispose<WsStatus>((ref) {
  return ref.watch(webSocketManagerProvider.select((state) => state.status));
});

/// WebSocket 건강성 상태
final webSocketHealthProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(webSocketManagerProvider.select((state) => state.isHealthy));
});

/// WebSocket 세션 정보
final webSocketSessionProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final state = ref.watch(webSocketManagerProvider);
  return {
    'sessionDuration': state.sessionDuration?.inMinutes ?? 0,
    'reconnectionAttempts': state.reconnectionAttempts,
    'subscribedSymbolsCount': state.subscribedSymbols.length,
    'lastConnectedAt': state.lastConnectedAt?.toIso8601String(),
    'sessionStartTime': state.sessionStartTime?.toIso8601String(),
    'isHealthy': state.isHealthy,
  };
});

/// WebSocket 진단 정보 (실시간)
final webSocketDiagnosticsProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  final state = ref.watch(webSocketManagerProvider);
  return {
    'status': state.status.toString(),
    'diagnostics': state.diagnostics,
    'timestamp': DateTime.now().toIso8601String(),
  };
});

// ===================================================================
// 🎛️ WebSocket 제어 컨트롤러
// ===================================================================

final webSocketControllerProvider = Provider.autoDispose((ref) => WebSocketController(ref));

class WebSocketController {
  final Ref _ref;
  WebSocketController(this._ref);

  /// 연결 시작
  Future<void> connect() async {
    final manager = _ref.read(webSocketManagerProvider.notifier);
    await manager.connect();
  }

  /// 연결 해제
  Future<void> disconnect() async {
    final manager = _ref.read(webSocketManagerProvider.notifier);
    await manager.disconnect();
  }

  /// 강제 재연결
  Future<void> reconnect({String reason = 'Manual reconnect'}) async {
    final manager = _ref.read(webSocketManagerProvider.notifier);
    await manager.reconnect(reason: reason);
  }

  /// 현재 상태 가져오기
  WebSocketState get currentState => _ref.read(webSocketManagerProvider);

  /// 연결되어 있는지 확인
  bool get isConnected => _ref.read(webSocketStatusProvider) == WsStatus.connected;

  /// 건강한 상태인지 확인
  bool get isHealthy => _ref.read(webSocketHealthProvider);
}