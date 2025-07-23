import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/volume.dart';

final Map<String, int> _previousRanks = {};

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

class _VolumeTileState extends State<VolumeTile> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  static final _volumeFormatter = NumberFormat.compact(locale: 'en_US');

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 750),
      vsync: this,
    );
    _colorAnimation = ColorTween(begin: Colors.transparent, end: Colors.transparent)
        .animate(_animationController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkRankChange();
    });
  }

  @override
  void didUpdateWidget(VolumeTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rank != oldWidget.rank) {
      _checkRankChange();
    }
  }

  void _checkRankChange() {
    final previousRank = _previousRanks[widget.volume.market];
    final currentRank = widget.rank;
    
    if (previousRank != null && currentRank < previousRank) {
      _colorAnimation = ColorTween(
        begin: Colors.green.withAlpha(102), // 0.4 opacity
        end: Colors.transparent,
      ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));
      _animationController.forward(from: 0.0);
    }
    
    _previousRanks[widget.volume.market] = currentRank;
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Color _getRankColor(BuildContext context) {
    if (widget.rank <= 3) return Colors.amber.shade600;
    if (widget.rank <= 10) return Theme.of(context).colorScheme.primary;
    // ✅ [수정] .withOpacity -> .withAlpha로 변경
    return Theme.of(context).colorScheme.onSurface.withAlpha(179); // 0.7 opacity
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rankColor = _getRankColor(context);

    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3.0),
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          children: [
            Text(
              '${widget.rank}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: rankColor,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 4,
              child: Text(
                widget.volume.ticker,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 5,
              child: Text(
                '\$${_volumeFormatter.format(widget.volume.totalValue)}',
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}