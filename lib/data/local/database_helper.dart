import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';

/// Manages the SQLite database lifecycle, schema creation, and migrations.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();

  final DatabaseFactory? _customFactory;
  final String? _customPath;

  Database? _database;
  Future<Database>? _openingFuture;

  DatabaseHelper._() : _customFactory = null, _customPath = null;

  /// Creates an isolated instance for unit tests (e.g. with `databaseFactoryFfi`).
  DatabaseHelper.custom({
    required DatabaseFactory databaseFactory,
    String path = inMemoryDatabasePath,
  }) : _customFactory = databaseFactory,
       _customPath = path;

  static const String tableWatchHistory = 'watch_history';
  static const String tablePlaybackSettings = 'playback_settings';
  static const String tableSavedSubtitles = 'saved_subtitles';
  static const String tableCachedVideos = 'cached_videos';
  static const String tableVaultConfig = 'vault_config';
  static const String tableVaultVideos = 'vault_videos';
  static const String tableVideoDownloads = 'video_downloads';

  Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) {
      return existing;
    }

    final inFlight = _openingFuture;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _openDatabase();
    _openingFuture = future;
    try {
      final db = await future;
      _database = db;
      return db;
    } catch (error, stackTrace) {
      throw LocalDatabaseException(
        'Failed to initialize local SQLite database.',
        cause: error,
        stackTrace: stackTrace,
      );
    } finally {
      _openingFuture = null;
    }
  }

  Future<Database> _openDatabase() async {
    final factory = _customFactory ?? databaseFactory;
    final String dbPath;
    if (_customPath != null) {
      dbPath = _customPath;
    } else {
      final dir = await getDatabasesPath();
      dbPath = p.join(dir, AppConfig.databaseName);
    }

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: AppConfig.databaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableWatchHistory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        media_key TEXT NOT NULL UNIQUE,
        file_path TEXT NOT NULL,
        title TEXT NOT NULL,
        folder_path TEXT NOT NULL DEFAULT '',
        file_size_bytes INTEGER NOT NULL DEFAULT 0,
        position_ms INTEGER NOT NULL DEFAULT 0,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        is_watched INTEGER NOT NULL DEFAULT 0,
        playback_speed REAL NOT NULL DEFAULT 1.0,
        aspect_ratio_mode TEXT NOT NULL DEFAULT 'fit',
        audio_track_id TEXT,
        subtitle_track_id TEXT,
        subtitle_delay_ms INTEGER NOT NULL DEFAULT 0,
        play_count INTEGER NOT NULL DEFAULT 0,
        last_played_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_watch_history_last_played
      ON $tableWatchHistory(last_played_at DESC)
    ''');
    await db.execute('''
      CREATE INDEX idx_watch_history_folder
      ON $tableWatchHistory(folder_path)
    ''');

    await db.execute('''
      CREATE TABLE $tablePlaybackSettings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        default_playback_speed REAL NOT NULL DEFAULT 1.0,
        default_aspect_ratio TEXT NOT NULL DEFAULT 'fit',
        resume_playback_enabled INTEGER NOT NULL DEFAULT 1,
        hardware_acceleration_enabled INTEGER NOT NULL DEFAULT 1,
        software_audio_boost_enabled INTEGER NOT NULL DEFAULT 1,
        max_audio_boost_percent INTEGER NOT NULL DEFAULT 200,
        background_audio_enabled INTEGER NOT NULL DEFAULT 0,
        night_mode_enabled INTEGER NOT NULL DEFAULT 0,
        use_libass INTEGER NOT NULL DEFAULT 1,
        subtitle_font_size REAL NOT NULL DEFAULT 28.0,
        subtitle_scale REAL NOT NULL DEFAULT 1.0,
        subtitle_color_hex INTEGER NOT NULL DEFAULT 4294967295,
        subtitle_bg_opacity REAL NOT NULL DEFAULT 0.65,
        preferred_subtitle_language TEXT NOT NULL DEFAULT 'en',
        opensubtitles_api_key TEXT NOT NULL DEFAULT '',
        openai_api_key TEXT NOT NULL DEFAULT '',
        library_sort_field TEXT NOT NULL DEFAULT 'date',
        library_sort_ascending INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.insert(
      tablePlaybackSettings,
      PlaybackSettings.defaults().toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.execute('''
      CREATE TABLE $tableSavedSubtitles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        media_key TEXT NOT NULL,
        local_file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        language_code TEXT NOT NULL DEFAULT 'und',
        language_name TEXT NOT NULL DEFAULT 'Unknown',
        format TEXT NOT NULL DEFAULT 'srt',
        source TEXT NOT NULL DEFAULT 'local',
        external_id TEXT,
        movie_hash TEXT,
        delay_ms INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_saved_subtitles_media_path
      ON $tableSavedSubtitles(media_key, local_file_path)
    ''');
    await db.execute('''
      CREATE INDEX idx_saved_subtitles_media_key
      ON $tableSavedSubtitles(media_key)
    ''');

    await db.execute('''
      CREATE TABLE $tableCachedVideos (
        media_key TEXT PRIMARY KEY,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        folder_path TEXT NOT NULL,
        folder_name TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        width INTEGER,
        height INTEGER,
        modified_at INTEGER NOT NULL,
        scanned_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_cached_videos_folder
      ON $tableCachedVideos(folder_path)
    ''');

    await _createV2Tables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE $tablePlaybackSettings '
        'ADD COLUMN background_audio_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $tablePlaybackSettings '
        'ADD COLUMN night_mode_enabled INTEGER NOT NULL DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE $tablePlaybackSettings '
        "ADD COLUMN openai_api_key TEXT NOT NULL DEFAULT ''",
      );
      await _createV2Tables(db);
    }
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableVaultConfig (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        pin_hash TEXT NOT NULL,
        pin_salt TEXT NOT NULL,
        biometric_enabled INTEGER NOT NULL DEFAULT 1,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableVaultVideos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vault_file_path TEXT NOT NULL UNIQUE,
        original_file_path TEXT NOT NULL,
        title TEXT NOT NULL,
        file_name TEXT NOT NULL,
        duration_ms INTEGER NOT NULL DEFAULT 0,
        size_bytes INTEGER NOT NULL DEFAULT 0,
        added_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableVideoDownloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        file_name TEXT NOT NULL,
        save_path TEXT NOT NULL,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        received_bytes INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        error_message TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    _openingFuture = null;
    if (db != null && db.isOpen) {
      await db.close();
    }
  }
}
