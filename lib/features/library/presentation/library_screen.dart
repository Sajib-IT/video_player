import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/features/downloader/data/web_video_download_service.dart';
import 'package:video_player_app/features/downloader/presentation/downloader_sheet.dart';
import 'package:video_player_app/features/library/domain/library_permission_status.dart';
import 'package:video_player_app/features/library/domain/library_sort_field.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/library/presentation/library_controller.dart';
import 'package:video_player_app/features/library/presentation/settings_screen.dart';
import 'package:video_player_app/features/library/presentation/widgets/folder_card.dart';
import 'package:video_player_app/features/library/presentation/widgets/video_list_tile.dart';
import 'package:video_player_app/features/library/presentation/widgets/video_thumbnail_box.dart';
import 'package:video_player_app/features/player/domain/player_snapshot.dart';
import 'package:video_player_app/features/player/presentation/player_screen.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/vault/presentation/vault_controller.dart';
import 'package:video_player_app/features/vault/presentation/vault_screen.dart';

/// Main local media library screen with Folder, All Videos, Audio/MP3,
/// Private Video Vault, Web Downloader, Search, Sort, and Background Mini Player.
class LibraryScreen extends StatefulWidget {
  final LibraryController controller;
  final PlayerService playerService;
  final VaultController? vaultController;
  final WebVideoDownloadController? downloadController;

  const LibraryScreen({
    super.key,
    required this.controller,
    required this.playerService,
    this.vaultController,
    this.downloadController,
  });

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _searchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  VaultController? _ownedVaultController;
  WebVideoDownloadController? _ownedDownloadController;

  VaultController get _vaultController =>
      widget.vaultController ?? (_ownedVaultController ??= VaultController());

