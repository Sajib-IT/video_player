import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/core/utils/movie_hash.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/subtitles/data/local_subtitle_picker.dart';
import 'package:video_player_app/features/subtitles/data/opensubtitles_api_client.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/domain/subtitle_search_query.dart';

typedef DirectoryProvider = Future<Directory> Function();

/// Coordinates local subtitle picking, OpenSubtitles search & download to
/// local app storage, moviehash computation, and SQLite persistence.
class SubtitleRepository {
  final OnlineSubtitleClient _apiClient;
  final LocalSubtitlePicker _localPicker;
  final PlaybackSettingsDao _settingsDao;
  final SavedSubtitleDao _savedSubtitleDao;
  final DirectoryProvider _documentsDirProvider;

  SubtitleRepository({
    OnlineSubtitleClient? apiClient,
    LocalSubtitlePicker? localPicker,
    PlaybackSettingsDao? settingsDao,
    SavedSubtitleDao? savedSubtitleDao,
    DirectoryProvider? documentsDirProvider,
  }) : _apiClient = apiClient ?? OpenSubtitlesApiClient(),
       _localPicker = localPicker ?? const DeviceLocalSubtitlePicker(),
       _settingsDao = settingsDao ?? PlaybackSettingsDao(),
       _savedSubtitleDao = savedSubtitleDao ?? SavedSubtitleDao(),
       _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory;

  Future<PickedSubtitleFile?> pickLocalSubtitle() =>
      _localPicker.pickSubtitleFile();

  Future<String?> computeMovieHash(String videoPath) {
    if (videoPath.contains('://')) return Future<String?>.value(null);
    return MovieHash.compute(videoPath);
  }

  Future<String> getEffectiveApiKey() async {
    final settings = await _settingsDao.getSettings();
    return settings.effectiveOpenSubtitlesApiKey;
  }

  Future<String> getEffectiveOpenAiApiKey() async {
    final settings = await _settingsDao.getSettings();
    return settings.effectiveOpenAiApiKey;
  }

  Future<String> getPreferredLanguageCode() async {
    final settings = await _settingsDao.getSettings();
    return settings.preferredSubtitleLanguage;
  }

  Future<List<OnlineSubtitleResult>> searchOnline(
    SubtitleSearchQuery query,
  ) async {
    final apiKey = await getEffectiveApiKey();
    return _apiClient.search(query: query, apiKey: apiKey);
  }

  /// Downloads [result] to local app storage, persists metadata in SQLite,
  /// and returns the resulting [SavedSubtitle].
  Future<SavedSubtitle> downloadAndSaveSubtitle({
    required String mediaKey,
    required OnlineSubtitleResult result,
    String? movieHash,
  }) async {
    final apiKey = await getEffectiveApiKey();
    final bytes = await _apiClient.downloadFileBytes(
      fileId: result.fileId,
      apiKey: apiKey,
    );

    final docsDir = await _documentsDirProvider();
    final subsDir = Directory(
      p.join(docsDir.path, 'subtitles', 'downloaded'),
    );
    if (!await subsDir.exists()) {
      await subsDir.create(recursive: true);
    }

    final cleanName = _normalizeSubtitleFileName(
      result.fileName,
      result.fileId,
    );
    final destFile = File(p.join(subsDir.path, '${result.fileId}_$cleanName'));
    await destFile.writeAsBytes(bytes, flush: true);

    final saved = SavedSubtitle(
      mediaKey: mediaKey,
      localFilePath: destFile.path,
      fileName: cleanName,
      languageCode: result.languageCode,
      languageName: result.languageName,
      format: MediaFormats.extensionOf(cleanName),
      source: SubtitleSource.opensubtitles,
      externalId: result.fileId.toString(),
      movieHash: movieHash,
      isActive: true,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    );

    return _savedSubtitleDao.upsert(saved);
  }

  Future<void> deleteSavedSubtitle(int id, {String? localFilePath}) async {
    await _savedSubtitleDao.deleteById(id);
    if (localFilePath != null && !localFilePath.contains('://')) {
      final file = File(localFilePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  String _normalizeSubtitleFileName(String rawName, int fileId) {
    final safe = rawName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (safe.isEmpty) return 'subtitle_$fileId.srt';
    if (MediaFormats.isSupportedSubtitle(safe)) return safe;
    return '$safe.srt';
  }
}
