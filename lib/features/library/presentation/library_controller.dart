import 'package:flutter/foundation.dart';
import 'package:video_player_app/data/local/models/playback_settings.dart';
import 'package:video_player_app/features/library/data/media_library_repository.dart';
import 'package:video_player_app/features/library/data/media_permission_service.dart';
import 'package:video_player_app/features/library/domain/library_permission_status.dart';
import 'package:video_player_app/features/library/domain/library_sort_field.dart';
import 'package:video_player_app/features/library/domain/library_sort_option.dart';
import 'package:video_player_app/features/library/domain/video_folder.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

enum LibraryViewMode { folders, allVideos, audio, vault }

/// State controller for local video/audio discovery, folder grouping, search,
/// sorting, and file management actions.
class LibraryController extends ChangeNotifier {
  final MediaLibraryRepository _repository;
  final MediaPermissionService _permissionService;

  LibraryController({
    MediaLibraryRepository? repository,
    MediaPermissionService? permissionService,
  }) : _repository = repository ?? MediaLibraryRepository(),
       _permissionService =
           permissionService ?? const DeviceMediaPermissionService();

  bool _isLoading = true;
  bool _isScanning = false;
  LibraryPermissionStatus _permissionStatus = LibraryPermissionStatus.unknown;
  LibraryViewMode _viewMode = LibraryViewMode.folders;
  LibrarySortOption _sortOption = const LibrarySortOption();
  String _searchQuery = '';
  String? _selectedFolderPath;
  List<VideoItem> _allMedia = const <VideoItem>[];
  String? _errorMessage;

  bool get isLoading => _isLoading;
  bool get isScanning => _isScanning;
  LibraryPermissionStatus get permissionStatus => _permissionStatus;
  LibraryViewMode get viewMode => _viewMode;
  LibrarySortOption get sortOption => _sortOption;
  String get searchQuery => _searchQuery;
  String? get selectedFolderPath => _selectedFolderPath;
  String? get errorMessage => _errorMessage;

  List<VideoItem> get allVideos =>
      _allMedia.where((m) => !m.isAudioOnly).toList(growable: false);

  List<VideoItem> get allAudio =>
      _allMedia.where((m) => m.isAudioOnly).toList(growable: false);

  String? get selectedFolderName {
    final path = _selectedFolderPath;
    if (path == null) return null;
    for (final v in allVideos) {
      if (v.folderPath == path) return v.folderName;
    }
    return 'Folder';
  }

  List<VideoItem> get continueWatchingVideos {
    final resumable = allVideos
        .where((v) => v.hasResumeProgress)
        .toList(growable: false);
    resumable.sort(
      (a, b) => (b.watchHistory?.lastPlayedAtMs ?? 0).compareTo(
        a.watchHistory?.lastPlayedAtMs ?? 0,
      ),
    );
    return resumable.take(10).toList(growable: false);
  }

  List<VideoItem> get visibleVideos {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = allVideos.where((video) {
      if (_selectedFolderPath != null &&
          video.folderPath != _selectedFolderPath) {
        return false;
      }
      if (query.isEmpty) return true;
      return video.title.toLowerCase().contains(query) ||
          video.fileName.toLowerCase().contains(query) ||
          video.folderName.toLowerCase().contains(query);
    }).toList();

    filtered.sort(_sortOption.compare);
    return List<VideoItem>.unmodifiable(filtered);
  }

  List<VideoItem> get visibleAudioTracks {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = allAudio.where((track) {
      if (query.isEmpty) return true;
      return track.title.toLowerCase().contains(query) ||
          track.fileName.toLowerCase().contains(query) ||
          track.folderName.toLowerCase().contains(query);
    }).toList();

    filtered.sort(_sortOption.compare);
    return List<VideoItem>.unmodifiable(filtered);
  }

  List<VideoFolder> get visibleFolders {
    final query = _searchQuery.trim().toLowerCase();
    final sortedAll = List<VideoItem>.from(allVideos)..sort(_sortOption.compare);
    final folders = MediaLibraryRepository.groupIntoFolders(sortedAll);
    if (query.isEmpty) return folders;

    return folders
        .where((folder) {
          if (folder.folderName.toLowerCase().contains(query)) return true;
          return folder.videos.any(
            (v) => v.title.toLowerCase().contains(query),
          );
        })
        .toList(growable: false);
  }

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _sortOption = await _repository.loadSortOption();
      final cached = await _repository.loadCachedVideos();
      if (cached.isNotEmpty) {
        _allMedia = cached;
        _isLoading = false;
        notifyListeners();
      }

      var status = await _permissionService.checkStatus();
      if (!status.hasAccess) {
        status = await _permissionService.requestPermission();
      }
      _permissionStatus = status;

      if (status.hasAccess) {
        await refresh();
      }
    } catch (error) {
      _errorMessage = 'Failed to load media library: $error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> requestPermissionAndScan() async {
    _permissionStatus = await _permissionService.requestPermission();
    notifyListeners();
    if (_permissionStatus.hasAccess) {
      await refresh();
    }
  }

  Future<void> openPermissionSettings() async {
    await _permissionService.openAppSettings();
  }

  Future<void> manageLimitedAccess() async {
    await _permissionService.presentLimitedSelection();
    await refresh();
  }

  Future<void> refresh() async {
    if (_isScanning) return;
    _isScanning = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allMedia = await _repository.scanAndCacheVideos();
    } catch (error) {
      _errorMessage = 'Unable to scan device storage: $error';
    } finally {
      _isScanning = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshWatchHistory() async {
    if (_allMedia.isEmpty) return;
    _allMedia = await _repository.attachHistory(_allMedia);
    notifyListeners();
  }

  void setViewMode(LibraryViewMode mode) {
    if (_viewMode == mode && _selectedFolderPath == null) return;
    _viewMode = mode;
    if (mode != LibraryViewMode.folders) {
      _selectedFolderPath = null;
    }
    notifyListeners();
  }

  void openFolder(String folderPath) {
    _selectedFolderPath = folderPath;
    notifyListeners();
  }

  void closeFolder() {
    if (_selectedFolderPath == null) return;
    _selectedFolderPath = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> setSortOption({
    LibrarySortField? field,
    bool? ascending,
  }) async {
    final next = _sortOption.copyWith(field: field, ascending: ascending);
    if (next == _sortOption) return;
    _sortOption = next;
    notifyListeners();
    await _repository.saveSortOption(next);
  }

  Future<void> markWatched(VideoItem item, {required bool watched}) async {
    await _repository.markWatched(item, watched: watched);
    await refreshWatchHistory();
  }

  Future<void> clearVideoProgress(VideoItem item) async {
    await _repository.clearHistory(item.mediaKey);
    await refreshWatchHistory();
  }

  Future<void> renameVideo(VideoItem item, String newBaseName) async {
    await _repository.renameVideo(item, newBaseName);
    await refresh();
  }

  Future<void> deleteVideo(VideoItem item) async {
    await _repository.deleteVideo(item);
    _allMedia = _allMedia
        .where((m) => m.mediaKey != item.mediaKey)
        .toList(growable: false);
    notifyListeners();
  }

  Future<void> shareVideo(VideoItem item) async {
    await _repository.shareVideo(item);
  }

  Future<VideoItem?> pickLocalVideoFile() async {
    return _repository.pickLocalVideoFile();
  }

  Future<PlaybackSettings> loadSettings() => _repository.getSettings();

  Future<PlaybackSettings> saveSettings(PlaybackSettings settings) {
    return _repository.saveSettings(settings);
  }
}
