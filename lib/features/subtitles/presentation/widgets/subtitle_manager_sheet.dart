import 'package:flutter/material.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/media_track_info.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/subtitles/data/ai_subtitle_service.dart';
import 'package:video_player_app/features/subtitles/data/subtitle_repository.dart';
import 'package:video_player_app/features/subtitles/presentation/subtitle_sheet_controller.dart';
import 'package:video_player_app/features/subtitles/presentation/widgets/subtitle_downloader_tab.dart';

/// Opens the unified 4-tab Audio & Subtitle Manager sheet:
/// 1) Tracks (Embedded Audio/Subtitles + Local File Picker + Saved Subtitles)
/// 2) Download (OpenSubtitles multi-language search & direct download)
/// 3) AI (OpenAI Whisper automatic speech-to-text & translation)
/// 4) Sync & Style (Delay -5.0s..+5.0s in 0.1s steps, Font Size, Scale, libass)
Future<void> showSubtitleManagerSheet(
  BuildContext context, {
  required PlayerService playerService,
  SubtitleRepository? subtitleRepository,
  AiSubtitleService? aiSubtitleService,
  int initialTabIndex = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _SubtitleManagerSheetBody(
      playerService: playerService,
      subtitleRepository: subtitleRepository,
      aiSubtitleService: aiSubtitleService,
      initialTabIndex: initialTabIndex,
    ),
  );
}

class _SubtitleManagerSheetBody extends StatefulWidget {
  final PlayerService playerService;
  final SubtitleRepository? subtitleRepository;
  final AiSubtitleService? aiSubtitleService;
  final int initialTabIndex;

  const _SubtitleManagerSheetBody({
    required this.playerService,
    this.subtitleRepository,
    this.aiSubtitleService,
    this.initialTabIndex = 0,
  });

  @override
  State<_SubtitleManagerSheetBody> createState() =>
      _SubtitleManagerSheetBodyState();
}

class _SubtitleManagerSheetBodyState extends State<_SubtitleManagerSheetBody>
    with SingleTickerProviderStateMixin {
  late final SubtitleSheetController _controller;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 3),
    );
    _controller = SubtitleSheetController(
      playerService: widget.playerService,
      repository: widget.subtitleRepository,
      aiSubtitleService: widget.aiSubtitleService,
    )..initialize();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.74,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            _controller,
            widget.playerService.snapshotListenable,
          ]),
          builder: (context, _) {
            final snapshot = widget.playerService.snapshot;
            return Column(
              children: [
                TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.accent,
                  labelColor: AppTheme.accent,
                  unselectedLabelColor: AppTheme.textSecondary,
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  tabs: const <Tab>[
                    Tab(text: 'Tracks'),
                    Tab(text: 'Download'),
                    Tab(text: 'AI Subtitles'),
                    Tab(text: 'Sync & Style'),
                  ],
                ),
                if (_controller.actionMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color:
                          (_controller.actionIsError
                                  ? AppTheme.danger
                                  : AppTheme.success)
                              .withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _controller.actionMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _controller.actionIsError
                            ? AppTheme.danger
                            : AppTheme.success,
                      ),
                    ),
                  ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _TracksTab(
                        controller: _controller,
                        scrollController: scrollController,
                      ),
                      SubtitleDownloaderTab(
                        controller: _controller,
                        snapshot: snapshot,
                        scrollController: scrollController,
                      ),
                      _AiSubtitlesTab(
                        controller: _controller,
                        scrollController: scrollController,
                      ),
                      _SyncAndStyleTab(
                        controller: _controller,
                        scrollController: scrollController,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TracksTab extends StatelessWidget {
  final SubtitleSheetController controller;
  final ScrollController scrollController;

  const _TracksTab({
    required this.controller,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final playerService = controller.playerService;
    final snapshot = playerService.snapshot;
    final audioTracks = _selectableTracks(snapshot.audioTracks);
    final embeddedSubtitles = _selectableTracks(snapshot.subtitleTracks);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        OutlinedButton.icon(
          onPressed: controller.pickAndAttachLocalSubtitle,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Load Local Subtitle (.srt, .ass, .ssa, .vtt, .sub)'),
        ),
        const SizedBox(height: 18),
        _SectionLabel('Audio Tracks'),
        if (audioTracks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Default audio stream active.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          )
        else
          for (final track in audioTracks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.audiotrack_rounded,
                color: snapshot.selectedAudioTrackId == track.id
                    ? AppTheme.accent
                    : AppTheme.textSecondary,
              ),
              title: Text(track.displayName),
              trailing: snapshot.selectedAudioTrackId == track.id
                  ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                  : null,
              onTap: () => playerService.selectAudioTrack(track.id),
            ),
        const Divider(height: 24),
        _SectionLabel('Subtitles'),
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.subtitles_off_outlined,
            color: snapshot.selectedSubtitleTrackId == 'no'
                ? AppTheme.accent
                : AppTheme.textSecondary,
          ),
          title: const Text('Off'),
          trailing: snapshot.selectedSubtitleTrackId == 'no'
              ? const Icon(Icons.check_rounded, color: AppTheme.accent)
              : null,
          onTap: playerService.disableSubtitles,
        ),
        for (final track in embeddedSubtitles)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.closed_caption_rounded,
              color: snapshot.selectedSubtitleTrackId == track.id
                  ? AppTheme.accent
                  : AppTheme.textSecondary,
            ),
            title: Text(track.displayName),
            trailing: snapshot.selectedSubtitleTrackId == track.id
                ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                : null,
            onTap: () => playerService.selectSubtitleTrack(track.id),
          ),
        if (snapshot.savedSubtitles.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionLabel('External & Downloaded Subtitles'),
          for (final saved in snapshot.savedSubtitles)
            _SavedSubtitleTile(
              saved: saved,
              isSelected:
                  snapshot.selectedSubtitleTrackId ==
                  'ext:${saved.localFilePath}',
              onSelect: () => playerService.selectSubtitleTrack(
                'ext:${saved.localFilePath}',
              ),
              onDelete: () => controller.deleteSavedSubtitle(saved),
            ),
        ],
      ],
    );
  }

  List<MediaTrackInfo> _selectableTracks(List<MediaTrackInfo> raw) {
    return raw
        .where((t) => !t.isSpecialAuto && !t.isSpecialNone && !t.isExternal)
        .toList(growable: false);
  }
}

