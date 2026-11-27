/// Base domain exception hierarchy for predictable error reporting across layers.
sealed class AppException implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message';
}

final class PlaybackException extends AppException {
  const PlaybackException(super.message, {super.cause, super.stackTrace});
}

final class LocalDatabaseException extends AppException {
  const LocalDatabaseException(super.message, {super.cause, super.stackTrace});
}

final class StoragePermissionException extends AppException {
  final bool isPermanentlyDenied;

  const StoragePermissionException(
    super.message, {
    this.isPermanentlyDenied = false,
    super.cause,
    super.stackTrace,
  });
}

final class SubtitleNetworkException extends AppException {
  final int? statusCode;

  const SubtitleNetworkException(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });
}

final class SubtitleFileException extends AppException {
  const SubtitleFileException(super.message, {super.cause, super.stackTrace});
}
