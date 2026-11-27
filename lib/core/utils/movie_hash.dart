import 'dart:io';
import 'dart:typed_data';

/// Computes the standard OpenSubtitles 64-bit moviehash (16-char lowercase hex).
///
/// Specification:
/// `hash = fileSize + sum(little-endian uint64 words of first 64 KiB) + sum(little-endian uint64 words of last 64 KiB)` mod 2^64.
/// Returns `null` if the file does not exist or is smaller than 64 KiB.
abstract final class MovieHash {
  static const int _chunkSize = 64 * 1024;
  static final BigInt _mask64 = (BigInt.one << 64) - BigInt.one;

  static Future<String?> compute(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return null;

    final fileSize = await file.length();
    if (fileSize < _chunkSize) return null;

    final raf = await file.open(mode: FileMode.read);
    try {
      var hash = BigInt.from(fileSize);

      final headBytes = await raf.read(_chunkSize);
      hash = (hash + _sumLittleEndian64(headBytes)) & _mask64;

      await raf.setPosition(fileSize - _chunkSize);
      final tailBytes = await raf.read(_chunkSize);
      hash = (hash + _sumLittleEndian64(tailBytes)) & _mask64;

      return hash.toRadixString(16).padLeft(16, '0');
    } finally {
      await raf.close();
    }
  }

  static BigInt _sumLittleEndian64(Uint8List bytes) {
    final byteData = ByteData.sublistView(bytes);
    final wordCount = bytes.lengthInBytes ~/ 8;
    var sum = BigInt.zero;

    for (var i = 0; i < wordCount; i++) {
      final offset = i * 8;
      final low = byteData.getUint32(offset, Endian.little);
      final high = byteData.getUint32(offset + 4, Endian.little);
      final word = (BigInt.from(high) << 32) | BigInt.from(low);
      sum = (sum + word) & _mask64;
    }
    return sum;
  }
}
