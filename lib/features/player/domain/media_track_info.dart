import 'package:video_player_app/core/config/subtitle_languages.dart';

/// Media track category.
enum MediaTrackKind { video, audio, subtitle }

/// Unified immutable representation of an embedded or external media track.
class MediaTrackInfo {
  final String id;
  final MediaTrackKind kind;
  final String? title;
  final String? languageCode;
  final String? codec;
  final String? channels;
  final int? width;
  final int? height;
  final bool isDefault;
  final bool isExternal;
  final String? externalFilePath;
  final int? savedSubtitleId;

  const MediaTrackInfo({
    required this.id,
    required this.kind,
    this.title,
    this.languageCode,
    this.codec,
    this.channels,
    this.width,
    this.height,
    this.isDefault = false,
    this.isExternal = false,
    this.externalFilePath,
    this.savedSubtitleId,
  });

  bool get isSpecialAuto => id == 'auto';
  bool get isSpecialNone => id == 'no';
  bool get isSpecialTrack => isSpecialAuto || isSpecialNone;

  String get displayName {
    if (isSpecialAuto) return 'Auto';
    if (isSpecialNone) return 'Off';

    final parts = <String>[];
    final cleanTitle = title?.trim();
    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      parts.add(cleanTitle);
    }

    final langLabel = SubtitleLanguages.labelForCode(languageCode);
    if (langLabel != 'Unknown' &&
        (cleanTitle == null ||
            !cleanTitle.toLowerCase().contains(langLabel.toLowerCase()))) {
      parts.add(langLabel);
    }

    if (parts.isEmpty) {
      parts.add('Track $id');
    }

    final meta = <String>[];
    if (codec != null && codec!.trim().isNotEmpty) {
      meta.add(codec!.trim().toUpperCase());
    }
    if (channels != null && channels!.trim().isNotEmpty) {
      meta.add(channels!.trim());
    }
    if (isExternal) {
      meta.add('External');
    }

    if (meta.isEmpty) return parts.join(' • ');
    return '${parts.join(' • ')} (${meta.join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaTrackInfo &&
        other.id == id &&
        other.kind == kind &&
        other.title == title &&
        other.languageCode == languageCode &&
        other.codec == codec &&
        other.channels == channels &&
        other.width == width &&
        other.height == height &&
        other.isDefault == isDefault &&
        other.isExternal == isExternal &&
        other.externalFilePath == externalFilePath &&
        other.savedSubtitleId == savedSubtitleId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    title,
    languageCode,
    codec,
    channels,
    width,
    height,
    isDefault,
    isExternal,
    externalFilePath,
    savedSubtitleId,
  );
}
