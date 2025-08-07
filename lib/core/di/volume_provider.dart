// lib/core/di/volume_provider.dart
// 🚧 DISABLED VERSION - 컴파일 에러 방지용 임시 파일
// 모든 Provider는 정의되어 있지만 실제 작동하지 않음

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/volume.dart';
import '../../core/common/time_frame_types.dart';
import '../../core/utils/logger.dart';

// ===================================================================
// 🚧 임시 비활성화된 Provider들 (컴파일 에러 방지용)
// ===================================================================

/// 🚧 임시 비활성화: 사용자가 선택한 시간 프레임
final volumeTimeFrameProvider = StateProvider<TimeFrame>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - volumeTimeFrameProvider');
  return TimeFrame.min5;
});

/// 🚧 임시 비활성화: 볼륨 표시 개수 (50 또는 100)
final volumeDisplayCountProvider = StateProvider<int>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - volumeDisplayCountProvider');
  return 50;
});

/// 🚧 임시 비활성화: 실시간 볼륨 데이터 (빈 스트림 반환)
final volumeDataProvider = StreamProvider.autoDispose<List<Volume>>((ref) async* {
  log.w('[VolumeProvider] 🚧 DISABLED - volumeDataProvider returning empty stream');
  
  // 영원히 빈 리스트만 방출
  yield <Volume>[];
  
  // 더 이상 아무것도 하지 않음 (실제 처리 완전 비활성화)
  await Future.delayed(const Duration(hours: 24)); // 24시간 대기 (실질적으로 아무것도 안함)
});

/// 🚧 임시 비활성화: 필터링된 볼륨 데이터
final filteredVolumeDataProvider = Provider.autoDispose<AsyncValue<List<Volume>>>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - filteredVolumeDataProvider returning empty');
  return const AsyncValue.data(<Volume>[]);
});

/// 🚧 임시 비활성화: 카운트다운
final volumeCountdownProvider = Provider.autoDispose<int>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - volumeCountdownProvider returning 0');
  return 0;
});

/// 🚧 임시 비활성화: 볼륨 통계 정보
final volumeStatsProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - volumeStatsProvider returning empty stats');
  return <String, dynamic>{
    'totalMarkets': 0,
    'totalValue': 0.0,
    'status': 'DISABLED'
  };
});

/// 🚧 임시 비활성화: 시간 프레임 정보
final timeFrameInfoProvider = Provider.autoDispose<Map<String, dynamic>>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - timeFrameInfoProvider returning basic info');
  return {
    'timeFrame': TimeFrame.min5,
    'displayName': 'DISABLED',
    'status': 'DISABLED'
  };
});

// ===================================================================
// 🚧 임시 비활성화된 컨트롤러들
// ===================================================================

/// 🚧 임시 비활성화: 시간 프레임 변경 컨트롤러
final volumeTimeFrameController = Provider.autoDispose((ref) => DisabledVolumeTimeFrameController(ref));

class DisabledVolumeTimeFrameController {
  final Ref _ref;
  DisabledVolumeTimeFrameController(this._ref);

  void setTimeFrame(TimeFrame newTimeFrame) {
    log.w('[VolumeTimeFrameController] 🚧 DISABLED - setTimeFrame ignored');
  }

  void nextTimeFrame() {
    log.w('[VolumeTimeFrameController] 🚧 DISABLED - nextTimeFrame ignored');
  }

  void previousTimeFrame() {
    log.w('[VolumeTimeFrameController] 🚧 DISABLED - previousTimeFrame ignored');
  }

  TimeFrame get currentTimeFrame => TimeFrame.min5;
  List<TimeFrame> get availableTimeFrames => TimeFrame.values;
}

/// 🚧 임시 비활성화: 표시 개수 변경 컨트롤러
final volumeDisplayController = Provider.autoDispose((ref) => DisabledVolumeDisplayController(ref));

class DisabledVolumeDisplayController {
  final Ref _ref;
  DisabledVolumeDisplayController(this._ref);

  void toggleDisplayCount() {
    log.w('[VolumeDisplayController] 🚧 DISABLED - toggleDisplayCount ignored');
  }

  void setDisplayCount(int count) {
    log.w('[VolumeDisplayController] 🚧 DISABLED - setDisplayCount ignored');
  }

