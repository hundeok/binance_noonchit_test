import 'dart:convert';
import '../../config/app_config.dart';
import '../../../domain/entities/trade.dart';
import '../../utils/logger.dart';
import 'base_ws_client.dart';

/// 바이낸스 선물(aggTrade) 스트림 전용 클라이언트
class TradeWsClient extends BaseWsClient<Trade> {
  TradeWsClient({void Function(WsStatus status)? onStatusChange})
      : super(
          // 1. URL: AppConfig에서 바이낸스 스트림 URL을 가져옴
          url: AppConfig.streamUrl,
          onStatusChange: onStatusChange,

          // 2. Ping/Pong: 바이낸스 정책에 맞게 설정
          clientPingInterval: null, // 서버가 Ping을 보내므로 클라이언트 Ping은 비활성화
          pongTimeout: AppConfig.wsPongTimeout,

          // 3. 구독 메시지 생성 (Binance 양식)
          encodeSubscribe: (markets) {
            final params = markets.map((m) => '${m.toLowerCase()}@aggTrade').toList();
            return json.encode({
              'method': 'SUBSCRIBE',
              'params': params,
              'id': DateTime.now().millisecondsSinceEpoch
            });
          },

          // 4. 데이터 파싱 (Binance 양식)
          decode: (json) {
            if (json is! Map<String, dynamic>) return null;

            // 실제 체결 데이터가 'data' 필드에 있는지 확인
            if (json.containsKey('data')) {
              try {
                return Trade.fromBinance(json['data']);
              } catch (e, st) {
                // ✅ 에러 로깅 방식 수정
                log.e('[WS Decode] Trade parsing error', e, st);
                return null;
              }
            }
            
            // 구독 성공 응답 등 데이터가 아닌 메시지는 무시
            return null;
          },
        );
}