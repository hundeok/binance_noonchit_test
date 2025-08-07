// ===================================================================
// lib/core/event/app_event.dart
// ===================================================================

import 'package:equatable/equatable.dart';

typedef Json = Map<String, dynamic>;

/// 🎯 바이낸스 전용 애플리케이션 이벤트
/// - id: 간단한 타임스탬프 기반 ID
/// - ts: UTC 밀리초 타임스탬프  
/// - payload: 바이낸스 데이터
class AppEvent extends Equatable {
  /// 고유 ID (타임스탬프 기반)
  final String id;
  
  /// UTC 밀리초 타임스탬프
  final int ts;
  
  /// 페이로드 데이터 (불변)
  final Json payload;

  const AppEvent({
    required this.id,
    required this.ts,
    required this.payload,
  });

  /// 🎯 현재 시각을 기준으로 간단한 ID 생성
  factory AppEvent.now(Json payload) {
    final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return AppEvent(
      id: 'evt_$nowUtcMs',
      ts: nowUtcMs,
      payload: Map<String, dynamic>.of(payload), // 방어적 복사
    );
  }

  /// UTC ms → 로컬 DateTime
  DateTime get timestamp =>
      DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toLocal();

  /// JSON 직렬화
  Json toJson() => {
        'id': id,
        'ts': ts,
        'payload': Map<String, dynamic>.of(payload),
      };

  /// JSON 역직렬화
  factory AppEvent.fromJson(Json json) {
    return AppEvent(
      id: json['id'] as String,
      ts: json['ts'] as int,
      payload: Map<String, dynamic>.of(json['payload'] as Json),
    );
  }

  @override
  List<Object?> get props => [id, ts, payload];
}
