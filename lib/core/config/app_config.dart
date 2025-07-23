import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

/// 바이낸스 선물(USDⓈ-M) 전용 애플리케이션 설정
/// 🎯 바이낸스 공식 WebSocket 백서 (2025-01-28) 100% 준수 + 앱 안정성 고려
class AppConfig {
  AppConfig._(); // 인스턴스화 방지

  // ===================================================================
  // 1. 환경 변수 및 토글
  // ===================================================================
  
  /// 테스트넷 사용 여부. `dart --define=BINANCE_TESTNET=true`로 컴파일 시 true.
  static const bool useTestnet = bool.fromEnvironment('BINANCE_TESTNET');
  
  static String apiKey = '';
  static String apiSecret = '';
  
  static Future<void> initialize() async {
    try {
      await dotenv.load();
      apiKey = dotenv.env['BINANCE_API_KEY'] ?? '';
      apiSecret = dotenv.env['BINANCE_API_SECRET'] ?? '';
      log.i('[AppConfig] Initialized. Testnet mode: $useTestnet');
    } catch (e) {
      log.w('[AppConfig] .env not found. Using empty credentials.');
    }
  }

  // ===================================================================
  // 2. 네트워크 엔드포인트 (테스트넷/메인넷 자동 전환)
  // ===================================================================
  
  static String get restBaseUrl =>
      useTestnet ? _testnetRestUrl : _mainnetRestUrl;
  static String get streamUrl =>
      useTestnet ? _testnetStreamUrl : _mainnetStreamUrl;

  // 바이낸스 공식 엔드포인트
  static const String _mainnetRestUrl = 'https://fapi.binance.com';
  static const String _testnetRestUrl = 'https://testnet.binancefuture.com';
  static const String _mainnetStreamUrl = 'wss://fstream.binance.com/stream';
  static const String _testnetStreamUrl = 'wss://stream.binancefuture.com/stream';

  // 추가 WebSocket 엔드포인트 옵션
  static const String mainStreamBase = 'wss://stream.binance.com:9443';
  static const String mainStreamAlt = 'wss://stream.binance.com:443';
  static const String dataOnlyStream = 'wss://data-stream.binance.vision';

  // ===================================================================
  // 3. REST API 설정
  // ===================================================================
  
  static const Duration restTimeout = Duration(seconds: 30);

  // ===================================================================
  // 4. 🎯 바이낸스 공식 WebSocket 제한사항 (백서 기준)
  // ===================================================================
  
  /// 🚨 핵심: 클라이언트→서버 메시지 제한 (PING, PONG, JSON 컨트롤)
  /// "WebSocket connections have a limit of 5 incoming messages per second"
  static const int wsMaxOutgoingMsgPerSec = 5;
  
  /// 단일 연결당 최대 스트림 구독 개수
  /// "A single connection can listen to a maximum of 1024 streams"
  static const int wsMaxStreams = 1024;
  
  /// IP당 연결 제한
  /// "There is a limit of 300 connections per attempt every 5 minutes per IP"
  static const int wsMaxConnectionsPer5Min = 300;
  
  /// 24시간 세션 제한
  /// "A single connection to stream.binance.com is only valid for 24 hours"
  static const Duration wsMaxSessionDuration = Duration(hours: 24);

  // ===================================================================
  // 5. 🎯 Ping/Pong 정책 (백서 기준)
  // ===================================================================
  
  /// 서버 Ping 간격
  /// "The WebSocket server will send a ping frame every 20 seconds"
  static const Duration wsServerPingInterval = Duration(seconds: 20);
  
  /// Pong 응답 타임아웃
  /// "If the WebSocket server does not receive a pong frame back from the connection within a minute"
  static const Duration wsPongTimeout = Duration(seconds: 60);
  
  /// Unsolicited Pong 간격 (바이낸스 백서에서는 권장하지 않음)
  /// "Unsolicited pong frames are allowed but will not prevent disconnection"
  static const Duration wsUnsolicitedPongInterval = Duration(seconds: 30);

