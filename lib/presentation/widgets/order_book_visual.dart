// lib/presentation/widgets/order_book_visual.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../core/di/core_provider.dart';
import '../../domain/entities/trade.dart';
import '../../core/config/app_config.dart';

/// 🎯 Order Book 시각화 위젯 - React 시뮬레이션 완벽 재현
class OrderBookVisual extends ConsumerWidget {
  final String market;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const OrderBookVisual({
    Key? key,
    required this.market,
    this.height,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
          
          return StreamBuilder<List<Trade>>(
            stream: Stream.periodic(const Duration(milliseconds: 500), (_) {
              // 🎯 Repository에서 직접 최신 depth5 데이터 가져오기
              final depth5Trades = repository.getStreamData(BinanceStreamType.depth5, limit: 10);
              // 해당 마켓의 데이터만 필터링
              return depth5Trades.where((trade) => trade.market == market).toList();
            }).where((trades) => trades.isNotEmpty),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildLoadingState(context);
              }

              // 가장 최신 depth5 데이터 사용
              final latestDepth5 = snapshot.data!.first;
              final orderBookData = _extractOrderBookData(latestDepth5);
              
              if (orderBookData == null) {
                return _buildErrorState(context, 'Invalid order book data format');
              }

              return _buildOrderBook(context, orderBookData);
            },
          );
        } catch (e) {
          return _buildErrorState(context, 'Failed to load order book: $e');
        }
      },
    );
  }

  /// ✅ [수정] Order Book 데이터 추출 - 바이낸스 실제 형식과 정규화된 형식 모두 지원
  OrderBookData? _extractOrderBookData(Trade trade) {
    if (trade.rawData == null) {
      print('🔍 OrderBook: rawData is null for ${trade.market}');
      return null;
    }

    try {
      List<dynamic>? bids;
      List<dynamic>? asks;

      // ✅ 수정: 바이낸스 실제 형식 ('b', 'a') 우선 확인
      if (trade.rawData!.containsKey('b') && trade.rawData!.containsKey('a')) {
        bids = trade.rawData!['b'] as List?;
        asks = trade.rawData!['a'] as List?;
        print('🔍 OrderBook: Using binance format (b/a) for ${trade.market}');
      }
      // ✅ 정규화된 형식 ('bids', 'asks') fallback
      else if (trade.rawData!.containsKey('bids') && trade.rawData!.containsKey('asks')) {
        bids = trade.rawData!['bids'] as List?;
        asks = trade.rawData!['asks'] as List?;
        print('🔍 OrderBook: Using normalized format (bids/asks) for ${trade.market}');
      }

      if (bids == null || asks == null) {
        print('🔍 OrderBook: No valid bid/ask data found');
        print('🔍 OrderBook: Available keys: ${trade.rawData!.keys.join(', ')}');
        return null;
      }

      print('🔍 OrderBook: ${trade.market} - bids: ${bids.length}, asks: ${asks.length}');

      if (bids.isEmpty || asks.isEmpty) {
        print('🔍 OrderBook: Empty bids or asks data');
        return null;
      }

      // 상위 5개 호가 추출
      final bidLevels = <OrderLevel>[];
      final askLevels = <OrderLevel>[];

      // ✅ 개선: 안전한 데이터 추출
      for (int i = 0; i < 5 && i < bids.length; i++) {
        final bid = bids[i];
        if (bid is List && bid.length >= 2) {
          final price = double.tryParse(bid[0].toString());
          final quantity = double.tryParse(bid[1].toString());
          
          if (price != null && quantity != null && price > 0 && quantity > 0) {
            bidLevels.add(OrderLevel(
              price: price,
              quantity: quantity,
              side: OrderSide.buy,
            ));
          }
        }
      }

      for (int i = 0; i < 5 && i < asks.length; i++) {
        final ask = asks[i];
        if (ask is List && ask.length >= 2) {
          final price = double.tryParse(ask[0].toString());
          final quantity = double.tryParse(ask[1].toString());
          
          if (price != null && quantity != null && price > 0 && quantity > 0) {
            askLevels.add(OrderLevel(
              price: price,
              quantity: quantity,
              side: OrderSide.sell,
            ));
          }
        }
      }

      // ✅ 유효한 데이터가 있는지 확인
      if (bidLevels.isEmpty && askLevels.isEmpty) {
        print('🔍 OrderBook: No valid price levels extracted');
        return null;
      }

      // 스프레드 계산
      final bestBid = bidLevels.isNotEmpty ? bidLevels[0].price : 0.0;
      final bestAsk = askLevels.isNotEmpty ? askLevels[0].price : 0.0;
      final spread = (bestAsk > 0 && bestBid > 0) ? bestAsk - bestBid : 0.0;

      print('🔍 OrderBook: ${trade.market} - spread: \$${spread.toStringAsFixed(2)}');
      print('🔍 OrderBook: Valid bid levels: ${bidLevels.length}, ask levels: ${askLevels.length}');

      return OrderBookData(
        bids: bidLevels,
        asks: askLevels.reversed.toList(), // asks는 높은 가격부터 표시
        spread: spread,
        lastUpdate: DateTime.now(),
      );
    } catch (e, st) {
      print('🚨 OrderBook parsing error: $e');
      print('🚨 Stack trace: $st');
      print('🚨 Raw data keys: ${trade.rawData?.keys.join(', ')}');
      if (trade.rawData != null) {
        // 디버깅을 위한 rawData 구조 출력 (첫 몇 개만)
        trade.rawData!.forEach((key, value) {
          if (value is List && value.isNotEmpty) {
            print('🚨 $key: ${value.take(2).toList()}... (${value.length} items)');
          } else {
            print('🚨 $key: $value');
          }
        });
      }
      return null;
    }
  }

  /// 🎨 메인 Order Book UI 구축
  Widget _buildOrderBook(BuildContext context, OrderBookData data) {
    return Container(
      height: height ?? 300,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, data),
          const SizedBox(height: 12),
          Expanded(
            child: Column(
              children: [
                // Asks (매도) - 위쪽에 표시
                Expanded(
                  child: _buildAsksSection(context, data.asks),
                ),
                
                // 스프레드 영역
                _buildSpreadSection(context, data.spread),
                
                // Bids (매수) - 아래쪽에 표시  
                Expanded(
                  child: _buildBidsSection(context, data.bids),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 📝 헤더 섹션
  Widget _buildHeader(BuildContext context, OrderBookData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Order Book Depth',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Live',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade700,
            ),
          ),
        ),
      ],
    );
  }

  /// 🔴 Asks (매도) 섹션
  Widget _buildAsksSection(BuildContext context, List<OrderLevel> asks) {
    if (asks.isEmpty) {
      return const Center(child: Text('No ask data', style: TextStyle(color: Colors.grey)));
    }

    // 최대 수량 계산 (바 차트 크기 조정용)
    final maxQuantity = asks.map((level) => level.quantity).reduce((a, b) => a > b ? a : b);

    return Column(
      children: asks.map((level) => _buildAskRow(context, level, maxQuantity)).toList(),
    );
  }

  /// 🟢 Bids (매수) 섹션
  Widget _buildBidsSection(BuildContext context, List<OrderLevel> bids) {
    if (bids.isEmpty) {
      return const Center(child: Text('No bid data', style: TextStyle(color: Colors.grey)));
    }

    // 최대 수량 계산 (바 차트 크기 조정용)
    final maxQuantity = bids.map((level) => level.quantity).reduce((a, b) => a > b ? a : b);

    return Column(
      children: bids.map((level) => _buildBidRow(context, level, maxQuantity)).toList(),
    );
  }

  /// 🔴 개별 Ask 행 (매도)
  Widget _buildAskRow(BuildContext context, OrderLevel level, double maxQuantity) {
    final widthPercentage = maxQuantity > 0 ? (level.quantity / maxQuantity * 100).clamp(0, 100) : 0;

    return Container(
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          // 가격 (왼쪽)
          SizedBox(
            width: 80,
            child: Text(
              level.price.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.red,
                fontFamily: 'monospace',
              ),
            ),
          ),
          
          // 수량 바 차트 (중간)
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widthPercentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFCDD2), Color(0xFFEF5350)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          
          // 수량 텍스트 (오른쪽)
          SizedBox(
            width: 60,
            child: Text(
              level.quantity.toStringAsFixed(3),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🟢 개별 Bid 행 (매수)
  Widget _buildBidRow(BuildContext context, OrderLevel level, double maxQuantity) {
    final widthPercentage = maxQuantity > 0 ? (level.quantity / maxQuantity * 100).clamp(0, 100) : 0;

    return Container(
      height: 24,
      margin: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          // 가격 (왼쪽)
          SizedBox(
            width: 80,
            child: Text(
              level.price.toStringAsFixed(2),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.green,
                fontFamily: 'monospace',
              ),
            ),
          ),
          
          // 수량 바 차트 (중간)
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: widthPercentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFC8E6C9), Color(0xFF66BB6A)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          
          // 수량 텍스트 (오른쪽)
          SizedBox(
            width: 60,
            child: Text(
              level.quantity.toStringAsFixed(3),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 💛 스프레드 섹션
  Widget _buildSpreadSection(BuildContext context, double spread) {
    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.yellow.shade200),
        ),
      ),
      child: Center(
        child: Text(
          'Spread: \$${spread.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.orange.shade700,
          ),
        ),
      ),
    );
  }

  /// ⏳ 로딩 상태
  Widget _buildLoadingState(BuildContext context) {
    return Container(
      height: height ?? 300,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              'Loading order book...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ 에러 상태
  Widget _buildErrorState(BuildContext context, String message) {
    return Container(
      height: height ?? 300,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade400,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              'Order Book Error',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// 📊 Order Book 데이터 모델들
// ===================================================================

/// 📊 Order Book 전체 데이터
class OrderBookData {
  final List<OrderLevel> bids;
  final List<OrderLevel> asks;
  final double spread;
  final DateTime lastUpdate;

  OrderBookData({
    required this.bids,
    required this.asks,
    required this.spread,
    required this.lastUpdate,
  });
}

/// 📈 개별 호가 레벨
class OrderLevel {
  final double price;
  final double quantity;
  final OrderSide side;

  OrderLevel({
    required this.price,
    required this.quantity,
    required this.side,
  });

  @override
  String toString() {
    return 'OrderLevel(price: $price, quantity: $quantity, side: $side)';
  }
}

/// 🎯 주문 방향
enum OrderSide {
  buy,
  sell,
}

// ===================================================================
// 🎨 사용법 예시
// ===================================================================

/// 사용 예시:
/// ```dart
/// OrderBookVisual(
///   market: 'BTCUSDT',
///   height: 400,
///   padding: EdgeInsets.all(16),
/// )
/// ```