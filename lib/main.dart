import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 이전에 만든 페이지를 임포트합니다.
import 'presentation/binance_live_page.dart';

void main() {
  // Riverpod을 앱 전체에서 사용하기 위해 ProviderScope로 감싸줍니다.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Binance Live Feed',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(), // 페이지 디자인에 맞춰 다크 테마 적용
      
      // 앱이 시작될 때 보여줄 첫 페이지로 지정합니다.
      home: const BinanceLivePage(),
    );
  }
}