  WebVideoDownloadController get _downloadController =>
      widget.downloadController ??
      (_ownedDownloadController ??= WebVideoDownloadController());

  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ownedVaultController?.dispose();
    _ownedDownloadController?.dispose();
    super.dispose();
  }

  Future<void> _openVideo(
    VideoItem video, {
    Duration? initialPosition,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          playerService: widget.playerService,
          request: video.toPlaybackRequest(initialPosition: initialPosition),
        ),
      ),
    );
    await widget.controller.refreshWatchHistory();
  }

  Future<void> _reopenBackgroundPlayer() async {
    final activeMedia = widget.playerService.snapshot.currentMedia;
    if (activeMedia == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          playerService: widget.playerService,
          request: activeMedia,
          resumeCurrentSession: true,
        ),
      ),
    );
    await widget.controller.refreshWatchHistory();
  }

  Future<void> _pickAndPlayLocalFile() async {
    final picked = await widget.controller.pickLocalVideoFile();
    if (picked == null || !mounted) return;
    await _openVideo(picked);
  }

  Future<void> _openWebDownloader() async {
    await showWebDownloaderSheet(
      context,
      downloadController: _downloadController,
      playerService: widget.playerService,
      onDownloadCompleted: widget.controller.refresh,
    );
  }

  Future<void> _renameVideo(LibraryController ctrl, VideoItem video) async {
    final textController = TextEditingController(
      text: p.basenameWithoutExtension(video.fileName),
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New file name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(textController.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (newName == null || newName.isEmpty || !mounted) return;

    try {
      await ctrl.renameVideo(video, newName);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Renamed to "$newName"')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _shareVideo(LibraryController ctrl, VideoItem video) async {
    try {
      await ctrl.shareVideo(video);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _moveToVault(LibraryController ctrl, VideoItem video) async {
    await _vaultController.initialize();
    if (!mounted) return;

    if (!_vaultController.isPinConfigured) {
      ctrl.setViewMode(LibraryViewMode.vault);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Set up a Private Vault PIN first to hide videos.'),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Move to Private Vault'),
        content: Text(
          'Hide "${video.title}" inside your PIN-protected Private Vault?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Move to Vault'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _vaultController.moveVideoToVault(video);
      await ctrl.refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moved to Private Vault.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _deleteVideo(LibraryController ctrl, VideoItem video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Media'),
        content: Text('Permanently delete "${video.title}" from device storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ctrl.deleteVideo(video);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deleted "${video.title}"')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showSortSheet() async {
    final current = widget.controller.sortOption;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sort Media By',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        widget.controller.setSortOption(
                          ascending: !current.ascending,
                        );
                        Navigator.of(sheetContext).pop();
                      },
                      icon: Icon(
                        current.ascending
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 18,
                      ),
                      label: Text(current.ascending ? 'Ascending' : 'Descending'),
                    ),
                  ],
                ),
              ),
              for (final field in LibrarySortField.values)
                ListTile(
                  leading: Icon(
                    _iconForSortField(field),
                    color: current.field == field
                        ? AppTheme.accent
                        : AppTheme.textSecondary,
                  ),
                  title: Text(field.label),
                  trailing: current.field == field
                      ? const Icon(Icons.check_rounded, color: AppTheme.accent)
                      : null,
                  onTap: () {
                    widget.controller.setSortOption(field: field);
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForSortField(LibrarySortField field) {
    switch (field) {
      case LibrarySortField.name:
        return Icons.sort_by_alpha_rounded;
      case LibrarySortField.date:
        return Icons.schedule_rounded;
      case LibrarySortField.size:
        return Icons.sd_storage_outlined;
      case LibrarySortField.duration:
        return Icons.timer_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final insideFolder = ctrl.selectedFolderPath != null;

        return PopScope(
          canPop: !insideFolder && !_searchVisible,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (_searchVisible) {
              setState(() => _searchVisible = false);
              _searchController.clear();
              ctrl.setSearchQuery('');
            } else if (insideFolder) {
              ctrl.closeFolder();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              leading: insideFolder
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: ctrl.closeFolder,
                    )
                  : null,
              titleSpacing: insideFolder ? 0 : 12,
              title: _searchVisible
                  ? TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Search videos, audio, or folders...',
                        border: InputBorder.none,
                      ),
                      onChanged: ctrl.setSearchQuery,
                    )
                  : (insideFolder
                        ? Text(
                            ctrl.selectedFolderName ?? 'Folder',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17.5,
                              letterSpacing: -0.3,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.asset(
                                  AppConfig.appLogoAsset,
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    AppConfig.appName,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16.5,
                                      letterSpacing: -0.35,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )),
              actions: [
                IconButton(
                  icon: Icon(
                    _searchVisible ? Icons.close_rounded : Icons.search_rounded,
                  ),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 36),
                  ),
                  tooltip: 'Search',
                  onPressed: () {
                    setState(() => _searchVisible = !_searchVisible);
                    if (!_searchVisible) {
                      _searchController.clear();
                      ctrl.setSearchQuery('');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.download_for_offline_outlined),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 36),
                  ),
                  tooltip: 'Web Downloader',
                  onPressed: _openWebDownloader,
                ),
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 36),
                  ),
                  tooltip: 'Sort',
                  onPressed: _showSortSheet,
                ),
                IconButton(
                  icon: const Icon(Icons.folder_open_rounded),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 36),
                  ),
                  tooltip: 'Open Local File',
                  onPressed: _pickAndPlayLocalFile,
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(34, 36),
                  ),
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => SettingsScreen(
                          libraryController: ctrl,
                          playerService: widget.playerService,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: _buildBody(ctrl),
            bottomNavigationBar: _BackgroundMiniPlayerBar(
              playerService: widget.playerService,
              onOpenPlayer: _reopenBackgroundPlayer,
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeSwitcher(LibraryController ctrl) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<LibraryViewMode>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: WidgetStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            ),
          ),
          segments: const <ButtonSegment<LibraryViewMode>>[
            ButtonSegment<LibraryViewMode>(
              value: LibraryViewMode.folders,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Folders', maxLines: 1, softWrap: false),
              ),
            ),
            ButtonSegment<LibraryViewMode>(
              value: LibraryViewMode.allVideos,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('All Videos', maxLines: 1, softWrap: false),
              ),
            ),
            ButtonSegment<LibraryViewMode>(
              value: LibraryViewMode.audio,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Audio', maxLines: 1, softWrap: false),
              ),
            ),
            ButtonSegment<LibraryViewMode>(
              value: LibraryViewMode.vault,
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Vault', maxLines: 1, softWrap: false),
              ),
            ),
          ],
          selected: <LibraryViewMode>{ctrl.viewMode},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) {
              ctrl.setViewMode(selection.first);
            }
          },
        ),
      ),
    );
  }

  Widget _buildBody(LibraryController ctrl) {
    final insideFolder = ctrl.selectedFolderPath != null;

    if (!insideFolder && ctrl.viewMode == LibraryViewMode.vault) {
      return Column(
        children: [
          _buildModeSwitcher(ctrl),
          Expanded(
            child: VaultTabView(
              controller: _vaultController,
              playerService: widget.playerService,
              onLibraryChanged: ctrl.refresh,
            ),
          ),
        ],
      );
    }

    if (ctrl.isLoading && ctrl.allVideos.isEmpty && ctrl.allAudio.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!ctrl.permissionStatus.hasAccess &&
        ctrl.allVideos.isEmpty &&
        ctrl.allAudio.isEmpty) {
      return Column(
        children: [
          if (!insideFolder) _buildModeSwitcher(ctrl),
          Expanded(
            child: _PermissionStateView(
              status: ctrl.permissionStatus,
              onRequestPermission: ctrl.requestPermissionAndScan,
              onOpenSettings: ctrl.openPermissionSettings,
              onOpenSingleFile: _pickAndPlayLocalFile,
            ),
          ),
        ],
      );
    }

    final showFoldersList =
        !insideFolder && ctrl.viewMode == LibraryViewMode.folders;
    final showAudioList =
        !insideFolder && ctrl.viewMode == LibraryViewMode.audio;
    final folders = ctrl.visibleFolders;
    final items = showAudioList ? ctrl.visibleAudioTracks : ctrl.visibleVideos;
    final continueWatching = showAudioList
        ? const <VideoItem>[]
        : ctrl.continueWatchingVideos;

    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (ctrl.permissionStatus == LibraryPermissionStatus.limited)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Material(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    leading: const Icon(
                      Icons.perm_media_outlined,
                      color: AppTheme.accentSecondary,
                    ),
                    title: const Text('Limited media access granted'),
                    subtitle: const Text('Tap to select additional media files'),
                    trailing: TextButton(
                      onPressed: ctrl.manageLimitedAccess,
                      child: const Text('Manage'),
                    ),
                  ),
                ),
              ),
            ),
          if (!insideFolder)
            SliverToBoxAdapter(child: _buildModeSwitcher(ctrl)),
          if (!insideFolder &&
              ctrl.searchQuery.isEmpty &&
              continueWatching.isNotEmpty)
            SliverToBoxAdapter(
              child: _ContinueWatchingStrip(
                videos: continueWatching,
                onTapVideo: (video) => _openVideo(video),
              ),
            ),
          if (ctrl.isScanning)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            ),
          if (ctrl.errorMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text(
                  ctrl.errorMessage!,
                  style: const TextStyle(color: AppTheme.danger),
                ),
              ),
            ),
          if (showFoldersList)
            if (folders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyLibraryView(
                  hasSearchQuery: ctrl.searchQuery.isNotEmpty,
                  isAudioMode: false,
                  onOpenSingleFile: _pickAndPlayLocalFile,
                  onRescan: ctrl.refresh,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverList.separated(
                  itemCount: folders.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return FolderCard(
                      folder: folder,
                      onTap: () => ctrl.openFolder(folder.folderPath),
                    );
                  },
                ),
              )
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyLibraryView(
                hasSearchQuery: ctrl.searchQuery.isNotEmpty,
                isAudioMode: showAudioList,
                onOpenSingleFile: _pickAndPlayLocalFile,
                onRescan: ctrl.refresh,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final media = items[index];
                  return VideoListTile(
                    video: media,
                    onTap: () => _openVideo(media),
                    onPlayFromStart: () =>
                        _openVideo(media, initialPosition: Duration.zero),
                    onToggleWatched: (watched) =>
                        ctrl.markWatched(media, watched: watched),
                    onClearProgress: () => ctrl.clearVideoProgress(media),
                    onRename: () => _renameVideo(ctrl, media),
                    onShare: () => _shareVideo(ctrl, media),
                    onMoveToVault: media.isAudioOnly
                        ? null
                        : () => _moveToVault(ctrl, media),
                    onDelete: () => _deleteVideo(ctrl, media),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _BackgroundMiniPlayerBar extends StatelessWidget {
  final PlayerService playerService;
  final VoidCallback onOpenPlayer;

  const _BackgroundMiniPlayerBar({
    required this.playerService,
    required this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PlayerSnapshot>(
      valueListenable: playerService.snapshotListenable,
      builder: (context, snapshot, _) {
        final media = snapshot.currentMedia;
        if (media == null || !snapshot.isBackgroundAudioEnabled) {
          return const SizedBox.shrink();
        }
        return Material(
          color: AppTheme.surfaceElevated,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: onOpenPlayer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: snapshot.progress,
                    minHeight: 2,
                    color: AppTheme.accent,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            media.isAudioOnly
                                ? Icons.music_note_rounded
                                : Icons.headphones_rounded,
                            color: AppTheme.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                media.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${DurationFormatter.format(snapshot.position)} / ${DurationFormatter.format(snapshot.duration)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: snapshot.isPlaying ? 'Pause' : 'Play',
                          icon: Icon(
                            snapshot.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          onPressed: playerService.playOrPause,
                        ),
                        IconButton(
                          tooltip: 'Stop Background Playback',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () async {
                            await playerService.setBackgroundAudioEnabled(false);
                            await playerService.stop();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContinueWatchingStrip extends StatelessWidget {
  final List<VideoItem> videos;
  final ValueChanged<VideoItem> onTapVideo;

  const _ContinueWatchingStrip({
    required this.videos,
    required this.onTapVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Text(
            'Continue Watching',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final video = videos[index];
              return GestureDetector(
                onTap: () => onTapVideo(video),
                child: SizedBox(
                  width: 156,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VideoThumbnailBox(
                        video: video,
                        width: 156,
                        height: 88,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Left at ${DurationFormatter.format(video.resumePosition)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PermissionStateView extends StatelessWidget {
  final LibraryPermissionStatus status;
  final VoidCallback onRequestPermission;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenSingleFile;

  const _PermissionStateView({
    required this.status,
    required this.onRequestPermission,
    required this.onOpenSettings,
    required this.onOpenSingleFile,
  });

  @override
  Widget build(BuildContext context) {
    final isPermanent = status == LibraryPermissionStatus.permanentlyDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 64,
              color: AppTheme.accent,
            ),
            const SizedBox(height: 16),
            Text(
              'Media Access Required',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isPermanent
                  ? 'Storage permission was permanently denied. Enable media access in system settings or open a file directly.'
                  : 'Grant media library permission so CineVault can organize your local videos & music and save resume history.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: isPermanent ? onOpenSettings : onRequestPermission,
              icon: Icon(
                isPermanent ? Icons.settings_outlined : Icons.lock_open_rounded,
              ),
              label: Text(
                isPermanent ? 'Open App Settings' : 'Grant Media Permission',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpenSingleFile,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Open Video File'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyLibraryView extends StatelessWidget {
  final bool hasSearchQuery;
  final bool isAudioMode;
  final VoidCallback onOpenSingleFile;
  final VoidCallback onRescan;

  const _EmptyLibraryView({
    required this.hasSearchQuery,
    required this.isAudioMode,
    required this.onOpenSingleFile,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    final noun = isAudioMode ? 'audio tracks' : 'local videos';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearchQuery
                  ? Icons.search_off_rounded
                  : (isAudioMode
                      ? Icons.library_music_outlined
                      : Icons.movie_filter_outlined),
              size: 56,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              hasSearchQuery ? 'No matching media found' : 'No $noun found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasSearchQuery
                  ? 'Try another search term or clear your filter.'
                  : 'Pull down to rescan storage or open any MKV, MP4, AVI, MOV, FLV, TS, RMVB, WebM, or MP3 file directly.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearchQuery) ...[
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenSingleFile,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Open Media File'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRescan,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Rescan'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
