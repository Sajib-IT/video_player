import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/data/local/dao/cached_video_dao.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/dao/vault_dao.dart';
import 'package:video_player_app/data/local/dao/video_download_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/cached_video_record.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/data/local/models/vault_models.dart';
import 'package:video_player_app/data/local/models/video_download_record.dart';
import 'package:video_player_app/features/library/domain/library_sort_field.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late WatchHistoryDao watchHistoryDao;
  late PlaybackSettingsDao settingsDao;
  late SavedSubtitleDao savedSubtitleDao;
  late CachedVideoDao cachedVideoDao;

  setUp(() async {
    dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    watchHistoryDao = WatchHistoryDao(dbHelper: dbHelper);
    settingsDao = PlaybackSettingsDao(dbHelper: dbHelper);
    savedSubtitleDao = SavedSubtitleDao(dbHelper: dbHelper);
    cachedVideoDao = CachedVideoDao(dbHelper: dbHelper);
  });

  tearDown(() async {
    await dbHelper.close();
  });

  test('seeds default playback settings on initial schema creation', () async {
    final settings = await settingsDao.getSettings();
    expect(settings.defaultPlaybackSpeed, 1.0);
    expect(settings.defaultAspectRatio, AspectRatioMode.fit);
    expect(settings.resumePlaybackEnabled, isTrue);
    expect(settings.softwareAudioBoostEnabled, isTrue);
    expect(settings.maxAudioBoostPercent, 200);
    expect(settings.useLibass, isTrue);
    expect(settings.preferredSubtitleLanguage, 'en');

    final updated = await settingsDao.saveSettings(
      settings.copyWith(
        defaultPlaybackSpeed: 1.5,
        preferredSubtitleLanguage: 'bn',
        librarySortField: LibrarySortField.size,
        librarySortAscending: true,
      ),
    );
    expect(updated.defaultPlaybackSpeed, 1.5);

    final reloaded = await settingsDao.getSettings();
    expect(reloaded.defaultPlaybackSpeed, 1.5);
    expect(reloaded.preferredSubtitleLanguage, 'bn');
    expect(reloaded.librarySortField, LibrarySortField.size);
    expect(reloaded.librarySortAscending, isTrue);
  });

  test('WatchHistoryDao saves, updates, and marks watched at >=90%', () async {
    final first = await watchHistoryDao.saveProgress(
      mediaKey: '/movies/sample.mkv',
      filePath: '/movies/sample.mkv',
      title: 'Sample',
      folderPath: '/movies',
      fileSizeBytes: 102400,
      position: const Duration(minutes: 12),
      duration: const Duration(minutes: 60),
      playbackSpeed: 1.25,
      aspectRatioMode: AspectRatioMode.ratio16x9,
      incrementPlayCount: true,
    );
    expect(first.id, isNotNull);
    expect(first.playCount, 1);
    expect(first.isWatched, isFalse);
    expect(first.hasResumableProgress, isTrue);

    final second = await watchHistoryDao.saveProgress(
      mediaKey: '/movies/sample.mkv',
      filePath: '/movies/sample.mkv',
      title: 'Sample',
      position: const Duration(minutes: 55),
      duration: const Duration(minutes: 60),
    );
    expect(second.id, first.id);
    expect(second.isWatched, isTrue);
    expect(second.positionMs, 0);
    expect(second.hasResumableProgress, isFalse);
  });

  test('SavedSubtitleDao enforces single active subtitle per media', () async {
    final sub1 = await savedSubtitleDao.upsert(
      const SavedSubtitle(
        mediaKey: '/movies/clip.mkv',
        localFilePath: '/subs/clip.en.srt',
        fileName: 'clip.en.srt',
        languageCode: 'en',
        languageName: 'English',
        format: 'srt',
        source: SubtitleSource.local,
        isActive: true,
        createdAtMs: 1000,
      ),
    );
    expect(sub1.id, isNotNull);
    expect(sub1.isActive, isTrue);

    final sub2 = await savedSubtitleDao.upsert(
      const SavedSubtitle(
        mediaKey: '/movies/clip.mkv',
        localFilePath: '/subs/clip.bn.ass',
        fileName: 'clip.bn.ass',
        languageCode: 'bn',
        languageName: 'Bengali',
        format: 'ass',
        source: SubtitleSource.opensubtitles,
        externalId: '98765',
        isActive: true,
        createdAtMs: 2000,
      ),
    );

    final all = await savedSubtitleDao.getForMedia('/movies/clip.mkv');
    expect(all.length, 2);
    expect(all.where((s) => s.isActive).map((s) => s.id), <int?>[sub2.id]);

    await savedSubtitleDao.updateDelay(sub2.id!, -400);
    final active = await savedSubtitleDao.getActiveForMedia('/movies/clip.mkv');
    expect(active?.delayMs, -400);
  });

  test('CachedVideoDao replaces cached library snapshot atomically', () async {
    await cachedVideoDao.replaceAll(<CachedVideoRecord>[
      const CachedVideoRecord(
        mediaKey: 'v1',
        filePath: '/storage/Movies/a.mp4',
        fileName: 'a.mp4',
        folderPath: '/storage/Movies',
        folderName: 'Movies',
        durationMs: 60000,
        sizeBytes: 5000000,
        modifiedAtMs: 1000,
        scannedAtMs: 2000,
      ),
    ]);
    final loaded = await cachedVideoDao.getAll();
    expect(loaded.length, 1);
    expect(loaded.first.fileName, 'a.mp4');
  });

  test('VaultDao, VideoDownloadDao, and v2 settings columns work properly', () async {
    final vaultDao = VaultDao(dbHelper: dbHelper);
    final downloadDao = VideoDownloadDao(dbHelper: dbHelper);

    await vaultDao.saveConfig(
      const VaultConfig(
        pinHash: 'hash123',
        pinSalt: 'salt123',
        biometricEnabled: false,
        updatedAtMs: 1000,
      ),
    );
    final cfg = await vaultDao.getConfig();
    expect(cfg?.pinHash, 'hash123');
    expect(cfg?.biometricEnabled, isFalse);

    final vInserted = await vaultDao.insertVideo(
      const VaultVideoRecord(
        title: 'Secret',
        fileName: 'secret.mkv',
        originalFilePath: '/storage/secret.mkv',
        vaultFilePath: '/app/.private_vault/secret.mkv',
        sizeBytes: 1234,
        addedAtMs: 5000,
      ),
    );
    expect(vInserted.id, isNotNull);
    expect((await vaultDao.getAllVideos()).length, 1);

    final dInserted = await downloadDao.insert(
      const VideoDownloadRecord(
        url: 'https://example.com/demo.mp4',
        fileName: 'demo.mp4',
        savePath: '/app/downloads/demo.mp4',
        status: VideoDownloadStatus.downloading,
        createdAtMs: 6000,
        updatedAtMs: 6000,
      ),
    );
    expect(dInserted.id, isNotNull);
    await downloadDao.update(
      dInserted.copyWith(status: VideoDownloadStatus.completed, receivedBytes: 100),
    );
    final allDownloads = await downloadDao.getAll();
    expect(allDownloads.first.status, VideoDownloadStatus.completed);

    final settings = await settingsDao.getSettings();
    final updated = await settingsDao.saveSettings(
      settings.copyWith(
        backgroundAudioEnabled: true,
        nightModeEnabled: true,
        openAiApiKey: 'sk-test-key',
      ),
    );
    expect(updated.backgroundAudioEnabled, isTrue);
    expect(updated.nightModeEnabled, isTrue);
    expect(updated.openAiApiKey, 'sk-test-key');
  });

  test('migrates existing v1 database to v2 cleanly without data loss', () async {
    final tempDir = await Directory.systemTemp.createTemp('db_v1_v2_test');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final dbPath = p.join(tempDir.path, 'legacy_v1.db');

    final v1Db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE watch_history (
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
            CREATE TABLE playback_settings (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              default_playback_speed REAL NOT NULL DEFAULT 1.0,
              default_aspect_ratio TEXT NOT NULL DEFAULT 'fit',
              resume_playback_enabled INTEGER NOT NULL DEFAULT 1,
              hardware_acceleration_enabled INTEGER NOT NULL DEFAULT 1,
              software_audio_boost_enabled INTEGER NOT NULL DEFAULT 1,
              max_audio_boost_percent INTEGER NOT NULL DEFAULT 200,
              use_libass INTEGER NOT NULL DEFAULT 1,
              subtitle_font_size REAL NOT NULL DEFAULT 28.0,
              subtitle_scale REAL NOT NULL DEFAULT 1.0,
              subtitle_color_hex INTEGER NOT NULL DEFAULT 4294967295,
              subtitle_bg_opacity REAL NOT NULL DEFAULT 0.65,
              preferred_subtitle_language TEXT NOT NULL DEFAULT 'en',
              opensubtitles_api_key TEXT NOT NULL DEFAULT '',
              library_sort_field TEXT NOT NULL DEFAULT 'date',
              library_sort_ascending INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL
            )
          ''');
          await db.insert('playback_settings', <String, Object?>{
            'id': 1,
            'default_playback_speed': 1.75,
            'preferred_subtitle_language': 'bn',
            'updated_at': 12345,
          });
        },
      ),
    );
    await v1Db.close();

    final upgradedHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: dbPath,
    );
    final upgradedSettings =
        await PlaybackSettingsDao(dbHelper: upgradedHelper).getSettings();
    expect(upgradedSettings.defaultPlaybackSpeed, 1.75);
    expect(upgradedSettings.preferredSubtitleLanguage, 'bn');
    expect(upgradedSettings.backgroundAudioEnabled, isFalse);
    expect(upgradedSettings.nightModeEnabled, isFalse);

    final vaultDao = VaultDao(dbHelper: upgradedHelper);
    await vaultDao.saveConfig(
      const VaultConfig(pinHash: 'h', pinSalt: 's', updatedAtMs: 100),
    );
    expect((await vaultDao.getConfig())?.pinHash, 'h');
    await upgradedHelper.close();
  });
}
