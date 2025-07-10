import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/volume_repository_impl.dart';
import '../../domain/entities/volume.dart'; // ✅ 누락된 import 추가
import '../../domain/repositories/volume_repository.dart';
import '../../domain/usecases/volume_usecase.dart';
import 'core_provider.dart';

// ===================================================================
// 1. Data & Domain Layer Providers
// ===================================================================

final volumeRepositoryProvider = Provider<VolumeRepository>((ref) {
  final remoteDS = ref.watch(tradeRemoteDSProvider); 
  final repo = VolumeRepositoryImpl(remoteDS);
  ref.onDispose(() => repo.dispose());
  return repo;
});

final volumeUsecaseProvider = Provider((ref) {
  final usecase = VolumeUsecase(ref.watch(volumeRepositoryProvider));
  return usecase;
});


// ===================================================================
// 2. UI State & Final Data Provider
// ===================================================================

final volumeTimeFrameProvider = StateProvider<TimeFrame>((ref) => TimeFrame.min5);

final volumeDataProvider = StreamProvider.autoDispose<List<Volume>>((ref) {
  final timeFrame = ref.watch(volumeTimeFrameProvider);
  final marketsAsync = ref.watch(marketsProvider);
  final usecase = ref.read(volumeUsecaseProvider);

  return marketsAsync.when(
    data: (markets) {
      if (markets.isEmpty) return const Stream.empty();
      return usecase.watchVolumeRanking(timeFrame, markets);
    },
    loading: () => const Stream.empty(),
    error: (e, st) => Stream.error(e, st),
  );
});