import 'dart:async';
import 'dart:io';

import 'package:cast/device.dart';
import 'package:cast/session.dart';
import 'package:cast/socket.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:video_player_app/features/cast/presentation/cast_controller.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';

class _FakeCastSession implements CastSession {
  @override
  final String sessionId = 'fake-cast-1';

  final StreamController<CastSessionState> _stateCtrl =
      StreamController<CastSessionState>.broadcast();
  final StreamController<Map<String, dynamic>> _msgCtrl =
      StreamController<Map<String, dynamic>>.broadcast();
  final List<(String, Map<String, dynamic>)> sentMessages =
      <(String, Map<String, dynamic>)>[];

  CastSessionState _state = CastSessionState.connecting;
  bool closed = false;

  void emitConnected() {
    _state = CastSessionState.connected;
    _stateCtrl.add(_state);
  }

  void emitPlayingMediaStatus(int mediaSessionId) {
    _msgCtrl.add(<String, dynamic>{
      'type': 'MEDIA_STATUS',
      'status': <Map<String, dynamic>>[
        <String, dynamic>{
          'mediaSessionId': mediaSessionId,
          'playerState': 'PLAYING',
        },
      ],
    });
  }

  @override
  CastSessionState get state => _state;

  @override
  Stream<CastSessionState> get stateStream => _stateCtrl.stream;

  @override
  Stream<Map<String, dynamic>> get messageStream => _msgCtrl.stream;

  @override
  CastSocket get socket => throw UnimplementedError();

  @override
  void sendMessage(String namespace, Map<String, dynamic> payload) {
    sentMessages.add((namespace, payload));
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> close() async {
    closed = true;
    _state = CastSessionState.closed;
    await _stateCtrl.close();
    await _msgCtrl.close();
  }
}

class _FakeCastGateway implements CastGateway {
  final List<CastDevice> discovered;
  final _FakeCastSession session = _FakeCastSession();
  bool closeCalled = false;

  _FakeCastGateway(this.discovered);

  @override
  Future<List<CastDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async => discovered;

  @override
  Future<CastSession> connectDevice(CastDevice device) async {
    scheduleMicrotask(() => session.emitConnected());
    return session;
  }

  @override
  Future<void> closeSession(CastSession session) async {
    closeCalled = true;
    await session.close();
  }
}

void main() {
  test('CastController discovers devices, streams local HTTP file, and controls TV', () async {
    final tempDir = await Directory.systemTemp.createTemp('cast_ctrl_test');
    addTearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });
    final mediaFile = File(p.join(tempDir.path, 'tv_sample.mp4'))
      ..writeAsBytesSync(<int>[0, 1, 2, 3, 4]);

    const tv = CastDevice(
      serviceName: 'LivingRoom._googlecast._tcp',
      name: 'Living Room TV',
      host: '192.168.1.50',
      port: 8009,
    );
    final gateway = _FakeCastGateway(<CastDevice>[tv]);
    final controller = CastController(gateway: gateway);

    await controller.scanDevices();
    expect(controller.devices, <CastDevice>[tv]);

    final ok = await controller.castMedia(
      device: tv,
      media: MediaPlaybackRequest.fromFilePath(mediaFile.path),
      startPosition: const Duration(seconds: 42),
    );
    expect(ok, isTrue);
    expect(controller.isConnected, isTrue);

    final loadMsg = gateway.session.sentMessages
        .where((m) => m.$2['type'] == 'LOAD')
        .first;
    expect(loadMsg.$2['currentTime'], 42);
    expect(
      (loadMsg.$2['media'] as Map)['contentId'].toString(),
      startsWith('http://'),
    );

    gateway.session.emitPlayingMediaStatus(77);
    await Future<void>.delayed(Duration.zero);

    controller.togglePlayPause();
    controller.seekTo(const Duration(seconds: 90));
    expect(
      gateway.session.sentMessages.any(
        (m) => m.$2['type'] == 'PAUSE' && m.$2['mediaSessionId'] == 77,
      ),
      isTrue,
    );
    expect(
      gateway.session.sentMessages.any(
        (m) => m.$2['type'] == 'SEEK' && m.$2['currentTime'] == 90,
      ),
      isTrue,
    );

    await controller.disconnect();
    expect(gateway.closeCalled, isTrue);
    expect(controller.isConnected, isFalse);
    controller.dispose();
  });
}
