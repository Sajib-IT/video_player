import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/core/errors/app_exception.dart';

/// Result returned when picking a local subtitle file from device storage.
class PickedSubtitleFile {
  final String filePath;
  final String fileName;
  final String languageCode;
  final String languageName;

  const PickedSubtitleFile({
    required this.filePath,
    required this.fileName,
    required this.languageCode,
    required this.languageName,
  });
}

/// Abstraction for selecting local `.srt`/`.ass`/`.ssa`/`.vtt`/`.sub` files.
abstract interface class LocalSubtitlePicker {
  Future<PickedSubtitleFile?> pickSubtitleFile();
}

/// Uses `file_picker` and caches picked subtitles into persistent app storage
/// so SAF/content-provider temporary paths remain valid across app restarts.
class DeviceLocalSubtitlePicker implements LocalSubtitlePicker {
  const DeviceLocalSubtitlePicker();

  @override
  Future<PickedSubtitleFile?> pickSubtitleFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Select Subtitle (.srt, .ass, .ssa, .vtt, .sub)',
      type: FileType.any,
    );
    if (picked == null) return null;

    final candidateName = picked.name.trim().isNotEmpty
        ? picked.name.trim()
        : (picked.path != null ? p.basename(picked.path!) : '');
    if (candidateName.isEmpty ||
        !MediaFormats.isSupportedSubtitle(candidateName)) {
      throw const SubtitleFileException(
        'Please choose a valid subtitle file (.srt, .ass, .ssa, .vtt, or .sub).',
      );
    }

    final persistedPath = await _persistPickedSubtitle(picked, candidateName);
    final inferred = inferLanguageFromFilename(candidateName);

    return PickedSubtitleFile(
      filePath: persistedPath,
      fileName: candidateName,
      languageCode: inferred?.iso6391 ?? 'und',
      languageName: inferred?.englishName ?? 'Local File',
    );
  }

  Future<String> _persistPickedSubtitle(
    PlatformFile picked,
    String fileName,
  ) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(docsDir.path, 'subtitles', 'local'));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final destFile = File(p.join(targetDir.path, '${stamp}_$safeName'));

    final localPath = picked.path;
    if (localPath != null && await File(localPath).exists()) {
      await File(localPath).copy(destFile.path);
      return destFile.path;
    }

    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) {
      throw const SubtitleFileException('Selected subtitle file is empty.');
    }
    await destFile.writeAsBytes(bytes, flush: true);
    return destFile.path;
  }

  /// Extracts a language token from filenames like `Movie.bn.srt` or `Clip.eng.ass`.
  static SubtitleLanguage? inferLanguageFromFilename(String fileName) {
    final stem = p.basenameWithoutExtension(fileName);
    final parts = stem.split(RegExp(r'[._\-\s\[\]()]+'));
    for (final token in parts.reversed) {
      final lang = SubtitleLanguages.findByCode(token);
      if (lang != null) return lang;
    }
    return null;
  }
}
