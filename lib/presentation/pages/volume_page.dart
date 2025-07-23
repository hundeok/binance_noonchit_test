import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/common/time_frame_types.dart';
import '../../core/di/volume_provider.dart';
import '../../domain/entities/volume.dart';
import '../controllers/volume_controller.dart';
import '../widgets/volume_tile.dart';

class VolumePage extends ConsumerWidget {
  const VolumePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeDataAsync = ref.watch(volumeDataProvider);
    final uiState = ref.watch(volumeControllerProvider);
    final controller = ref.read(volumeControllerProvider.notifier);
    
    return Column(
      children: [
        // ✅ [수정] ref를 전달하여 오류 해결
        _buildControls(context, ref, controller, uiState),
        const Divider(height: 1),
        Expanded(
          child: volumeDataAsync.when(
            data: (volumes) => _buildVolumeList(context, volumes, uiState),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildControls(BuildContext context, WidgetRef ref, VolumeController controller, VolumeControllerState uiState) {
    final currentTimeFrame = controller.currentTimeFrame;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Timeframe: ${currentTimeFrame.displayName}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              _buildTopLimitToggle(controller, uiState),
              // ✅ [수정] ref를 전달하여 오류 해결
              _buildCountdownWidget(context, ref),
            ],
          ),
          Slider(
            value: TimeFrame.values.indexOf(currentTimeFrame).toDouble(),
            min: 0,
            max: (controller.availableTimeFrames.length - 1).toDouble(),
            divisions: controller.availableTimeFrames.length - 1,
            label: currentTimeFrame.displayName,
            onChanged: (value) {
              final newTimeFrame = controller.availableTimeFrames[value.round()];
              controller.setTimeFrame(newTimeFrame);
            },
            onChangeEnd: (_) => HapticFeedback.mediumImpact(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopLimitToggle(VolumeController controller, VolumeControllerState uiState) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        controller.toggleTopLimit();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          // ✅ [수정] .withOpacity -> .withAlpha로 변경
          color: uiState.isTop100 ? Colors.orange.withAlpha(51) : Colors.transparent, // 0.2 opacity
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withAlpha(179), width: 1.5), // 0.7 opacity
        ),
        child: Text(
          controller.currentLimitName,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownWidget(BuildContext context, WidgetRef ref) {
    final volumeData = ref.watch(volumeDataProvider);
    final remainingSeconds = volumeData.when(
      data: (volumes) => volumes.isNotEmpty ? volumes.first.remainingSeconds : 0,
      loading: () => 0,
      error: (_, __) => 0,
    );
    
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 16, color: Theme.of(context).hintColor),
        const SizedBox(width: 4),
        SizedBox(
          width: 42,
          child: Text(
            timeStr,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.orange,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVolumeList(BuildContext context, List<Volume> volumes, VolumeControllerState uiState) {
    if (volumes.isEmpty) {
      return const Center(child: Text('거래량 데이터가 없습니다.'));
    }
    
    final limitedList = volumes.take(uiState.isTop100 ? 100 : 50).toList();
    
    return RawScrollbar(
      thumbVisibility: true,
      thickness: 8,
      radius: const Radius.circular(4),
      child: ListView.builder(
        primary: false,
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
        itemCount: limitedList.length,
        itemBuilder: (context, index) => VolumeTile(
          volume: limitedList[index],
          rank: index + 1,
        ),
      ),
    );
  }
}