// lib/domain/usecases/volume_usecase.dart

import '../entities/volume.dart';
import '../repositories/volume_repository.dart';

class VolumeUsecase {
  final VolumeRepository _repository;

  VolumeUsecase(this._repository);

  Stream<List<Volume>> watchVolumeRanking(TimeFrame timeFrame, List<String> markets) {
    return _repository.watchVolumeRanking(timeFrame, markets);
  }

  void resetTimeFrame(TimeFrame timeFrame) {
    _repository.resetTimeFrame(timeFrame);
  }

  void resetAllTimeFrames() {
    _repository.resetAllTimeFrames();
  }

  void dispose() {
    _repository.dispose();
  }
}