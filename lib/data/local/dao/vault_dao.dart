import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/vault_models.dart';

/// Data access object for Private Video Vault PIN configuration and hidden entries.
class VaultDao {
  final DatabaseHelper _dbHelper;

  VaultDao({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<VaultConfig?> getConfig() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableVaultConfig,
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return VaultConfig.fromMap(rows.first);
  }

  Future<void> saveConfig(VaultConfig config) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableVaultConfig,
      config.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VaultVideoRecord>> getAllVideos() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tableVaultVideos,
      orderBy: 'added_at DESC',
    );
    return rows.map(VaultVideoRecord.fromMap).toList(growable: false);
  }

  Future<VaultVideoRecord> insertVideo(VaultVideoRecord record) async {
    final db = await _dbHelper.database;
    final rowId = await db.insert(
      DatabaseHelper.tableVaultVideos,
      record.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return record.copyWith(id: rowId);
  }

  Future<int> deleteVideoById(int id) async {
    final db = await _dbHelper.database;
    return db.delete(
      DatabaseHelper.tableVaultVideos,
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
