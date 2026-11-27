/// Formatting utilities for media timestamps, seek deltas, and file sizes.
abstract final class DurationFormatter {
  /// Formats a duration as `HH:MM:SS` if >= 1 hour, otherwise `MM:SS`.
  static String format(Duration duration) {
    final safeMs = duration.inMilliseconds < 0 ? 0 : duration.inMilliseconds;
    final totalSeconds = safeMs ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  /// Formats a signed second offset such as `+10s`, `-10s`, or `+0.3s`.
  static String formatSignedSeconds(Duration delta, {bool decimal = false}) {
    final ms = delta.inMilliseconds;
    final sign = ms >= 0 ? '+' : '-';
    final absMs = ms.abs();
    if (decimal) {
      return '$sign${(absMs / 1000.0).toStringAsFixed(1)}s';
    }
    final seconds = (absMs / 1000.0).round();
    return '$sign${seconds}s';
  }

  /// Formats byte sizes cleanly into B / KB / MB / GB.
  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final decimals = unitIndex <= 1 ? 0 : (value >= 100 ? 0 : 1);
    return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
  }
}
