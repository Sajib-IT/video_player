import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:cast/device.dart';
import 'package:cast/session.dart';
import 'package:cast/session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/features/cast/data/local_media_http_server.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';

/// Abstraction for Chromecast mDNS discovery & CASTV2 session opening.
abstract interface class CastGateway {
  Future<List<CastDevice>> discoverDevices({Duration timeout});
  Future<CastSession> connectDevice(CastDevice device);
  Future<void> closeSession(CastSession session);
}

class PackageCastGateway implements CastGateway {
  static const String _castServiceType = '_googlecast._tcp';

  const PackageCastGateway();

  @override
  Future<List<CastDevice>> discoverDevices({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final discoveredById = <String, CastDevice>{};
    final discovery = BonsoirDiscovery(type: _castServiceType);
    await discovery.initialize();

    final sub = discovery.eventStream?.listen((event) {
      if (event is BonsoirDiscoveryServiceFoundEvent) {
        event.service.resolve(discovery.serviceResolver);
      } else if (event is BonsoirDiscoveryServiceResolvedEvent ||
          event is BonsoirDiscoveryServiceUpdatedEvent) {
        final service = event.service;
        if (service == null) return;
        final host = service.hostAddresses.isNotEmpty
            ? service.hostAddresses.first
            : service.hostname;
        if (host == null || host.isEmpty || service.port <= 0) {
          return;
        }

        final friendlyName = <String?>[
          service.attributes['md'],
          service.attributes['fn'],
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' - ');

        discoveredById[service.name] = CastDevice(
          serviceName: service.name,
          name: friendlyName.isNotEmpty ? friendlyName : service.name,
          port: service.port,
          host: host,
          extras: service.attributes,
        );
      }
    });

    try {
      await discovery.start();
      await Future<void>.delayed(timeout);
    } finally {
      await sub?.cancel();
      await discovery.stop();
    }

    return discoveredById.values.toList(growable: false);
  }

  @override
  Future<CastSession> connectDevice(CastDevice device) {
    return CastSessionManager().startSession(device);
  }

  @override
  Future<void> closeSession(CastSession session) {
    return CastSessionManager().endSession(session.sessionId);
  }
}

/// Manages Chromecast discovery, local HTTP range streaming, and remote transport.
class CastController extends ChangeNotifier {
  static const String _defaultMediaReceiverAppId = 'CC1AD845';

  final CastGateway _gateway;
  final LocalMediaHttpServer _httpServer;

  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isRemotePlaying = false;
  CastDevice? _connectedDevice;
  CastSession? _session;
  int? _mediaSessionId;
  int _requestId = 1;
  String? _errorMessage;
  List<CastDevice> _devices = const <CastDevice>[];
  StreamSubscription<CastSessionState>? _stateSub;
  StreamSubscription<Map<String, dynamic>>? _msgSub;
  bool _isDisposed = false;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  CastController({
    CastGateway? gateway,
    LocalMediaHttpServer? httpServer,
  }) : _gateway = gateway ?? const PackageCastGateway(),
       _httpServer = httpServer ?? LocalMediaHttpServer();

  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isRemotePlaying => _isRemotePlaying;
  CastDevice? get connectedDevice => _connectedDevice;
  String? get errorMessage => _errorMessage;
  List<CastDevice> get devices => _devices;

  Future<void> scanDevices() async {
    if (_isScanning || _isDisposed) return;
    _isScanning = true;
    _errorMessage = null;
    _safeNotify();

    try {
      _devices = await _gateway.discoverDevices(
        timeout: const Duration(seconds: 5),
      );
    } catch (error) {
      _errorMessage = 'Failed to scan Chromecast devices: $error';
    } finally {
      _isScanning = false;
      _safeNotify();
    }
  }

