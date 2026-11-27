import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/watch_history_entry.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';

/// Data access object for watch progress, resume positions, and per-video settings.
class WatchHistoryDao {
  final DatabaseHelper _dbHelper;

  WatchHistoryDao({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<WatchHistoryEntry?> getByMediaKey(String mediaKey) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableWatchHistory,
      where: 'media_key = ?',
      whereArgs: <Object?>[mediaKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return WatchHistoryEntry.fromMap(rows.first);
  }

  Future<Map<String, WatchHistoryEntry>> getAllIndexed() async {
    final db = await _dbHelper.database;
    final rows = await db.query(DatabaseHelper.tableWatchHistory);
    final result = <String, WatchHistoryEntry>{};
    for (final row in rows) {
      final entry = WatchHistoryEntry.fromMap(row);
      result[entry.mediaKey] = entry;
    }
    return result;
  }

  Future<List<WatchHistoryEntry>> getRecent({int limit = 30}) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableWatchHistory,
      orderBy: 'last_played_at DESC',
      limit: limit,
    );
    return rows.map(WatchHistoryEntry.fromMap).toList(growable: false);
  }

  Future<WatchHistoryEntry> upsert(WatchHistoryEntry entry) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final data = entry.toMap()..remove('id');
      final updated = await txn.update(
        DatabaseHelper.tableWatchHistory,
        data,
        where: 'media_key = ?',
        whereArgs: <Object?>[entry.mediaKey],
      );
      if (updated == 0) {
        final insertedId = await txn.insert(
          DatabaseHelper.tableWatchHistory,
          data,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return entry.copyWith(id: insertedId);
      }

      final rows = await txn.query(
        DatabaseHelper.tableWatchHistory,
        where: 'media_key = ?',
        whereArgs: <Object?>[entry.mediaKey],
        limit: 1,
      );
      return rows.isEmpty ? entry : WatchHistoryEntry.fromMap(rows.first);
    });
  }

  /// Records playback progress and automatically derives watched state.
  Future<WatchHistoryEntry> saveProgress({
    required String mediaKey,
    required String filePath,
    required String title,
    String folderPath = '',
    int fileSizeBytes = 0,
    required Duration position,
    required Duration duration,
    double? playbackSpeed,
    AspectRatioMode? aspectRatioMode,
    String? audioTrackId,
    String? subtitleTrackId,
    int? subtitleDelayMs,
    bool incrementPlayCount = false,
    bool? forceWatched,
  }) async {
    final existing = await getByMediaKey(mediaKey);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final positionMs = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    final durationMs = duration.inMilliseconds < 0
        ? (existing?.durationMs ?? 0)
        : (duration.inMilliseconds > 0
              ? duration.inMilliseconds
              : (existing?.durationMs ?? 0));

    final reachedWatchedRatio =
        durationMs > 0 &&
        (positionMs / durationMs) >= AppConfig.watchedCompletionRatio;
    final watched = forceWatched ?? ((existing?.isWatched ?? false) || reachedWatchedRatio);

    final nextEntry = WatchHistoryEntry(
      id: existing?.id,
      mediaKey: mediaKey,
      filePath: filePath,
      title: title,
      folderPath: folderPath.isNotEmpty
          ? folderPath
          : (existing?.folderPath ?? ''),
      fileSizeBytes: fileSizeBytes > 0
          ? fileSizeBytes
          : (existing?.fileSizeBytes ?? 0),
      positionMs: watched && reachedWatchedRatio ? 0 : positionMs,
      durationMs: durationMs,
      isWatched: watched,
      playbackSpeed: playbackSpeed ?? existing?.playbackSpeed ?? 1.0,
      aspectRatioMode:
          aspectRatioMode ?? existing?.aspectRatioMode ?? AspectRatioMode.fit,
      audioTrackId: audioTrackId ?? existing?.audioTrackId,
      subtitleTrackId: subtitleTrackId ?? existing?.subtitleTrackId,
      subtitleDelayMs: subtitleDelayMs ?? existing?.subtitleDelayMs ?? 0,
      playCount: (existing?.playCount ?? 0) + (incrementPlayCount ? 1 : 0),
      lastPlayedAtMs: nowMs,
      updatedAtMs: nowMs,
    );

    return upsert(nextEntry);
  }

  Future<void> markWatched(
    String mediaKey, {
    required bool watched,
    String? filePath,
    String? title,
    String folderPath = '',
    int fileSizeBytes = 0,
    int durationMs = 0,
  }) async {
    final existing = await getByMediaKey(mediaKey);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (existing == null) {
      if (filePath == null || title == null) return;
      await upsert(
        WatchHistoryEntry(
          mediaKey: mediaKey,
          filePath: filePath,
          title: title,
          folderPath: folderPath,
          fileSizeBytes: fileSizeBytes,
          positionMs: 0,
          durationMs: durationMs,
          isWatched: watched,
          lastPlayedAtMs: nowMs,
          updatedAtMs: nowMs,
        ),
      );
      return;
    }

    await upsert(
      existing.copyWith(
        isWatched: watched,
        positionMs: watched ? 0 : existing.positionMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  Future<int> deleteByMediaKey(String mediaKey) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableWatchHistory,
      where: 'media_key = ?',
      whereArgs: <Object?>[mediaKey],
    );
  }

  Future<int> clearAll() async {
    final db = await _dbHelper.database;
    return db.delete(DatabaseHelper.tableWatchHistory);
  }
}
