/// Application-wide configuration constants and defaults.
abstract final class AppConfig {
  static const String appName = 'CineVault Player';
  static const String appLogoAsset = 'assets/images/cinevault_logo.png';
  static const String databaseName = 'cinevault_player.db';
  static const int databaseVersion = 2;

  /// Bundled fallback font asset used by libass on Android for ASS/SSA styling.
  static const String libassAndroidFontAsset = 'assets/fonts/roboto-regular.ttf';
  static const String libassAndroidFontName = 'Roboto';

  /// OpenSubtitles REST API v1 configuration.
  static const String openSubtitlesBaseUrl =
      'https://api.opensubtitles.com/api/v1';
  static const String openSubtitlesUserAgent = 'CineVaultPlayer v1.0.0';
  static const String openSubtitlesApiKey = String.fromEnvironment(
    'OPENSUBTITLES_API_KEY',
  );

  /// OpenAI Whisper API configuration for AI speech-to-text & subtitle translation.
  static const String openAiBaseUrl = 'https://api.openai.com/v1';
  static const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const int whisperMaxFileBytes = 25 * 1024 * 1024;

  /// Playback limits and defaults.
  static const double minPlaybackSpeed = 0.25;
  static const double maxPlaybackSpeed = 8.0;
  static const List<double> playbackSpeedPresets = <double>[
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
    4.0,
    6.0,
    8.0,
  ];

  static const double minVolumePercent = 0.0;
  static const double standardMaxVolumePercent = 100.0;
  static const double boostedMaxVolumePercent = 200.0;

  static const Duration doubleTapSeekStep = Duration(seconds: 10);
  static const Duration progressSaveInterval = Duration(seconds: 5);
  static const Duration resumeMinThreshold = Duration(seconds: 2);
  static const double watchedCompletionRatio = 0.90;

  /// Subtitle delay & scale constraints.
  static const Duration minSubtitleDelay = Duration(milliseconds: -5000);
  static const Duration maxSubtitleDelay = Duration(milliseconds: 5000);
  static const Duration subtitleDelayStep = Duration(milliseconds: 100);
  static const double minSubtitleScale = 0.5;
  static const double maxSubtitleScale = 2.5;
  static const double minSubtitleFontSize = 14.0;
  static const double maxSubtitleFontSize = 48.0;

  /// libmpv demuxer cache size (32 MiB).
  static const int playerBufferSizeBytes = 32 * 1024 * 1024;
}
