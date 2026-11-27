import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/dao/watch_history_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/services/media_kit_player_service.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/subtitles/data/local_subtitle_picker.dart';
import 'package:video_player_app/features/subtitles/data/opensubtitles_api_client.dart';
import 'package:video_player_app/features/subtitles/data/subtitle_repository.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/domain/subtitle_search_query.dart';
import 'package:video_player_app/features/subtitles/presentation/subtitle_sheet_controller.dart';

class _NoopWakelock implements WakelockGateway {
  const _NoopWakelock();
  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer({required super.configuration});

  final List<SubtitleTrack> subtitleCalls = <SubtitleTrack>[];

  @override
  Future<void> open(Playable playable, {bool play = true}) async {
    state = state.copyWith(playing: play);
    playingController.add(play);
  }

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) async {
    subtitleCalls.add(track);
    state = state.copyWith(track: state.track.copyWith(subtitle: track));
    trackController.add(state.track);
  }

  @override
  Future<void> stop() async {}
}

class _FakeLocalPicker implements LocalSubtitlePicker {
  PickedSubtitleFile? nextPick;

  @override
  Future<PickedSubtitleFile?> pickSubtitleFile() async => nextPick;
}

class _FakeOnlineClient implements OnlineSubtitleClient {
  List<OnlineSubtitleResult> searchResults = const <OnlineSubtitleResult>[];
  SubtitleNetworkException? searchError;
  Uint8List downloadBytes = Uint8List.fromList(
    utf8.encode('1\n00:00:01,000 --> 00:00:02,000\nSub line\n'),
  );

  @override
  Future<List<OnlineSubtitleResult>> search({
    required SubtitleSearchQuery query,
    required String apiKey,
  }) async {
    if (searchError != null) throw searchError!;
    return searchResults;
  }

  @override
  Future<Uint8List> downloadFileBytes({
    required int fileId,
    required String apiKey,
  }) async {
    return downloadBytes;
  }
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late DatabaseHelper dbHelper;
  late PlaybackSettingsDao settingsDao;
  late SavedSubtitleDao savedSubtitleDao;
  late WatchHistoryDao watchHistoryDao;
  late _FakePlatformPlayer fakePlatform;
  late MediaKitPlayerService playerService;
  late _FakeLocalPicker localPicker;
  late _FakeOnlineClient onlineClient;
  late SubtitleSheetController sheetController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('subtitle_ctrl_test');
    dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    settingsDao = PlaybackSettingsDao(dbHelper: dbHelper);
    savedSubtitleDao = SavedSubtitleDao(dbHelper: dbHelper);
    watchHistoryDao = WatchHistoryDao(dbHelper: dbHelper);

    final defaults = await settingsDao.getSettings();
    await settingsDao.saveSettings(
      defaults.copyWith(openSubtitlesApiKey: 'test-key'),
    );

    playerService = MediaKitPlayerService(
      watchHistoryDao: watchHistoryDao,
      settingsDao: settingsDao,
      savedSubtitleDao: savedSubtitleDao,
      wakelockGateway: const _NoopWakelock(),
      attachVideoController: false,
      playerFactory: (config) {
        fakePlatform = _FakePlatformPlayer(configuration: config);
        return Player(configuration: config, platformPlayer: fakePlatform);
      },
    );
    await playerService.initialize();
    await playerService.openMedia(
      MediaPlaybackRequest.fromFilePath(
        '${tempDir.path}/Dandadan.05.1080p.mkv',
      ),
    );

    localPicker = _FakeLocalPicker();
    onlineClient = _FakeOnlineClient();
    sheetController = SubtitleSheetController(
      playerService: playerService,
      repository: SubtitleRepository(
        apiClient: onlineClient,
        localPicker: localPicker,
        settingsDao: settingsDao,
        savedSubtitleDao: savedSubtitleDao,
        documentsDirProvider: () async => tempDir,
      ),
    );
    await sheetController.initialize();
  });

  tearDown(() async {
    sheetController.dispose();
    await playerService.dispose();
    await dbHelper.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('picks local ASS subtitle, persists in SQLite, and attaches to player', () async {
    final assFile = File('${tempDir.path}/dandadan.bn.ass')
      ..writeAsStringSync('[Script Info]\nTitle: Test\n');
    localPicker.nextPick = PickedSubtitleFile(
      filePath: assFile.path,
      fileName: 'dandadan.bn.ass',
      languageCode: 'bn',
      languageName: 'Bengali',
    );

    await sheetController.pickAndAttachLocalSubtitle();

    expect(sheetController.actionIsError, isFalse);
    expect(playerService.snapshot.savedSubtitles.length, 1);
    expect(
      playerService.snapshot.savedSubtitles.first.source,
      SubtitleSource.local,
    );
    expect(fakePlatform.subtitleCalls.last.uri, isTrue);
  });

  test('searches online subtitles, handles errors, downloads, and loads into player', () async {
    onlineClient.searchError = const SubtitleNetworkException('Network offline');
    await sheetController.searchOnline();
    expect(sheetController.searchError, 'Network offline');

    onlineClient.searchError = null;
    onlineClient.searchResults = const <OnlineSubtitleResult>[
      OnlineSubtitleResult(
        subtitleId: '99',
        fileId: 555,
        fileName: 'Dandadan.05.bn.srt',
        languageCode: 'bn',
        releaseName: 'Dandadan.05.WEB',
        downloadCount: 400,
      ),
    ];
    await sheetController.searchOnline();
    expect(sheetController.searchError, isNull);
    expect(sheetController.results.length, 1);

    final ok = await sheetController.downloadAndAttach(
      sheetController.results.first,
    );
    expect(ok, isTrue);

    final saved = playerService.snapshot.savedSubtitles.first;
    expect(saved.source, SubtitleSource.opensubtitles);
    expect(saved.languageCode, 'bn');
    expect(File(saved.localFilePath).existsSync(), isTrue);
    expect(
      playerService.snapshot.selectedSubtitleTrackId,
      'ext:${saved.localFilePath}',
    );

    // Step sync delay in 0.1s steps and verify bounds/persistence
    await sheetController.stepDelay(100);
    await sheetController.stepDelay(100);
    expect(playerService.snapshot.subtitleDelay, const Duration(milliseconds: 200));
    await sheetController.resetDelay();
    expect(playerService.snapshot.subtitleDelay, Duration.zero);

    // Adjust font size & scale
    await sheetController.setFontSize(34);
    expect(playerService.snapshot.subtitleFontSize, 34);
    await sheetController.setScale(1.4);
    expect(playerService.snapshot.subtitleScale, 1.4);

    // Delete downloaded subtitle removes local file and clears active subtitle
    await sheetController.deleteSavedSubtitle(saved);
    expect(File(saved.localFilePath).existsSync(), isFalse);
    expect(playerService.snapshot.selectedSubtitleTrackId, 'no');
  });
}
