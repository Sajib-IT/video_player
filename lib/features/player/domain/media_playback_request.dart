import 'package:path/path.dart' as p;
import 'package:video_player_app/core/constants/media_formats.dart';

/// Descriptor for opening a local video/audio file or network media stream.
class MediaPlaybackRequest {
  final String mediaKey;
  final String uriOrPath;
  final String title;
  final String folderPath;
  final int fileSizeBytes;
  final Duration? initialPosition;
  final bool isAudioOnly;

  const MediaPlaybackRequest({
    required this.mediaKey,
    required this.uriOrPath,
    required this.title,
    this.folderPath = '',
    this.fileSizeBytes = 0,
    this.initialPosition,
    this.isAudioOnly = false,
  });

  factory MediaPlaybackRequest.fromFilePath(
    String filePath, {
    String? title,
    int fileSizeBytes = 0,
    Duration? initialPosition,
    bool? isAudioOnly,
  }) {
    final normalized = filePath.contains('://')
        ? filePath
        : p.normalize(filePath);
    return MediaPlaybackRequest(
      mediaKey: normalized,
      uriOrPath: normalized,
      title: title ?? p.basenameWithoutExtension(normalized),
      folderPath: normalized.contains('://') ? '' : p.dirname(normalized),
      fileSizeBytes: fileSizeBytes,
      initialPosition: initialPosition,
      isAudioOnly: isAudioOnly ?? MediaFormats.isSupportedAudio(normalized),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaPlaybackRequest &&
        other.mediaKey == mediaKey &&
        other.uriOrPath == uriOrPath &&
        other.title == title &&
        other.folderPath == folderPath &&
        other.fileSizeBytes == fileSizeBytes &&
        other.initialPosition == initialPosition &&
        other.isAudioOnly == isAudioOnly;
  }

  @override
  int get hashCode => Object.hash(
    mediaKey,
    uriOrPath,
    title,
    folderPath,
    fileSizeBytes,
    initialPosition,
    isAudioOnly,
  );
}
