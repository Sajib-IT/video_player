import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/data/local/dao/cached_video_dao.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/features/library/data/local_video_scanner.dart';
import 'package:video_player_app/features/library/data/media_library_repository.dart';
import 'package:video_player_app/features/library/data/media_permission_service.dart';
import 'package:video_player_app/features/library/domain/library_permission_status.dart';
import 'package:video_player_app/features/library/domain/library_sort_field.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/library/presentation/library_controller.dart';

class _FakePermissionService implements MediaPermissionService {
  LibraryPermissionStatus statusToReturn = LibraryPermissionStatus.granted;

  @override
  Future<LibraryPermissionStatus> checkStatus() async => statusToReturn;

  @override
  Future<LibraryPermissionStatus> requestPermission() async => statusToReturn;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<void> presentLimitedSelection() async {}
}

class _FakeVideoScanner implements LocalVideoScanner {
  List<VideoItem> videosToReturn = const <VideoItem>[];

  @override
  Future<List<VideoItem>> scanVideos() async => videosToReturn;

  @override
  Future<VideoItem?> pickSingleVideoFile() async => null;
}

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late WatchHistoryDao historyDao;
  late CachedVideoDao cachedDao;
  late PlaybackSettingsDao settingsDao;
  late _FakePermissionService permissionService;
  late _FakeVideoScanner scanner;
  late LibraryController controller;

  final sampleVideos = <VideoItem>[
    VideoItem(
      mediaKey: '/Movies/Alpha.mkv',
      filePath: '/Movies/Alpha.mkv',
      fileName: 'Alpha.mkv',
      title: 'Alpha',
      folderPath: '/Movies',
      folderName: 'Movies',
      duration: const Duration(minutes: 120),
      sizeBytes: 3000,
      width: 1920,
      height: 1080,
      modifiedAt: DateTime(2026, 1, 10),
    ),
    VideoItem(
      mediaKey: '/Anime/Zeta.mp4',
      filePath: '/Anime/Zeta.mp4',
      fileName: 'Zeta.mp4',
      title: 'Zeta',
      folderPath: '/Anime',
      folderName: 'Anime',
      duration: const Duration(minutes: 24),
      sizeBytes: 9000,
      width: 1280,
      height: 720,
      modifiedAt: DateTime(2026, 3, 5),
    ),
    VideoItem(
      mediaKey: '/Movies/Beta.webm',
      filePath: '/Movies/Beta.webm',
      fileName: 'Beta.webm',
      title: 'Beta',
      folderPath: '/Movies',
      folderName: 'Movies',
      duration: const Duration(minutes: 45),
      sizeBytes: 6000,
      modifiedAt: DateTime(2026, 2, 1),
    ),
  ];

  setUp(() async {
    dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    historyDao = WatchHistoryDao(dbHelper: dbHelper);
    cachedDao = CachedVideoDao(dbHelper: dbHelper);
    settingsDao = PlaybackSettingsDao(dbHelper: dbHelper);
    permissionService = _FakePermissionService();
    scanner = _FakeVideoScanner()..videosToReturn = sampleVideos;

    controller = LibraryController(
      permissionService: permissionService,
      repository: MediaLibraryRepository(
        scanner: scanner,
        watchHistoryDao: historyDao,
        cachedVideoDao: cachedDao,
        settingsDao: settingsDao,
      ),
    );
  });

  tearDown(() async {
    controller.dispose();
    await dbHelper.close();
  });

  test('scans folders, enriches resume history, searches, and sorts', () async {
    await historyDao.saveProgress(
      mediaKey: '/Movies/Alpha.mkv',
      filePath: '/Movies/Alpha.mkv',
      title: 'Alpha',
      position: const Duration(minutes: 30),
      duration: const Duration(minutes: 120),
    );

    await controller.initialize();

    expect(controller.allVideos.length, 3);
    expect(controller.visibleFolders.length, 2);
    expect(controller.continueWatchingVideos.length, 1);
    expect(controller.continueWatchingVideos.first.title, 'Alpha');

    // Sort by name ascending
    await controller.setSortOption(field: LibrarySortField.name, ascending: true);
    controller.setViewMode(LibraryViewMode.allVideos);
    expect(
      controller.visibleVideos.map((v) => v.title).toList(),
      <String>['Alpha', 'Beta', 'Zeta'],
    );

    // Sort by size descending
    await controller.setSortOption(field: LibrarySortField.size, ascending: false);
    expect(
      controller.visibleVideos.map((v) => v.title).toList(),
      <String>['Zeta', 'Beta', 'Alpha'],
    );

    // Search query narrows folders & videos
    controller.setSearchQuery('beta');
    expect(controller.visibleVideos.map((v) => v.title), <String>['Beta']);
    expect(controller.visibleFolders.length, 1);
    expect(controller.visibleFolders.first.folderName, 'Movies');
  });

  test('marks unplayed video watched and clears progress', () async {
    await controller.initialize();
    final zeta = controller.allVideos.firstWhere((v) => v.title == 'Zeta');
    expect(zeta.isWatched, isFalse);

    await controller.markWatched(zeta, watched: true);
    final updated = controller.allVideos.firstWhere((v) => v.title == 'Zeta');
    expect(updated.isWatched, isTrue);

    await controller.clearVideoProgress(updated);
    final cleared = controller.allVideos.firstWhere((v) => v.title == 'Zeta');
    expect(cleared.isWatched, isFalse);
    expect(cleared.watchHistory, isNull);
  });

  test('respects denied storage permission without scanning', () async {
    permissionService.statusToReturn = LibraryPermissionStatus.permanentlyDenied;
    await controller.initialize();

    expect(controller.permissionStatus, LibraryPermissionStatus.permanentlyDenied);
    expect(controller.allVideos, isEmpty);
  });
}
