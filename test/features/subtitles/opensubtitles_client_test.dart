import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/features/subtitles/data/local_subtitle_picker.dart';
import 'package:video_player_app/features/subtitles/data/opensubtitles_api_client.dart';
import 'package:video_player_app/features/subtitles/domain/online_subtitle_result.dart';
import 'package:video_player_app/features/subtitles/domain/subtitle_search_query.dart';

typedef AdapterHandler =
    ResponseBody Function(
      RequestOptions options,
    );

class _MockHttpAdapter implements HttpClientAdapter {
  final AdapterHandler handler;

  _MockHttpAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('cleanTitleFromFilename strips release tags and codecs cleanly', () {
    expect(
      SubtitleSearchQuery.cleanTitleFromFilename(
        'Inception.2010.1080p.BluRay.x264-YIFY',
      ),
      'Inception 2010',
    );
    expect(
      SubtitleSearchQuery.cleanTitleFromFilename(
        '[SubsPlease] Dandadan - 05 (1080p) [A1B2C3D4]',
      ),
      'Dandadan - 05',
    );
  });

  test('inferLanguageFromFilename detects ISO-639-1 and ISO-639-2 codes', () {
    expect(
      DeviceLocalSubtitlePicker.inferLanguageFromFilename('Movie.bn.srt')
          ?.iso6391,
      'bn',
    );
    expect(
      DeviceLocalSubtitlePicker.inferLanguageFromFilename('Anime.eng.ass')
          ?.iso6391,
      'en',
    );
    expect(
      DeviceLocalSubtitlePicker.inferLanguageFromFilename('Track_ja.vtt')
          ?.iso6391,
      'ja',
    );
  });

  test('OpenSubtitlesApiClient searches, prioritizes hash matches, and downloads', () async {
    RequestOptions? capturedSearch;
    RequestOptions? capturedDownloadPost;

    final dio = Dio(BaseOptions(baseUrl: 'https://api.opensubtitles.com/api/v1'));
    dio.httpClientAdapter = _MockHttpAdapter((options) {
      if (options.path == '/subtitles') {
        capturedSearch = options;
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': '10',
                'attributes': <String, dynamic>{
                  'language': 'en',
                  'release': 'Movie.1080p.WEB-DL',
                  'download_count': 5000,
                  'ratings': 9.0,
                  'moviehash_match': false,
                  'hearing_impaired': false,
                  'files': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'file_id': 101,
                      'file_name': 'movie.en.srt',
                    },
                  ],
                },
              },
              <String, dynamic>{
                'id': '11',
                'attributes': <String, dynamic>{
                  'language': 'bn',
                  'release': 'Movie.BluRay.BN',
                  'download_count': 120,
                  'ratings': 10.0,
                  'moviehash_match': true,
                  'hearing_impaired': false,
                  'files': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'file_id': 202,
                      'file_name': 'movie.bn.srt',
                    },
                  ],
                },
              },
            ],
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }

      if (options.path == '/download') {
        capturedDownloadPost = options;
        return ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            'link': 'https://cdn.example.com/sub/202.srt',
          }),
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        );
      }

      return ResponseBody.fromString(
        '1\n00:00:01,000 --> 00:00:03,000\nহ্যালো\n',
        200,
      );
    });

    final client = OpenSubtitlesApiClient(dio: dio);
    final results = await client.search(
      query: const SubtitleSearchQuery(
        query: 'Movie',
        movieHash: '0123456789abcdef',
        languageCodes: <String>['bn', 'en'],
      ),
      apiKey: 'test-key-123',
    );

    expect(capturedSearch?.headers['Api-Key'], 'test-key-123');
    expect(capturedSearch?.queryParameters['languages'], 'bn,en');
    expect(capturedSearch?.queryParameters['moviehash'], '0123456789abcdef');
    expect(results.length, 2);
    // Exact moviehash match is promoted to the top.
    expect(results.first.fileId, 202);
    expect(results.first.isHashMatch, isTrue);
    expect(results.first.languageName, 'Bengali');

    final bytes = await client.downloadFileBytes(
      fileId: 202,
      apiKey: 'test-key-123',
    );
    expect(capturedDownloadPost?.data['file_id'], 202);
    expect(utf8.decode(bytes), contains('হ্যালো'));
  });

  test('OpenSubtitlesApiClient throws typed SubtitleNetworkException on missing key & 429', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.opensubtitles.com/api/v1'));
    dio.httpClientAdapter = _MockHttpAdapter((options) {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{'message': 'Daily limit exceeded'}),
        429,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );
    });

    final client = OpenSubtitlesApiClient(dio: dio);
    await expectLater(
      client.search(
        query: const SubtitleSearchQuery(query: 'Movie'),
        apiKey: '',
      ),
      throwsA(isA<SubtitleNetworkException>()),
    );

    await expectLater(
      client.search(
        query: const SubtitleSearchQuery(query: 'Movie'),
        apiKey: 'valid-key',
      ),
      throwsA(
        isA<SubtitleNetworkException>().having(
          (e) => e.message,
          'message',
          contains('Daily limit exceeded'),
        ),
      ),
    );
  });

  test('OnlineSubtitleResult skips malformed entries without files', () {
    final parsed = OnlineSubtitleResult.fromOpenSubtitlesJson(<String, dynamic>{
      'id': '1',
      'attributes': <String, dynamic>{
        'language': 'en',
        'files': <dynamic>[],
      },
    });
    expect(parsed, isNull);
  });
}
