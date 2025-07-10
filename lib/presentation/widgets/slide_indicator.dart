// lib/presentation/widgets/slide_indicator.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 현재 선택된 탭의 인덱스를 관리하는 간단한 Provider
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// 페이지 정보를 담는 간단한 클래스
class PageInfo {
  final String title;
  final IconData icon;
  const PageInfo(this.title, this.icon);
}

class SlideIndicator extends ConsumerWidget {
  final List<PageInfo> pages;
  final PageController pageController;

  const SlideIndicator({
    Key? key,
    required this.pages,
    required this.pageController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(selectedTabProvider);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(pages.length, (index) {
        final page = pages[index];
        final isSelected = index == currentIndex;
        final color = isSelected ? Theme.of(context).colorScheme.primary : Colors.grey;

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(selectedTabProvider.notifier).state = index;
            pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(page.icon, color: color, size: isSelected ? 24 : 20),
                Text(
                  page.title,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}