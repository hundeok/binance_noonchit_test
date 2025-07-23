import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../utils/logger.dart';

/// 🎯 바이낸스 IP Ban 방지 + 업비트 Adaptive 로직 결합 백오프
/// 백서 제한: "300 connections per attempt every 5 minutes per IP"
class ExponentialBackoff {
  final Duration initialDelay;
  final Duration maxDelay;
  final double randomizationFactor;
  final int maxRetries;
  
  // ✅ [추가] 업비트 스타일 adaptive 기능
  final Connectivity _connectivity = Connectivity();

  int _retryCount = 0;
  Timer? _retryTimer;
  DateTime? _firstAttemptTime;
  DateTime? _lastFailureTime; // ✅ [추가] 마지막 실패 시간
  Duration? _currentDelay; // ✅ [추가] 현재 적용 중인 delay 추적

  // ✅ [추가] 네트워크별 지연 승수 (바이낸스 정책에 맞게 조정)
  static const Map<ConnectivityResult, double> _networkMultipliers = {
    ConnectivityResult.wifi: 0.9, // WiFi는 빠른 재연결 (바이낸스는 보수적)
    ConnectivityResult.mobile: 1.3, // 모바일은 더 보수적
    ConnectivityResult.ethernet: 0.8, // 유선은 가장 빠름
    ConnectivityResult.none: 2.5, // 연결 없음은 매우 보수적 (바이낸스 IP ban 고려)
  };

  ExponentialBackoff({
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.randomizationFactor = 0.3,
    this.maxRetries = 10,
  });

  /// 🎯 현재 적용 중인 delay (추가된 프로퍼티)
  Duration? get currentDelay => _currentDelay;

  /// 🎯 다음 재시도까지의 대기 시간 계산 (adaptive 로직 적용)
  Future<Duration> get nextDelay async {
    if (_retryCount == 0) return Duration.zero;

    // 기본 지수 백오프
    final baseDelay = initialDelay * math.pow(2, _retryCount - 1);

    // 🎯 바이낸스 특화: 5분 경계에서 더 긴 대기
    Duration adjustedDelay = baseDelay;
    if (_retryCount >= 5) {
      adjustedDelay = Duration(minutes: 1 + _retryCount);
    }

    // ✅ [추가] 네트워크 상태 고려 (업비트 방식)
    final connectivityResult = await _connectivity.checkConnectivity();
    final networkMultiplier = _networkMultipliers[connectivityResult] ?? 1.0;

    // ✅ [추가] 시간 기반 페널티 계산
    final failurePenalty = _calculateFailurePenalty();

    // 랜덤 지터 적용
    final random = math.Random();
    final baseMs = adjustedDelay.inMilliseconds.toDouble();
    final jitterRange = baseMs * randomizationFactor;
    final jitter = (random.nextDouble() * 2 - 1) * jitterRange;
    
    // ✅ [개선] 모든 factor 적용
    final adaptiveMs = baseMs * networkMultiplier * failurePenalty + jitter;
    final finalMs = adaptiveMs.clamp(
      initialDelay.inMilliseconds.toDouble(), 
      maxDelay.inMilliseconds.toDouble()
    );

    final finalDuration = Duration(milliseconds: finalMs.round());
    
    log.d('[Backoff] 🧮 Adaptive calculation: '
        'base=${baseMs.round()}ms, network=$connectivityResult×${networkMultiplier.toStringAsFixed(1)}, '
        'penalty×${failurePenalty.toStringAsFixed(1)}, final=${finalMs.round()}ms');

    return finalDuration;
  }

  /// ✅ [추가] 업비트 스타일 실패 페널티 계산
  double _calculateFailurePenalty() {
    if (_lastFailureTime == null) return 1.0;

    final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
    
    // 5분 이상 지나면 페널티 리셋 (바이낸스 5분 정책과 맞춤)
    if (timeSinceLastFailure > const Duration(minutes: 5)) {
      return 1.0;
    }

    // 바이낸스는 IP ban이 더 위험하므로 페널티 더 크게 (1.8배까지)
    return math.min(1.8, 1.0 + (_retryCount * 0.15));
  }

  /// 🎯 바이낸스 IP 제한 고려한 재시도 시도 (adaptive 적용)
  void attempt(Future<void> Function() action) async {
    _retryTimer?.cancel();

    if (_retryCount >= maxRetries) {
      log.e('[Backoff] 🚨 Max retry limit reached ($maxRetries). Stopping to prevent IP ban.');
      _resetForCooldown();
      return;
    }

    if (_shouldCooldown()) {
      log.w('[Backoff] 🕐 5-minute cooldown activated for IP safety');
      _resetForCooldown();
      return;
    }

    _retryCount++;
    _firstAttemptTime ??= DateTime.now();
    _lastFailureTime = DateTime.now(); // ✅ [추가] 실패 시간 기록

    // ✅ [수정] adaptive delay 사용
    final delay = await nextDelay;
    _currentDelay = delay; // ✅ [추가] 현재 delay 저장
    
    final totalDuration = DateTime.now().difference(_firstAttemptTime!);

    log.i('[Backoff] 🔄 Attempt #$_retryCount after ${delay.inSeconds}s '
        '(Total: ${totalDuration.inMinutes}min)');

    _retryTimer = Timer(delay, () async {
      try {
        await action();
        // 성공 시 리셋은 외부에서 호출
      } catch (e) {
        log.w('[Backoff] ❌ Action failed: $e');
        // 실패 시 다시 재시도하지 않음
      }
    });
  }

