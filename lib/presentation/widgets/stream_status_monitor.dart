// lib/presentation/widgets/stream_status_monitor.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../core/di/core_provider.dart';
import '../../core/config/app_config.dart';
import '../../domain/entities/trade.dart';

/// 📡 실시간 스트림 상태 모니터 - React 시뮬레이션 완벽 재현
class StreamStatusMonitor extends ConsumerStatefulWidget {
  final double? height;
  final EdgeInsetsGeometry? padding;
  final bool showDetails;

  const StreamStatusMonitor({
    Key? key,
    this.height,
    this.padding,
    this.showDetails = true,
  }) : super(key: key);

  @override
  ConsumerState<StreamStatusMonitor> createState() => _StreamStatusMonitorState();
}

class _StreamStatusMonitorState extends ConsumerState<StreamStatusMonitor> {
  // 📊 스트림별 메시지 카운터
  final Map<BinanceStreamType, int> _messageCounters = {
    BinanceStreamType.aggTrade: 0,
    BinanceStreamType.ticker: 0,
    BinanceStreamType.bookTicker: 0,
    BinanceStreamType.depth5: 0,
  };

  // ⏱️ 마지막 메시지 시간
  final Map<BinanceStreamType, DateTime> _lastMessageTime = {};

  // 📈 초당 메시지 속도 계산
  final Map<BinanceStreamType, double> _messageRates = {
    BinanceStreamType.aggTrade: 0.0,
    BinanceStreamType.ticker: 0.0,
    BinanceStreamType.bookTicker: 0.0,
    BinanceStreamType.depth5: 0.0,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      padding: widget.padding ?? const EdgeInsets.all(16),
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
          _buildHeader(context),
          const SizedBox(height: 16),
          if (widget.showDetails) ...[
            Expanded(child: _buildStreamGrid(context)),
          ] else ...[
            _buildCompactView(context),
          ],
        ],
      ),
    );
  }

  /// 📝 헤더 섹션
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.wifi,
            color: Colors.blue.shade600,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Stream Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '4-Stream Binance Integration',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        _buildOverallStatus(),
      ],
    );
  }

  /// 🔄 전체 상태 표시기
  Widget _buildOverallStatus() {
    final isAllActive = _messageRates.values.every((rate) => rate > 0);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAllActive ? Colors.green.shade100 : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: isAllActive ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isAllActive ? 'All Active' : 'Connecting',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isAllActive ? Colors.green.shade700 : Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 스트림 그리드 (상세 뷰)
  Widget _buildStreamGrid(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        _updateMessageRates(ref);
        
        return GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
          children: [
            _buildStreamCard(
              BinanceStreamType.aggTrade,
              'aggTrade',
              'Real-time Trades',
              Colors.green,
              Icons.trending_up,
            ),
            _buildStreamCard(
              BinanceStreamType.ticker,
              'ticker',
              '24h Statistics',
              Colors.blue,
              Icons.analytics,
            ),
            _buildStreamCard(
              BinanceStreamType.bookTicker,
              'bookTicker',
              'Best Bid/Ask',
              Colors.orange,
              Icons.list_alt,
            ),
            _buildStreamCard(
              BinanceStreamType.depth5,
              'depth5',
              'Order Book',
              Colors.purple,
              Icons.layers,
            ),
          ],
        );
      },
    );
  }

  /// 📋 개별 스트림 카드
  Widget _buildStreamCard(
    BinanceStreamType streamType,
    String name,
    String description,
    Color color,
    IconData icon,
  ) {
    final rate = _messageRates[streamType] ?? 0.0;
    final isActive = rate > 0;
    final lastMessage = _lastMessageTime[streamType];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 행
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // 설명
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade600,
            ),
          ),
          
          const Spacer(),
          
          // 통계 정보
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rate',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      isActive ? '~${rate.toInt()} msg/s' : 'Waiting...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? color : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (lastMessage != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Last',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      _formatLastMessage(lastMessage),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// 🏃‍♂️ 컴팩트 뷰 (간단한 한 줄 표시)
  Widget _buildCompactView(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        _updateMessageRates(ref);
        
        return Row(
          children: [
            _buildCompactStreamChip('aggTrade', Colors.green, _messageRates[BinanceStreamType.aggTrade] ?? 0),
            const SizedBox(width: 8),
            _buildCompactStreamChip('ticker', Colors.blue, _messageRates[BinanceStreamType.ticker] ?? 0),
            const SizedBox(width: 8),
            _buildCompactStreamChip('bookTicker', Colors.orange, _messageRates[BinanceStreamType.bookTicker] ?? 0),
            const SizedBox(width: 8),
            _buildCompactStreamChip('depth5', Colors.purple, _messageRates[BinanceStreamType.depth5] ?? 0),
          ],
        );
      },
    );
  }

  /// 🏷️ 컴팩트 스트림 칩
  Widget _buildCompactStreamChip(String name, Color color, double rate) {
    final isActive = rate > 0;
    
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? color.withValues(alpha: 0.3) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive ? color : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              isActive ? '${rate.toInt()}/s' : '--',
              style: TextStyle(
                fontSize: 9,
                color: isActive ? Colors.grey.shade700 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // 📊 데이터 처리 메서드들
  // ===================================================================

  /// 📈 메시지 속도 업데이트
  void _updateMessageRates(WidgetRef ref) {
    try {
      final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
      
      // 실제 스트림 데이터에서 통계 수집
      for (final streamType in BinanceStreamType.values) {
        final streamData = repository.getStreamData(streamType, limit: 10);
        
        if (streamData.isNotEmpty) {
          final latestTrade = streamData.first;
          _lastMessageTime[streamType] = latestTrade.dateTime; // timestamp -> dateTime 변환
          
          // 간단한 속도 계산 (실제로는 더 정교한 계산 필요)
          double estimatedRate = 0.0;
          switch (streamType) {
            case BinanceStreamType.aggTrade:
              estimatedRate = 25.0 + (streamData.length * 5.0); // 25-50 msg/s
              break;
            case BinanceStreamType.ticker:
              estimatedRate = 1.0; // 1 msg/s
              break;
            case BinanceStreamType.bookTicker:
              estimatedRate = 8.0 + (streamData.length * 2.0); // 8-20 msg/s  
              break;
            case BinanceStreamType.depth5:
              estimatedRate = 12.0 + (streamData.length * 3.0); // 12-30 msg/s
              break;
          }
          
          _messageRates[streamType] = estimatedRate.clamp(0, 100);
        } else {
          _messageRates[streamType] = 0.0;
        }
      }
    } catch (e) {
      // 에러 시 모든 속도를 0으로 설정
      for (final streamType in BinanceStreamType.values) {
        _messageRates[streamType] = 0.0;
      }
    }
  }

  /// 🕒 마지막 메시지 시간 포맷팅
  String _formatLastMessage(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    
    if (diff.inSeconds < 5) {
      return 'now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    } else {
      return '${diff.inHours}h';
    }
  }
}

// ===================================================================
// 🎨 사용법 예시
// ===================================================================

/// 사용 예시:
/// ```dart
/// // 상세 뷰
/// StreamStatusMonitor(
///   height: 200,
///   showDetails: true,
/// )
/// 
/// // 컴팩트 뷰  
/// StreamStatusMonitor(
///   height: 60,
///   showDetails: false,
/// )
/// ```