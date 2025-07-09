// lib/core/config/app_config.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';
import '../utils/logger.dart';

/// 🔄 Binance Futures 전용으로 재구성된 애플리케이션 설정
class AppConfig {
  AppConfig._();

  static Future<void> init({String? envPath}) async {
    try {
      await dotenv.load(fileName: envPath ?? '.env');
      _loadEnv();
    } catch (e) {
      log.w('[AppConfig] .env file not found, using defaults.');
    }
    log.i('[AppConfig] Initialized for Binance Futures.');
  }

  static void _loadEnv() {
    // 🔄 바이낸스 API 키 로드
    _apiKey = dotenv.env['BINANCE_API_KEY'] ?? '';
    _apiSecret = dotenv.env['BINANCE_API_SECRET'] ?? '';
  }

  // ─────────────────── API Credentials ───────────────────
  static String _apiKey = '';
  static String _apiSecret = '';
  static String get apiKey => _apiKey;
  static String get apiSecret => _apiSecret;

  // ──────────────── Environment & Logging ────────────────
  static const bool isDebugMode = !bool.fromEnvironment('dart.vm.product');
  static Level get logLevel => isDebugMode ? Level.debug : Level.warning;
  static bool get enableWebSocketLog => true;
  static bool get enableTradeLog => true;

  // ──────────────── 🔄 Binance Futures REST API ────────────────
  static const String restBaseUrl = 'https://fapi.binance.com';
  // 💡 바이낸스는 IP당 분당 2400의 가중치를 가짐. 대부분의 조회는 가중치 1~5 소모.
  //    자세한 Rate-Limit 로직은 ApiClient의 인터셉터에서 관리.
  static const Duration restTimeout = Duration(seconds: 10);

  // ──────────────── 🔄 Binance Futures WebSocket API ────────────────
  static const String streamUrl = 'wss://fstream.binance.com/stream';
  static const int wsMaxSubscriptions = 1024;
  // 💡 바이낸스는 서버가 3분마다 Ping을 보내므로 클라이언트 Ping은 불필요.
  //    10분 내 Pong 응답이 없으면 연결 종료.
  static const Duration wsPongTimeout = Duration(minutes: 10);
  static const int wsMaxRetries = 10;
  static const Duration wsInitialBackoff = Duration(seconds: 2);
  static const Duration wsMaxBackoff = Duration(seconds: 30);

  // ──────────────── 🔄 Trade Filters (단위: USDT) ────────────────
  //    거래 필터 단위를 원화(KRW)에서 USDT로 변경
  static final List<double> tradeFilters = [
    10000,   // 1만 USDT
    20000,   // 2만 USDT
    50000,   // 5만 USDT
    100000,  // 10만 USDT
    200000,  // 20만 USDT
    500000,  // 50만 USDT
  ];

  static String formatFilterLabel(double f) {
    if (f >= 10000) return '${(f / 10000).toInt()}만\$';
    return '${(f / 1000).toInt()}천\$';
  }
}