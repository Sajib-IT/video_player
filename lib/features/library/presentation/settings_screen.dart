import 'package:flutter/material.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';
import 'package:video_player_app/features/library/presentation/library_controller.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

/// Persistent settings screen for playback defaults, background audio,
/// Night Mode, boost, libass, and OpenSubtitles / OpenAI Whisper API keys.
class SettingsScreen extends StatefulWidget {
  final LibraryController libraryController;
  final PlayerService playerService;

  const SettingsScreen({
    super.key,
    required this.libraryController,
    required this.playerService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PlaybackSettings? _settings;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _openAiKeyController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await widget.libraryController.loadSettings();
    if (!mounted) return;
    _apiKeyController.text = loaded.openSubtitlesApiKey;
    _openAiKeyController.text = loaded.openAiApiKey;
    setState(() => _settings = loaded);
  }

  Future<void> _save(PlaybackSettings next) async {
    setState(() {
      _saving = true;
      _settings = next;
    });
    final saved = await widget.libraryController.saveSettings(next);
    if (saved.useLibass != widget.playerService.snapshot.useLibass) {
      await widget.playerService.setLibassEnabled(saved.useLibass);
    }
    if (saved.backgroundAudioEnabled !=
        widget.playerService.snapshot.isBackgroundAudioEnabled) {
      await widget.playerService.setBackgroundAudioEnabled(
        saved.backgroundAudioEnabled,
      );
    }
    if (saved.nightModeEnabled != widget.playerService.snapshot.isNightMode) {
      await widget.playerService.setNightModeEnabled(saved.nightModeEnabled);
    }
    if (mounted) {
      setState(() {
        _saving = false;
        _settings = saved;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _openAiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player & Subtitle Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: settings == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionHeader('Playback'),
                SwitchListTile(
                  title: const Text('Resume Playback'),
                  subtitle: const Text(
                    'Continue videos from last saved position',
                  ),
                  value: settings.resumePlaybackEnabled,
                  onChanged: (v) =>
                      _save(settings.copyWith(resumePlaybackEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text('Hardware Decoding Acceleration'),
                  subtitle: const Text(
                    'Use GPU decoding when supported by device',
                  ),
                  value: settings.hardwareAccelerationEnabled,
                  onChanged: (v) => _save(
                    settings.copyWith(hardwareAccelerationEnabled: v),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Software Audio Boost (up to 200%)'),
                  subtitle: const Text(
                    'Boost quiet videos past 100% via libmpv volume gain',
                  ),
                  value: settings.softwareAudioBoostEnabled,
                  onChanged: (v) =>
                      _save(settings.copyWith(softwareAudioBoostEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text('Background Audio Playback'),
                  subtitle: const Text(
                    'Continue audio playback when minimized or screen locked',
                  ),
                  value: settings.backgroundAudioEnabled,
                  onChanged: (v) =>
                      _save(settings.copyWith(backgroundAudioEnabled: v)),
                ),
                SwitchListTile(
                  title: const Text('Night Mode Filter'),
                  subtitle: const Text(
                    'Warm blue-light overlay filter during late-night viewing',
                  ),
                  value: settings.nightModeEnabled,
                  onChanged: (v) =>
                      _save(settings.copyWith(nightModeEnabled: v)),
                ),
                ListTile(
                  title: const Text('Default Playback Speed'),
                  trailing: DropdownButton<double>(
                    value: AppConfig.playbackSpeedPresets.contains(
                          settings.defaultPlaybackSpeed,
                        )
                        ? settings.defaultPlaybackSpeed
                        : 1.0,
                    items: AppConfig.playbackSpeedPresets
                        .map(
                          (speed) => DropdownMenuItem<double>(
                            value: speed,
                            child: Text('${speed}x'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _save(settings.copyWith(defaultPlaybackSpeed: value));
                      }
                    },
                  ),
                ),
                const Divider(height: 28),
                const _SectionHeader('Subtitles & libass'),
                SwitchListTile(
                  title: const Text('Styled ASS/SSA Rendering (libass)'),
                  subtitle: const Text(
                    'Render rich ASS/SSA animations & fonts directly via libass',
                  ),
                  value: settings.useLibass,
                  onChanged: (v) => _save(settings.copyWith(useLibass: v)),
                ),
                ListTile(
                  title: const Text('Preferred Download Language'),
                  trailing: DropdownButton<String>(
                    value: SubtitleLanguages.findByCode(
                              settings.preferredSubtitleLanguage,
                            )?.iso6391 ??
                        'en',
                    items: SubtitleLanguages.all
                        .map(
                          (lang) => DropdownMenuItem<String>(
                            value: lang.iso6391,
                            child: Text(lang.englishName),
                          ),
                        )
                        .toList(),
                    onChanged: (code) {
                      if (code != null) {
                        _save(
                          settings.copyWith(preferredSubtitleLanguage: code),
                        );
                      }
                    },
                  ),
                ),
                const Divider(height: 28),
                const _SectionHeader('OpenSubtitles REST API v1'),
                TextField(
                  controller: _apiKeyController,
                  decoration: InputDecoration(
                    labelText: 'OpenSubtitles API Key',
                    hintText:
                        'Optional override if not built with --dart-define',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save_rounded),
                      onPressed: () {
                        _save(
                          settings.copyWith(
                            openSubtitlesApiKey: _apiKeyController.text.trim(),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('OpenSubtitles API key saved.'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _SectionHeader('OpenAI Whisper AI Subtitles'),
                TextField(
                  controller: _openAiKeyController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'OpenAI API Key',
                    hintText: 'Required for AI speech-to-text & translation',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.save_rounded),
                      onPressed: () {
                        _save(
                          settings.copyWith(
                            openAiApiKey: _openAiKeyController.text.trim(),
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('OpenAI API key saved.'),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          AppConfig.appLogoAsset,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConfig.appName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'v1.0.0 • Powered by libmpv, FFmpeg & libass',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
