import 'package:flutter/foundation.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/subtitles/data/ai_subtitle_service.dart';
import 'package:video_player_app/features/subtitles/data/subtitle_repository.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/domain/subtitle_search_query.dart';

/// State controller for managing local subtitle picking, online search/download,
/// AI Whisper transcription/translation, saved subtitle deletion, and sync/style.
class SubtitleSheetController extends ChangeNotifier {
  final PlayerService playerService;
  final SubtitleRepository repository;
  final AiSubtitleService aiSubtitleService;

  SubtitleSheetController({
    required this.playerService,
    SubtitleRepository? repository,
    AiSubtitleService? aiSubtitleService,
  }) : repository = repository ?? SubtitleRepository(),
       aiSubtitleService =
           aiSubtitleService ?? OpenAiWhisperSubtitleService();

  String _searchText = '';
  String? _movieHash;
  bool _useMovieHash = true;
  final Set<String> _selectedLanguages = <String>{};
  bool _hasApiKey = true;
  bool _hasOpenAiApiKey = true;
  String _aiTargetLanguageCode = 'en';
  bool _isGeneratingAi = false;

  bool _isSearching = false;
  bool _hasSearched = false;
  int? _downloadingFileId;
  String? _searchError;
  String? _actionMessage;
  bool _actionIsError = false;
  List<OnlineSubtitleResult> _results = const <OnlineSubtitleResult>[];

  String get searchText => _searchText;
  String? get movieHash => _movieHash;
  bool get useMovieHash => _useMovieHash;
  Set<String> get selectedLanguages => Set<String>.unmodifiable(_selectedLanguages);
  bool get hasApiKey => _hasApiKey;
  bool get hasOpenAiApiKey => _hasOpenAiApiKey;
  String get aiTargetLanguageCode => _aiTargetLanguageCode;
  bool get isGeneratingAi => _isGeneratingAi;

  bool get isSearching => _isSearching;
  bool get hasSearched => _hasSearched;
  int? get downloadingFileId => _downloadingFileId;
  String? get searchError => _searchError;
  String? get actionMessage => _actionMessage;
  bool get actionIsError => _actionIsError;
  List<OnlineSubtitleResult> get results => _results;

  Future<void> initialize() async {
    final media = playerService.snapshot.currentMedia;
    if (media != null) {
      _searchText = SubtitleSearchQuery.cleanTitleFromFilename(media.title);
    }

    final preferredLang = await repository.getPreferredLanguageCode();
    if (preferredLang.trim().isNotEmpty && preferredLang != 'und') {
      _selectedLanguages.add(preferredLang.trim().toLowerCase());
      _aiTargetLanguageCode = preferredLang.trim().toLowerCase();
    }

    final apiKey = await repository.getEffectiveApiKey();
    _hasApiKey = apiKey.trim().isNotEmpty;
    final openAiKey = await repository.getEffectiveOpenAiApiKey();
    _hasOpenAiApiKey = openAiKey.trim().isNotEmpty;
    notifyListeners();

    if (media != null) {
      await _computeHash(media);
    }
  }

  Future<void> _computeHash(MediaPlaybackRequest media) async {
    try {
      _movieHash = await repository.computeMovieHash(media.uriOrPath);
      notifyListeners();
    } catch (_) {}
  }

  void setSearchText(String value) {
    _searchText = value;
  }

  void setUseMovieHash(bool value) {
    if (_useMovieHash == value) return;
    _useMovieHash = value;
    notifyListeners();
  }

  void setAiTargetLanguage(String code) {
    _aiTargetLanguageCode = code.trim().toLowerCase();
    notifyListeners();
  }

  void toggleLanguage(String iso6391) {
    final code = iso6391.trim().toLowerCase();
    if (_selectedLanguages.contains(code)) {
      _selectedLanguages.remove(code);
    } else {
      _selectedLanguages.add(code);
    }
    notifyListeners();
  }

  void clearLanguageFilters() {
    if (_selectedLanguages.isEmpty) return;
    _selectedLanguages.clear();
    notifyListeners();
  }

  Future<void> pickAndAttachLocalSubtitle() async {
    _clearActionMessage();
    try {
      final picked = await repository.pickLocalSubtitle();
      if (picked == null) return;

      await playerService.attachExternalSubtitle(
        filePath: picked.filePath,
        title: picked.fileName,
        languageCode: picked.languageCode,
        languageName: picked.languageName,
        source: SubtitleSource.local,
        persistInDb: true,
      );

      _setActionMessage('Loaded subtitle: ${picked.fileName}');
    } on AppException catch (error) {
      _setActionMessage(error.message, isError: true);
    } catch (error) {
      _setActionMessage('Unable to load subtitle file: $error', isError: true);
    }
  }

