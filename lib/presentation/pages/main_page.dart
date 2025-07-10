// lib/presentation/pages/main_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/slide_indicator.dart';
import 'trade_page.dart';
import 'volume_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  late PageController _pageController;

  // ✅ 메뉴는 2개만 사용
  final List<PageInfo> _pages = const [
    PageInfo('체결', Icons.list_alt_rounded),
    PageInfo('거래량', Icons.bar_chart_rounded),
  ];

  @override
  void initState() {
    super.initState();
    // 첫 페이지를 '체결'로 설정
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        pages: _pages,
        pageController: _pageController,
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          // 페이지 스와이프 시, 인디케이터의 상태도 함께 변경
          ref.read(selectedTabProvider.notifier).state = index;
        },
        children: const [
          // ✅ 페이지 위젯 목록
          TradePage(),
          VolumePage(),
        ],
      ),
    );
  }
}