import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:video_player_app/core/constants/media_formats.dart';

/// Lightweight local HTTP/1.1 byte-range server (`206 Partial Content`) so
/// Chromecast / Android TV receivers can stream and seek local phone files.
class LocalMediaHttpServer {
  HttpServer? _server;
  String? _servedFilePath;
  String? _token;
  String? _hostIp;

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  Future<Uri> startServingFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('Cannot serve missing media file', filePath);
    }

    await stop();

    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server = server;
    _servedFilePath = filePath;
    _token = _randomToken();
    _hostIp = await _resolveLanIpv4();

    server.listen(_handleRequest);

    final ext = MediaFormats.extensionOf(filePath);
    final suffix = ext.isNotEmpty ? '.$ext' : '';
    return Uri.parse('http://$_hostIp:${server.port}/media$_token$suffix');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    try {
      final expectedSuffix = _token ?? '';
      if (expectedSuffix.isEmpty ||
          !request.uri.path.startsWith('/media$expectedSuffix')) {
        response.statusCode = HttpStatus.forbidden;
        await response.close();
        return;
      }

      final path = _servedFilePath;
      if (path == null) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }

      final fileLength = await file.length();
      final mimeType = MediaFormats.mimeTypeForMedia(path);

      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.set(HttpHeaders.contentTypeHeader, mimeType);
      response.headers.set('Access-Control-Allow-Origin', '*');

      final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final spec = rangeHeader.substring(6).split(',').first.trim();
        final parts = spec.split('-');
        final start = parts[0].isNotEmpty ? int.tryParse(parts[0]) : null;
        final end = parts.length > 1 && parts[1].isNotEmpty
            ? int.tryParse(parts[1])
            : null;

        final resolvedStart = start ?? 0;
        final resolvedEnd = (end ?? (fileLength - 1)).clamp(0, fileLength - 1);

        if (resolvedStart < 0 ||
            resolvedStart >= fileLength ||
            resolvedEnd < resolvedStart) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes */$fileLength',
          );
          await response.close();
          return;
        }

        final chunkLength = resolvedEnd - resolvedStart + 1;
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $resolvedStart-$resolvedEnd/$fileLength',
        );
        response.headers.set(HttpHeaders.contentLengthHeader, chunkLength);

        if (request.method.toUpperCase() != 'HEAD') {
          await response.addStream(
            file.openRead(resolvedStart, resolvedEnd + 1),
          );
        }
        await response.close();
        return;
      }

      response.statusCode = HttpStatus.ok;
      response.headers.set(HttpHeaders.contentLengthHeader, fileLength);
      if (request.method.toUpperCase() != 'HEAD') {
        await response.addStream(file.openRead());
      }
      await response.close();
    } catch (_) {
      try {
        await response.close();
      } catch (_) {}
    }
  }

  Future<String> _resolveLanIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return InternetAddress.loopbackIPv4.address;
  }

  String _randomToken() {
    final rng = Random.secure();
    return List<int>.generate(
      12,
      (_) => rng.nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    _servedFilePath = null;
    _token = null;
    if (server != null) {
      await server.close(force: true);
    }
  }
}