class _AiSubtitlesTab extends StatelessWidget {
  final SubtitleSheetController controller;
  final ScrollController scrollController;

  const _AiSubtitlesTab({
    required this.controller,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        if (!controller.hasOpenAiApiKey)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentSecondary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.accentSecondary.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.key_rounded, color: AppTheme.accentSecondary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'OpenAI API key not set. Add it in Library Settings or pass --dart-define=OPENAI_API_KEY=...',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.divider),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppTheme.accent),
                  SizedBox(width: 8),
                  Text(
                    'AI Speech-to-Text & Translation',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                'Uses OpenAI Whisper to transcribe speech directly into synced .srt subtitles and optionally translate into Bengali, English, Hindi, Spanish, Arabic, Japanese, and more.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Target Subtitle Language'),
          trailing: DropdownButton<String>(
            value: SubtitleLanguages.findByCode(
                      controller.aiTargetLanguageCode,
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
              if (code != null) controller.setAiTargetLanguage(code);
            },
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: controller.isGeneratingAi
              ? null
              : controller.generateAiSubtitle,
          icon: controller.isGeneratingAi
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_awesome_rounded),
          label: Text(
            controller.isGeneratingAi
                ? 'Transcribing & Translating...'
                : 'Generate AI Subtitles (.srt)',
          ),
        ),
      ],
    );
  }
}

class _SavedSubtitleTile extends StatelessWidget {
  final SavedSubtitle saved;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  const _SavedSubtitleTile({
    required this.saved,
    required this.isSelected,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final sourceLabel = saved.source == SubtitleSource.opensubtitles
        ? 'Online / AI'
        : 'Local';
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.subtitles_rounded,
        color: isSelected ? AppTheme.accent : AppTheme.accentSecondary,
      ),
      title: Text(
        saved.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${saved.languageName} • ${saved.format.toUpperCase()} • $sourceLabel',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSelected)
            const Icon(Icons.check_rounded, color: AppTheme.accent),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppTheme.textSecondary,
            ),
            tooltip: 'Remove subtitle',
            onPressed: onDelete,
          ),
        ],
      ),
      onTap: onSelect,
    );
  }
}

class _SyncAndStyleTab extends StatelessWidget {
  final SubtitleSheetController controller;
  final ScrollController scrollController;

  const _SyncAndStyleTab({
    required this.controller,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.playerService.snapshot;
    final delayMs = snapshot.subtitleDelay.inMilliseconds.clamp(
      AppConfig.minSubtitleDelay.inMilliseconds,
      AppConfig.maxSubtitleDelay.inMilliseconds,
    );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel('Subtitle Sync Delay'),
            TextButton(
              onPressed: delayMs == 0 ? null : controller.resetDelay,
              child: const Text('Reset 0.0s'),
            ),
          ],
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => controller.stepDelay(-500),
                child: const Text('-0.5s'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed: () => controller.stepDelay(-100),
                child: const Text('-0.1s'),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 70,
                child: Text(
                  DurationFormatter.formatSignedSeconds(
                    Duration(milliseconds: delayMs),
                    decimal: true,
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accent,
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              FilledButton.tonal(
                onPressed: () => controller.stepDelay(100),
                child: const Text('+0.1s'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => controller.stepDelay(500),
                child: const Text('+0.5s'),
              ),
            ],
          ),
        ),
        Slider(
          min: AppConfig.minSubtitleDelay.inMilliseconds.toDouble(),
          max: AppConfig.maxSubtitleDelay.inMilliseconds.toDouble(),
          divisions: 100,
          value: delayMs.toDouble(),
          onChanged: (value) {
            final snapped = (value / 100).round() * 100;
            controller.setDelayMs(snapped);
          },
        ),
        const Divider(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel('Font Size'),
            Text(
              '${snapshot.subtitleFontSize.round()} pt',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
        Slider(
          min: AppConfig.minSubtitleFontSize,
          max: AppConfig.maxSubtitleFontSize,
          divisions: 34,
          value: snapshot.subtitleFontSize.clamp(
            AppConfig.minSubtitleFontSize,
            AppConfig.maxSubtitleFontSize,
          ),
          onChanged: controller.setFontSize,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel('ASS / libass Scale'),
            Text(
              '${snapshot.subtitleScale.toStringAsFixed(2)}x',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
        Slider(
          min: AppConfig.minSubtitleScale,
          max: AppConfig.maxSubtitleScale,
          divisions: 20,
          value: snapshot.subtitleScale.clamp(
            AppConfig.minSubtitleScale,
            AppConfig.maxSubtitleScale,
          ),
          onChanged: controller.setScale,
        ),
        const Divider(height: 24),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Styled ASS/SSA Renderer (libass)'),
          subtitle: const Text(
            'Enable for full ASS/SSA typography & animations; disable to render SRT/VTT with system Unicode fonts.',
          ),
          value: snapshot.useLibass,
          onChanged: controller.setLibassEnabled,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
