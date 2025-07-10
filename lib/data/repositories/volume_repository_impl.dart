// lib/data/repositories/volume_repository_impl.dart

import 'dart:async';
import 'package:collection/collection.dart'; // sorted를 위해 import 추가
import '../../core/utils/logger.dart';
import '../../domain/entities/trade.dart';
import '../../domain/entities/volume.dart';
import '../../domain/repositories/volume_repository.dart';
import '../datasources/trade_remote_ds.dart';

class VolumeRepositoryImpl implements VolumeRepository {
  final TradeRemoteDataSource _remoteDataSource;

  final Map<TimeFrame, StreamController<List<Volume>>> _controllers = {};
  StreamSubscription? _rawTradeSub;
  final Map<TimeFrame, Map<String, double>> _volumeCache = {};
  final Map<TimeFrame, DateTime> _timeFrameStartTimes = {};
  Timer? _batchUpdateTimer;
  Timer? _resetCheckTimer;
  bool _isInitialized = false;

  VolumeRepositoryImpl(this._remoteDataSource) {
    for (final tf in TimeFrame.values) {
      _controllers[tf] = StreamController<List<Volume>>.broadcast();
      _volumeCache[tf] = {};
      _timeFrameStartTimes[tf] = DateTime.now();
    }
    _resetCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) => _checkTimeFrameResets());
  }

  void _initialize(List<String> markets) {
    if (_isInitialized) return;
    _isInitialized = true;
    final rawTradeStream = _remoteDataSource.watchTrades(markets);
    _rawTradeSub = rawTradeStream.listen(_processTrade);
    log.i('[VolumeRepo] Initialized.');
  }

  void _processTrade(Trade trade) {
    for (final tf in TimeFrame.values) {
      final cache = _volumeCache[tf]!;
      cache[trade.market] = (cache[trade.market] ?? 0) + trade.totalValue;
    }
    _scheduleBatchUpdate();
  }

  void _scheduleBatchUpdate() {
    _batchUpdateTimer?.cancel();
    _batchUpdateTimer = Timer(const Duration(milliseconds: 100), _performBatchUpdate);
  }

  void _performBatchUpdate() {
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final tf in TimeFrame.values) {
      final cache = _volumeCache[tf]!;
      final startTime = _timeFrameStartTimes[tf]!;
      
      final volumeList = cache.entries.map((entry) => Volume(
            market: entry.key,
            totalValue: entry.value,
            lastUpdated: now,
            timeFrame: tf,
            timeFrameStart: startTime.millisecondsSinceEpoch,
          ))
      // ✅ sortedBy -> sorted로 변경하고, null 안정성 처리
      .sorted((a, b) => b.totalValue.compareTo(a.totalValue));
      
      _controllers[tf]?.add(volumeList);
    }
  }

  void _checkTimeFrameResets() {
    final now = DateTime.now();
    for (final tf in TimeFrame.values) {
      final startTime = _timeFrameStartTimes[tf]!;
      if (now.difference(startTime) >= tf.duration) {
        _resetTimeFrame(tf, now);
      }
    }
  }

  void _resetTimeFrame(TimeFrame timeFrame, DateTime newStartTime) {
    _volumeCache[timeFrame]?.clear();
    _timeFrameStartTimes[timeFrame] = newStartTime;
    _performBatchUpdate();
  }

  @override
  Stream<List<Volume>> watchVolumeRanking(TimeFrame timeFrame, List<String> markets) {
    _initialize(markets);
    Future.microtask(_performBatchUpdate);
    return _controllers[timeFrame]?.stream ?? const Stream.empty();
  }

  @override
  void resetTimeFrame(TimeFrame timeFrame) {
    _resetTimeFrame(timeFrame, DateTime.now());
  }

  @override
  void resetAllTimeFrames() {
    final now = DateTime.now();
    for (final tf in TimeFrame.values) {
      _resetTimeFrame(tf, now);
    }
  }

  @override
  void dispose() {
    _rawTradeSub?.cancel();
    _batchUpdateTimer?.cancel();
    _resetCheckTimer?.cancel();
    for (var controller in _controllers.values) {
      controller.close();
    }
    log.i('[VolumeRepo] Disposed.');
  }
}