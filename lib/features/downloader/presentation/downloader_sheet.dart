import 'package:flutter/material.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/data/local/models/video_download_record.dart';
import 'package:video_player_app/features/downloader/data/web_video_download_service.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/player/presentation/player_screen.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

/// Opens the Web Video Downloader bottom sheet for direct URL downloads.
Future<void> showWebDownloaderSheet(
  BuildContext context, {
  required WebVideoDownloadController downloadController,
  required PlayerService playerService,
  required VoidCallback onDownloadCompleted,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _WebDownloaderSheetBody(
      controller: downloadController,
      playerService: playerService,
      onDownloadCompleted: onDownloadCompleted,
    ),
  );
}

class _WebDownloaderSheetBody extends StatefulWidget {
  final WebVideoDownloadController controller;
  final PlayerService playerService;
  final VoidCallback onDownloadCompleted;

  const _WebDownloaderSheetBody({
    required this.controller,
    required this.playerService,
    required this.onDownloadCompleted,
  });

  @override
  State<_WebDownloaderSheetBody> createState() =>
      _WebDownloaderSheetBodyState();
}

class _WebDownloaderSheetBodyState extends State<_WebDownloaderSheetBody> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.loadHistory();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final completed = await widget.controller.startDownload(_urlController.text);
    if (completed != null) {
      _urlController.clear();
      widget.onDownloadCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final ctrl = widget.controller;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  'Web Video Downloader',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Paste a direct HTTP/HTTPS video link (MP4, MKV, WebM). YouTube URLs are blocked per Google Play policy.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Direct Video URL',
                          hintText: 'https://example.com/clip.mp4',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _start(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: const Text('Get'),
                    ),
                  ],
                ),
                if (ctrl.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      ctrl.errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                if (ctrl.records.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No web video downloads yet.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  for (final item in ctrl.records)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.fileName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (item.status ==
                                    VideoDownloadStatus.downloading)
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: item.id != null
                                        ? () => ctrl.cancelDownload(item.id!)
                                        : null,
                                  )
                                else if (item.status ==
                                    VideoDownloadStatus.completed) ...[
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: AppTheme.accent,
                                    ),
                                    onPressed: () {
                                      final video = VideoItem.fromPickedFile(
                                        filePath: item.savePath,
                                        fileNameOverride: item.fileName,
                                        sizeBytes: item.totalBytes > 0
                                            ? item.totalBytes
                                            : item.receivedBytes,
                                        modifiedAt: DateTime.now(),
                                      );
                                      Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) => PlayerScreen(
                                            playerService: widget.playerService,
                                            request: video.toPlaybackRequest(),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppTheme.textSecondary,
                                    ),
                                    onPressed: () => ctrl.deleteRecord(item),
                                  ),
                                ] else
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppTheme.textSecondary,
                                    ),
                                    onPressed: () => ctrl.deleteRecord(item),
                                  ),
                              ],
                            ),
                            if (item.status == VideoDownloadStatus.downloading)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: LinearProgressIndicator(
                                  value: item.totalBytes > 0
                                      ? item.progress
                                      : null,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              _statusLine(item),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    item.status == VideoDownloadStatus.failed
                                    ? AppTheme.danger
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  String _statusLine(VideoDownloadRecord item) {
    switch (item.status) {
      case VideoDownloadStatus.pending:
        return 'Queued...';
      case VideoDownloadStatus.downloading:
        final pct = item.totalBytes > 0
            ? '${(item.progress * 100).round()}%'
            : DurationFormatter.formatFileSize(item.receivedBytes);
        return 'Downloading $pct';
      case VideoDownloadStatus.completed:
        final bytes = item.totalBytes > 0
            ? item.totalBytes
            : item.receivedBytes;
        return bytes > 0
            ? 'Saved • ${DurationFormatter.formatFileSize(bytes)}'
            : 'Saved';
      case VideoDownloadStatus.failed:
        return item.errorMessage ?? 'Failed';
      case VideoDownloadStatus.cancelled:
        return 'Cancelled';
    }
  }
}
