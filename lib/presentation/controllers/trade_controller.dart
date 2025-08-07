// ===================================================================
// lib/presentation/controllers/trade_controller.dart
// 현재 Provider 체제에 맞게 수정된 Trade Controller
// ===================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/common/time_frame_types.dart';
import '../../core/di/core_provider.dart';
import '../../domain/entities/trade.dart';
import '../../core/utils/logger.dart';

// ===================================================================
// 📊 State 클래스 (기존 유지)
// ===================================================================

class TradeControllerState {
  final bool isLoading;
  final String? errorMessage;
  final List<Trade> trades;
  final TradeFilter currentFilter;
  final int selectedFilterIndex;

  TradeControllerState({
    this.isLoading = true,
    this.errorMessage,
    this.trades = const [],
    required this.currentFilter,
    required this.selectedFilterIndex,
  });

  TradeControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Trade>? trades,
    TradeFilter? currentFilter,
    int? selectedFilterIndex,
  }) {
    return TradeControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      trades: trades ?? this.trades,
      currentFilter: currentFilter ?? this.currentFilter,
      selectedFilterIndex: selectedFilterIndex ?? this.selectedFilterIndex,
    );
  }
}

// ===================================================================
// 🎯 Controller 클래스 (현재 체제에 맞게 수정)
// ===================================================================

class TradeController extends StateNotifier<TradeControllerState> {
  final Ref _ref;
  
  // ✅ ProviderSubscription으로 구독 관리
  ProviderSubscription? _filteredTradesSub;
  ProviderSubscription? _rawStreamSub;

  TradeController(this._ref)
      : super(TradeControllerState(
          currentFilter: _ref.read(tradeFilterProvider),
          selectedFilterIndex: TradeFilter.values.indexOf(_ref.read(tradeFilterProvider)),
        )) {
    log.d('[TradeController] Initializing controller...');
    _listenToTrades();
  }

  // ===================================================================
  // 🎧 스트림 구독 관리
  // ===================================================================

  void _listenToTrades() {
    log.d('[TradeController] Setting up trade stream listeners...');

    // 🎯 [수정] rawTradesProvider 스트림 구독 (로딩/에러 상태 감지)
    _rawStreamSub = _ref.listen<AsyncValue<Trade>>(
      rawTradesProvider,
      (previous, next) {
        // 로딩 상태 변경 감지
        if (state.isLoading && !next.isLoading) {
          log.d('[TradeController] Raw stream loading completed');
          state = state.copyWith(isLoading: false);
        }

        // 에러 상태 처리
        if (next.hasError) {
          final errorMsg = next.error.toString();
          log.e('[TradeController] Raw stream error: $errorMsg');
          state = state.copyWith(
            errorMessage: errorMsg,
            isLoading: false,
          );
        }

        // 성공적으로 데이터 수신 시 에러 메시지 클리어
        if (next.hasValue && state.errorMessage != null) {
          log.d('[TradeController] Raw stream recovered from error');
          state = state.copyWith(errorMessage: null);
        }
      },
      fireImmediately: true,
    );

    // 🎯 [수정] filteredTradesProvider 스트림 구독 (필터링된 거래 목록)
    _filteredTradesSub = _ref.listen<AsyncValue<List<Trade>>>(
      filteredTradesProvider,
      (previous, next) {
        next.when(
          data: (trades) {
            log.d('[TradeController] Received ${trades.length} filtered trades');
            state = state.copyWith(
              trades: trades,
              isLoading: false,
              errorMessage: null,
            );
          },
          loading: () {
            // 이미 데이터가 있다면 로딩 상태로 변경하지 않음 (부드러운 UX)
            if (state.trades.isEmpty) {
              log.d('[TradeController] Filtered trades loading...');
              state = state.copyWith(isLoading: true);
            }
          },
          error: (error, stackTrace) {
            final errorMsg = error.toString();
            log.e('[TradeController] Filtered trades error: $errorMsg', error, stackTrace);
            state = state.copyWith(
              errorMessage: errorMsg,
              isLoading: false,
            );
          },
        );
      },
      fireImmediately: true,
    );

    log.i('[TradeController] ✅ Trade stream listeners configured');
  }

  // ===================================================================
  // 🎛️ 필터 제어 메서드
  // ===================================================================

