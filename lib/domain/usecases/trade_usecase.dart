// lib/domain/usecases/trade_usecase.dart

import '../entities/trade.dart';
import '../repositories/trade_repository.dart';

class TradeUsecase {
  final TradeRepository _repository;

  TradeUsecase(this._repository);

  Stream<List<Trade>> watchFilteredTrades(List<String> markets) {
    return _repository.watchFilteredTrades(markets);
  }

  Stream<Trade> watchAggregatedTrades(List<String> markets) {
    return _repository.watchAggregatedTrades(markets);
  }
  
  void updateThreshold(double threshold) {
    _repository.updateThreshold(threshold);
  }
  
  void dispose() {
    _repository.dispose();
  }
}