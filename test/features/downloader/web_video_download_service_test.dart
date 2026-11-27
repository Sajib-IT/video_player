import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/video_download_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/data/local/models/video_download_record.dart';
import 'package:video_player_app/features/downloader/data/web_video_download_service.dart';

class _MockDownloadAdapter implements HttpClientAdapter {
  final Uint8List payload;

  _MockDownloadAdapter(this.payload);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      payload,
      200,
      headers: <String, List<String>>{
        HttpHeaders.contentLengthHeader: <String>['${payload.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();

  test('blocks YouTube domains strictly for Google Play compliance', () {
    const blocked = <String>[
      'https://youtube.com/watch?v=abc123',
      'https://www.youtube.com/watch?v=abc123',
      'https://m.youtube.com/shorts/xyz',
      'https://music.youtube.com/watch?v=123',
      'https://youtu.be/abc123',
      'https://redirector.googlevideo.com/videoplayback',
    ];

    for (final url in blocked) {
      expect(
        () => WebVideoDownloadController.validateDownloadUrl(url),
        throwsA(isA<StoragePermissionException>()),
      );
    }

    final valid = WebVideoDownloadController.validateDownloadUrl(
      'https://cdn.example.com/movies/sample_clip.mp4',
    );
    expect(valid.host, 'cdn.example.com');
  });

  test('downloads allowed direct video URL and marks SQLite record completed', () async {
    final dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    final tempDir = await Directory.systemTemp.createTemp('web_dl_test');
    addTearDown(() async {
      await dbHelper.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final dio = Dio()
      ..httpClientAdapter = _MockDownloadAdapter(
        Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5, 6, 7]),
      );
    final controller = WebVideoDownloadController(
      dio: dio,
      dao: VideoDownloadDao(dbHelper: dbHelper),
      documentsDirProvider: () async => tempDir,
    );
    addTearDown(controller.dispose);

    final record = await controller.startDownload(
      'https://cdn.example.com/trailer.mp4',
    );
    expect(record, isNotNull);
    expect(record!.status, VideoDownloadStatus.completed);
    expect(await File(record.savePath).readAsBytes(), <int>[0, 1, 2, 3, 4, 5, 6, 7]);
  });
}
