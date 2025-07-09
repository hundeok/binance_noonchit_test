// lib/core/utils/logger.dart

import 'package:logger/logger.dart';

/// 글로벌 Logger 인스턴스
final Logger log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 120,
    colors: true,
    printTime: true,
  ),
  level: Level.debug, // 개발 중에는 debug 레벨 사용
);