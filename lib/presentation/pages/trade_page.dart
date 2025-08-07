import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/trade_controller.dart';
import '../widgets/trade_tile.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../core/di/core_provider.dart';
import '../widgets/order_book_visual.dart';
import '../widgets/prediction_panel.dart';
import '../widgets/stream_status_monitor.dart';

/// 🚀 완전체 Trade Page - 고급 퀀트 분석 대시보드
class TradePage extends ConsumerStatefulWidget {
  const TradePage({Key? key}) : super(key: key);

  @override
  ConsumerState<TradePage> createState() => _TradePageState();
}

class _TradePageState extends ConsumerState<TradePage> with TickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tradeControllerProvider);
    final controller = ref.read(tradeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        toolbarHeight: 45, // 기본 56 → 45로 슬림하게
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36), // 기본 48 → 36으로 슬림하게
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), // 폰트 크기 축소
            tabs: const [
              Tab(icon: Icon(Icons.list, size: 18), text: 'Trade List'), // 아이콘 크기 축소
              Tab(icon: Icon(Icons.analytics, size: 18), text: 'Analytics'),
              Tab(icon: Icon(Icons.dashboard, size: 18), text: 'Dashboard'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTradeListTab(context, controller, state),
          _buildAnalyticsTab(context, ref),
          _buildDashboardTab(context, ref),
        ],
      ),
    );
  }

  // ===================================================================
  // 📊 Tab 1: Trade List (개선된 버전)
  // ===================================================================

  Widget _buildTradeListTab(BuildContext context, TradeController controller, TradeControllerState state) {
    return Column(
      children: [
        _buildEnhancedFilterSlider(context, controller, state),
        _buildStreamTypeSelector(context, ref),
        const Divider(height: 1),
        Expanded(child: _buildTradeList(context, state)),
      ],
    );
  }

  Widget _buildEnhancedFilterSlider(BuildContext context, TradeController controller, TradeControllerState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8), // 세로 마진 축소
      padding: const EdgeInsets.all(12), // 패딩 축소 16 → 12
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.indigo.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter: ${state.currentFilter.displayName}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith( // titleMedium → titleSmall
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // 패딩 축소
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12), // 둥글기 축소
                ),
                child: Text(
                  '${state.trades.length} trades',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 11, // 폰트 크기 축소 12 → 11
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4), // 간격 축소 8 → 4
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.indigo.shade400,
              inactiveTrackColor: Colors.indigo.shade100,
              thumbColor: Colors.indigo.shade600,
              overlayColor: Colors.indigo.shade100,
              trackHeight: 3.0, // 트랙 높이 축소
            ),
            child: Slider(
              value: state.selectedFilterIndex.toDouble(),
              min: 0,
              max: (controller.availableFilters.length - 1).toDouble(),
              divisions: controller.availableFilters.length - 1,
              label: state.currentFilter.displayName,
              onChanged: (value) {
                final newFilter = controller.availableFilters[value.round()];
                controller.setThreshold(newFilter);
              },
              onChangeEnd: (_) {
                HapticFeedback.mediumImpact();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamTypeSelector(BuildContext context, WidgetRef ref) {
    return Container(
      height: 50, // 높이 축소 60 → 50
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Stream Types:',
            style: Theme.of(context).textTheme.labelSmall?.copyWith( // labelMedium → labelSmall
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildStreamChip('aggTrade', Colors.green, '25/s'),
                _buildStreamChip('ticker', Colors.blue, '1/s'),
                _buildStreamChip('bookTicker', Colors.orange, '8/s'),
                _buildStreamChip('depth5', Colors.purple, '12/s'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamChip(String streamType, Color color, String count) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        label: Text('$streamType ($count)'),
        backgroundColor: color.withValues(alpha: 0.1),
        labelStyle: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTradeList(BuildContext context, TradeControllerState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading monster data...'),
          ],
        ),
      );
    }
    
    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text('Error: ${state.errorMessage}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(tradeControllerProvider.notifier).refresh();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (state.trades.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_empty, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No trades captured yet...\n(Threshold: ${state.currentFilter.displayName})',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ],
        ),
      );
    }
    
    return RawScrollbar(
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      thickness: 8,
      radius: const Radius.circular(4),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: state.trades.length,
        itemBuilder: (context, index) {
          return TradeTile(trade: state.trades[index]);
        },
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).dividerColor.withAlpha(25),
          indent: 16,
          endIndent: 16,
        ),
      ),
    );
  }

  // ===================================================================
  // 🧠 Tab 2: Analytics (퀀트 분석) - 완전 업그레이드!
  // ===================================================================

  Widget _buildAnalyticsTab(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsHeader(context),
          const SizedBox(height: 16),
          _buildQuickStats(context, ref),
          const SizedBox(height: 24),
          
          // 🎯 새로운 섹션: Order Flow 분석 (Order Book + 압력 분석)
          _buildOrderFlowSection(context, ref),
          const SizedBox(height: 24),
          
          // 🤖 새로운 섹션: AI 예측 패널
          _buildPredictionSection(context, ref),
          const SizedBox(height: 24),
          
          // 📊 기존 분석 카드들 (간소화)
          _buildAnalysisCards(context, ref),
        ],
      ),
    );
  }

  /// 🌊 Order Flow 분석 섹션 (Order Book + 압력 분석)
  Widget _buildOrderFlowSection(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
          final status = repository.getStatus();
          
          // 🎯 실제 마켓명 가져오기 (하드코딩 해결!)
          final currentMarkets = repository.getCurrentMarkets();
          final activeMarket = currentMarkets.isNotEmpty ? currentMarkets.first : 'BTCUSDT';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🌊 Order Flow Analysis',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              
              // 2열 레이아웃: Order Book + Order Flow 압력
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 왼쪽: Order Book Visual
                  Expanded(
                    flex: 3,
                    child: OrderBookVisual(
                      market: activeMarket, // 🎯 실제 마켓 사용!
                      height: 350,
                    ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // 오른쪽: Order Flow 압력 분석
                  Expanded(
                    flex: 2,
                    child: _buildOrderFlowPressure(context, ref, activeMarket), // 마켓 전달
                  ),
                ],
              ),
            ],
          );
        } catch (e) {
          return _buildOrderFlowError();
        }
      },
    );
  }

  /// 🎯 Order Flow 압력 분석 위젯
  Widget _buildOrderFlowPressure(BuildContext context, WidgetRef ref, String market) {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
          final volatilityData = repository.getVolatilityData(market); // 🎯 실제 마켓 사용!
          
          if (volatilityData == null) {
            return _buildOrderFlowPlaceholder();
          }

          return Container(
            height: 350,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 헤더
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.trending_up,
                        color: Colors.blue.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Order Pressure',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Buy Pressure
                _buildPressureBar(
                  context,
                  'Buy Pressure',
                  volatilityData.buyPressure,
                  Colors.green,
                ),
                
                const SizedBox(height: 16),
                
                // Sell Pressure  
                _buildPressureBar(
                  context,
                  'Sell Pressure',
                  volatilityData.sellPressure,
                  Colors.red,
                ),
                
                const SizedBox(height: 24),
                
                // 불균형 정보
                _buildImbalanceSection(context, volatilityData),
                
                const Spacer(),
                
                // 압력 변화 트렌드
                _buildPressureChange(context, volatilityData),
              ],
            ),
          );
        } catch (e) {
          return _buildOrderFlowPlaceholder();
        }
      },
    );
  }

  /// 📊 압력 바 차트
  Widget _buildPressureBar(BuildContext context, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
            Text(
              '${value.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 12,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.6),
                    color,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// ⚖️ 불균형 섹션
  Widget _buildImbalanceSection(BuildContext context, VolatilityData volatilityData) {
    final imbalance = volatilityData.imbalance;
    final isPositive = imbalance > 0;
    final absImbalance = imbalance.abs();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Imbalance',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: 16,
                color: isPositive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${imbalance.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
              const Spacer(),
              Text(
                isPositive ? 'Buy Heavy' : 'Sell Heavy',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 📈 압력 변화 트렌드
  Widget _buildPressureChange(BuildContext context, VolatilityData volatilityData) {
    Color changeColor;
    IconData changeIcon;
    String changeText;
    
    switch (volatilityData.pressureChange) {
      case 'increasing':
        changeColor = Colors.green;
        changeIcon = Icons.arrow_upward;
        changeText = 'Pressure Increasing';
        break;
      case 'decreasing':
        changeColor = Colors.red;
        changeIcon = Icons.arrow_downward;
        changeText = 'Pressure Decreasing';
        break;
      default:
        changeColor = Colors.grey;
        changeIcon = Icons.remove;
        changeText = 'Pressure Stable';
    }

    return Row(
      children: [
        Icon(changeIcon, size: 14, color: changeColor),
        const SizedBox(width: 6),
        Text(
          changeText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: changeColor,
          ),
        ),
        const Spacer(),
        Text(
          'Last update: ${_formatTime(volatilityData.timestamp)}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }

  /// 📝 Order Flow 플레이스홀더
  Widget _buildOrderFlowPlaceholder() {
    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 12),
            Text(
              'Order Flow Analysis',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Waiting for depth5 stream data...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ Order Flow 에러
  Widget _buildOrderFlowError() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red.shade400, size: 32),
            const SizedBox(height: 8),
            Text(
              'Order Flow Error',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Failed to load market data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ❌ Prediction 에러
  Widget _buildPredictionError() {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology, color: Colors.purple.shade400, size: 32),
            const SizedBox(height: 8),
            Text(
              'AI Prediction Error',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Failed to load prediction data',
              style: TextStyle(
                fontSize: 12,
                color: Colors.purple.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🤖 AI 예측 섹션
  Widget _buildPredictionSection(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
          
          // 🎯 실제 마켓명 가져오기
          final currentMarkets = repository.getCurrentMarkets();
          final activeMarket = currentMarkets.isNotEmpty ? currentMarkets.first : 'BTCUSDT';
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🤖 AI Market Prediction',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 16),
              
              // 예측 패널
              PredictionPanel(
                market: activeMarket, // 🎯 실제 마켓 사용!
                height: 320,
              ),
            ],
          );
        } catch (e) {
          return _buildPredictionError();
        }
      },
    );
  }

  /// 🕒 시간 포맷팅 헬퍼
  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }

  Widget _buildAnalyticsHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.analytics, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quant Analytics Engine',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time market analysis powered by AI',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
          final quantSummary = repository.getQuantSummary();
          final predictionSummary = repository.getPredictionSummary();

          return Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Markets',
                  '${quantSummary['totalMarkets']}',
                  '${quantSummary['activeAnalysis']} active',
                  Colors.blue,
                  Icons.show_chart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Bullish',
                  '${quantSummary['bullishMarkets']}',
                  '${_calculatePercentage(quantSummary['bullishMarkets'], quantSummary['totalMarkets'])}%',
                  Colors.green,
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Bearish',
                  '${quantSummary['bearishMarkets']}',
                  '${_calculatePercentage(quantSummary['bearishMarkets'], quantSummary['totalMarkets'])}%',
                  Colors.red,
                  Icons.trending_down,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Confi',
                  '${predictionSummary['avgConfidence'].toStringAsFixed(0)}',
                  '${predictionSummary['highConfidencePredictions']} high',
                  Colors.purple,
                  Icons.psychology,
                ),
              ),
            ],
          );
        } catch (e) {
          return _buildLoadingStats();
        }
      },
    );
  }

  Widget _buildLoadingStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(context, 'Markets', '--', 'Loading...', Colors.grey, Icons.show_chart)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(context, 'Bullish', '--', 'Loading...', Colors.grey, Icons.trending_up)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(context, 'Bearish', '--', 'Loading...', Colors.grey, Icons.trending_down)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(context, 'Confi', '--', 'Loading...', Colors.grey, Icons.psychology)),
      ],
    );
  }

  String _calculatePercentage(dynamic numerator, dynamic denominator) {
    if (denominator == 0) return '0';
    return ((numerator / denominator) * 100).toStringAsFixed(0);
  }

  Widget _buildStatCard(BuildContext context, String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisCards(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        try {
          final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
          
          return Column(
            children: [
              StreamBuilder(
                stream: repository.quantAnalysisStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildAnalysisPlaceholder('Momentum Analysis', 'Waiting for data...');
                  }

                  final analysis = snapshot.data;
                  if (analysis?.momentum == null) {
                    return _buildAnalysisPlaceholder('Momentum Analysis', 'No momentum data available');
                  }

                  final momentum = analysis!.momentum!;

                  return _buildAnalysisCard(
                    context,
                    'Momentum Analysis',
                    'Market: ${analysis.market}',
                    [
                      _buildAnalysisRow('Direction', momentum.direction, _getDirectionColor(momentum.direction)),
                      _buildAnalysisRow('Score', momentum.score.toStringAsFixed(1), Colors.blue),
                      _buildAnalysisRow('Confidence', '${momentum.confidence.toStringAsFixed(0)}%', Colors.green),
                    ],
                    Icons.speed,
                    Colors.orange,
                  );
                },
              ),
              const SizedBox(height: 16),
              StreamBuilder(
                stream: repository.predictionStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return _buildAnalysisPlaceholder('AI Prediction', 'Processing...');
                  }

                  final prediction = snapshot.data;
                  if (prediction == null) {
                    return _buildAnalysisPlaceholder('AI Prediction', 'No prediction data available');
                  }

                  return _buildAnalysisCard(
                    context,
                    'AI Prediction',
                    'Market: ${prediction.market} (${prediction.timeframe})',
                    [
                      _buildAnalysisRow('Direction', prediction.direction, _getDirectionColor(prediction.direction)),
                      _buildAnalysisRow('Probability', '${prediction.probability.toStringAsFixed(0)}%', Colors.purple),
                      _buildAnalysisRow('Target', '\${prediction.targetPrice.toStringAsFixed(2)}', Colors.green),
                    ],
                    Icons.psychology,
                    Colors.deepPurple,
                  );
                },
              ),
            ],
          );
        } catch (e) {
          return _buildAnalysisPlaceholder('Analysis Error', 'Failed to load analysis data');
        }
      },
    );
  }

  Widget _buildAnalysisCard(BuildContext context, String title, String subtitle, List<Widget> rows, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...rows,
        ],
      ),
    );
  }

  Widget _buildAnalysisPlaceholder(String title, String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 📊 Tab 3: Dashboard (시스템 모니터링) - 완전 업그레이드!
  // ===================================================================

  Widget _buildDashboardTab(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDashboardHeader(context),
          const SizedBox(height: 16),
          _buildRealTimeMetrics(context, ref),
          const SizedBox(height: 16),
          
          // 🎯 새로운 섹션: 실시간 스트림 상태 모니터
          StreamStatusMonitor(
            height: 280, // 250 → 280으로 증가 (30px 추가)
            showDetails: true,
          ),
          
          const SizedBox(height: 16),
          _buildSystemHealth(context, ref),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.dashboard, color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monster Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real-time system monitoring & performance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.circle, color: Colors.green, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeMetrics(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final stats = ref.watch(tradeStatsProvider);
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Real-time Performance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      'Processed/sec',
                      '${stats['processedPerSecond'] ?? "0"}',
                      Icons.speed,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Filtered/sec',
                      '${stats['filteredPerSecond'] ?? "0"}',
                      Icons.filter_alt,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Total',
                      '${stats['processedCount'] ?? "0"}',
                      Icons.analytics,
                      Colors.orange,
                    ),
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      'Cache',
                      '${stats['filterCacheSize'] ?? "0"}',
                      Icons.storage,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSystemHealth(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final repositoryStatus = ref.watch(repositoryStatusProvider);
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Health',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildHealthItem(
                'Repository',
                repositoryStatus['isInitialized'] == true ? 'Healthy' : 'Initializing',
                repositoryStatus['isInitialized'] == true ? Colors.green : Colors.orange,
                Icons.storage,
              ),
              _buildHealthItem(
                'Markets',
                '${repositoryStatus['currentMarkets']} active',
                Colors.blue,
                Icons.public,
              ),
              _buildHealthItem(
                'Memory',
                '${repositoryStatus['seenIdsCount']} cached',
                Colors.purple,
                Icons.memory,
              ),
              _buildHealthItem(
                'Last Update',
                _formatLastUpdate(repositoryStatus['lastUpdateTime']),
                Colors.green,
                Icons.access_time,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthItem(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // 🎨 헬퍼 메서드들
  // ===================================================================

  Color _getDirectionColor(String direction) {
    switch (direction.toLowerCase()) {
      case 'bullish':
      case 'up':
        return Colors.green;
      case 'bearish':
      case 'down':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatLastUpdate(String? timestamp) {
    if (timestamp == null) return 'Never';
    
    try {
      final time = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(time);
      
      if (diff.inSeconds < 60) {
        return '${diff.inSeconds}s ago';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}m ago';
      } else {
        return '${diff.inHours}h ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}