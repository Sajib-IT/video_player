/// Download lifecycle state for web video downloads.
enum VideoDownloadStatus {
  pending('pending'),
  downloading('downloading'),
  completed('completed'),
  failed('failed'),
  cancelled('cancelled');

  final String id;

  const VideoDownloadStatus(this.id);

  static VideoDownloadStatus fromId(String? raw) {
    for (final value in VideoDownloadStatus.values) {
      if (value.id == raw) return value;
    }
    return VideoDownloadStatus.pending;
  }
}

/// Persisted record for a downloaded web video.
class VideoDownloadRecord {
  final int? id;
  final String url;
  final String fileName;
  final String savePath;
  final int totalBytes;
  final int receivedBytes;
  final VideoDownloadStatus status;
  final String? errorMessage;
  final int createdAtMs;
  final int updatedAtMs;

  const VideoDownloadRecord({
    this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.totalBytes = 0,
    this.receivedBytes = 0,
    this.status = VideoDownloadStatus.pending,
    this.errorMessage,
    required this.createdAtMs,
    required this.updatedAtMs,
  });

  double get progress {
    if (status == VideoDownloadStatus.completed) return 1.0;
    if (totalBytes <= 0) return 0.0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  VideoDownloadRecord copyWith({
    int? id,
    String? url,
    String? fileName,
    String? savePath,
    int? totalBytes,
    int? receivedBytes,
    VideoDownloadStatus? status,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? updatedAtMs,
  }) {
    return VideoDownloadRecord(
      id: id ?? this.id,
      url: url ?? this.url,
      fileName: fileName ?? this.fileName,
      savePath: savePath ?? this.savePath,
      totalBytes: totalBytes ?? this.totalBytes,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'url': url,
    'file_name': fileName,
    'save_path': savePath,
    'total_bytes': totalBytes,
    'received_bytes': receivedBytes,
    'status': status.id,
    'error_message': errorMessage,
    'created_at': createdAtMs,
    'updated_at': updatedAtMs,
  };

  factory VideoDownloadRecord.fromMap(Map<String, Object?> map) {
    return VideoDownloadRecord(
      id: map['id'] as int?,
      url: map['url'] as String,
      fileName: map['file_name'] as String,
      savePath: map['save_path'] as String,
      totalBytes: (map['total_bytes'] as int?) ?? 0,
      receivedBytes: (map['received_bytes'] as int?) ?? 0,
      status: VideoDownloadStatus.fromId(map['status'] as String?),
      errorMessage: map['error_message'] as String?,
      createdAtMs: (map['created_at'] as int?) ?? 0,
      updatedAtMs: (map['updated_at'] as int?) ?? 0,
    );
  }
}