  // ===================================================================
  // 6. 🛡️ 안전 설정 (백서 기준 + 앱 안정성 고려)
  // ===================================================================
  
  /// 실제 구독할 심볼 수 (1024보다 적게 - 안전 버퍼)
  static const int wsMaxSubscriptions = 200;
  
  /// 24시간 전 미리 재연결 (세션 만료 방지)
  static const Duration wsSessionRefresh = Duration(hours: 23);
  
  /// ✅ [수정] 서버→클라이언트 메시지 제한 (앱 안정성 우선)
  /// 바이낸스는 무제한이지만, 앱이 감당할 수 있는 수준으로 설정
  static const int wsMaxInMsgPerSec = 500;  // 2000 → 500 (4배 감소)
  
  /// ✅ [추가] 심각한 상황에서의 강제 제한
  static const int wsEmergencyMsgLimit = 1000;  // 초당 1000개 넘으면 연결 끊기
  
  /// ✅ [추가] 메시지 폭주 감지 임계값
  static const int wsMsgFloodThreshold = 800;   // 800개 넘으면 경고 레벨 상승
  
  /// 컨트롤 메시지 전송 간격 (5개/초 제한 준수)
  static const Duration wsControlMsgInterval = Duration(milliseconds: 220); // 200ms + 버퍼
  
  /// 재연결 시도 제한 (IP Ban 방지)
  static const int wsMaxReconnectAttempts = 10;
  static const Duration wsReconnectCooldown = Duration(minutes: 5);

  // ===================================================================
  // 7. ✅ [추가] 스트림별 메시지 빈도 제한 (앱 안정성)
  // ===================================================================
  
  /// 스트림 타입별 예상 메시지 빈도 (초당)
  static const Map<String, int> streamMessageRates = {
    'ticker': 1,        // 24hr 통계, 1초마다
    'miniTicker': 1,    // 24hr mini 통계, 1초마다
    'bookTicker': 10,   // 최고 호가, 실시간 (빠름)
    'aggTrade': 50,     // 집계 거래, 거래량에 따라
    'trade': 100,       // 개별 거래, 매우 빠름
    'depth5': 10,       // 5단계 호가, 1초마다
    'depth10': 10,      // 10단계 호가, 1초마다
    'depth20': 10,      // 20단계 호가, 1초마다
    'depth': 100,       // 전체 호가, 매우 빠름 (위험)
    'depth@100ms': 500, // 100ms 호가, 극도로 빠름 (매우 위험)
    'kline_1s': 1,      // 1초 캔들
    'kline_1m': 1,      // 1분 캔들
    'kline_others': 1,  // 기타 캔들
  };
  
  /// ✅ [추가] 위험한 스트림 타입들 (높은 메시지 빈도)
  static const Set<String> highVolumeStreams = {
    'depth',
    'depth@100ms',
    'trade',
    'aggTrade',
  };
  
  /// ✅ [추가] 안전한 스트림 타입들 (낮은 메시지 빈도)
  static const Set<String> safeStreams = {
    'ticker',
    'miniTicker',
    'kline_1m',
    'kline_5m',
    'kline_15m',
    'kline_1h',
  };

  // ===================================================================
  // 8. 📊 스트림별 업데이트 속도 (백서 기준)
  // ===================================================================
  
  static const Map<String, String> streamUpdateSpeeds = {
    'aggTrade': 'Real-time',
    'trade': 'Real-time',
    'bookTicker': 'Real-time',
    'miniTicker': '1000ms',
    'ticker': '1000ms',
    'depth': '1000ms',
    'depth@100ms': '100ms',
    'kline_1s': '1000ms',
    'kline_others': '2000ms',
  };

  // ===================================================================
  // 9. 🎛️ 지원되는 WebSocket 컨트롤 메서드
  // ===================================================================
  
