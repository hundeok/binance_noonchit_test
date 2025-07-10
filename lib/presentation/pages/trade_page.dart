import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ✅ 사용하지 않는 import 제거
// import '../../core/common/time_frame_types.dart';
// import '../../core/config/app_config.dart';
// import '../../core/di/core_provider.dart';

import '../controllers/trade_controller.dart';
import '../widgets/trade_tile.dart';

class TradePage extends ConsumerWidget {
  const TradePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(tradeControllerProvider);
    final controller = ref.read(tradeControllerProvider.notifier);

    final slider = _buildFilterSlider(context, controller, state);
    final tradeList = _buildTradeList(context, state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Binance Futures - Live Trades'),
        elevation: 1,
      ),
      body: Column(
        children: [
          slider,
          const Divider(height: 1),
          Expanded(child: tradeList),
        ],
      ),
    );
  }

  Widget _buildFilterSlider(
    BuildContext context,
    TradeController controller,
    TradeControllerState state,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Minimum Value: ${state.currentFilter.displayName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Slider(
            value: state.selectedFilterIndex.toDouble(),
            min: 0,
            max: (controller.availableFilters.length - 1).toDouble(),
            divisions: controller.availableFilters.length - 1,
            label: state.currentFilter.displayName,
            onChanged: (value) {
              final newFilter = controller.availableFilters[value.round()];
              controller.setThreshold(newFilter);
            },
            onChangeEnd: (_) {
              HapticFeedback.mediumImpact();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTradeList(BuildContext context, TradeControllerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.errorMessage != null) {
      return Center(child: Text('Error: ${state.errorMessage}'));
    }
    if (state.trades.isEmpty) {
      return Center(
        child: Text(
          'No trades captured.\n(Threshold: ${state.currentFilter.displayName})',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).hintColor),
        ),
      );
    }
    
    return RawScrollbar(
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 8,
      radius: const Radius.circular(4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: state.trades.length,
        itemBuilder: (context, index) {
          return TradeTile(trade: state.trades[index]);
        },
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          // ✅ .withOpacity(0.1) -> .withAlpha(25)로 수정 (0.1 * 255 = 25.5)
          color: Theme.of(context).dividerColor.withAlpha(25),
          indent: 16,
          endIndent: 16,
        ),
      ),
    );
  }
}