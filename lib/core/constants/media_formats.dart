import 'package:path/path.dart' as p;

/// Supported video, audio, and external subtitle formats handled by libmpv/FFmpeg.
abstract final class MediaFormats {
  static const Set<String> videoExtensions = <String>{
    'mkv',
    'mp4',
    'avi',
    'mov',
    'flv',
    'ts',
    'm2ts',
    'mts',
    'webm',
    'wmv',
    'm4v',
    '3gp',
    'rmvb',
    'rm',
    'mpg',
    'mpeg',
    'ogv',
  };

  static const Set<String> audioExtensions = <String>{
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'wma',
    'alac',
    'aiff',
  };

  static const List<String> subtitleExtensions = <String>[
    'srt',
    'ass',
    'ssa',
    'vtt',
    'sub',
  ];

  static String extensionOf(String pathOrUrl) {
    final clean = pathOrUrl.split('?').first.split('#').first;
    final ext = p.extension(clean).toLowerCase();
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  static bool isSupportedVideo(String pathOrUrl) {
    return videoExtensions.contains(extensionOf(pathOrUrl));
  }

  static bool isSupportedAudio(String pathOrUrl) {
    return audioExtensions.contains(extensionOf(pathOrUrl));
  }

  static bool isSupportedSubtitle(String pathOrUrl) {
    return subtitleExtensions.contains(extensionOf(pathOrUrl));
  }

  static bool isStyledAssSubtitle(String pathOrUrl) {
    final ext = extensionOf(pathOrUrl);
    return ext == 'ass' || ext == 'ssa';
  }

  static String mimeTypeForMedia(String pathOrUrl) {
    switch (extensionOf(pathOrUrl)) {
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'ts':
      case 'm2ts':
      case 'mts':
        return 'video/mp2t';
      case 'flv':
        return 'video/x-flv';
      case 'wmv':
        return 'video/x-ms-wmv';
      case '3gp':
        return 'video/3gpp';
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'flac':
        return 'audio/flac';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      default:
        return 'application/octet-stream';
    }
  }
}
