import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/trade.dart';

class TradeTile extends ConsumerWidget {
  final Trade trade;

  const TradeTile({Key? key, required this.trade}) : super(key: key);

  static final _timeFormat = DateFormat('HH:mm:ss');
  static final _quantityFormat = NumberFormat('#,##0.###');
  static final _totalFormat = NumberFormat('#,##0');

  String _formatPrice(double price) {
    if (price < 0.01) return price.toStringAsFixed(6);
    if (price < 1) return price.toStringAsFixed(4);
    if (price < 100) return price.toStringAsFixed(2);
    return price.toStringAsFixed(1);
  }

  String _getDisplayName(WidgetRef ref) {
    return trade.market.replaceAll('USDT', '');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bool isBuy = trade.isBuy;
    final Color sideColor = isBuy ? Colors.green.shade400 : Colors.red.shade400;

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // ✅ 시간 (Flex: 13)
            Expanded(
              flex: 13,
              child: Text(
                _timeFormat.format(trade.dateTime),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ),

            // ✅ 티커 (Flex: 17)
            Expanded(
              flex: 17,
              child: Text(
                _getDisplayName(ref),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // ✅ 가격 / 수량 (Flex: 20)
            Expanded(
              flex: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    // ✅ 가격 앞에 '$' 기호 추가
                    '\$${_formatPrice(trade.price)}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _quantityFormat.format(trade.quantity),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            ),

            // ✅ 총액 (Flex: 20)
            Expanded(
              flex: 20,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  // ✅ 총액 앞에 '$' 기호 추가
                  '\$${_totalFormat.format(trade.totalValue)}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: sideColor,
                  ),
                ),
              ),
            ),

            // 방향 아이콘
            Padding(
              padding: const EdgeInsets.only(left: 10.0),
              child: Icon(
                isBuy ? Icons.arrow_upward : Icons.arrow_downward,
                color: sideColor,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}