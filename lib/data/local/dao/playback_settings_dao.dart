import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';

/// Data access object for global playback, audio boost, and subtitle preferences.
class PlaybackSettingsDao {
  final DatabaseHelper _dbHelper;

  PlaybackSettingsDao({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<PlaybackSettings> getSettings() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseHelper.tablePlaybackSettings,
      where: 'id = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      final defaults = PlaybackSettings.defaults();
      await saveSettings(defaults);
      return defaults;
    }
    return PlaybackSettings.fromMap(rows.first);
  }

  Future<PlaybackSettings> saveSettings(PlaybackSettings settings) async {
    final db = await _dbHelper.database;
    final normalized = settings.copyWith(
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await db.insert(
      DatabaseHelper.tablePlaybackSettings,
      normalized.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return normalized;
  }
}
