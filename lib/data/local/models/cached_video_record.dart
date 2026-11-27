/// Offline SQLite cache record of discovered local video files for fast startup.
class CachedVideoRecord {
  final String mediaKey;
  final String filePath;
  final String fileName;
  final String folderPath;
  final String folderName;
  final int durationMs;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int modifiedAtMs;
  final int scannedAtMs;

  const CachedVideoRecord({
    required this.mediaKey,
    required this.filePath,
    required this.fileName,
    required this.folderPath,
    required this.folderName,
    required this.durationMs,
    required this.sizeBytes,
    this.width,
    this.height,
    required this.modifiedAtMs,
    required this.scannedAtMs,
  });

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'media_key': mediaKey,
      'file_path': filePath,
      'file_name': fileName,
      'folder_path': folderPath,
      'folder_name': folderName,
      'duration_ms': durationMs,
      'size_bytes': sizeBytes,
      'width': width,
      'height': height,
      'modified_at': modifiedAtMs,
      'scanned_at': scannedAtMs,
    };
  }

  factory CachedVideoRecord.fromMap(Map<String, Object?> map) {
    return CachedVideoRecord(
      mediaKey: map['media_key'] as String,
      filePath: map['file_path'] as String,
      fileName: map['file_name'] as String,
      folderPath: map['folder_path'] as String,
      folderName: map['folder_name'] as String,
      durationMs: (map['duration_ms'] as int?) ?? 0,
      sizeBytes: (map['size_bytes'] as int?) ?? 0,
      width: map['width'] as int?,
      height: map['height'] as int?,
      modifiedAtMs: (map['modified_at'] as int?) ?? 0,
      scannedAtMs: (map['scanned_at'] as int?) ?? 0,
    );
  }
}
