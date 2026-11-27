import 'package:flutter/material.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/player/domain/ab_loop_range.dart';

/// Interactive cinema seek bar with buffer track, A-B loop pins, and
/// floating live timestamp preview while dragging.
class PlayerSeekBar extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final Duration buffer;
  final ABLoopRange abLoop;
  final VoidCallback onScrubStart;
  final ValueChanged<Duration> onScrubEnd;
  final ValueChanged<Duration>? onScrubUpdate;

  const PlayerSeekBar({
    super.key,
    required this.position,
    required this.duration,
    required this.buffer,
    required this.abLoop,
    required this.onScrubStart,
    required this.onScrubEnd,
    this.onScrubUpdate,
  });

  @override
  State<PlayerSeekBar> createState() => _PlayerSeekBarState();
}

class _PlayerSeekBarState extends State<PlayerSeekBar> {
  bool _dragging = false;
  double _dragRatio = 0.0;

  double get _effectiveRatio {
    if (_dragging) return _dragRatio;
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return 0.0;
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  Duration _ratioToDuration(double ratio) {
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) return Duration.zero;
    return Duration(milliseconds: (ratio.clamp(0.0, 1.0) * totalMs).round());
  }

  void _updateFromLocalX(double localX, double width) {
    if (width <= 0) return;
    final nextRatio = (localX / width).clamp(0.0, 1.0);
    setState(() => _dragRatio = nextRatio);
    widget.onScrubUpdate?.call(_ratioToDuration(nextRatio));
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.duration.inMilliseconds;
    final bufferRatio = totalMs > 0
        ? (widget.buffer.inMilliseconds / totalMs).clamp(0.0, 1.0)
        : 0.0;
    final playedRatio = _effectiveRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final previewTime = _ratioToDuration(playedRatio);
        final thumbX = (playedRatio * trackWidth).clamp(0.0, trackWidth);

        final loopA = widget.abLoop.pointA;
        final loopB = widget.abLoop.pointB;
        final loopARatio = (loopA != null && totalMs > 0)
            ? (loopA.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : null;
        final loopBRatio = (loopB != null && totalMs > 0)
            ? (loopB.inMilliseconds / totalMs).clamp(0.0, 1.0)
            : null;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            setState(() => _dragging = true);
            widget.onScrubStart();
            _updateFromLocalX(details.localPosition.dx, trackWidth);
          },
          onHorizontalDragUpdate: (details) {
            _updateFromLocalX(details.localPosition.dx, trackWidth);
          },
          onHorizontalDragEnd: (_) {
            final target = _ratioToDuration(_dragRatio);
            setState(() => _dragging = false);
            widget.onScrubEnd(target);
          },
          onHorizontalDragCancel: () {
            setState(() => _dragging = false);
            widget.onScrubEnd(widget.position);
          },
          onTapDown: (details) {
            final target = _ratioToDuration(
              (details.localPosition.dx / trackWidth).clamp(0.0, 1.0),
            );
            widget.onScrubEnd(target);
          },
          child: SizedBox(
            height: 40,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                if (_dragging)
                  Positioned(
                    left: (thumbX - 34).clamp(0.0, (trackWidth - 68).clamp(0.0, trackWidth)),
                    top: -32,
                    child: Container(
                      width: 68,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppTheme.accent.withValues(alpha: 0.7),
                        ),
                      ),
                      child: Text(
                        DurationFormatter.format(previewTime),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                Container(
                  height: _dragging ? 5.5 : 4.0,
                  width: trackWidth,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Container(
                  height: _dragging ? 5.5 : 4.0,
                  width: trackWidth * bufferRatio,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                if (loopARatio != null && loopBRatio != null)
                  Positioned(
                    left: trackWidth * loopARatio,
                    child: Container(
                      height: _dragging ? 5.5 : 4.0,
                      width: ((loopBRatio - loopARatio) * trackWidth).clamp(
                        0.0,
                        trackWidth,
                      ),
                      color: AppTheme.accentSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                Container(
                  height: _dragging ? 5.5 : 4.0,
                  width: trackWidth * playedRatio,
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                if (loopARatio != null)
                  Positioned(
                    left: (trackWidth * loopARatio - 1.5).clamp(0.0, trackWidth),
                    child: Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                if (loopBRatio != null)
                  Positioned(
                    left: (trackWidth * loopBRatio - 1.5).clamp(0.0, trackWidth),
                    child: Container(
                      width: 3,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppTheme.accentSecondary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                Positioned(
                  left: (thumbX - (_dragging ? 8.5 : 6.5)).clamp(
                    0.0,
                    (trackWidth - 17).clamp(0.0, trackWidth),
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: _dragging ? 17 : 13,
                    height: _dragging ? 17 : 13,
                    decoration: BoxDecoration(
                      color: AppTheme.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
