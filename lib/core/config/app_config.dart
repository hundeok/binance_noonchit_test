import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/logger.dart';

/// 바이낸스 선물(USDⓈ-M) 전용 애플리케이션 설정 (풀-세팅 버전)
class AppConfig {
  AppConfig._(); // 인스턴스화 방지

  // ===================================================================
  // 1. 환경 변수 및 토글
  // ===================================================================

  /// ✅ 테스트넷 사용 여부. `dart --define=BINANCE_TESTNET=true`로 컴파일 시 true.
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

  // ✅ 환경에 따라 URL을 동적으로 반환
  static String get restBaseUrl =>
      useTestnet ? _testnetRestUrl : _mainnetRestUrl;
  
  static String get streamUrl =>
      useTestnet ? _testnetStreamUrl : _mainnetStreamUrl;
      
  // Private 상수
  static const String _mainnetRestUrl = 'https://fapi.binance.com';
  static const String _testnetRestUrl = 'https://testnet.binancefuture.com';
  static const String _mainnetStreamUrl = 'wss://fstream.binance.com/stream';
  static const String _testnetStreamUrl = 'wss://stream.binancefuture.com/stream';


  // ===================================================================
  // 3. WebSocket 규칙 및 제한 (체크리스트 기반)
  // ===================================================================

  /// ✅ 서버 Ping에 대한 Pong 응답 타임아웃 (공식: 1분, 안전 버퍼 포함)
  static const Duration wsPongTimeout = Duration(seconds: 70);
  
  /// ✅ 클라이언트가 먼저 보내는 Unsolicited Pong 주기 (서버 생존 확인용)
  static const Duration wsUnsolicitedPongInterval = Duration(seconds: 30);

  /// ✅ 24시간 세션 만료에 대비한 자동 재연결 주기
  static const Duration wsSessionRefresh = Duration(hours: 23, minutes: 55);

  /// ✅ 단일 연결 최대 스트림 구독 개수
  static const int wsMaxStreams = 1024;
  
  /// ✅ 초당 최대 수신 메시지 개수 (데이터, Ping, Pong 등 모두 포함)
  static const int wsMaxInMsgPerSec = 10;
  
  /// ✅ 제어 메시지(SUB/UNSUB 등) 전송 간 최소 간격 (초당 5회 제한)
  static const Duration wsControlMsgInterval = Duration(milliseconds: 200);

}