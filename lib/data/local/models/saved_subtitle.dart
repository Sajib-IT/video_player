/// Origin of a saved external subtitle file.
enum SubtitleSource {
  local('local'),
  opensubtitles('opensubtitles');

  final String id;

  const SubtitleSource(this.id);

  static SubtitleSource fromId(String? raw) {
    for (final value in SubtitleSource.values) {
      if (value.id == raw) return value;
    }
    return SubtitleSource.local;
  }
}

/// Persisted external subtitle metadata associated with a specific video.
class SavedSubtitle {
  final int? id;
  final String mediaKey;
  final String localFilePath;
  final String fileName;
  final String languageCode;
  final String languageName;
  final String format;
  final SubtitleSource source;
  final String? externalId;
  final String? movieHash;
  final int delayMs;
  final bool isActive;
  final int createdAtMs;

  const SavedSubtitle({
    this.id,
    required this.mediaKey,
    required this.localFilePath,
    required this.fileName,
    this.languageCode = 'und',
    this.languageName = 'Unknown',
    this.format = 'srt',
    this.source = SubtitleSource.local,
    this.externalId,
    this.movieHash,
    this.delayMs = 0,
    this.isActive = false,
    required this.createdAtMs,
  });

  SavedSubtitle copyWith({
    int? id,
    String? mediaKey,
    String? localFilePath,
    String? fileName,
    String? languageCode,
    String? languageName,
    String? format,
    SubtitleSource? source,
    String? externalId,
    String? movieHash,
    int? delayMs,
    bool? isActive,
    int? createdAtMs,
  }) {
    return SavedSubtitle(
      id: id ?? this.id,
      mediaKey: mediaKey ?? this.mediaKey,
      localFilePath: localFilePath ?? this.localFilePath,
      fileName: fileName ?? this.fileName,
      languageCode: languageCode ?? this.languageCode,
      languageName: languageName ?? this.languageName,
      format: format ?? this.format,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      movieHash: movieHash ?? this.movieHash,
      delayMs: delayMs ?? this.delayMs,
      isActive: isActive ?? this.isActive,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'media_key': mediaKey,
      'local_file_path': localFilePath,
      'file_name': fileName,
      'language_code': languageCode,
      'language_name': languageName,
      'format': format,
      'source': source.id,
      'external_id': externalId,
      'movie_hash': movieHash,
      'delay_ms': delayMs,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAtMs,
    };
  }

  factory SavedSubtitle.fromMap(Map<String, Object?> map) {
    return SavedSubtitle(
      id: map['id'] as int?,
      mediaKey: map['media_key'] as String,
      localFilePath: map['local_file_path'] as String,
      fileName: map['file_name'] as String,
      languageCode: (map['language_code'] as String?) ?? 'und',
      languageName: (map['language_name'] as String?) ?? 'Unknown',
      format: (map['format'] as String?) ?? 'srt',
      source: SubtitleSource.fromId(map['source'] as String?),
      externalId: map['external_id'] as String?,
      movieHash: map['movie_hash'] as String?,
      delayMs: (map['delay_ms'] as int?) ?? 0,
      isActive: ((map['is_active'] as int?) ?? 0) == 1,
      createdAtMs: (map['created_at'] as int?) ?? 0,
    );
  }
}