  /// 거래대금 필터 변경
  void setThreshold(TradeFilter newFilter) {
    if (state.currentFilter == newFilter) {
      log.d('[TradeController] Filter unchanged: ${newFilter.displayName}');
      return;
    }

    log.i('[TradeController] 🔄 Filter change: ${state.currentFilter.displayName} → ${newFilter.displayName}');

    // 🎯 Provider 상태 업데이트
    _ref.read(tradeFilterProvider.notifier).state = newFilter;

    // 🎯 Controller 상태 업데이트
    state = state.copyWith(
      currentFilter: newFilter,
      selectedFilterIndex: TradeFilter.values.indexOf(newFilter),
      isLoading: true, // 새 필터 적용 중 로딩 표시
    );

    log.d('[TradeController] ✅ Filter updated to: ${newFilter.displayName} (${newFilter.value.toStringAsFixed(0)})');
  }

  /// 다음 필터로 순환
  void nextFilter() {
    final currentIndex = state.selectedFilterIndex;
    final nextIndex = (currentIndex + 1) % TradeFilter.values.length;
    final nextFilter = TradeFilter.values[nextIndex];
    
    log.d('[TradeController] Cycling to next filter: $nextIndex');
    setThreshold(nextFilter);
  }

  /// 이전 필터로 순환
  void previousFilter() {
    final currentIndex = state.selectedFilterIndex;
    final prevIndex = (currentIndex - 1 + TradeFilter.values.length) % TradeFilter.values.length;
    final prevFilter = TradeFilter.values[prevIndex];
    
    log.d('[TradeController] Cycling to previous filter: $prevIndex');
    setThreshold(prevFilter);
  }

  // ===================================================================
  // 📊 상태 조회 메서드
  // ===================================================================

  /// 사용 가능한 모든 필터 목록
  List<TradeFilter> get availableFilters => TradeFilter.values;

  /// 현재 필터의 표시 이름
  String get currentFilterDisplayName => state.currentFilter.displayName;

  /// 현재 필터의 거래대금 임계값
  double get currentThreshold => state.currentFilter.value;

  /// 현재 거래 수
  int get currentTradeCount => state.trades.length;

  /// 에러 상태 여부
  bool get hasError => state.errorMessage != null;

  /// 로딩 상태 여부 (실제 로딩 중이거나 에러가 없을 때)
  bool get isActivelyLoading => state.isLoading && !hasError;

  // ===================================================================
  // 🔄 수동 새로고침 (필요시)
  // ===================================================================

  /// 수동으로 스트림 재구독 (문제 발생 시 복구용)
  void refresh() {
    log.i('[TradeController] 🔄 Manual refresh requested');
    
    // 기존 구독 해제
    _filteredTradesSub?.close();
    _rawStreamSub?.close();
    
    // 로딩 상태로 변경
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
    );
    
    // 스트림 재구독
    _listenToTrades();
  }

  /// 에러 상태 클리어
  void clearError() {
    if (state.errorMessage != null) {
      log.d('[TradeController] Clearing error state');
      state = state.copyWith(errorMessage: null);
    }
  }

  // ===================================================================
  // 🧹 정리
  // ===================================================================

  @override
  void dispose() {
    log.d('[TradeController] Disposing controller...');
    
    // ✅ 구독 해제
    _filteredTradesSub?.close();
    _rawStreamSub?.close();
    
    log.i('[TradeController] ✅ Controller disposed');
    super.dispose();
  }
}

// ===================================================================
// 🎯 Provider 정의 (autoDispose로 메모리 관리)
// ===================================================================

final tradeControllerProvider =
    StateNotifierProvider.autoDispose<TradeController, TradeControllerState>((ref) {
  return TradeController(ref);
});

// ===================================================================
// 🎛️ 편의용 Provider들 (UI에서 쉽게 사용할 수 있도록)
// ===================================================================

/// 현재 거래 목록만 조회
final currentTradesProvider = Provider.autoDispose<List<Trade>>((ref) {
  return ref.watch(tradeControllerProvider.select((state) => state.trades));
});

/// 현재 필터 정보만 조회
final currentFilterProvider = Provider.autoDispose<TradeFilter>((ref) {
  return ref.watch(tradeControllerProvider.select((state) => state.currentFilter));
});

/// 로딩 상태만 조회
final tradesLoadingProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(tradeControllerProvider.select((state) => state.isLoading));
});

/// 에러 상태만 조회
final tradesErrorProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(tradeControllerProvider.select((state) => state.errorMessage));
});

/// Controller 인스턴스 직접 접근 (메서드 호출용)
final tradeControllerNotifierProvider = Provider.autoDispose<TradeController>((ref) {
  return ref.watch(tradeControllerProvider.notifier);
});