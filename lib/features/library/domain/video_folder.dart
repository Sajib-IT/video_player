import 'package:video_player_app/features/library/domain/video_item.dart';

/// Represents a device folder/album grouping one or more local [VideoItem]s.
class VideoFolder {
  final String folderPath;
  final String folderName;
  final List<VideoItem> videos;

  const VideoFolder({
    required this.folderPath,
    required this.folderName,
    required this.videos,
  });

  int get videoCount => videos.length;

  int get unwatchedCount => videos.where((v) => !v.isWatched).length;

  int get totalSizeBytes =>
      videos.fold<int>(0, (sum, item) => sum + item.sizeBytes);

  Duration get totalDuration => videos.fold<Duration>(
    Duration.zero,
    (sum, item) => sum + item.effectiveDuration,
  );

  DateTime get latestModified {
    if (videos.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    var latest = videos.first.modifiedAt;
    for (final v in videos.skip(1)) {
      if (v.modifiedAt.isAfter(latest)) {
        latest = v.modifiedAt;
      }
    }
    return latest;
  }
}
