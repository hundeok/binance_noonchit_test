import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/volume_provider.dart';
import '../../domain/entities/volume.dart';
import '../controllers/volume_controller.dart';
import '../widgets/volume_tile.dart';

class VolumePage extends ConsumerWidget {
  const VolumePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumeDataAsync = ref.watch(volumeDataProvider);
    final controller = ref.read(volumeControllerProvider);

    // ✅ Column을 바로 반환하여 MainPage에 통합
    return Column(
      children: [
        // ✅ 시간대 선택 슬라이더 UI 적용
        _buildTimeFrameSlider(context, controller),
        const Divider(height: 1),
        Expanded(
          child: volumeDataAsync.when(
            data: (volumes) {
              if (volumes.isEmpty) {
                return Center(child: Text('No volume data for ${controller.currentTimeFrame.displayName}.'));
              }
              // ✅ 기본적으로 Top 100을 표시
              final limitedList = volumes.take(100).toList();
              
              return RawScrollbar(
                thumbVisibility: true,
                interactive: true,
                thickness: 8,
                radius: const Radius.circular(4),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  itemCount: limitedList.length,
                  itemBuilder: (context, index) {
                    return VolumeTile(
                      volume: limitedList[index],
                      rank: index + 1,
                    );
                  },
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  /// 시간대 선택을 위한 슬라이더 위젯
  Widget _buildTimeFrameSlider(BuildContext context, VolumeController controller) {
    final timeFrames = controller.availableTimeFrames;
    final currentTimeFrame = controller.currentTimeFrame;
    final currentIndex = timeFrames.indexOf(currentTimeFrame);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TimeFrame: ${currentTimeFrame.displayName}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Slider(
            value: currentIndex.toDouble(),
            min: 0,
            max: (timeFrames.length - 1).toDouble(),
            divisions: timeFrames.length - 1,
            label: currentTimeFrame.displayName,
            onChanged: (value) {