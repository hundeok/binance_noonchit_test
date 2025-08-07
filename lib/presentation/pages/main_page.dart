// lib/presentation/pages/main_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common_app_bar.dart';
import '../widgets/slide_indicator.dart';
import 'trade_page.dart';
// import 'volume_page.dart';  // ✅ 임시 비활성화

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
        children: [
          // ✅ 페이지 위젯 목록
          const TradePage(),
          
          // ✅ 임시 더미 볼륨 페이지 (실제 작동 안함)
          _buildTempVolumePage(),
        ],
      ),
    );
  }

  /// 🚧 임시 볼륨 페이지 (실제 작동하지 않음)
  Widget _buildTempVolumePage() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Volume Ranking (Under Development)'),
        backgroundColor: Colors.orange.shade100,
        elevation: 1,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🚧 공사중 아이콘
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.orange.shade600,
            ),
            
            const SizedBox(height: 24),
            
            // 제목
            Text(
              '🚧 Under Development',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 설명
            Text(
              'Volume ranking feature is currently being optimized.\nPlease use the Trade tab for now.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 현재 작업 상태
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Current Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  _buildStatusItem('✅', 'Trade page optimization', 'Completed'),
                  _buildStatusItem('🔄', 'Volume calculation logic', 'In Progress'),
                  _buildStatusItem('⏳', 'UI performance tuning', 'Pending'),
                  _buildStatusItem('⏳', 'Real-time volume ranking', 'Pending'),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // 트레이드 페이지로 이동 버튼
            ElevatedButton.icon(
              onPressed: () {
                _pageController.animateToPage(
                  0, // Trade page
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              icon: const Icon(Icons.list_alt_rounded),
              label: const Text('Go to Trade Page'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 상태 아이템 빌더
  Widget _buildStatusItem(String emoji, String task, String status) {
    Color statusColor;
    switch (status) {
      case 'Completed':
        statusColor = Colors.green.shade600;
        break;
      case 'In Progress':
        statusColor = Colors.orange.shade600;
        break;
      default:
        statusColor = Colors.grey.shade500;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              task,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(51), // 0.2 opacity
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}