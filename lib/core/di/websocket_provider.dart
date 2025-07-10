import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/websocket/base_ws_client.dart';
import '../network/websocket/trade_ws_client.dart';
import '../utils/logger.dart';

/// WebSocket 연결 상태를 UI에 제공하는 Provider
final wsStatusProvider = StateProvider<WsStatus>((ref) => WsStatus.disconnected);

/// WebSocket 클라이언트 인스턴스를 생성하고 제공하는 핵심 Provider
///
/// 이 Provider는 `TradeWsClient` (내부적으로 바이낸스 로직을 가짐)를 생성하고,
/// 클라이언트의 상태 변경을 감지하여 `wsStatusProvider`를 업데이트합니다.
final wsClientProvider = Provider<TradeWsClient>((ref) {
  return TradeWsClient(
    onStatusChange: (status) {
      // WebSocket 클라이언트의 내부 상태가 변경될 때마다
      // UI가 감지할 수 있도록 `wsStatusProvider`의 상태를 업데이트합니다.
      final currentStatus = ref.read(wsStatusProvider);
      if (currentStatus != status) {
        ref.read(wsStatusProvider.notifier).state = status;
        log.i('[WebSocket] Status changed to: $status');
      }
    },
  );
});