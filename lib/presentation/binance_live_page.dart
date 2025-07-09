import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

// 1. 이전 단계에서 만든 Provider 파일 임포트
import '../core/di/binance_provider.dart';
import '../domain/entities/trade.dart';

class BinanceLivePage extends ConsumerWidget {
  const BinanceLivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 2. StateNotifierProvider를 watch하여 실시간 체결 리스트를 구독
    final List<Trade> trades = ref.watch(binanceTradesProvider);

    // 숫자 포맷팅을 위한 Formatter 준비
    final priceFormatter = NumberFormat('#,##0.00', 'en_US');
    final volumeFormatter = NumberFormat('#,##0.####', 'en_US');
    final totalFormatter = NumberFormat('#,##0', 'en_US');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Binance Futures Live Trades',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        itemCount: trades.length,
        itemBuilder: (context, index) {
          final trade = trades[index];
          final isBuy = trade.isBuy;
          
          // 매수/매도에 따른 색상 결정
          final mainColor = isBuy ? Colors.greenAccent[400] : Colors.redAccent[400];
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 마켓, 시간 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trade.market,
                      style: TextStyle(
                        color: mainColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('HH:mm:ss').format(
                        DateTime.fromMillisecondsSinceEpoch(trade.timestampMs),
                      ),
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ],
                ),
                
                // 가격 정보
                Text(
                  priceFormatter.format(trade.price),
                  style: TextStyle(
                    color: mainColor,
                    fontSize: 16,
                    fontFamily: 'monospace', // 숫자 가독성을 위해
                  ),
                ),

                // 수량, 총액 정보
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      volumeFormatter.format(trade.volume),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${totalFormatter.format(trade.price * trade.volume)} USDT',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[800],
          height: 1,
        ),
      ),
    );
  }
}