  int get currentDisplayCount => 50;
  bool get isTop100 => false;
  String get displayLabel => 'DISABLED';
}

// ===================================================================
// 🚧 임시 비활성화된 디버그 Provider들
// ===================================================================

/// 🚧 임시 비활성화: 볼륨 프로세싱 상태 모니터링
final volumeDebugInfoProvider = StateNotifierProvider.autoDispose<
    DisabledVolumeDebugNotifier, Map<String, dynamic>>((ref) {
  return DisabledVolumeDebugNotifier(ref);
});

class DisabledVolumeDebugNotifier extends StateNotifier<Map<String, dynamic>> {
  final Ref _ref;

  DisabledVolumeDebugNotifier(this._ref) : super({
    'status': 'DISABLED',
    'message': 'Volume provider is temporarily disabled',
    'timestamp': DateTime.now().toIso8601String(),
  }) {
    log.w('[VolumeDebugNotifier] 🚧 DISABLED - Debug info disabled');
  }

  @override
  void dispose() {
    log.w('[VolumeDebugNotifier] 🚧 DISABLED - Disposing disabled notifier');
    super.dispose();
  }
}

/// 🚧 임시 비활성화: 특정 마켓의 볼륨 상세 정보 조회
final marketVolumeDetailProvider = Provider.family.autoDispose<Volume?, String>((ref, market) {
  log.w('[VolumeProvider] 🚧 DISABLED - marketVolumeDetailProvider returning null for $market');
  return null;
});

/// 🚧 임시 비활성화: 상위 N개 마켓 조회
final topMarketsProvider = Provider.family.autoDispose<List<String>, int>((ref, count) {
  log.w('[VolumeProvider] 🚧 DISABLED - topMarketsProvider returning empty list');
  return <String>[];
});

/// 🚧 임시 비활성화: VolumePage에서 사용할 최종 Provider
final volumePageDataProvider = Provider.autoDispose<({
  AsyncValue<List<Volume>> volumes,
  TimeFrame timeFrame,
  int countdown,
  int displayCount,
  bool isTop100,
})>((ref) {
  log.w('[VolumeProvider] 🚧 DISABLED - volumePageDataProvider returning disabled data');
  
  return (
    volumes: const AsyncValue.data(<Volume>[]),
    timeFrame: TimeFrame.min5,
    countdown: 0,
    displayCount: 50,
    isTop100: false,
  );
});

/// 🚧 임시 비활성화: 볼륨 순위 변동 알림 Provider
final volumeRankingChangeProvider = StreamProvider.autoDispose<Map<String, int>>((ref) async* {
  log.w('[VolumeProvider] 🚧 DISABLED - volumeRankingChangeProvider returning empty stream');
  
  // 영원히 빈 맵만 방출
  yield <String, int>{};
  
  // 더 이상 아무것도 하지 않음
  await Future.delayed(const Duration(hours: 24));
});

// ===================================================================
// 🚧 임시 비활성화 상태 알림
// ===================================================================

/// 🚧 볼륨 프로바이더 비활성화 상태 확인 Provider
final volumeProviderStatusProvider = Provider((ref) {
  return {
    'isEnabled': false,
    'status': 'TEMPORARILY_DISABLED',
    'reason': 'Performance optimization - Trade line focus',
    'message': 'Volume provider is temporarily disabled to focus on trade line optimization',
    'timestamp': DateTime.now().toIso8601String(),
  };
});

// ===================================================================
// 🚧 로그 출력 (앱 시작 시 비활성화 상태 알림)
// ===================================================================

void _logDisabledStatus() {
  log.w('');
  log.w('🚧' + '=' * 60);
  log.w('🚧 VOLUME PROVIDER TEMPORARILY DISABLED');
  log.w('🚧' + '=' * 60);
  log.w('🚧 Reason: Performance optimization for trade line');
  log.w('🚧 Status: All volume providers return empty/default values');
  log.w('🚧 Impact: No background volume processing');
  log.w('🚧 Note: Compile errors prevented, functionality disabled');
  log.w('🚧' + '=' * 60);
  log.w('');
}

// Provider 최초 접근 시 비활성화 상태 로그 출력
final _volumeProviderInitializer = Provider((ref) {
  _logDisabledStatus();
  return true;
});