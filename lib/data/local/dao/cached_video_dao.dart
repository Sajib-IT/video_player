import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/cached_video_record.dart';

/// Data access object for offline-first local video library caching.
class CachedVideoDao {
  final DatabaseHelper _dbHelper;

  CachedVideoDao({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<CachedVideoRecord>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableCachedVideos,
      orderBy: 'modified_at DESC',
    );
    return rows.map(CachedVideoRecord.fromMap).toList(growable: false);
  }

  Future<void> replaceAll(List<CachedVideoRecord> records) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseHelper.tableCachedVideos);
      final batch = txn.batch();
      for (final record in records) {
        batch.insert(
          DatabaseHelper.tableCachedVideos,
          record.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }
}
