// lib/presentation/widgets/common_app_bar.dart
import 'package:flutter/material.dart';
import 'slide_indicator.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<PageInfo> pages;
  final PageController pageController;

  const CommonAppBar({
    Key? key,
    required this.pages,
    required this.pageController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0.5,
      // AppBar 중앙에 페이지 전환 인디케이터를 배치
      title: SlideIndicator(
        pages: pages,
        pageController: pageController,
      ),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}