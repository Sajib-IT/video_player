import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/video_download_record.dart';

/// Data access object for web video download history and progress.
class VideoDownloadDao {
  final DatabaseHelper _dbHelper;

  VideoDownloadDao({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<VideoDownloadRecord>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableVideoDownloads,
      orderBy: 'created_at DESC',
    );
    return rows.map(VideoDownloadRecord.fromMap).toList(growable: false);
  }

  Future<VideoDownloadRecord> insert(VideoDownloadRecord record) async {
    final db = await _dbHelper.database;
    final rowId = await db.insert(
      DatabaseHelper.tableVideoDownloads,
      record.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.copyWith(id: rowId);
  }

  Future<void> update(VideoDownloadRecord record) async {
    final id = record.id;
    if (id == null) return;
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tableVideoDownloads,
      record.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> deleteById(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableVideoDownloads,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
