import 'package:logger/logger.dart';

/// 앱 전체에서 사용할 전역 로거 인스턴스
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 1, // 로그 호출 스택을 한 줄만 표시
    errorMethodCount: 8, // 에러 발생 시 표시할 스택 트레이스 라인 수
    lineLength: 120, // 로그 한 줄의 최대 길이
    colors: true, // 로그 레벨별 컬러 적용
    printEmojis: true, // 로그 레벨별 이모지 적용
    printTime: true, // 타임스탬프 출력
  ),
  // 개발 중에는 모든 레벨의 로그를, 릴리즈 시에는 Level.warning 등으로 변경 가능
  level: Level.debug,
);
