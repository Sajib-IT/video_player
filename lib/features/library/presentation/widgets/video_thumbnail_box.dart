import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

/// Displays an asynchronously loaded video thumbnail with duration, container,
/// watched badge, and bottom playback progress indicator.
class VideoThumbnailBox extends StatefulWidget {
  final VideoItem video;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const VideoThumbnailBox({
    super.key,
    required this.video,
    this.width = 132,
    this.height = 76,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  State<VideoThumbnailBox> createState() => _VideoThumbnailBoxState();
}

class _VideoThumbnailBoxState extends State<VideoThumbnailBox> {
  static final Map<String, Uint8List> _memoryCache = <String, Uint8List>{};
  static const int _maxCacheEntries = 120;

  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(covariant VideoThumbnailBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.assetId != widget.video.assetId) {
      _bytes = null;
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    final assetId = widget.video.assetId;
    if (assetId == null || assetId.isEmpty) return;

    final cached = _memoryCache[assetId];
    if (cached != null) {
      if (mounted) setState(() => _bytes = cached);
      return;
    }

    try {
      final asset = await AssetEntity.fromId(assetId);
      final data = await asset?.thumbnailDataWithSize(
        const ThumbnailSize(320, 180),
        quality: 75,
      );
      if (data == null || !mounted) return;

      if (_memoryCache.length >= _maxCacheEntries) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      _memoryCache[assetId] = data;
      setState(() => _bytes = data);
    } catch (_) {
      // Fallback cleanly to the vector placeholder when thumbnails are unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = widget.video.effectiveDuration;
    final progress = widget.video.progressRatio;

    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_bytes != null)
              Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFF1A2233), Color(0xFF101520)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.movie_creation_outlined,
                    color: AppTheme.textSecondary,
                    size: 28,
                  ),
                ),
              ),
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.video.containerLabel,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
            if (widget.video.isWatched)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 11,
                    color: Colors.black,
                  ),
                ),
              ),
            if (duration > Duration.zero)
              Positioned(
                bottom: progress > 0 ? 7 : 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    DurationFormatter.format(duration),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
            if (progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.video.isWatched ? AppTheme.success : AppTheme.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
