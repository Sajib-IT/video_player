import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:photo_manager/photo_manager.dart';
import 'package:video_player_app/features/library/domain/library_permission_status.dart';

/// Abstraction for checking and requesting device media storage permissions.
abstract interface class MediaPermissionService {
  Future<LibraryPermissionStatus> checkStatus();
  Future<LibraryPermissionStatus> requestPermission();
  Future<void> openAppSettings();
  Future<void> presentLimitedSelection();
}

/// Platform implementation bridging `photo_manager` and `permission_handler`.
class DeviceMediaPermissionService implements MediaPermissionService {
  const DeviceMediaPermissionService();

  static final PermissionRequestOption _requestOption = PermissionRequestOption(
    iosAccessLevel: IosAccessLevel.readWrite,
    androidPermission: AndroidPermission(
      type: RequestType.video + RequestType.audio,
      mediaLocation: false,
    ),
  );

  @override
  Future<LibraryPermissionStatus> checkStatus() async {
    if (!_isMobilePlatform) {
      return LibraryPermissionStatus.granted;
    }

    try {
      final state = await PhotoManager.getPermissionState(
        requestOption: _requestOption,
      );
      return _mapPhotoManagerState(state);
    } catch (_) {
      return LibraryPermissionStatus.denied;
    }
  }

  @override
  Future<LibraryPermissionStatus> requestPermission() async {
    if (!_isMobilePlatform) {
      return LibraryPermissionStatus.granted;
    }

    try {
      final pmState = await PhotoManager.requestPermissionExtend(
        requestOption: _requestOption,
      );
      if (pmState.isAuth) {
        return LibraryPermissionStatus.granted;
      }
      if (pmState.isLimited) {
        return LibraryPermissionStatus.limited;
      }

      if (Platform.isAndroid) {
        final videosStatus = await ph.Permission.videos.status;
        if (videosStatus.isGranted) return LibraryPermissionStatus.granted;
        if (videosStatus.isPermanentlyDenied) {
          return LibraryPermissionStatus.permanentlyDenied;
        }
        final storageStatus = await ph.Permission.storage.status;
        if (storageStatus.isGranted) return LibraryPermissionStatus.granted;
        if (storageStatus.isPermanentlyDenied) {
          return LibraryPermissionStatus.permanentlyDenied;
        }
      }

      return LibraryPermissionStatus.denied;
    } catch (_) {
      return LibraryPermissionStatus.denied;
    }
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await ph.openAppSettings();
    } catch (_) {
      await PhotoManager.openSetting();
    }
  }

  @override
  Future<void> presentLimitedSelection() async {
    try {
      await PhotoManager.presentLimited(type: RequestType.video);
    } catch (_) {
      // Ignore on unsupported OS versions.
    }
  }

  LibraryPermissionStatus _mapPhotoManagerState(PermissionState state) {
    switch (state) {
      case PermissionState.authorized:
        return LibraryPermissionStatus.granted;
      case PermissionState.limited:
        return LibraryPermissionStatus.limited;
      case PermissionState.restricted:
        return LibraryPermissionStatus.permanentlyDenied;
      case PermissionState.denied:
      case PermissionState.notDetermined:
        return LibraryPermissionStatus.denied;
    }
  }

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);
}
