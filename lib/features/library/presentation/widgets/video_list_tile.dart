import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/library/presentation/widgets/video_thumbnail_box.dart';

/// Library media row showing thumbnail/artwork, metadata, resume indicator,
/// and file manager actions.
class VideoListTile extends StatelessWidget {
  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback onPlayFromStart;
  final ValueChanged<bool> onToggleWatched;
  final VoidCallback onClearProgress;
  final VoidCallback? onRename;
  final VoidCallback? onShare;
  final VoidCallback? onMoveToVault;
  final VoidCallback? onDelete;

  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    required this.onPlayFromStart,
    required this.onToggleWatched,
    required this.onClearProgress,
    this.onRename,
    this.onShare,
    this.onMoveToVault,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat.MMMd().format(video.modifiedAt);
    final metaParts = <String>[
      if (video.resolutionLabel != null)
        video.resolutionLabel!
      else if (video.isAudioOnly && video.effectiveDuration > Duration.zero)
        DurationFormatter.format(video.effectiveDuration),
      if (video.sizeBytes > 0) DurationFormatter.formatFileSize(video.sizeBytes),
      dateText,
    ];

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              if (video.isAudioOnly)
                _AudioArtworkBox(containerLabel: video.containerLabel)
              else
                VideoThumbnailBox(video: video, width: 112, height: 64),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      metaParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (video.hasResumeProgress)
                          _StatusPill(
                            label:
                                'Resume ${DurationFormatter.format(video.resumePosition)}',
                            color: AppTheme.accent,
                          )
                        else if (video.isWatched)
                          const _StatusPill(
                            label: 'Watched',
                            color: AppTheme.success,
                          )
                        else
                          _StatusPill(
                            label: video.folderName,
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More options',
                padding: EdgeInsets.zero,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: AppTheme.textSecondary,
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'restart':
                      onPlayFromStart();
                    case 'watched':
                      onToggleWatched(!video.isWatched);
                    case 'clear':
                      onClearProgress();
                    case 'rename':
                      onRename?.call();
                    case 'share':
                      onShare?.call();
                    case 'vault':
                      onMoveToVault?.call();
                    case 'delete':
                      onDelete?.call();
                  }
                },
                itemBuilder: (context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'restart',
                    child: Text('Play from beginning'),
                  ),
                  PopupMenuItem<String>(
                    value: 'watched',
                    child: Text(
                      video.isWatched ? 'Mark as unwatched' : 'Mark as watched',
                    ),
                  ),
                  if (video.watchHistory != null)
                    const PopupMenuItem<String>(
                      value: 'clear',
                      child: Text('Clear progress'),
                    ),
                  if (onShare != null)
                    const PopupMenuItem<String>(
                      value: 'share',
                      child: Text('Share'),
                    ),
                  if (onRename != null && !video.filePath.contains('://'))
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Text('Rename'),
                    ),
                  if (onMoveToVault != null &&
                      !video.isAudioOnly &&
                      !video.filePath.contains('://'))
                    const PopupMenuItem<String>(
                      value: 'vault',
                      child: Text('Move to Private Vault'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioArtworkBox extends StatelessWidget {
  final String containerLabel;

  const _AudioArtworkBox({required this.containerLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1D3557), Color(0xFF131B2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_note_rounded, color: AppTheme.accent, size: 28),
          const SizedBox(height: 2),
          Text(
            containerLabel,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
