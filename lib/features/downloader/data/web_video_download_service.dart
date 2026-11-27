import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/video_download_dao.dart';
import 'package:video_player_app/data/local/models/video_download_record.dart';

typedef DownloadDirProvider = Future<Directory> Function();

/// Direct web video downloader with Play Store compliance URL filtering
/// (strictly blocks YouTube domains) and SQLite download tracking.
class WebVideoDownloadController extends ChangeNotifier {
  static const Set<String> _restrictedHosts = <String>{
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
    'youtube-nocookie.com',
    'googlevideo.com',
  };

  final Dio _dio;
  final VideoDownloadDao _dao;
  final DownloadDirProvider _documentsDirProvider;

  final Map<int, CancelToken> _cancelTokens = <int, CancelToken>{};
  List<VideoDownloadRecord> _records = const <VideoDownloadRecord>[];
  bool _isLoading = false;
  String? _errorMessage;

  WebVideoDownloadController({
    Dio? dio,
    VideoDownloadDao? dao,
    DownloadDirProvider? documentsDirProvider,
  }) : _dio = dio ?? Dio(),
       _dao = dao ?? VideoDownloadDao(),
       _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory;

  List<VideoDownloadRecord> get records => _records;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Validates HTTP/HTTPS direct URL and rejects restricted streaming sites.
  static Uri validateDownloadUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !(uri.scheme == 'http' || uri.scheme == 'https') ||
        uri.host.isEmpty) {
      throw const SubtitleNetworkException(
        'Enter a valid HTTP or HTTPS direct video URL.',
      );
    }

    final host = uri.host.toLowerCase();
    for (final blocked in _restrictedHosts) {
      if (host == blocked || host.endsWith('.$blocked')) {
        throw const StoragePermissionException(
          'Downloading from YouTube is strictly disabled for Google Play compliance.',
        );
      }
    }
    return uri;
  }

  Future<void> loadHistory() async {
    _isLoading = true;
    notifyListeners();
    try {
      _records = await _dao.getAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<VideoDownloadRecord?> startDownload(String rawUrl) async {
    _errorMessage = null;
    final Uri uri;
    try {
      uri = validateDownloadUrl(rawUrl);
    } on AppException catch (error) {
      _errorMessage = error.message;
      notifyListeners();
      return null;
    }

    final docsDir = await _documentsDirProvider();
    final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final fileName = _deriveFileName(uri);
    final savePath = p.join(
      downloadsDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_$fileName',
    );
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    var record = await _dao.insert(
      VideoDownloadRecord(
        url: uri.toString(),
        fileName: fileName,
        savePath: savePath,
        status: VideoDownloadStatus.downloading,
        createdAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
    await loadHistory();

    final cancelToken = CancelToken();
    final id = record.id!;
    _cancelTokens[id] = cancelToken;

    try {
      await _dio.download(
        uri.toString(),
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          record = record.copyWith(
            receivedBytes: received,
            totalBytes: total > 0 ? total : record.totalBytes,
            status: VideoDownloadStatus.downloading,
          );
          _replaceInMemory(record);
        },
      );

      final file = File(savePath);
      final finalSize = await file.exists() ? await file.length() : record.receivedBytes;
      record = record.copyWith(
        receivedBytes: finalSize,
        totalBytes: finalSize,
        status: VideoDownloadStatus.completed,
        clearErrorMessage: true,
      );
      await _dao.update(record);
      _replaceInMemory(record);
      return record;
    } on DioException catch (error) {
      final isCancelled = CancelToken.isCancel(error);
      record = record.copyWith(
        status: isCancelled
            ? VideoDownloadStatus.cancelled
            : VideoDownloadStatus.failed,
        errorMessage: isCancelled
            ? 'Download cancelled.'
            : (error.message ?? 'Download failed.'),
      );
      await _dao.update(record);
      _replaceInMemory(record);
      return null;
    } finally {
      _cancelTokens.remove(id);
    }
  }

  void cancelDownload(int recordId) {
    _cancelTokens[recordId]?.cancel('User cancelled');
  }

  Future<void> deleteRecord(VideoDownloadRecord record) async {
    if (record.id != null) {
      cancelDownload(record.id!);
      await _dao.deleteById(record.id!);
    }
    final file = File(record.savePath);
    if (await file.exists()) {
      await file.delete();
    }
    await loadHistory();
  }

  void _replaceInMemory(VideoDownloadRecord updated) {
    _records = _records
        .map((r) => r.id == updated.id ? updated : r)
        .toList(growable: false);
    notifyListeners();
  }

  String _deriveFileName(Uri uri) {
    final last = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
    final sanitized = last.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (sanitized.isEmpty) {
      return 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';
    }
    if (MediaFormats.isSupportedVideo(sanitized) ||
        MediaFormats.isSupportedAudio(sanitized)) {
      return sanitized;
    }
    return '$sanitized.mp4';
  }
}
