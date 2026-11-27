import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/features/cast/data/local_media_http_server.dart';

void main() {
  test('serves full file (200), byte ranges (206), and blocks wrong tokens (403)', () async {
    final dir = await Directory.systemTemp.createTemp('cast_http_test');
    addTearDown(() => dir.delete(recursive: true));
    final file = File(p.join(dir.path, 'stream_test.mp4'))
      ..writeAsBytesSync(utf8.encode('0123456789ABCDEF'));

    final server = LocalMediaHttpServer();
    addTearDown(() => server.stop());

    final url = await server.startServingFile(file.path);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));

    // Full fetch
    final reqFull = await client.getUrl(url);
    final resFull = await reqFull.close();
    final fullBody = await utf8.decodeStream(resFull);
    expect(resFull.statusCode, HttpStatus.ok);
    expect(resFull.headers.value(HttpHeaders.acceptRangesHeader), 'bytes');
    expect(fullBody, '0123456789ABCDEF');

    // Byte range request
    final reqRange = await client.getUrl(url);
    reqRange.headers.set(HttpHeaders.rangeHeader, 'bytes=4-9');
    final resRange = await reqRange.close();
    final partialBody = await utf8.decodeStream(resRange);
    expect(resRange.statusCode, HttpStatus.partialContent);
    expect(resRange.headers.value(HttpHeaders.contentRangeHeader), 'bytes 4-9/16');
    expect(partialBody, '456789');

    // Unauthorized path
    final badUrl = url.replace(path: '/mediawrong.mp4');
    final reqBad = await client.getUrl(badUrl);
    final resBad = await reqBad.close();
    await resBad.drain<void>();
    expect(resBad.statusCode, HttpStatus.forbidden);
  });
}
