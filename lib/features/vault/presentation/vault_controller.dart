import 'package:flutter/foundation.dart';
import 'package:video_player_app/data/local/models/vault_models.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/vault/data/vault_repository.dart';

/// State controller for Private Video Vault PIN setup, biometric unlock, and files.
class VaultController extends ChangeNotifier {
  final VaultRepository _repository;

  VaultController({VaultRepository? repository})
    : _repository = repository ?? VaultRepository();

  bool _isLoading = true;
  bool _isPinConfigured = false;
  bool _isUnlocked = false;
  bool _biometricAvailable = false;
  bool _biometricEnabled = true;
  String? _errorMessage;
  List<VaultVideoRecord> _videos = const <VaultVideoRecord>[];

  bool get isLoading => _isLoading;
  bool get isPinConfigured => _isPinConfigured;
  bool get isUnlocked => _isUnlocked;
  bool get biometricAvailable => _biometricAvailable;
  bool get biometricEnabled => _biometricEnabled;
  String? get errorMessage => _errorMessage;
  List<VaultVideoRecord> get videos => _videos;

  Future<void> initialize() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final config = await _repository.getConfig();
      _isPinConfigured = config != null;
      _biometricEnabled = config?.biometricEnabled ?? true;
      _biometricAvailable = await _repository.isBiometricAvailable();
      if (_isUnlocked) {
        _videos = await _repository.getVaultVideos();
      }
    } catch (error) {
      _errorMessage = '$error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setupPin(String pin) async {
    _errorMessage = null;
    try {
      await _repository.setPin(pin, biometricEnabled: _biometricAvailable);
      _isPinConfigured = true;
      _isUnlocked = true;
      _biometricEnabled = _biometricAvailable;
      _videos = await _repository.getVaultVideos();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = '$error';
      notifyListeners();
      return false;
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    _errorMessage = null;
    final ok = await _repository.verifyPin(pin);
    if (!ok) {
      _errorMessage = 'Incorrect Vault PIN. Try again.';
      notifyListeners();
      return false;
    }
    _isUnlocked = true;
    _videos = await _repository.getVaultVideos();
    notifyListeners();
    return true;
  }

  Future<bool> unlockWithBiometrics() async {
    _errorMessage = null;
    final ok = await _repository.authenticateWithBiometrics();
    if (!ok) {
      _errorMessage = 'Biometric unlock was cancelled or failed.';
      notifyListeners();
      return false;
    }
    _isUnlocked = true;
    _videos = await _repository.getVaultVideos();
    notifyListeners();
    return true;
  }

  void lockVault() {
    if (!_isUnlocked) return;
    _isUnlocked = false;
    _videos = const <VaultVideoRecord>[];
    _errorMessage = null;
    notifyListeners();
  }

  Future<VaultVideoRecord> moveVideoToVault(VideoItem video) async {
    final record = await _repository.moveVideoToVault(video);
    if (_isUnlocked) {
      _videos = await _repository.getVaultVideos();
      notifyListeners();
    }
    return record;
  }

  Future<String> restoreVideo(VaultVideoRecord record) async {
    final restoredPath = await _repository.restoreVideoFromVault(record);
    _videos = await _repository.getVaultVideos();
    notifyListeners();
    return restoredPath;
  }

  Future<void> deleteVideo(VaultVideoRecord record) async {
    await _repository.deleteVaultVideo(record);
    _videos = await _repository.getVaultVideos();
    notifyListeners();
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    _biometricEnabled = enabled;
    await _repository.setBiometricEnabled(enabled);
    notifyListeners();
  }
}
