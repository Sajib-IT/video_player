import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/constants/media_formats.dart';

/// Represents a downloadable subtitle entry returned by OpenSubtitles REST API v1.
class OnlineSubtitleResult {
  final String subtitleId;
  final int fileId;
  final String fileName;
  final String languageCode;
  final String releaseName;
  final String featureTitle;
  final int? releaseYear;
  final int downloadCount;
  final double rating;
  final bool isHashMatch;
  final bool isHearingImpaired;

  const OnlineSubtitleResult({
    required this.subtitleId,
    required this.fileId,
    required this.fileName,
    required this.languageCode,
    this.releaseName = '',
    this.featureTitle = '',
    this.releaseYear,
    this.downloadCount = 0,
    this.rating = 0.0,
    this.isHashMatch = false,
    this.isHearingImpaired = false,
  });

  String get languageName => SubtitleLanguages.labelForCode(languageCode);

  String get formatExtension {
    final ext = MediaFormats.extensionOf(fileName);
    return ext.isEmpty ? 'srt' : ext;
  }

  /// Parses one item from OpenSubtitles REST API v1 `/subtitles` `data` array.
  static OnlineSubtitleResult? fromOpenSubtitlesJson(Map<String, dynamic> json) {
    final attrs = json['attributes'];
    if (attrs is! Map<String, dynamic>) return null;

    final filesRaw = attrs['files'];
    if (filesRaw is! List || filesRaw.isEmpty) return null;
    final firstFile = filesRaw.first;
    if (firstFile is! Map<String, dynamic>) return null;

    final rawFileId = firstFile['file_id'];
    final fileId = rawFileId is int
        ? rawFileId
        : int.tryParse(rawFileId?.toString() ?? '');
    if (fileId == null || fileId <= 0) return null;

    final rawFileName = (firstFile['file_name'] as String?)?.trim();
    final release = (attrs['release'] as String?)?.trim() ?? '';
    final language = (attrs['language'] as String?)?.trim().toLowerCase() ?? 'und';
    final fileName = (rawFileName != null && rawFileName.isNotEmpty)
        ? rawFileName
        : '${release.isNotEmpty ? release : 'subtitle_$fileId'}.srt';

    final feature = attrs['feature_details'];
    String featureTitle = '';
    int? releaseYear;
    if (feature is Map<String, dynamic>) {
      featureTitle =
          (feature['movie_name'] as String?)?.trim() ??
          (feature['title'] as String?)?.trim() ??
          '';
      final rawYear = feature['year'];
      releaseYear = rawYear is int
          ? rawYear
          : int.tryParse(rawYear?.toString() ?? '');
    }

    final rawCount = attrs['download_count'];
    final downloadCount = rawCount is int
        ? rawCount
        : int.tryParse(rawCount?.toString() ?? '') ?? 0;

    final rawRating = attrs['ratings'];
    final rating = rawRating is num ? rawRating.toDouble() : 0.0;

    return OnlineSubtitleResult(
      subtitleId: json['id']?.toString() ?? fileId.toString(),
      fileId: fileId,
      fileName: fileName,
      languageCode: language,
      releaseName: release,
      featureTitle: featureTitle,
      releaseYear: releaseYear,
      downloadCount: downloadCount,
      rating: rating,
      isHashMatch: attrs['moviehash_match'] == true,
      isHearingImpaired: attrs['hearing_impaired'] == true,
    );
  }
}
