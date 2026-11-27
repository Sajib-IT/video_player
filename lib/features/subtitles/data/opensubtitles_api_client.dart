import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/domain/subtitle_search_query.dart';

/// Abstract remote provider for searching and downloading subtitle files.
abstract interface class OnlineSubtitleClient {
  Future<List<OnlineSubtitleResult>> search({
    required SubtitleSearchQuery query,
    required String apiKey,
  });

  Future<Uint8List> downloadFileBytes({
    required int fileId,
    required String apiKey,
  });
}

/// OpenSubtitles REST API v1 client powered by `dio`.
class OpenSubtitlesApiClient implements OnlineSubtitleClient {
  final Dio _dio;

  OpenSubtitlesApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: AppConfig.openSubtitlesBaseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 25),
              headers: const <String, String>{
                'Accept': 'application/json',
                'User-Agent': AppConfig.openSubtitlesUserAgent,
              },
            ),
          );

  @override
  Future<List<OnlineSubtitleResult>> search({
    required SubtitleSearchQuery query,
    required String apiKey,
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const SubtitleNetworkException(
        'OpenSubtitles API key is not configured. Add it in Settings to search online subtitles.',
      );
    }
    if (!query.hasQuery && !query.hasMovieHash) {
      throw const SubtitleNetworkException(
        'Enter a movie or episode title to search for subtitles.',
      );
    }

    final params = <String, dynamic>{
      if (query.hasQuery) 'query': query.query.trim(),
      if (query.hasMovieHash) 'moviehash': query.movieHash!.trim(),
      if (query.languageCodes.isNotEmpty)
        'languages': query.languageCodes.join(','),
      'order_by': 'download_count',
      'order_direction': 'desc',
    };

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/subtitles',
        queryParameters: params,
        options: Options(
          headers: <String, String>{'Api-Key': trimmedKey},
        ),
      );

      final body = response.data;
      final dataList = body?['data'];
      if (dataList is! List) return const <OnlineSubtitleResult>[];

      final results = <OnlineSubtitleResult>[];
      for (final raw in dataList) {
        if (raw is Map<String, dynamic>) {
          final parsed = OnlineSubtitleResult.fromOpenSubtitlesJson(raw);
          if (parsed != null) results.add(parsed);
        }
      }

      results.sort((a, b) {
        if (a.isHashMatch != b.isHashMatch) {
          return a.isHashMatch ? -1 : 1;
        }
        return b.downloadCount.compareTo(a.downloadCount);
      });
      return results;
    } on DioException catch (error, stackTrace) {
      throw _mapDioError(error, stackTrace, contextLabel: 'Subtitle search');
    }
  }

  @override
  Future<Uint8List> downloadFileBytes({
    required int fileId,
    required String apiKey,
  }) async {
    final trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const SubtitleNetworkException(
        'OpenSubtitles API key is not configured.',
      );
    }

    try {
      final linkResponse = await _dio.post<Map<String, dynamic>>(
        '/download',
        data: <String, dynamic>{'file_id': fileId},
        options: Options(
          headers: <String, String>{
            'Api-Key': trimmedKey,
            'Content-Type': 'application/json',
          },
        ),
      );

      final link = (linkResponse.data?['link'] as String?)?.trim();
      if (link == null || link.isEmpty) {
        final serverMsg = linkResponse.data?['message']?.toString();
        throw SubtitleNetworkException(
          serverMsg != null && serverMsg.isNotEmpty
              ? serverMsg
              : 'OpenSubtitles did not return a download link.',
        );
      }

      final fileResponse = await _dio.get<List<int>>(
        link,
        options: Options(responseType: ResponseType.bytes),
      );

      final rawBytes = fileResponse.data;
      if (rawBytes == null || rawBytes.isEmpty) {
        throw const SubtitleNetworkException(
          'Downloaded subtitle file was empty.',
        );
      }
      return Uint8List.fromList(rawBytes);
    } on DioException catch (error, stackTrace) {
      throw _mapDioError(error, stackTrace, contextLabel: 'Subtitle download');
    }
  }

  SubtitleNetworkException _mapDioError(
    DioException error,
    StackTrace stackTrace, {
    required String contextLabel,
  }) {
    final statusCode = error.response?.statusCode;
    final serverMessage = _extractServerMessage(error.response?.data);

    if (statusCode == 401 || statusCode == 403) {
      return SubtitleNetworkException(
        serverMessage ??
            'OpenSubtitles rejected the API key or authorization (HTTP $statusCode). Check your API key in Settings.',
        statusCode: statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (statusCode == 429) {
      return SubtitleNetworkException(
        serverMessage ??
            'OpenSubtitles rate limit or daily download quota reached. Please try again later.',
        statusCode: statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (statusCode != null && statusCode >= 400) {
      return SubtitleNetworkException(
        serverMessage ?? '$contextLabel failed (HTTP $statusCode).',
        statusCode: statusCode,
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return SubtitleNetworkException(
        '$contextLabel timed out. Check your internet connection and retry.',
        cause: error,
        stackTrace: stackTrace,
      );
    }
    if (error.type == DioExceptionType.connectionError) {
      return SubtitleNetworkException(
        'No internet connection. Unable to reach OpenSubtitles.',
        cause: error,
        stackTrace: stackTrace,
      );
    }

    return SubtitleNetworkException(
      serverMessage ?? '$contextLabel failed: ${error.message ?? 'Unknown error'}',
      statusCode: statusCode,
      cause: error,
      stackTrace: stackTrace,
    );
  }

  String? _extractServerMessage(dynamic data) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        return msg.toString().trim();
      }
    }
    return null;
  }
}