  Future<void> generateAiSubtitle() async {
    final media = playerService.snapshot.currentMedia;
    if (media == null) {
      _setActionMessage('No active media loaded.', isError: true);
      return;
    }

    _isGeneratingAi = true;
    _clearActionMessage();
    notifyListeners();

    try {
      final saved = await aiSubtitleService.generateAndTranslate(
        mediaKey: media.mediaKey,
        mediaPath: media.uriOrPath,
        targetLanguageCode: _aiTargetLanguageCode,
      );
      await playerService.attachExternalSubtitle(
        filePath: saved.localFilePath,
        title: saved.fileName,
        languageCode: saved.languageCode,
        languageName: saved.languageName,
        source: SubtitleSource.opensubtitles,
        externalId: saved.externalId,
        persistInDb: true,
      );
      _setActionMessage('AI subtitles generated: ${saved.fileName}');
    } on AppException catch (error) {
      _setActionMessage(error.message, isError: true);
    } catch (error) {
      _setActionMessage('AI subtitle failed: $error', isError: true);
    } finally {
      _isGeneratingAi = false;
      notifyListeners();
    }
  }

  Future<void> searchOnline({String? overrideQuery}) async {
    if (overrideQuery != null) {
      _searchText = overrideQuery;
    }

    _isSearching = true;
    _searchError = null;
    _clearActionMessage();
    notifyListeners();

    try {
      final apiKey = await repository.getEffectiveApiKey();
      _hasApiKey = apiKey.trim().isNotEmpty;

      final query = SubtitleSearchQuery(
        query: _searchText,
        movieHash: _useMovieHash ? _movieHash : null,
        languageCodes: _selectedLanguages.toList(growable: false),
      );
      _results = await repository.searchOnline(query);
      _hasSearched = true;
    } on AppException catch (error) {
      _searchError = error.message;
      _hasSearched = true;
    } catch (error) {
      _searchError = 'Unexpected search failure: $error';
      _hasSearched = true;
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<bool> downloadAndAttach(OnlineSubtitleResult result) async {
    final media = playerService.snapshot.currentMedia;
    if (media == null) {
      _setActionMessage('No active video to attach subtitle to.', isError: true);
      return false;
    }

    _downloadingFileId = result.fileId;
    _clearActionMessage();
    notifyListeners();

    try {
      final saved = await repository.downloadAndSaveSubtitle(
        mediaKey: media.mediaKey,
        result: result,
        movieHash: _movieHash,
      );

      await playerService.attachExternalSubtitle(
        filePath: saved.localFilePath,
        title: saved.fileName,
        languageCode: saved.languageCode,
        languageName: saved.languageName,
        source: SubtitleSource.opensubtitles,
        externalId: saved.externalId,
        movieHash: saved.movieHash,
        persistInDb: true,
      );

      _setActionMessage(
        'Downloaded & loaded ${result.languageName}: ${saved.fileName}',
      );
      return true;
    } on AppException catch (error) {
      _setActionMessage(error.message, isError: true);
      return false;
    } catch (error) {
      _setActionMessage(
        'Failed to download subtitle: $error',
        isError: true,
      );
      return false;
    } finally {
      _downloadingFileId = null;
      notifyListeners();
    }
  }

  Future<void> deleteSavedSubtitle(SavedSubtitle saved) async {
    final id = saved.id;
    if (id == null) return;

    final wasSelected =
        playerService.snapshot.selectedSubtitleTrackId ==
        'ext:${saved.localFilePath}';
    await repository.deleteSavedSubtitle(
      id,
      localFilePath: saved.localFilePath,
    );
    if (wasSelected) {
      await playerService.disableSubtitles();
    } else {
      await playerService.selectSubtitleTrack(
        playerService.snapshot.selectedSubtitleTrackId,
      );
    }
    _setActionMessage('Removed ${saved.fileName}');
  }

  Future<void> stepDelay(int deltaMs) async {
    await playerService.stepSubtitleDelay(Duration(milliseconds: deltaMs));
  }

  Future<void> setDelayMs(int delayMs) async {
    await playerService.setSubtitleDelay(Duration(milliseconds: delayMs));
  }

  Future<void> resetDelay() async {
    await playerService.setSubtitleDelay(Duration.zero);
  }

  Future<void> setFontSize(double size) async {
    await playerService.setSubtitleFontSize(
      size.clamp(AppConfig.minSubtitleFontSize, AppConfig.maxSubtitleFontSize),
    );
  }

  Future<void> setScale(double scale) async {
    await playerService.setSubtitleScale(
      scale.clamp(AppConfig.minSubtitleScale, AppConfig.maxSubtitleScale),
    );
  }

  Future<void> setLibassEnabled(bool enabled) async {
    await playerService.setLibassEnabled(enabled);
  }

  void _setActionMessage(String msg, {bool isError = false}) {
    _actionMessage = msg;
    _actionIsError = isError;
    notifyListeners();
  }

  void _clearActionMessage() {
    _actionMessage = null;
    _actionIsError = false;
  }
}