  /// 🎯 바이낸스 5분 제한 고려 (300 connections per 5 minutes)
  bool _shouldCooldown() {
    if (_firstAttemptTime == null) return false;

    final elapsed = DateTime.now().difference(_firstAttemptTime!);

    // 5분 내에 너무 많은 시도 (바이낸스 정책)
    if (elapsed < const Duration(minutes: 5) && _retryCount >= 8) {
      return true;
    }

    // 총 시도 시간이 너무 길면 (15분 이상)
    if (elapsed > const Duration(minutes: 15)) {
      return true;
    }

    return false;
  }

  /// 5분 쿨다운 후 재시작
  void _resetForCooldown() {
    const cooldownDuration = Duration(minutes: 5);
    log.i('[Backoff] 🕐 Starting ${cooldownDuration.inMinutes}min cooldown...');

    _retryTimer?.cancel();
    _retryTimer = Timer(cooldownDuration, () {
      log.i('[Backoff] ✅ Cooldown complete - resetting counters');
      reset();
    });
  }

  /// 연결 성공 시 백오프 리셋
  void reset() {
    _retryCount = 0;
    _firstAttemptTime = null;
    _lastFailureTime = null; // ✅ [추가] 실패 시간도 리셋
    _currentDelay = null; // ✅ [추가] 현재 delay도 리셋
    _retryTimer?.cancel();
    log.d('[Backoff] ✅ Reset - ready for new attempts');
  }

  /// 백오프 완전 중지
  void cancel() {
    _retryTimer?.cancel();
    _retryCount = 0;
    _firstAttemptTime = null;
    _lastFailureTime = null; // ✅ [추가]
    _currentDelay = null; // ✅ [추가]
    log.d('[Backoff] 🛑 Cancelled');
  }

  // ===================================================================
  // 📊 상태 정보 (확장됨)
  // ===================================================================

  int get retryCount => _retryCount;
  bool get isActive => _retryTimer?.isActive ?? false;
  bool get isInCooldown => _retryCount == 0 && isActive;

  Duration? get timeSinceFirstAttempt => _firstAttemptTime != null
      ? DateTime.now().difference(_firstAttemptTime!)
      : null;

  /// ✅ [확장] 더 상세한 디버그 정보
  Map<String, dynamic> getDebugInfo() {
    return {
      'retryCount': _retryCount,
      'isActive': isActive,
      'isInCooldown': isInCooldown,
      'currentDelaySeconds': _currentDelay?.inSeconds,
      'timeSinceFirstAttemptMinutes': timeSinceFirstAttempt?.inMinutes ?? 0,
      'timeSinceLastFailureMinutes': _lastFailureTime != null 
          ? DateTime.now().difference(_lastFailureTime!).inMinutes 
          : null,
      'maxRetries': maxRetries,
      'shouldCooldown': _shouldCooldown(),
      'failurePenalty': _calculateFailurePenalty(),
    };
  }

  /// ✅ [개선] 백오프 전략 설명
  String getStrategyDescription() {
    final buf = StringBuffer();
    buf.writeln('🎯 Binance Adaptive IP Ban Prevention Strategy:');
    buf.writeln('  • Initial delay: ${initialDelay.inSeconds}s');
    buf.writeln('  • Max delay: ${maxDelay.inMinutes}min');
    buf.writeln('  • Max retries: $maxRetries');
    buf.writeln('  • Jitter factor: ${(randomizationFactor * 100).toInt()}%');
    buf.writeln('  • Network-aware: YES (WiFi×0.9, Mobile×1.3, etc.)');
    buf.writeln('  • Failure penalty: ${_calculateFailurePenalty().toStringAsFixed(1)}×');
    buf.writeln('  • 5-minute cooldown: ${_retryCount >= 8 ? "ACTIVE" : "Ready"}');
    return buf.toString();
  }

  /// 현재 백오프 상태 요약
  String getStatusSummary() {
    if (_retryCount == 0) return '✅ Ready';
    if (isInCooldown) return '🕐 Cooling down';
    if (_retryCount >= maxRetries) return '🚨 Max retries reached';
    return '🔄 Retrying (#$_retryCount/${maxRetries})';
  }

  /// ✅ [추가] 건강성 체크
  bool get isHealthy {
    // 너무 많은 재시도는 비건강
    if (_retryCount >= maxRetries * 0.8) return false;
    
    // 쿨다운 중이면 비건강
    if (isInCooldown) return false;
    
    // 실패 페널티가 너무 높으면 비건강
    if (_calculateFailurePenalty() > 1.5) return false;
    
    return true;
  }
}