import 'package:path/path.dart' as p;
import 'package:video_player_app/data/local/dao/cached_video_dao.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';
import 'package:video_player_app/features/library/data/local_video_scanner.dart';
import 'package:video_player_app/features/library/data/media_file_operations.dart';
import 'package:video_player_app/features/library/domain/library_sort_option.dart';
import 'package:video_player_app/features/library/domain/video_folder.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

/// Coordinates offline SQLite cache, live device storage scans, watch history
/// enrichment, folder grouping, and file management actions.
class MediaLibraryRepository {
  final LocalVideoScanner _scanner;
  final WatchHistoryDao _watchHistoryDao;
  final CachedVideoDao _cachedVideoDao;
  final PlaybackSettingsDao _settingsDao;
  final SavedSubtitleDao _savedSubtitleDao;
  final MediaFileOperations _fileOperations;

  MediaLibraryRepository({
    LocalVideoScanner? scanner,
    WatchHistoryDao? watchHistoryDao,
    CachedVideoDao? cachedVideoDao,
    PlaybackSettingsDao? settingsDao,
    SavedSubtitleDao? savedSubtitleDao,
    MediaFileOperations? fileOperations,
  }) : _scanner = scanner ?? const PhotoManagerVideoScanner(),
       _watchHistoryDao = watchHistoryDao ?? WatchHistoryDao(),
       _cachedVideoDao = cachedVideoDao ?? CachedVideoDao(),
       _settingsDao = settingsDao ?? PlaybackSettingsDao(),
       _savedSubtitleDao = savedSubtitleDao ?? SavedSubtitleDao(),
       _fileOperations = fileOperations ?? const DeviceMediaFileOperations();

  Future<List<VideoItem>> loadCachedVideos() async {
    final cached = await _cachedVideoDao.getAll();
    final historyMap = await _watchHistoryDao.getAllIndexed();
    return cached
        .map(
          (record) => VideoItem.fromCachedRecord(
            record,
            watchHistory: historyMap[record.mediaKey],
          ),
        )
        .toList(growable: false);
  }

  Future<List<VideoItem>> scanAndCacheVideos() async {
    final scanned = await _scanner.scanVideos();
    final historyMap = await _watchHistoryDao.getAllIndexed();
    final enriched = scanned
        .map(
          (item) => item.copyWith(watchHistory: historyMap[item.mediaKey]),
        )
        .toList(growable: false);

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await _cachedVideoDao.replaceAll(
      enriched
          .map((item) => item.toCachedRecord(scannedAtMs: nowMs))
          .toList(growable: false),
    );
    return enriched;
  }

  Future<List<VideoItem>> attachHistory(List<VideoItem> items) async {
    final historyMap = await _watchHistoryDao.getAllIndexed();
    return items
        .map(
          (item) => item.copyWith(
            watchHistory: historyMap[item.mediaKey],
            clearWatchHistory: !historyMap.containsKey(item.mediaKey),
          ),
        )
        .toList(growable: false);
  }

  Future<VideoItem?> pickLocalVideoFile() async {
    final picked = await _scanner.pickSingleVideoFile();
    if (picked == null) return null;
    final history = await _watchHistoryDao.getByMediaKey(picked.mediaKey);
    return picked.copyWith(watchHistory: history);
  }

  Future<void> markWatched(VideoItem item, {required bool watched}) {
    return _watchHistoryDao.markWatched(
      item.mediaKey,
      watched: watched,
      filePath: item.filePath,
      title: item.title,
      folderPath: item.folderPath,
      fileSizeBytes: item.sizeBytes,
      durationMs: item.effectiveDuration.inMilliseconds,
    );
  }

  Future<void> clearHistory(String mediaKey) {
    return _watchHistoryDao.deleteByMediaKey(mediaKey);
  }

  Future<String> renameVideo(VideoItem item, String newBaseName) async {
    final newPath = await _fileOperations.renameVideo(item, newBaseName);
    final oldHistory = await _watchHistoryDao.getByMediaKey(item.mediaKey);
    if (oldHistory != null) {
      await _watchHistoryDao.deleteByMediaKey(item.mediaKey);
      await _watchHistoryDao.upsert(
        oldHistory.copyWith(
          mediaKey: newPath,
          filePath: newPath,
          title: p.basenameWithoutExtension(newPath),
        ),
      );
    }
    return newPath;
  }

  Future<void> deleteVideo(VideoItem item) async {
    await _fileOperations.deleteVideo(item);
    await _watchHistoryDao.deleteByMediaKey(item.mediaKey);
    await _savedSubtitleDao.deleteForMedia(item.mediaKey);
  }

  Future<void> shareVideo(VideoItem item) {
    return _fileOperations.shareVideo(item);
  }

  Future<LibrarySortOption> loadSortOption() async {
    final settings = await _settingsDao.getSettings();
    return LibrarySortOption(
      field: settings.librarySortField,
      ascending: settings.librarySortAscending,
    );
  }

  Future<PlaybackSettings> getSettings() => _settingsDao.getSettings();

  Future<PlaybackSettings> saveSettings(PlaybackSettings settings) {
    return _settingsDao.saveSettings(settings);
  }

  Future<void> saveSortOption(LibrarySortOption sortOption) async {
    final settings = await _settingsDao.getSettings();
    await _settingsDao.saveSettings(
      settings.copyWith(
        librarySortField: sortOption.field,
        librarySortAscending: sortOption.ascending,
      ),
    );
  }

  /// Groups sorted [videos] by `folderPath`, ordered by latest modified date.
  static List<VideoFolder> groupIntoFolders(List<VideoItem> videos) {
    final grouped = <String, List<VideoItem>>{};
    final folderNames = <String, String>{};

    for (final video in videos) {
      grouped.putIfAbsent(video.folderPath, () => <VideoItem>[]).add(video);
      folderNames.putIfAbsent(video.folderPath, () => video.folderName);
    }

    final folders = grouped.entries
        .map(
          (entry) => VideoFolder(
            folderPath: entry.key,
            folderName: folderNames[entry.key] ?? 'Videos',
            videos: List<VideoItem>.unmodifiable(entry.value),
          ),
        )
        .toList(growable: false);

    folders.sort((a, b) => b.latestModified.compareTo(a.latestModified));
    return folders;
  }
}
