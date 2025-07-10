import 'dart:async';
import 'dart:math';

class ExponentialBackoff {
  final Duration initialDelay;
  final Duration maxDelay;
  final double randomizationFactor;
  int _retryCount = 0;

  ExponentialBackoff({
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(seconds: 60),
    this.randomizationFactor = 0.5,
  });

  /// 재시도 횟수에 따라 다음 재연결까지의 대기 시간을 계산
  Duration get nextDelay {
    if (_retryCount == 0) return Duration.zero;
    
    final delay = initialDelay * pow(2, _retryCount - 1);
    final random = Random();
    final jitter = (delay.inMilliseconds * randomizationFactor * (random.nextDouble() * 2 - 1)).round();
    
    final finalDelay = Duration(milliseconds: delay.inMilliseconds + jitter);
    
    return finalDelay < maxDelay ? finalDelay : maxDelay;
  }

  /// 재연결 시도
  Future<void> attempt(Future<void> Function() action) async {
    _retryCount++;
    await Future.delayed(nextDelay);
    await action();
  }

  /// 연결 성공 시 재시도 횟수 리셋
  void reset() => _retryCount = 0;

  int get retryCount => _retryCount;
}