import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/volume.dart';

class VolumeTile extends StatefulWidget {
  final Volume volume;
  final int rank;

  const VolumeTile({
    Key? key,
    required this.volume,
    required this.rank,
  }) : super(key: key);

  @override
  State<VolumeTile> createState() => _VolumeTileState();
}

class _VolumeTileState extends State<VolumeTile> {
  Timer? _timer;
  late int _remainingSeconds;

  // 숫자 포맷터
  static final _volumeFormatter = NumberFormat.compact(locale: 'en_US');

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.volume.remainingSeconds;
    // 1초마다 남은 시간을 다시 계산하여 UI를 업데이트
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final newRemaining = widget.volume.remainingSeconds;
      if (_remainingSeconds != newRemaining) {
        setState(() {
          _remainingSeconds = newRemaining;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  
  // 남은 시간을 mm:ss 형식으로 변환
  String get _formattedRemainingTime {
    if (_remainingSeconds <= 0) return '00:00';
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // 랭킹에 따른 색상
  Color _getRankColor(BuildContext context) {
    if (widget.rank <= 3) return Colors.amber.shade600;
    if (widget.rank <= 10) return Theme.of(context).colorScheme.primary;
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = _getRankColor(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          // 랭킹
          Text(
            '${widget.rank}',
            style: theme.textTheme.titleSmall?.copyWith(
              color: rankColor,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 16),
          // 코인 티커
          Expanded(
            flex: 3,
            child: Text(
              widget.volume.ticker,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // 누적 거래대금
          Expanded(
            flex: 5,
            child: Text(
              '\$${_volumeFormatter.format(widget.volume.totalValue)}',
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 남은 시간
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                _formattedRemainingTime,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}