  static const List<String> wsSupportedMethods = [
    'SUBSCRIBE',
    'UNSUBSCRIBE',
    'LIST_SUBSCRIPTIONS',
    'SET_PROPERTY',
    'GET_PROPERTY',
  ];

  // ===================================================================
  // 10. ⚠️ 바이낸스 WebSocket 에러 코드
  // ===================================================================
  
  static const Map<int, String> wsErrorCodes = {
    0: 'Unknown property',
    1: 'Invalid value type: expected Boolean',
    2: 'Invalid request format',
    3: 'Invalid JSON syntax',
  };

  // ===================================================================
  // 11. ✅ [추가] 앱 안정성을 위한 자동 제어 설정
  // ===================================================================
  
  /// 메시지 과부하 시 자동 대응 활성화
  static const bool enableAutoMessageControl = true;
  
  /// 위험한 스트림 자동 차단
  static const bool blockHighVolumeStreams = false;  // 개발 단계에서는 false
  
  /// 메시지 속도별 로그 레벨
  static const Map<int, String> messageRateLogLevels = {
    100: 'debug',   // 100/sec 이하: 디버그
    300: 'info',    // 300/sec 이하: 정보
    500: 'warn',    // 500/sec 이하: 경고
    800: 'error',   // 800/sec 이하: 에러
    1000: 'fatal',  // 1000/sec 초과: 치명적
  };
  
  /// ✅ [추가] 로깅 최적화 (스팸 방지)
  static const Duration logThrottleInterval = Duration(seconds: 5);  // 5초마다 한 번만 로그
  static const int logBurstLimit = 3;  // 연속 3개까지만 허용

  // ===================================================================
  // 12. 🔧 고급 설정
  // ===================================================================
  
  /// 마이크로초 타임스탬프 사용 여부
  static const bool useMicrosecondTimestamps = false;
  
  /// Combined 스트림 사용 (우리가 사용하는 방식)
  static const bool useCombinedStreams = true;
  
  /// WebSocket 연결 안정성을 위한 Keep-Alive
  static const Duration wsKeepAliveInterval = Duration(seconds: 45);
  
  /// ✅ [추가] 메모리 정리 주기
  static const Duration memoryCleanupInterval = Duration(seconds: 30);
  
  /// ✅ [추가] 성능 모니터링 간격
  static const Duration performanceMonitorInterval = Duration(seconds: 10);

  // ===================================================================
  // 13. ✅ [추가] 유틸리티 메서드들
  // ===================================================================
  
  /// 스트림이 고용량인지 확인
  static bool isHighVolumeStream(String streamName) {
    return highVolumeStreams.any((pattern) => streamName.contains(pattern));
  }
  
  /// 스트림이 안전한지 확인
  static bool isSafeStream(String streamName) {
    return safeStreams.any((pattern) => streamName.contains(pattern));
  }
  
  /// 메시지 속도에 따른 로그 레벨 결정
  static String getLogLevelForMessageRate(int messagesPerSec) {
    for (final entry in messageRateLogLevels.entries) {
      if (messagesPerSec <= entry.key) {
        return entry.value;
      }
    }
    return 'fatal';
  }
  
  /// 예상 메시지 속도 계산
  static int estimateMessageRate(List<String> streamNames) {
    int totalRate = 0;
    for (final streamName in streamNames) {
      for (final entry in streamMessageRates.entries) {
        if (streamName.contains(entry.key)) {
          totalRate += entry.value;
          break;
        }
      }
    }
    return totalRate;
  }
  
  /// ✅ [추가] 구독 안전성 검사
  static bool isSafeToSubscribe(List<String> streamNames) {
    final estimatedRate = estimateMessageRate(streamNames);
    final hasHighVolumeStreams = streamNames.any(isHighVolumeStream);
    
    return estimatedRate <= wsMaxInMsgPerSec && 
           (!blockHighVolumeStreams || !hasHighVolumeStreams);
  }
}