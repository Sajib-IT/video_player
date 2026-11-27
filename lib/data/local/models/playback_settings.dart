import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/features/library/domain/library_sort_field.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';

/// Persisted global playback, audio boost, subtitle appearance, and library defaults.
class PlaybackSettings {
  final int id;
  final double defaultPlaybackSpeed;
  final AspectRatioMode defaultAspectRatio;
  final bool resumePlaybackEnabled;
  final bool hardwareAccelerationEnabled;
  final bool softwareAudioBoostEnabled;
  final int maxAudioBoostPercent;
  final bool backgroundAudioEnabled;
  final bool nightModeEnabled;
  final bool useLibass;
  final double subtitleFontSize;
  final double subtitleScale;
  final int subtitleColorHex;
  final double subtitleBgOpacity;
  final String preferredSubtitleLanguage;
  final String openSubtitlesApiKey;
  final String openAiApiKey;
  final LibrarySortField librarySortField;
  final bool librarySortAscending;
  final int updatedAtMs;

  const PlaybackSettings({
    this.id = 1,
    this.defaultPlaybackSpeed = 1.0,
    this.defaultAspectRatio = AspectRatioMode.fit,
    this.resumePlaybackEnabled = true,
    this.hardwareAccelerationEnabled = true,
    this.softwareAudioBoostEnabled = true,
    this.maxAudioBoostPercent = 200,
    this.backgroundAudioEnabled = false,
    this.nightModeEnabled = false,
    this.useLibass = true,
    this.subtitleFontSize = 28.0,
    this.subtitleScale = 1.0,
    this.subtitleColorHex = 0xFFFFFFFF,
    this.subtitleBgOpacity = 0.65,
    this.preferredSubtitleLanguage = 'en',
    this.openSubtitlesApiKey = '',
    this.openAiApiKey = '',
    this.librarySortField = LibrarySortField.date,
    this.librarySortAscending = false,
    this.updatedAtMs = 0,
  });

