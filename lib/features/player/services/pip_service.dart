import 'dart:async';

import 'package:flutter/services.dart';

/// Abstraction for native Android Picture-in-Picture (PiP) mode control.
abstract interface class PipService {
  Stream<bool> get isInPipModeStream;
  Future<bool> isPipSupported();
  Future<bool> enterPipMode({int width = 16, int height = 9});
}

/// MethodChannel / EventChannel bridge to Android `MainActivity` PiP APIs.
class MethodChannelPipService implements PipService {
  static const MethodChannel _methodChannel = MethodChannel(
    'com.cinevault.player/pip',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.cinevault.player/pip_events',
  );

  const MethodChannelPipService();

  @override
  Stream<bool> get isInPipModeStream {
    try {
      return _eventChannel.receiveBroadcastStream().map(
        (event) => event == true,
      );
    } catch (_) {
      return const Stream<bool>.empty();
    }
  }

  @override
  Future<bool> isPipSupported() async {
    try {
      return await _methodChannel.invokeMethod<bool>('isPipSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> enterPipMode({int width = 16, int height = 9}) async {
    try {
      return await _methodChannel.invokeMethod<bool>(
            'enterPipMode',
            <String, int>{'width': width, 'height': height},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
