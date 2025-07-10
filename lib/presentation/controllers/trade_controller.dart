// lib/presentation/controllers/trade_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/common/time_frame_types.dart';
import '../../core/di/core_provider.dart';
import '../../domain/entities/trade.dart';

// State 클래스는 변경 없음
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

// Controller 클래스 수정
class TradeController extends StateNotifier<TradeControllerState> {
  final Ref _ref;
  // ✅ StreamSubscription -> ProviderSubscription 으로 변경
  ProviderSubscription? _filteredTradesSub;
  ProviderSubscription? _rawStreamSub;

  TradeController(this._ref)
      : super(TradeControllerState(
          currentFilter: _ref.read(tradeFilterProvider),
          selectedFilterIndex: TradeFilter.values.indexOf(_ref.read(tradeFilterProvider)),
        )) {
    _listenToTrades();
  }

  void _listenToTrades() {
    // raw stream의 로딩/에러 상태를 감지
    _rawStreamSub = _ref.listen<AsyncValue<Trade>>(
      rawTradeStreamProvider,
      (previous, next) {
        if (state.isLoading && !next.isLoading) {
          state = state.copyWith(isLoading: false);
        }
        if (next.hasError) {
          state = state.copyWith(errorMessage: next.error.toString(), isLoading: false);
        }
      },
      fireImmediately: true,
    );

    // 필터링된 최종 목록을 구독하여 UI에 표시할 trades를 업데이트
    _filteredTradesSub = _ref.listen<List<Trade>>(
      filteredTradesProvider, 
      (previous, next) {
        state = state.copyWith(trades: next, isLoading: false);
      },
      fireImmediately: true,
    );
  }

  void setThreshold(TradeFilter newFilter) {
    _ref.read(tradeFilterProvider.notifier).state = newFilter;
    state = state.copyWith(
      currentFilter: newFilter,
      selectedFilterIndex: TradeFilter.values.indexOf(newFilter),
    );
  }

  List<TradeFilter> get availableFilters => TradeFilter.values;
  String get currentFilterDisplayName => state.currentFilter.displayName;

  @override
  void dispose() {
    // ✅ 구독 취소 방식을 .close()로 변경
    _filteredTradesSub?.close();
    _rawStreamSub?.close();
    super.dispose();
  }
}

// Provider 정의는 변경 없음
final tradeControllerProvider =
    StateNotifierProvider.autoDispose<TradeController, TradeControllerState>((ref) {
  return TradeController(ref);
});