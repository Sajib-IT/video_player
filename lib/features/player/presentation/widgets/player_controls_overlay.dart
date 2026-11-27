import 'package:flutter/material.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/player/presentation/player_view_controller.dart';
import 'package:video_player_app/features/player/presentation/widgets/player_seek_bar.dart';

/// Custom cinema player overlay with auto-hide controls, transport buttons,
/// seek bar, A-B loop toggle, Night Mode, Quick Mute, HW/SW decoder switch,
/// Sleep Timer, Background Audio, PiP, Cast, Screenshot, and Kids Touch Lock.
class PlayerControlsOverlay extends StatelessWidget {
  final PlayerSnapshot snapshot;
  final PlayerViewController viewController;
  final VoidCallback onBack;
  final VoidCallback onOpenSpeedSheet;
  final VoidCallback onOpenAspectRatioSheet;
  final VoidCallback onOpenTracksSheet;
  final VoidCallback? onOpenSleepTimerSheet;
  final VoidCallback? onOpenCastSheet;

  const PlayerControlsOverlay({
    super.key,
    required this.snapshot,
    required this.viewController,
    required this.onBack,
    required this.onOpenSpeedSheet,
    required this.onOpenAspectRatioSheet,
    required this.onOpenTracksSheet,
    this.onOpenSleepTimerSheet,
    this.onOpenCastSheet,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.isInPipMode) {
      return const SizedBox.shrink();
    }

    if (snapshot.isTouchLocked) {
      return _KidsTouchLockOverlay(
        hintVisible: viewController.unlockHintVisible,
        onUnlock: viewController.toggleTouchLock,
      );
    }

    final visible = viewController.controlsVisible;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 220),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _TopGradientBar(
              snapshot: snapshot,
              viewController: viewController,
              onBack: onBack,
              onOpenTracksSheet: onOpenTracksSheet,
              onOpenSpeedSheet: onOpenSpeedSheet,
              onOpenAspectRatioSheet: onOpenAspectRatioSheet,
              onOpenCastSheet: onOpenCastSheet,
            ),
            _CenterTransportBar(
              snapshot: snapshot,
              viewController: viewController,
            ),
            _BottomGradientBar(
              snapshot: snapshot,
              viewController: viewController,
              onOpenTracksSheet: onOpenTracksSheet,
              onOpenSleepTimerSheet: onOpenSleepTimerSheet,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopGradientBar extends StatelessWidget {
  final PlayerSnapshot snapshot;
  final PlayerViewController viewController;
  final VoidCallback onBack;
  final VoidCallback onOpenTracksSheet;
  final VoidCallback onOpenSpeedSheet;
  final VoidCallback onOpenAspectRatioSheet;
  final VoidCallback? onOpenCastSheet;

  const _TopGradientBar({
    required this.snapshot,
    required this.viewController,
    required this.onBack,
    required this.onOpenTracksSheet,
    required this.onOpenSpeedSheet,
    required this.onOpenAspectRatioSheet,
    this.onOpenCastSheet,
  });

  @override
  Widget build(BuildContext context) {
    final speedLabel =
        '${snapshot.playbackSpeed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}x';
    final maxActionClusterWidth =
        (MediaQuery.sizeOf(context).width * 0.65).clamp(180.0, 560.0);

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.78),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppTheme.textPrimary,
                  tooltip: 'Back',
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: Text(
                    snapshot.currentMedia?.title ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxActionClusterWidth),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onOpenCastSheet != null)
                          IconButton(
                            onPressed: onOpenCastSheet,
                            icon: const Icon(Icons.cast_rounded),
                            color: AppTheme.textPrimary,
                            tooltip: 'Cast to TV',
                            visualDensity: VisualDensity.compact,
                          ),
                        IconButton(
                          onPressed: viewController.toggleMute,
                          icon: Icon(
                            snapshot.isMuted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                          ),
                          color: snapshot.isMuted
                              ? AppTheme.accentSecondary
                              : AppTheme.textPrimary,
                          tooltip: 'Quick Mute',
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 2),
                        _OverlayChipButton(
                          label: speedLabel,
                          icon: Icons.speed_rounded,
                          onTap: onOpenSpeedSheet,
                        ),
                        const SizedBox(width: 6),
                        _OverlayChipButton(
                          label: snapshot.aspectRatioMode.label,
                          icon: Icons.aspect_ratio_rounded,
                          onTap: onOpenAspectRatioSheet,
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: onOpenTracksSheet,
                          icon: const Icon(Icons.subtitles_rounded),
                          color: AppTheme.textPrimary,
                          tooltip: 'Audio & Subtitles',
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CenterTransportBar extends StatelessWidget {
  final PlayerSnapshot snapshot;
  final PlayerViewController viewController;

  const _CenterTransportBar({
    required this.snapshot,
    required this.viewController,
  });

  @override
  Widget build(BuildContext context) {
    final playerService = viewController.playerService;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TransportButton(
            icon: Icons.replay_10_rounded,
            size: 34,
            onPressed: () {
              playerService.seekBy(-AppConfig.doubleTapSeekStep);
              viewController.showControls();
            },
          ),
          const SizedBox(width: 28),
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.56),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: snapshot.isBuffering
                ? const Padding(
                    padding: EdgeInsets.all(18),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: AppTheme.accent,
                    ),
                  )
                : IconButton(
                    iconSize: 38,
                    color: AppTheme.textPrimary,
                    onPressed: () {
                      playerService.playOrPause();
                      viewController.showControls();
                    },
                    icon: Icon(
                      snapshot.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
          ),
          const SizedBox(width: 28),
          _TransportButton(
            icon: Icons.forward_10_rounded,
            size: 34,
            onPressed: () {
              playerService.seekBy(AppConfig.doubleTapSeekStep);
              viewController.showControls();
            },
          ),
        ],
      ),
    );
  }
}

