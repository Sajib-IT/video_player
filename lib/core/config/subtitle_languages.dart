/// Represents a subtitle language supported across track matching and
/// OpenSubtitles REST API v1 queries.
class SubtitleLanguage {
  final String iso6391;
  final String iso6392;
  final String englishName;
  final String nativeName;

  const SubtitleLanguage({
    required this.iso6391,
    required this.iso6392,
    required this.englishName,
    required this.nativeName,
  });

  String get displayLabel =>
      nativeName == englishName ? englishName : '$englishName ($nativeName)';
}

/// Curated multi-language catalog for embedded track display and online
/// subtitle search filtering.
abstract final class SubtitleLanguages {
  static const List<SubtitleLanguage> all = <SubtitleLanguage>[
    SubtitleLanguage(
      iso6391: 'en',
      iso6392: 'eng',
      englishName: 'English',
      nativeName: 'English',
    ),
    SubtitleLanguage(
      iso6391: 'bn',
      iso6392: 'ben',
      englishName: 'Bengali',
      nativeName: 'বাংলা',
    ),
    SubtitleLanguage(
      iso6391: 'hi',
      iso6392: 'hin',
      englishName: 'Hindi',
      nativeName: 'हिन्दी',
    ),
    SubtitleLanguage(
      iso6391: 'es',
      iso6392: 'spa',
      englishName: 'Spanish',
      nativeName: 'Español',
    ),
    SubtitleLanguage(
      iso6391: 'ar',
      iso6392: 'ara',
      englishName: 'Arabic',
      nativeName: 'العربية',
    ),
    SubtitleLanguage(
      iso6391: 'ja',
      iso6392: 'jpn',
      englishName: 'Japanese',
      nativeName: '日本語',
    ),
    SubtitleLanguage(
      iso6391: 'ko',
      iso6392: 'kor',
      englishName: 'Korean',
      nativeName: '한국어',
    ),
    SubtitleLanguage(
      iso6391: 'fr',
      iso6392: 'fre',
      englishName: 'French',
      nativeName: 'Français',
    ),
    SubtitleLanguage(
      iso6391: 'de',
      iso6392: 'ger',
      englishName: 'German',
      nativeName: 'Deutsch',
    ),
    SubtitleLanguage(
      iso6391: 'pt',
      iso6392: 'por',
      englishName: 'Portuguese',
      nativeName: 'Português',
    ),
    SubtitleLanguage(
      iso6391: 'ru',
      iso6392: 'rus',
      englishName: 'Russian',
      nativeName: 'Русский',
    ),
    SubtitleLanguage(
      iso6391: 'zh',
      iso6392: 'chi',
      englishName: 'Chinese',
      nativeName: '中文',
    ),
    SubtitleLanguage(
      iso6391: 'ur',
      iso6392: 'urd',
      englishName: 'Urdu',
      nativeName: 'اردو',
    ),
    SubtitleLanguage(
      iso6391: 'ta',
      iso6392: 'tam',
      englishName: 'Tamil',
      nativeName: 'தமிழ்',
    ),
    SubtitleLanguage(
      iso6391: 'te',
      iso6392: 'tel',
      englishName: 'Telugu',
      nativeName: 'తెలుగు',
    ),
    SubtitleLanguage(
      iso6391: 'ml',
      iso6392: 'mal',
      englishName: 'Malayalam',
      nativeName: 'മലയാളം',
    ),
    SubtitleLanguage(
      iso6391: 'tr',
      iso6392: 'tur',
      englishName: 'Turkish',
      nativeName: 'Türkçe',
    ),
    SubtitleLanguage(
      iso6391: 'id',
      iso6392: 'ind',
      englishName: 'Indonesian',
      nativeName: 'Bahasa Indonesia',
    ),
    SubtitleLanguage(
      iso6391: 'ms',
      iso6392: 'may',
      englishName: 'Malay',
      nativeName: 'Bahasa Melayu',
    ),
    SubtitleLanguage(
      iso6391: 'vi',
      iso6392: 'vie',
      englishName: 'Vietnamese',
      nativeName: 'Tiếng Việt',
    ),
    SubtitleLanguage(
      iso6391: 'th',
      iso6392: 'tha',
      englishName: 'Thai',
      nativeName: 'ไทย',
    ),
    SubtitleLanguage(
      iso6391: 'it',
      iso6392: 'ita',
      englishName: 'Italian',
      nativeName: 'Italiano',
    ),
    SubtitleLanguage(
      iso6391: 'nl',
      iso6392: 'dut',
      englishName: 'Dutch',
      nativeName: 'Nederlands',
    ),
    SubtitleLanguage(
      iso6391: 'pl',
      iso6392: 'pol',
      englishName: 'Polish',
      nativeName: 'Polski',
    ),
    SubtitleLanguage(
      iso6391: 'fa',
      iso6392: 'per',
      englishName: 'Persian',
      nativeName: 'فارسی',
    ),
    SubtitleLanguage(
      iso6391: 'uk',
      iso6392: 'ukr',
      englishName: 'Ukrainian',
      nativeName: 'Українська',
    ),
    SubtitleLanguage(
      iso6391: 'sv',
      iso6392: 'swe',
      englishName: 'Swedish',
      nativeName: 'Svenska',
    ),
    SubtitleLanguage(
      iso6391: 'no',
      iso6392: 'nor',
      englishName: 'Norwegian',
      nativeName: 'Norsk',
    ),
    SubtitleLanguage(
      iso6391: 'da',
      iso6392: 'dan',
      englishName: 'Danish',
      nativeName: 'Dansk',
    ),
    SubtitleLanguage(
      iso6391: 'fi',
      iso6392: 'fin',
      englishName: 'Finnish',
      nativeName: 'Suomi',
    ),
    SubtitleLanguage(
      iso6391: 'el',
      iso6392: 'gre',
      englishName: 'Greek',
      nativeName: 'Ελληνικά',
    ),
    SubtitleLanguage(
      iso6391: 'he',
      iso6392: 'heb',
      englishName: 'Hebrew',
      nativeName: 'עברית',
    ),
    SubtitleLanguage(
      iso6391: 'cs',
      iso6392: 'cze',
      englishName: 'Czech',
      nativeName: 'Čeština',
    ),
    SubtitleLanguage(
      iso6391: 'hu',
      iso6392: 'hun',
      englishName: 'Hungarian',
      nativeName: 'Magyar',
    ),
    SubtitleLanguage(
      iso6391: 'ro',
      iso6392: 'rum',
      englishName: 'Romanian',
      nativeName: 'Română',
    ),
  ];

  /// Resolves a language by ISO-639-1 (`en`, `bn`) or ISO-639-2 (`eng`, `ben`).
  static SubtitleLanguage? findByCode(String? rawCode) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final normalized = rawCode.trim().toLowerCase().split(RegExp(r'[-_]')).first;
    for (final lang in all) {
      if (lang.iso6391 == normalized || lang.iso6392 == normalized) {
        return lang;
      }
    }
    return null;
  }

  /// Returns a human-readable language name or falls back to upper-cased code.
  static String labelForCode(String? rawCode) {
    final match = findByCode(rawCode);
    if (match != null) return match.englishName;
    if (rawCode == null || rawCode.trim().isEmpty || rawCode == 'und') {
      return 'Unknown';
    }
    return rawCode.toUpperCase();
  }
}