  factory PlaybackSettings.defaults({int? updatedAtMs}) {
    return PlaybackSettings(
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Resolves user-configured OpenSubtitles API key or compile-time fallback.
  String get effectiveOpenSubtitlesApiKey {
    final override = openSubtitlesApiKey.trim();
    return override.isNotEmpty ? override : AppConfig.openSubtitlesApiKey;
  }

  /// Resolves user-configured OpenAI Whisper API key or compile-time fallback.
  String get effectiveOpenAiApiKey {
    final override = openAiApiKey.trim();
    return override.isNotEmpty ? override : AppConfig.openAiApiKey;
  }

  double get maxVolumePercent => softwareAudioBoostEnabled
      ? maxAudioBoostPercent.toDouble().clamp(100.0, 200.0)
      : AppConfig.standardMaxVolumePercent;

  PlaybackSettings copyWith({
    double? defaultPlaybackSpeed,
    AspectRatioMode? defaultAspectRatio,
    bool? resumePlaybackEnabled,
    bool? hardwareAccelerationEnabled,
    bool? softwareAudioBoostEnabled,
    int? maxAudioBoostPercent,
    bool? backgroundAudioEnabled,
    bool? nightModeEnabled,
    bool? useLibass,
    double? subtitleFontSize,
    double? subtitleScale,
    int? subtitleColorHex,
    double? subtitleBgOpacity,
    String? preferredSubtitleLanguage,
    String? openSubtitlesApiKey,
    String? openAiApiKey,
    LibrarySortField? librarySortField,
    bool? librarySortAscending,
    int? updatedAtMs,
  }) {
    return PlaybackSettings(
      id: 1,
      defaultPlaybackSpeed: defaultPlaybackSpeed ?? this.defaultPlaybackSpeed,
      defaultAspectRatio: defaultAspectRatio ?? this.defaultAspectRatio,
      resumePlaybackEnabled:
          resumePlaybackEnabled ?? this.resumePlaybackEnabled,
      hardwareAccelerationEnabled:
          hardwareAccelerationEnabled ?? this.hardwareAccelerationEnabled,
      softwareAudioBoostEnabled:
          softwareAudioBoostEnabled ?? this.softwareAudioBoostEnabled,
      maxAudioBoostPercent: maxAudioBoostPercent ?? this.maxAudioBoostPercent,
      backgroundAudioEnabled:
          backgroundAudioEnabled ?? this.backgroundAudioEnabled,
      nightModeEnabled: nightModeEnabled ?? this.nightModeEnabled,
      useLibass: useLibass ?? this.useLibass,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleScale: subtitleScale ?? this.subtitleScale,
      subtitleColorHex: subtitleColorHex ?? this.subtitleColorHex,
      subtitleBgOpacity: subtitleBgOpacity ?? this.subtitleBgOpacity,
      preferredSubtitleLanguage:
          preferredSubtitleLanguage ?? this.preferredSubtitleLanguage,
      openSubtitlesApiKey: openSubtitlesApiKey ?? this.openSubtitlesApiKey,
      openAiApiKey: openAiApiKey ?? this.openAiApiKey,
      librarySortField: librarySortField ?? this.librarySortField,
      librarySortAscending: librarySortAscending ?? this.librarySortAscending,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'default_playback_speed': defaultPlaybackSpeed,
      'default_aspect_ratio': defaultAspectRatio.id,
      'resume_playback_enabled': resumePlaybackEnabled ? 1 : 0,
      'hardware_acceleration_enabled': hardwareAccelerationEnabled ? 1 : 0,
      'software_audio_boost_enabled': softwareAudioBoostEnabled ? 1 : 0,
      'max_audio_boost_percent': maxAudioBoostPercent,
      'background_audio_enabled': backgroundAudioEnabled ? 1 : 0,
      'night_mode_enabled': nightModeEnabled ? 1 : 0,
      'use_libass': useLibass ? 1 : 0,
      'subtitle_font_size': subtitleFontSize,
      'subtitle_scale': subtitleScale,
      'subtitle_color_hex': subtitleColorHex,
      'subtitle_bg_opacity': subtitleBgOpacity,
      'preferred_subtitle_language': preferredSubtitleLanguage,
      'opensubtitles_api_key': openSubtitlesApiKey,
      'openai_api_key': openAiApiKey,
      'library_sort_field': librarySortField.id,
      'library_sort_ascending': librarySortAscending ? 1 : 0,
      'updated_at': updatedAtMs,
    };
  }

  factory PlaybackSettings.fromMap(Map<String, Object?> map) {
    return PlaybackSettings(
      id: (map['id'] as int?) ?? 1,
      defaultPlaybackSpeed:
          ((map['default_playback_speed'] as num?) ?? 1.0).toDouble(),
      defaultAspectRatio: AspectRatioMode.fromId(
        map['default_aspect_ratio'] as String?,
      ),
      resumePlaybackEnabled:
          ((map['resume_playback_enabled'] as int?) ?? 1) == 1,
      hardwareAccelerationEnabled:
          ((map['hardware_acceleration_enabled'] as int?) ?? 1) == 1,
      softwareAudioBoostEnabled:
          ((map['software_audio_boost_enabled'] as int?) ?? 1) == 1,
      maxAudioBoostPercent: (map['max_audio_boost_percent'] as int?) ?? 200,
      backgroundAudioEnabled:
          ((map['background_audio_enabled'] as int?) ?? 0) == 1,
      nightModeEnabled: ((map['night_mode_enabled'] as int?) ?? 0) == 1,
      useLibass: ((map['use_libass'] as int?) ?? 1) == 1,
      subtitleFontSize:
          ((map['subtitle_font_size'] as num?) ?? 28.0).toDouble(),
      subtitleScale: ((map['subtitle_scale'] as num?) ?? 1.0).toDouble(),
      subtitleColorHex: (map['subtitle_color_hex'] as int?) ?? 0xFFFFFFFF,
      subtitleBgOpacity:
          ((map['subtitle_bg_opacity'] as num?) ?? 0.65).toDouble(),
      preferredSubtitleLanguage:
          (map['preferred_subtitle_language'] as String?) ?? 'en',
      openSubtitlesApiKey: (map['opensubtitles_api_key'] as String?) ?? '',
      openAiApiKey: (map['openai_api_key'] as String?) ?? '',
      librarySortField: LibrarySortField.fromId(
        map['library_sort_field'] as String?,
      ),
      librarySortAscending:
          ((map['library_sort_ascending'] as int?) ?? 0) == 1,
      updatedAtMs: (map['updated_at'] as int?) ?? 0,
    );
  }
}
