import 'package:screen_brightness/screen_brightness.dart';
import 'package:volume_controller/volume_controller.dart';

/// Abstraction for hardware screen brightness and OS media volume controls.
abstract interface class DeviceControlService {
  Future<double> getBrightness();
  Future<void> setBrightness(double brightness);
  Future<void> resetBrightness();
  Future<double> getSystemVolume();
  Future<void> setSystemVolume(double volume);
}

/// Platform plugin implementation backed by `screen_brightness` and `volume_controller`.
class PluginDeviceControlService implements DeviceControlService {
  const PluginDeviceControlService();

  @override
  Future<double> getBrightness() async {
    try {
      final app = await ScreenBrightness.instance.application;
      if (app >= 0.0 && app <= 1.0) return app;
      final sys = await ScreenBrightness.instance.system;
      return sys.clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  @override
  Future<void> setBrightness(double brightness) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(
        brightness.clamp(0.0, 1.0),
      );
    } catch (_) {
      // Ignore missing platform channel in headless tests or unsupported hosts.
    }
  }

  @override
  Future<void> resetBrightness() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {
      // Ignore missing platform channel in headless tests or unsupported hosts.
    }
  }

  @override
  Future<double> getSystemVolume() async {
    try {
      final vol = await VolumeController.instance.getVolume();
      return vol.clamp(0.0, 1.0);
    } catch (_) {
      return 0.5;
    }
  }

  @override
  Future<void> setSystemVolume(double volume) async {
    try {
      VolumeController.instance.showSystemUI = false;
      await VolumeController.instance.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {
      // Ignore missing platform channel in headless tests or unsupported hosts.
    }
  }
}
