import 'package:flutter/material.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

/// Shows the playback speed selector bottom sheet (0.25x to 8.0x).
Future<void> showPlaybackSpeedSheet(
  BuildContext context, {
  required PlayerService playerService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return ValueListenableBuilder<PlayerSnapshot>(
        valueListenable: playerService.snapshotListenable,
        builder: (context, snapshot, _) {
          final speed = snapshot.playbackSpeed;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Playback Speed',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${speed.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Slider(
                  min: AppConfig.minPlaybackSpeed,
                  max: AppConfig.maxPlaybackSpeed,
                  divisions: 155,
                  value: speed.clamp(
                    AppConfig.minPlaybackSpeed,
                    AppConfig.maxPlaybackSpeed,
                  ),
                  onChanged: (value) {
                    final rounded = (value * 20).round() / 20.0;
                    playerService.setPlaybackSpeed(rounded);
                  },
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppConfig.playbackSpeedPresets
                      .map(
                        (preset) => ChoiceChip(
                          label: Text('${preset}x'),
                          selected: (speed - preset).abs() < 0.03,
                          onSelected: (_) =>
                              playerService.setPlaybackSpeed(preset),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Shows the aspect ratio / zoom selector bottom sheet.
Future<void> showAspectRatioSheet(
  BuildContext context, {
  required PlayerService playerService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return ValueListenableBuilder<PlayerSnapshot>(
        valueListenable: playerService.snapshotListenable,
        builder: (context, snapshot, _) {
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Aspect Ratio & Zoom',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                for (final mode in AspectRatioMode.values)
                  ListTile(
                    leading: Icon(
                      _iconForAspect(mode),
                      color: snapshot.aspectRatioMode == mode
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                    ),
                    title: Text(mode.label),
                    trailing: snapshot.aspectRatioMode == mode
                        ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                        : null,
                    onTap: () {
                      playerService.setAspectRatioMode(mode);
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Shows the Sleep Timer bottom sheet with preset intervals & end-of-video mode.
Future<void> showSleepTimerSheet(
  BuildContext context, {
  required PlayerService playerService,
}) {
  const presets = <int>[15, 30, 45, 60, 90];
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return ValueListenableBuilder<PlayerSnapshot>(
        valueListenable: playerService.snapshotListenable,
        builder: (context, snapshot, _) {
          final remaining = snapshot.sleepTimerRemaining;
          return SafeArea(
            top: false,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sleep Timer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (remaining != null)
                      Text(
                        DurationFormatter.format(remaining),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentSecondary,
                        ),
                      )
                    else if (snapshot.sleepAfterCurrentVideo)
                      const Text(
                        'End of Video',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentSecondary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined),
                  title: const Text('Off'),
                  trailing: !snapshot.hasSleepTimer
                      ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                      : null,
                  onTap: () {
                    playerService.cancelSleepTimer();
                    Navigator.of(sheetContext).pop();
                  },
                ),
                for (final minutes in presets)
                  ListTile(
                    leading: const Icon(Icons.bedtime_outlined),
                    title: Text('$minutes minutes'),
                    onTap: () {
                      playerService.setSleepTimer(Duration(minutes: minutes));
                      Navigator.of(sheetContext).pop();
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.stop_circle_outlined),
                  title: const Text('Stop after current video'),
                  trailing: snapshot.sleepAfterCurrentVideo
                      ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                      : null,
                  onTap: () {
                    playerService.setSleepAfterCurrentVideo();
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

IconData _iconForAspect(AspectRatioMode mode) {
  switch (mode) {
    case AspectRatioMode.fit:
      return Icons.fit_screen_rounded;
    case AspectRatioMode.fill:
      return Icons.crop_free_rounded;
    case AspectRatioMode.stretch:
      return Icons.aspect_ratio_rounded;
    case AspectRatioMode.ratio16x9:
      return Icons.crop_16_9_rounded;
    case AspectRatioMode.ratio4x3:
      return Icons.crop_3_2_rounded;
  }
}
