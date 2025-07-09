// lib/domain/entities/trade.dart

import 'package:flutter/foundation.dart';

@immutable
class Trade {
  final String market;
  final double price;
  final double volume;
  final double total; // 💰 총 거래대금 (price * volume)
  final bool isBuy;
  final int timestampMs;
  final String id;

  const Trade({
    required this.market,
    required this.price,
    required this.volume,
    required this.total,
    required this.isBuy,
    required this.timestampMs,
    required this.id,
  });

  DateTime get timestamp => DateTime.fromMillisecondsSinceEpoch(timestampMs);

  factory Trade.fromBinance(Map<String, dynamic> json) {
    final price = double.parse(json['p'].toString());
    final quantity = double.parse(json['q'].toString());
    return Trade(
      market: json['s'] as String,
      price: price,
      volume: quantity,
      total: price * quantity,
      isBuy: !(json['m'] as bool),
      timestampMs: json['T'] as int,
      id: json['a'].toString(),
    );
  }
}