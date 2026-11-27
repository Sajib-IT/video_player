import 'package:flutter/material.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/presentation/subtitle_sheet_controller.dart';

/// Multi-language OpenSubtitles search and direct download tab.
class SubtitleDownloaderTab extends StatefulWidget {
  final SubtitleSheetController controller;
  final PlayerSnapshot snapshot;
  final ScrollController scrollController;

  const SubtitleDownloaderTab({
    super.key,
    required this.controller,
    required this.snapshot,
    required this.scrollController,
  });

  @override
  State<SubtitleDownloaderTab> createState() => _SubtitleDownloaderTabState();
}

class _SubtitleDownloaderTabState extends State<SubtitleDownloaderTab> {
  static const List<String> _quickLangCodes = <String>[
    'en',
    'bn',
    'hi',
    'es',
    'ar',
    'ja',
    'ko',
    'fr',
  ];

  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: widget.controller.searchText,
    );
  }

  @override
  void didUpdateWidget(covariant SubtitleDownloaderTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_queryController.text.isEmpty &&
        widget.controller.searchText.isNotEmpty) {
      _queryController.text = widget.controller.searchText;
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _showAllLanguagesDialog() async {
    var filter = '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = SubtitleLanguages.all.where((lang) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              return lang.englishName.toLowerCase().contains(q) ||
                  lang.nativeName.toLowerCase().contains(q) ||
                  lang.iso6391.contains(q);
            }).toList();

            return AlertDialog(
              title: const Text('Select Subtitle Languages'),
              content: SizedBox(
                width: double.maxFinite,
                height: 360,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filter language (e.g. Bengali, Japanese)...',
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setDialogState(() => filter = v),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final lang = filtered[index];
                          final selected = widget.controller.selectedLanguages
                              .contains(lang.iso6391);
                          return CheckboxListTile(
                            dense: true,
                            value: selected,
                            title: Text(lang.displayLabel),
                            subtitle: Text(lang.iso6391.toUpperCase()),
                            onChanged: (_) {
                              widget.controller.toggleLanguage(lang.iso6391);
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    widget.controller.clearLanguageFilters();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('All Languages'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final downloadedIds = widget.snapshot.savedSubtitles
        .map((s) => s.externalId)
        .whereType<String>()
        .toSet();

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (!ctrl.hasApiKey)
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
                    'OpenSubtitles API key not set. Add it in Library Settings or pass --dart-define=OPENSUBTITLES_API_KEY=...',
                    style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _queryController,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Movie or Episode Title',
                  hintText: 'e.g. Inception 2010 or Dandadan 05',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: ctrl.setSearchText,
                onSubmitted: (value) => ctrl.searchOnline(overrideQuery: value),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: ctrl.isSearching
                  ? null
                  : () => ctrl.searchOnline(
                      overrideQuery: _queryController.text,
                    ),
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Search'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (ctrl.movieHash != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                FilterChip(
                  selected: ctrl.useMovieHash,
                  label: Text(
                    'Match File Hash (${ctrl.movieHash!.substring(0, 8)}…)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onSelected: ctrl.setUseMovieHash,
                ),
              ],
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: ctrl.selectedLanguages.isEmpty,
                onSelected: (_) => ctrl.clearLanguageFilters(),
              ),
              const SizedBox(width: 6),
              for (final code in _quickLangCodes) ...[
                FilterChip(
                  label: Text(SubtitleLanguages.labelForCode(code)),
                  selected: ctrl.selectedLanguages.contains(code),
                  onSelected: (_) => ctrl.toggleLanguage(code),
                ),
                const SizedBox(width: 6),
              ],
              ActionChip(
                avatar: const Icon(Icons.translate_rounded, size: 16),
                label: const Text('More Languages'),
                onPressed: _showAllLanguagesDialog,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (ctrl.isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (ctrl.searchError != null)
          _SearchMessageCard(
            icon: Icons.cloud_off_rounded,
            color: AppTheme.danger,
            title: 'Search Error',
            message: ctrl.searchError!,
            actionLabel: 'Retry Search',
            onAction: () =>
                ctrl.searchOnline(overrideQuery: _queryController.text),
          )
        else if (!ctrl.hasSearched)
          const _SearchMessageCard(
            icon: Icons.subtitles_outlined,
            color: AppTheme.accent,
            title: 'Search Online Subtitles',
            message:
                'Tap Search to query OpenSubtitles by video hash, cleaned title, and selected languages.',
          )
        else if (ctrl.results.isEmpty)
          _SearchMessageCard(
            icon: Icons.search_off_rounded,
            color: AppTheme.textSecondary,
            title: 'No Subtitles Found',
            message:
                'No matches found for "${ctrl.searchText}". Try broadening your language filter or editing the title.',
            actionLabel: ctrl.selectedLanguages.isNotEmpty
                ? 'Search All Languages'
                : null,
            onAction: ctrl.selectedLanguages.isNotEmpty
                ? () {
                    ctrl.clearLanguageFilters();
                    ctrl.searchOnline(overrideQuery: _queryController.text);
                  }
                : null,
          )
        else
          for (final item in ctrl.results)
            _OnlineSubtitleTile(
              item: item,
              isDownloaded: downloadedIds.contains(item.fileId.toString()),
              isDownloading: ctrl.downloadingFileId == item.fileId,
              onDownload: () => ctrl.downloadAndAttach(item),
            ),
      ],
    );
  }
}

class _OnlineSubtitleTile extends StatelessWidget {
  final OnlineSubtitleResult item;
  final bool isDownloaded;
  final bool isDownloading;
  final VoidCallback onDownload;

  const _OnlineSubtitleTile({
    required this.item,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[
      item.languageName,
      item.formatExtension.toUpperCase(),
      if (item.downloadCount > 0) '${item.downloadCount} downloads',
      if (item.isHearingImpaired) 'HI',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          item.releaseName.isNotEmpty ? item.releaseName : item.fileName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (item.isHashMatch)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    'HASH MATCH',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              Text(
                subtitleParts.join(' • '),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        trailing: isDownloading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : IconButton(
                icon: Icon(
                  isDownloaded
                      ? Icons.download_done_rounded
                      : Icons.download_rounded,
                  color: isDownloaded ? AppTheme.success : AppTheme.accent,
                ),
                tooltip: isDownloaded
                    ? 'Downloaded • Tap to re-apply'
                    : 'Download & Load',
                onPressed: onDownload,
              ),
        onTap: isDownloading ? null : onDownload,
      ),
    );
  }
}

class _SearchMessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SearchMessageCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
