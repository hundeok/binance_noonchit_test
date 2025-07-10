import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/volume_provider.dart';
import '../../domain/entities/volume.dart';
import '../../domain/usecases/volume_usecase.dart';

/// VolumePage의 UI 상태를 담는 불변 클래스
class VolumeControllerState {
  final bool isTop100;

  const VolumeControllerState({this.isTop100 = false}); // 기본값 Top 50

  VolumeControllerState copyWith({bool? isTop100}) {
    return VolumeControllerState(isTop100: isTop100 ?? this.isTop100);
  }
}

/// VolumePage의 상태와 로직을 관리하는 컨트롤러
class VolumeController extends StateNotifier<VolumeControllerState> {
  final Ref _ref;

  VolumeController(this._ref) : super(const VolumeControllerState());

  // --- UI 상태 변경 메서드 ---

  /// Top 50과 Top 100 표시를 토글합니다.
  void toggleTopLimit() {
    state = state.copyWith(isTop100: !state.isTop100);
  }

  /// 시간대(TimeFrame)를 변경합니다.
  void setTimeFrame(TimeFrame newTimeFrame) {
    _ref.read(volumeTimeFrameProvider.notifier).state = newTimeFrame;
  }

  // --- 비즈니스 로직 호출 메서드 ---

  /// 현재 시간대의 거래량을 리셋합니다.
  void resetCurrentTimeFrame() {
    final usecase = _ref.read(volumeUsecaseProvider);
    final currentTimeFrame = _ref.read(volumeTimeFrameProvider);
    usecase.resetTimeFrame(currentTimeFrame);
  }

  // --- UI에 필요한 데이터 getter ---

  /// 현재 선택된 시간대
  TimeFrame get currentTimeFrame => _ref.watch(volumeTimeFrameProvider);
  
  /// 사용 가능한 모든 시간대 목록
  List<TimeFrame> get availableTimeFrames => TimeFrame.values;
  
  /// 현재 표시할 목록 개수 (50 또는 100)
  int get currentLimit => state.isTop100 ? 100 : 50;
  
  /// 현재 표시 모드 이름
  String get currentLimitName => state.isTop100 ? 'Top 100' : 'Top 50';
}


/// VolumeController를 제공하는 최종 Provider
final volumeControllerProvider =
    StateNotifierProvider.autoDispose<VolumeController, VolumeControllerState>((ref) {
  return VolumeController(ref);
});