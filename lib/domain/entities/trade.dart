import 'package:equatable/equatable.dart';

class Trade extends Equatable {
  /// 심볼 (e.g., BTCUSDT)
  final String market;

  /// 체결 가격
  final double price;

  /// 체결 수량 (API 필드명 'q'에 맞춰 volume -> quantity로 변경)
  final double quantity;

  /// 총 체결액 (price * quantity)
  final double totalValue; // total -> totalValue로 명확화

  /// 매수 체결 여부
  final bool isBuy;

  /// 체결 시각 (milliseconds from epoch)
  final int timestamp; // timestampMs -> timestamp로 간소화

  /// 거래 고유 ID (Aggregate trade ID)
  final String tradeId; // id -> tradeId로 명확화

  const Trade({
    required this.market,
    required this.price,
    required this.quantity,
    required this.totalValue,
    required this.isBuy,
    required this.timestamp,
    required this.tradeId,
  });

  /// UI에서 사용하기 편한 DateTime 객체
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  /// 바이낸스 선물 `aggTrade` 스트림 데이터로부터 Trade 객체 생성
  factory Trade.fromBinance(Map<String, dynamic> json) {
    final price = double.parse(json['p'].toString());
    final quantity = double.parse(json['q'].toString());

    return Trade(
      market: json['s'] as String,
      price: price,
      quantity: quantity,
      totalValue: price * quantity,
      isBuy: !(json['m'] as bool), // isBuyerMaker(`m`)가 false일 때가 매수
      timestamp: json['T'] as int,
      tradeId: json['a'].toString(),
    );
  }

  /// Equatable을 위한 설정. tradeId를 기준으로 객체의 동등성을 비교합니다.
  @override
  List<Object> get props => [tradeId];
}