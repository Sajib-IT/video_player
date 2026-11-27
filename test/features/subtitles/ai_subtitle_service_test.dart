import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/features/subtitles/data/ai_subtitle_service.dart';

class _MockOpenAiAdapter implements HttpClientAdapter {
  final List<String> requestedPaths = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    if (options.path == '/audio/transcriptions') {
      return ResponseBody.fromString(
        '1\n00:00:00,000 --> 00:00:02,000\nHello world\n',
        200,
      );
    }
    if (options.path == '/chat/completions') {
      return ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'choices': <Map<String, dynamic>>[
            <String, dynamic>{
              'message': <String, dynamic>{
                'content': '1\n00:00:00,000 --> 00:00:02,000\nহ্যালো বিশ্ব\n',
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
    return ResponseBody.fromString('Not Found', 404);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  sqfliteFfiInit();

  test('requires OpenAI API key and generates + translates SRT via Whisper', () async {
    final dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    final tempDir = await Directory.systemTemp.createTemp('ai_sub_test');
    addTearDown(() async {
      await dbHelper.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    final mediaFile = File(p.join(tempDir.path, 'sample.mp3'))
      ..writeAsBytesSync(<int>[1, 2, 3, 4]);

    final settingsDao = PlaybackSettingsDao(dbHelper: dbHelper);
    final savedSubDao = SavedSubtitleDao(dbHelper: dbHelper);
    final adapter = _MockOpenAiAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.openai.com/v1'))
      ..httpClientAdapter = adapter;

    final service = OpenAiWhisperSubtitleService(
      dio: dio,
      settingsDao: settingsDao,
      savedSubtitleDao: savedSubDao,
      documentsDirProvider: () async => tempDir,
    );

    await expectLater(
      service.generateAndTranslate(
        mediaKey: mediaFile.path,
        mediaPath: mediaFile.path,
        targetLanguageCode: 'bn',
      ),
      throwsA(isA<SubtitleNetworkException>()),
    );

    final settings = await settingsDao.getSettings();
    await settingsDao.saveSettings(
      settings.copyWith(openAiApiKey: 'sk-test-12345'),
    );

    final saved = await service.generateAndTranslate(
      mediaKey: mediaFile.path,
      mediaPath: mediaFile.path,
      targetLanguageCode: 'bn',
    );

    expect(adapter.requestedPaths, <String>[
      '/audio/transcriptions',
      '/chat/completions',
    ]);
    expect(saved.languageCode, 'bn');
    expect(await File(saved.localFilePath).readAsString(), contains('হ্যালো বিশ্ব'));
  });
}
