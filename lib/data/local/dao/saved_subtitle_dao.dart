import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';

/// Data access object for local and downloaded external subtitle metadata.
class SavedSubtitleDao {
  final DatabaseHelper _dbHelper;

  SavedSubtitleDao({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<SavedSubtitle>> getForMedia(String mediaKey) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableSavedSubtitles,
      where: 'media_key = ?',
      whereArgs: <Object?>[mediaKey],
      orderBy: 'is_active DESC, created_at DESC',
    );
    return rows.map(SavedSubtitle.fromMap).toList(growable: false);
  }

  Future<SavedSubtitle?> getActiveForMedia(String mediaKey) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableSavedSubtitles,
      where: 'media_key = ? AND is_active = 1',
      whereArgs: <Object?>[mediaKey],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SavedSubtitle.fromMap(rows.first);
  }

  Future<SavedSubtitle> upsert(SavedSubtitle subtitle) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      if (subtitle.isActive) {
        await txn.update(
          DatabaseHelper.tableSavedSubtitles,
          <String, Object?>{'is_active': 0},
          where: 'media_key = ?',
          whereArgs: <Object?>[subtitle.mediaKey],
        );
      }

      final payload = subtitle.toMap()..remove('id');
      final updated = await txn.update(
        DatabaseHelper.tableSavedSubtitles,
        payload,
        where: 'media_key = ? AND local_file_path = ?',
        whereArgs: <Object?>[subtitle.mediaKey, subtitle.localFilePath],
      );

      if (updated == 0) {
        final rowId = await txn.insert(
          DatabaseHelper.tableSavedSubtitles,
          payload,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return subtitle.copyWith(id: rowId);
      }

      final rows = await txn.query(
        DatabaseHelper.tableSavedSubtitles,
        where: 'media_key = ? AND local_file_path = ?',
        whereArgs: <Object?>[subtitle.mediaKey, subtitle.localFilePath],
        limit: 1,
      );
      return rows.isEmpty ? subtitle : SavedSubtitle.fromMap(rows.first);
    });
  }

  Future<void> setActiveSubtitle(String mediaKey, int? subtitleId) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        DatabaseHelper.tableSavedSubtitles,
        <String, Object?>{'is_active': 0},
        where: 'media_key = ?',
        whereArgs: <Object?>[mediaKey],
      );
      if (subtitleId != null) {
        await txn.update(
          DatabaseHelper.tableSavedSubtitles,
          <String, Object?>{'is_active': 1},
          where: 'id = ? AND media_key = ?',
          whereArgs: <Object?>[subtitleId, mediaKey],
        );
      }
    });
  }

  Future<void> updateDelay(int subtitleId, int delayMs) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableSavedSubtitles,
      <String, Object?>{'delay_ms': delayMs},
      where: 'id = ?',
      whereArgs: <Object?>[subtitleId],
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableSavedSubtitles,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> deleteForMedia(String mediaKey) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableSavedSubtitles,
      where: 'media_key = ?',
      whereArgs: <Object?>[mediaKey],
    );
  }
}
