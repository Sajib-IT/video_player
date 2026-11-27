/// Search parameters for online subtitle lookup by title, filename, hash, and language.
class SubtitleSearchQuery {
  final String query;
  final String? movieHash;
  final List<String> languageCodes;

  const SubtitleSearchQuery({
    required this.query,
    this.movieHash,
    this.languageCodes = const <String>[],
  });

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasMovieHash => movieHash != null && movieHash!.trim().isNotEmpty;

  /// Normalizes release filenames such as
  /// `[SubsPlease] Movie.2024.1080p.BluRay.x264-GROUP` into clean search text.
  static String cleanTitleFromFilename(String rawTitle) {
    var cleaned = rawTitle
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\([^\)]*\)'), ' ')
        .replaceAll(RegExp(r'[._]+'), ' ');

    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(2160p|1080p|720p|480p|4k|8k|uhd|bluray|blu-ray|bdrip|brrip|'
        r'web-dl|webdl|webrip|hdrip|hdtv|dvdrip|remux|x264|x265|h264|h265|'
        r'hevc|av1|aac|ac3|eac3|dts|atmos|10bit|8bit|proper|repack|extended|'
        r'yify|yts|rarbg|subsplease|erai-raws)\b',
        caseSensitive: false,
      ),
      ' ',
    );

    cleaned = cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s\-–]+|[\s\-–]+$'), '')
        .trim();
    return cleaned.isNotEmpty ? cleaned : rawTitle.trim();
  }
}
