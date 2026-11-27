import 'package:flutter/material.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/player/presentation/player_hud_state.dart';

/// Displays live gesture HUD feedback (Brightness, Volume/Boost, Seek Preview,
/// Double-Tap Seek, and transient action toasts) without blocking touches.
class PlayerHudOverlay extends StatelessWidget {
  final PlayerHudState hudState;

  const PlayerHudOverlay({super.key, required this.hudState});

  @override
  Widget build(BuildContext context) {
    if (!hudState.isVisible) return const SizedBox.shrink();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hudState.type == HudFeedbackType.brightness)
            Center(child: _BrightnessHudCard(brightness: hudState.brightness)),
          if (hudState.type == HudFeedbackType.volume)
            Center(child: _VolumeHudCard(volumePercent: hudState.volumePercent)),
          if (hudState.type == HudFeedbackType.seekPreview)
            Center(
              child: _SeekPreviewCard(
                target: hudState.seekTarget,
                delta: hudState.seekDelta,
                duration: hudState.mediaDuration,
              ),
            ),
          if (hudState.type == HudFeedbackType.doubleTapSeek)
            Align(
              alignment: hudState.doubleTapForward
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 42),
                child: _DoubleTapBadge(
                  forward: hudState.doubleTapForward,
                  delta: hudState.seekDelta,
                ),
              ),
            ),
          if (hudState.type == HudFeedbackType.toast &&
              hudState.toastMessage != null)
            Align(
              alignment: const Alignment(0, -0.72),
              child: _ToastPill(message: hudState.toastMessage!),
            ),
        ],
      ),
    );
  }
}

class _BrightnessHudCard extends StatelessWidget {
  final double brightness;

  const _BrightnessHudCard({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final percent = (brightness * 100).round().clamp(0, 100);
    return _HudGlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            percent == 0
                ? Icons.brightness_low_rounded
                : (percent < 50
                      ? Icons.brightness_medium_rounded
                      : Icons.brightness_high_rounded),
            color: AppTheme.accentSecondary,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            'Brightness $percent%',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: brightness.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppTheme.accentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeHudCard extends StatelessWidget {
  final double volumePercent;

  const _VolumeHudCard({required this.volumePercent});

  @override
  Widget build(BuildContext context) {
    final rounded = volumePercent.round().clamp(0, 200);
    final isBoosted = rounded > 100;
    final baseRatio = (rounded / 100.0).clamp(0.0, 1.0);
    final boostRatio = ((rounded - 100) / 100.0).clamp(0.0, 1.0);

    return _HudGlassContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            rounded == 0
                ? Icons.volume_off_rounded
                : (isBoosted
                      ? Icons.graphic_eq_rounded
                      : Icons.volume_up_rounded),
            color: isBoosted ? AppTheme.accentSecondary : AppTheme.accent,
            size: 30,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Volume $rounded%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (isBoosted) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accentSecondary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'BOOST',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: baseRatio,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
          if (isBoosted) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: boostRatio,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SeekPreviewCard extends StatelessWidget {
  final Duration target;
  final Duration delta;
  final Duration duration;

  const _SeekPreviewCard({
    required this.target,
    required this.delta,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = duration.inMilliseconds > 0
        ? (target.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    return _HudGlassContainer(
      width: 210,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DurationFormatter.format(target),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            DurationFormatter.formatSignedSeconds(delta),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoubleTapBadge extends StatelessWidget {
  final bool forward;
  final Duration delta;

  const _DoubleTapBadge({required this.forward, required this.delta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            forward ? Icons.fast_forward_rounded : Icons.fast_rewind_rounded,
            color: AppTheme.textPrimary,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            DurationFormatter.formatSignedSeconds(delta),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToastPill extends StatelessWidget {
  final String message;

  const _ToastPill({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

class _HudGlassContainer extends StatelessWidget {
  final Widget child;
  final double width;

  const _HudGlassContainer({required this.child, this.width = 176});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: child,
    );
  }
}
