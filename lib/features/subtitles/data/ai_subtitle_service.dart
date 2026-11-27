import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/playback_settings_dao.dart';
import 'package:video_player_app/data/local/dao/saved_subtitle_dao.dart';
import 'package:video_player_app/data/local/models/saved_subtitle.dart';

typedef AiDirectoryProvider = Future<Directory> Function();

/// Contract for AI speech-to-text transcription and subtitle translation.
abstract interface class AiSubtitleService {
  Future<SavedSubtitle> generateAndTranslate({
    required String mediaKey,
    required String mediaPath,
    required String targetLanguageCode,
  });
}

/// OpenAI Whisper (`/audio/transcriptions`, `/audio/translations`) + GPT SRT
/// translator implementing automatic speech-to-text and multilingual AI subtitles.
class OpenAiWhisperSubtitleService implements AiSubtitleService {
  final Dio _dio;
  final PlaybackSettingsDao _settingsDao;
  final SavedSubtitleDao _savedSubtitleDao;
  final AiDirectoryProvider _documentsDirProvider;

  OpenAiWhisperSubtitleService({
    Dio? dio,
    PlaybackSettingsDao? settingsDao,
    SavedSubtitleDao? savedSubtitleDao,
    AiDirectoryProvider? documentsDirProvider,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: AppConfig.openAiBaseUrl,
               connectTimeout: const Duration(seconds: 20),
               receiveTimeout: const Duration(minutes: 2),
             ),
           ),
       _settingsDao = settingsDao ?? PlaybackSettingsDao(),
       _savedSubtitleDao = savedSubtitleDao ?? SavedSubtitleDao(),
       _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory;

  @override
  Future<SavedSubtitle> generateAndTranslate({
    required String mediaKey,
    required String mediaPath,
    required String targetLanguageCode,
  }) async {
    final settings = await _settingsDao.getSettings();
    final apiKey = settings.effectiveOpenAiApiKey;
    if (apiKey.isEmpty) {
      throw const SubtitleNetworkException(
        'OpenAI API key is not configured. Add it in Library Settings or via --dart-define=OPENAI_API_KEY.',
      );
    }

    if (mediaPath.contains('://')) {
      throw const SubtitleFileException(
        'AI Subtitles require a direct local media file path.',
      );
    }

    final file = File(mediaPath);
    if (!await file.exists()) {
      throw const SubtitleFileException('Media file not found on disk.');
    }

    final sizeBytes = await file.length();
    if (sizeBytes > AppConfig.whisperMaxFileBytes) {
      throw const SubtitleFileException(
        'File exceeds OpenAI Whisper 25 MB upload limit. Select an audio track or shorter clip under 25 MB.',
      );
    }

    final targetLang = targetLanguageCode.trim().toLowerCase();
    final useDirectEnglishTranslation = targetLang == 'en';
    final endpoint = useDirectEnglishTranslation
        ? '/audio/translations'
        : '/audio/transcriptions';

    try {
      final formData = FormData.fromMap(<String, dynamic>{
        'model': 'whisper-1',
        'response_format': 'srt',
        'file': await MultipartFile.fromFile(
          file.path,
          filename: p.basename(file.path),
        ),
      });

      final whisperResponse = await _dio.post<String>(
        endpoint,
        data: formData,
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $apiKey'},
          responseType: ResponseType.plain,
        ),
      );

      var srtContent = (whisperResponse.data ?? '').trim();
      if (srtContent.isEmpty) {
        throw const SubtitleNetworkException(
          'Whisper returned an empty subtitle transcript.',
        );
      }

      if (targetLang.isNotEmpty &&
          targetLang != 'auto' &&
          targetLang != 'en') {
        srtContent = await _translateSrt(
          srtContent: srtContent,
          targetLanguageCode: targetLang,
          apiKey: apiKey,
        );
      }

      final docsDir = await _documentsDirProvider();
      final aiDir = Directory(p.join(docsDir.path, 'subtitles', 'ai'));
      if (!await aiDir.exists()) {
        await aiDir.create(recursive: true);
      }

      final langSlug = (targetLang.isEmpty || targetLang == 'auto')
          ? 'auto'
          : targetLang;
      final baseName = p.basenameWithoutExtension(mediaPath);
      final fileName = '${baseName}_ai_$langSlug.srt';
      final outFile = File(
        p.join(
          aiDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_$fileName',
        ),
      );
      await outFile.writeAsString(srtContent, flush: true);

      final saved = SavedSubtitle(
        mediaKey: mediaKey,
        localFilePath: outFile.path,
        fileName: fileName,
        languageCode: langSlug == 'auto' ? 'und' : langSlug,
        languageName: langSlug == 'auto'
            ? 'AI Auto-Detected'
            : '${SubtitleLanguages.labelForCode(langSlug)} (AI)',
        format: 'srt',
        source: SubtitleSource.opensubtitles,
        externalId: 'ai_${DateTime.now().millisecondsSinceEpoch}',
        isActive: true,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
      );

      return await _savedSubtitleDao.upsert(saved);
    } on DioException catch (error, stackTrace) {
      final status = error.response?.statusCode;
      throw SubtitleNetworkException(
        'AI Subtitle generation failed${status != null ? ' (HTTP $status)' : ''}: ${error.message ?? 'Network error'}',
        statusCode: status,
        cause: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<String> _translateSrt({
    required String srtContent,
    required String targetLanguageCode,
    required String apiKey,
  }) async {
    final targetName = SubtitleLanguages.labelForCode(targetLanguageCode);
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/completions',
      data: <String, dynamic>{
        'model': 'gpt-4o-mini',
        'temperature': 0.2,
        'messages': <Map<String, String>>[
          <String, String>{
            'role': 'system',
            'content':
                'Translate the dialogue lines of this SRT subtitle file into $targetName. Preserve exact SRT cue numbers and timestamps. Return only valid SRT text.',
          },
          <String, String>{'role': 'user', 'content': srtContent},
        ],
      },
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    final choices = response.data?['choices'];
    if (choices is List && choices.isNotEmpty) {
      final message = (choices.first as Map?)?['message'];
      final content = (message as Map?)?['content']?.toString().trim();
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    return srtContent;
  }
}