class _BottomGradientBar extends StatelessWidget {
  final PlayerSnapshot snapshot;
  final PlayerViewController viewController;
  final VoidCallback onOpenTracksSheet;
  final VoidCallback? onOpenSleepTimerSheet;

  const _BottomGradientBar({
    required this.snapshot,
    required this.viewController,
    required this.onOpenTracksSheet,
    this.onOpenSleepTimerSheet,
  });

  @override
  Widget build(BuildContext context) {
    final total = snapshot.duration;
    final position = snapshot.position;
    final remaining = total > position ? total - position : Duration.zero;
    final rightTimeLabel = viewController.showRemainingTime
        ? '-${DurationFormatter.format(remaining)}'
        : DurationFormatter.format(total);

    final loop = snapshot.abLoop;
    final loopLabel = loop.isActive && loop.pointA != null && loop.pointB != null
        ? 'A-B ${DurationFormatter.format(loop.pointA!)}–${DurationFormatter.format(loop.pointB!)}'
        : (loop.hasPointA ? 'Set B' : 'A-B Loop');

    final sleepRemaining = snapshot.sleepTimerRemaining;
    final sleepLabel = sleepRemaining != null
        ? DurationFormatter.format(sleepRemaining)
        : (snapshot.sleepAfterCurrentVideo ? 'End' : null);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.84),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      DurationFormatter.format(position),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PlayerSeekBar(
                        position: position,
                        duration: total,
                        buffer: snapshot.buffer,
                        abLoop: loop,
                        onScrubStart: viewController.onScrubStart,
                        onScrubEnd: (target) async {
                          await viewController.playerService.seekTo(target);
                          viewController.onScrubEnd();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: viewController.toggleRemainingTime,
                      child: Text(
                        rightTimeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      onPressed: viewController.toggleTouchLock,
                      icon: const Icon(Icons.lock_open_rounded),
                      color: AppTheme.textPrimary,
                      tooltip: 'Kids Touch Lock',
                      visualDensity: VisualDensity.compact,
                    ),
                    _OverlayChipButton(
                      label: loopLabel,
                      icon: Icons.repeat_rounded,
                      highlighted: loop.hasPointA || loop.isActive,
                      onTap: viewController.toggleABLoopAction,
                    ),
                    if (snapshot.isAudioBoosted) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.accentSecondary.withValues(
                            alpha: 0.22,
                          ),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          'Boost ${snapshot.playerVolumePercent.round()}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accentSecondary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _OverlayChipButton(
                                label: snapshot.hardwareAccelerationEnabled
                                    ? 'HW+'
                                    : 'SW',
                                icon: Icons.memory_rounded,
                                highlighted:
                                    snapshot.hardwareAccelerationEnabled,
                                onTap: viewController.toggleHardwareDecoder,
                              ),
                              if (onOpenSleepTimerSheet != null) ...[
                                const SizedBox(width: 4),
                                if (sleepLabel != null)
                                  _OverlayChipButton(
                                    label: sleepLabel,
                                    icon: Icons.bedtime_rounded,
                                    highlighted: true,
                                    onTap: onOpenSleepTimerSheet!,
                                  )
                                else
                                  IconButton(
                                    onPressed: onOpenSleepTimerSheet,
                                    icon: const Icon(Icons.bedtime_outlined),
                                    color: AppTheme.textPrimary,
                                    tooltip: 'Sleep Timer',
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                              IconButton(
                                onPressed: viewController.toggleNightMode,
                                icon: Icon(
                                  snapshot.isNightMode
                                      ? Icons.nights_stay_rounded
                                      : Icons.nights_stay_outlined,
                                ),
                                color: snapshot.isNightMode
                                    ? AppTheme.accentSecondary
                                    : AppTheme.textPrimary,
                                tooltip: 'Night Mode',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: viewController.toggleBackgroundAudio,
                                icon: Icon(
                                  snapshot.isBackgroundAudioEnabled
                                      ? Icons.headphones_rounded
                                      : Icons.headphones_outlined,
                                ),
                                color: snapshot.isBackgroundAudioEnabled
                                    ? AppTheme.accent
                                    : AppTheme.textPrimary,
                                tooltip: 'Background Audio',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: viewController.captureScreenshot,
                                icon: const Icon(Icons.camera_alt_outlined),
                                color: AppTheme.textPrimary,
                                tooltip: 'Screenshot',
                                visualDensity: VisualDensity.compact,
                              ),
                              if (viewController.isPipSupported)
                                IconButton(
                                  onPressed: viewController.enterPipMode,
                                  icon: const Icon(
                                    Icons.picture_in_picture_alt_rounded,
                                  ),
                                  color: AppTheme.textPrimary,
                                  tooltip: 'Picture-in-Picture',
                                  visualDensity: VisualDensity.compact,
                                ),
                              IconButton(
                                onPressed: onOpenTracksSheet,
                                icon: const Icon(Icons.audiotrack_rounded),
                                color: AppTheme.textPrimary,
                                tooltip: 'Audio & Subtitles',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: viewController.cycleAspectRatio,
                                icon: const Icon(Icons.fit_screen_rounded),
                                color: AppTheme.textPrimary,
                                tooltip: 'Cycle Aspect Ratio',
                                visualDensity: VisualDensity.compact,
                              ),
                              IconButton(
                                onPressed: viewController.toggleOrientation,
                                icon: Icon(_iconForOrientation(viewController.orientationMode)),
                                color: AppTheme.textPrimary,
                                tooltip: 'Rotate Screen (${viewController.orientationMode.label})',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForOrientation(OrientationMode mode) {
    switch (mode) {
      case OrientationMode.autoSensor:
        return Icons.screen_rotation_rounded;
      case OrientationMode.landscape:
        return Icons.screen_lock_landscape_rounded;
      case OrientationMode.portrait:
        return Icons.screen_lock_portrait_rounded;
    }
  }
}

class _KidsTouchLockOverlay extends StatelessWidget {
  final bool hintVisible;
  final VoidCallback onUnlock;

  const _KidsTouchLockOverlay({
    required this.hintVisible,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: AnimatedOpacity(
            opacity: hintVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !hintVisible,
              child: Material(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(99),
                child: InkWell(
                  borderRadius: BorderRadius.circular(99),
                  onTap: onUnlock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.65),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: AppTheme.accent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Touch Locked • Tap to Unlock',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onPressed;

  const _TransportButton({
    required this.icon,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.44),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        iconSize: size,
        color: AppTheme.textPrimary,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _OverlayChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool highlighted;
  final VoidCallback onTap;

  const _OverlayChipButton({
    required this.label,
    required this.icon,
    this.highlighted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tint = highlighted ? AppTheme.accentSecondary : AppTheme.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: highlighted
              ? AppTheme.accentSecondary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: highlighted
                ? AppTheme.accentSecondary.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: tint),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
