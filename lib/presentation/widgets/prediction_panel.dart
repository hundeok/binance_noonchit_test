// lib/presentation/widgets/prediction_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/trade_repository_impl.dart';
import '../../core/di/core_provider.dart';
import '../../domain/entities/trade.dart';

/// 🤖 고급 AI 예측 패널 - React 시뮬레이션 완벽 재현
class PredictionPanel extends ConsumerWidget {
  final String market;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const PredictionPanel({
    Key? key,
    required this.market,
    this.height,
    this.padding,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: height ?? 320,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<PredictionResult>(
        stream: _getPredictionStream(ref),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildLoadingState(context);
          }

          final prediction = snapshot.data!;
          return _buildPredictionContent(context, prediction);
        },
      ),
    );
  }

  /// 🎯 예측 스트림 가져오기
  Stream<PredictionResult> _getPredictionStream(WidgetRef ref) {
    try {
      final repository = ref.watch(tradeRepositoryProvider) as TradeRepositoryImpl;
      return repository.predictionStream
          .where((prediction) => prediction.market == market);
    } catch (e) {
      return Stream.empty();
    }
  }

  /// 🎨 예측 콘텐츠 구축
  Widget _buildPredictionContent(BuildContext context, PredictionResult prediction) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 20),
        _buildDirectionAndConfidence(context, prediction),
        const SizedBox(height: 20),
        _buildTargetPrice(context, prediction),
        const SizedBox(height: 16),
        _buildPredictionDetails(context, prediction),
        const Spacer(),
        _buildFooter(context, prediction),
      ],
    );
  }

  /// 📝 헤더 섹션
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.psychology,
            color: Colors.purple.shade600,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI Prediction',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                ),
              ),
              Text(
                'Machine Learning Analysis',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.purple.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  /// 🎯 방향성과 신뢰도 섹션
  Widget _buildDirectionAndConfidence(BuildContext context, PredictionResult prediction) {
    return Row(
      children: [
        // 왼쪽: 방향성
        Expanded(
          child: _buildDirectionCard(context, prediction),
        ),
        const SizedBox(width: 16),
        // 오른쪽: 신뢰도
        Expanded(
          child: _buildConfidenceCard(context, prediction),
        ),
      ],
    );
  }

  /// 📈 방향성 카드
  Widget _buildDirectionCard(BuildContext context, PredictionResult prediction) {
    final direction = prediction.direction.toLowerCase();
    
    IconData icon;
    Color color;
    String displayText;
    
    switch (direction) {
      case 'up':
        icon = Icons.trending_up;
        color = Colors.green;
        displayText = 'BULLISH';
        break;
      case 'down':
        icon = Icons.trending_down;
        color = Colors.red;
        displayText = 'BEARISH';
        break;
      default:
        icon = Icons.trending_flat;
        color = Colors.orange;
        displayText = 'SIDEWAYS';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Direction',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            displayText,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 📊 신뢰도 카드
  Widget _buildConfidenceCard(BuildContext context, PredictionResult prediction) {
    final confidence = prediction.probability;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        children: [
          Text(
            'Confidence',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // 원형 진행률 표시기
          SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              children: [
                CircularProgressIndicator(
                  value: confidence / 100,
                  strokeWidth: 4,
                  backgroundColor: Colors.purple.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade600),
                ),
                Center(
                  child: Text(
                    '${confidence.toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getConfidenceColor(confidence).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _getConfidenceLevel(confidence),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getConfidenceColor(confidence),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 목표가 섹션
  Widget _buildTargetPrice(BuildContext context, PredictionResult prediction) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flag, color: Colors.green.shade600, size: 16),
              const SizedBox(width: 6),
              Text(
                'Target Price',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                prediction.timeframe,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${prediction.targetPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Expected price movement based on current analysis',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// 📋 예측 세부사항
  Widget _buildPredictionDetails(BuildContext context, PredictionResult prediction) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        children: [
          _buildDetailRow('Market', prediction.market),
          _buildDetailRow('Timeframe', prediction.timeframe),
          _buildDetailRow('Algorithm', 'Momentum + Trend Analysis'),
          _buildDetailRow('Risk Level', _getRiskLevel(prediction.probability)),
        ],
      ),
    );
  }

  /// 📊 세부사항 행
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade700,
            ),
          ),
        ],
      ),
    );
  }

  /// 🕒 푸터 (타임스탬프)
  Widget _buildFooter(BuildContext context, PredictionResult prediction) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Text(
          'Updated ${_formatTime(prediction.timestamp)}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'AI v2.1',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.purple.shade600,
            ),
          ),
        ),
      ],
    );
  }

  /// ⏳ 로딩 상태
  Widget _buildLoadingState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildHeader(context),
        const Spacer(),
        CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.purple.shade400),
        ),
        const SizedBox(height: 16),
        Text(
          'AI is analyzing...',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.purple.shade600,
          ),
        ),
        Text(
          'Processing market data and trends',
          style: TextStyle(
            fontSize: 12,
            color: Colors.purple.shade500,
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // ===================================================================
  // 🎨 헬퍼 메서드들
  // ===================================================================

  /// 신뢰도 색상 계산
  Color _getConfidenceColor(double confidence) {
    if (confidence >= 80) return Colors.green;
    if (confidence >= 65) return Colors.orange;
    return Colors.red;
  }

  /// 신뢰도 레벨 텍스트
  String _getConfidenceLevel(double confidence) {
    if (confidence >= 80) return 'HIGH';
    if (confidence >= 65) return 'MEDIUM';
    return 'LOW';
  }

  /// 리스크 레벨 계산
  String _getRiskLevel(double confidence) {
    if (confidence >= 80) return 'Low Risk';
    if (confidence >= 65) return 'Medium Risk';
    return 'High Risk';
  }

  /// 시간 포맷팅
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
}

// ===================================================================
// 🎨 사용법 예시
// ===================================================================

/// 사용 예시:
/// ```dart
/// PredictionPanel(
///   market: 'BTCUSDT',
///   height: 350,
///   padding: EdgeInsets.all(20),
/// )
/// ```