  Future<bool> castMedia({
    required CastDevice device,
    required MediaPlaybackRequest media,
    Duration startPosition = Duration.zero,
  }) async {
    if (_isConnecting || _isDisposed) return false;
    await disconnect();

    _isConnecting = true;
    _errorMessage = null;
    _safeNotify();

    try {
      final String streamUrl;
      if (media.uriOrPath.startsWith('http://') ||
          media.uriOrPath.startsWith('https://')) {
        streamUrl = media.uriOrPath;
      } else if (media.uriOrPath.contains('://')) {
        throw StateError(
          'Only direct local files or HTTP URLs can be cast to Chromecast.',
        );
      } else {
        final uri = await _httpServer.startServingFile(media.uriOrPath);
        streamUrl = uri.toString();
      }

      final session = await _gateway.connectDevice(device);
      _session = session;
      _connectedDevice = device;

      final connectedCompleter = Completer<void>();
      if (session.state == CastSessionState.connected) {
        connectedCompleter.complete();
      }
      _stateSub = session.stateStream.listen((state) {
        if (state == CastSessionState.connected &&
            !connectedCompleter.isCompleted) {
          connectedCompleter.complete();
        } else if (state == CastSessionState.closed) {
          _handleSessionClosed();
        }
      });

      _msgSub = session.messageStream.listen((payload) {
        if (payload['type'] == 'MEDIA_STATUS') {
          final statuses = payload['status'];
          if (statuses is List && statuses.isNotEmpty) {
            final first = statuses.first;
            if (first is Map) {
              _mediaSessionId = (first['mediaSessionId'] as num?)?.toInt();
              final playerState = first['playerState']?.toString();
              _isRemotePlaying =
                  playerState == 'PLAYING' || playerState == 'BUFFERING';
              _safeNotify();
            }
          }
        }
      });

      session.sendMessage(CastSession.kNamespaceReceiver, <String, dynamic>{
        'type': 'LAUNCH',
        'appId': _defaultMediaReceiverAppId,
      });

      await connectedCompleter.future.timeout(const Duration(seconds: 12));

      session.sendMessage(CastSession.kNamespaceMedia, <String, dynamic>{
        'type': 'LOAD',
        'requestId': _requestId++,
        'autoplay': true,
        'currentTime': startPosition.inSeconds,
        'media': <String, dynamic>{
          'contentId': streamUrl,
          'streamType': 'BUFFERED',
          'contentType': MediaFormats.mimeTypeForMedia(media.uriOrPath),
          'metadata': <String, dynamic>{
            'metadataType': 0,
            'title': media.title,
          },
        },
      });

      _isConnected = true;
      _isRemotePlaying = true;
      return true;
    } catch (error) {
      _errorMessage = 'Chromecast failed: $error';
      await disconnect();
      return false;
    } finally {
      _isConnecting = false;
      _safeNotify();
    }
  }

  void togglePlayPause() {
    final session = _session;
    final mediaId = _mediaSessionId;
    if (session == null || mediaId == null) return;
    session.sendMessage(CastSession.kNamespaceMedia, <String, dynamic>{
      'type': _isRemotePlaying ? 'PAUSE' : 'PLAY',
      'requestId': _requestId++,
      'mediaSessionId': mediaId,
    });
  }

  void seekTo(Duration position) {
    final session = _session;
    final mediaId = _mediaSessionId;
    if (session == null || mediaId == null) return;
    session.sendMessage(CastSession.kNamespaceMedia, <String, dynamic>{
      'type': 'SEEK',
      'requestId': _requestId++,
      'mediaSessionId': mediaId,
      'currentTime': position.inSeconds,
    });
  }

  Future<void> disconnect() async {
    await _stateSub?.cancel();
    await _msgSub?.cancel();
    _stateSub = null;
    _msgSub = null;

    final session = _session;
    _session = null;
    if (session != null) {
      try {
        await _gateway.closeSession(session);
      } catch (_) {}
    }

    await _httpServer.stop();
    _connectedDevice = null;
    _mediaSessionId = null;
    _isConnected = false;
    _isRemotePlaying = false;
    _safeNotify();
  }

  void _handleSessionClosed() {
    _connectedDevice = null;
    _mediaSessionId = null;
    _isConnected = false;
    _isRemotePlaying = false;
    unawaited(_httpServer.stop());
    _safeNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    unawaited(disconnect());
    super.dispose();
  }
}
