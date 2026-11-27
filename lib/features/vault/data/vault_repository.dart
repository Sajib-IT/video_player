import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/vault_dao.dart';
import 'package:video_player_app/data/local/models/vault_models.dart';
import 'package:video_player_app/features/library/data/media_file_operations.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';

typedef VaultDirectoryProvider = Future<Directory> Function();

/// Abstraction for device biometric authentication (Fingerprint / Face ID).
abstract interface class BiometricAuthGateway {
  Future<bool> isBiometricAvailable();
  Future<bool> authenticate(String reason);
}

class LocalAuthBiometricGateway implements BiometricAuthGateway {
  final LocalAuthentication _auth;

  LocalAuthBiometricGateway({LocalAuthentication? auth})
    : _auth = auth ?? LocalAuthentication();

  @override
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return canCheck || supported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
      );
    } catch (_) {
      return false;
    }
  }
}

/// Manages salted PIN credentials, biometrics, and hidden internal-storage files.
class VaultRepository {
  final VaultDao _vaultDao;
  final BiometricAuthGateway _biometricGateway;
  final MediaFileOperations _fileOps;
  final VaultDirectoryProvider _documentsDirProvider;

  VaultRepository({
    VaultDao? vaultDao,
    BiometricAuthGateway? biometricGateway,
    MediaFileOperations? fileOps,
    VaultDirectoryProvider? documentsDirProvider,
  }) : _vaultDao = vaultDao ?? VaultDao(),
       _biometricGateway = biometricGateway ?? LocalAuthBiometricGateway(),
       _fileOps = fileOps ?? const DeviceMediaFileOperations(),
       _documentsDirProvider =
           documentsDirProvider ?? getApplicationDocumentsDirectory;

  Future<bool> isPinConfigured() async => (await _vaultDao.getConfig()) != null;

  Future<VaultConfig?> getConfig() => _vaultDao.getConfig();

  Future<bool> isBiometricAvailable() =>
      _biometricGateway.isBiometricAvailable();

  Future<void> setPin(String pin, {bool biometricEnabled = true}) async {
    final normalized = pin.trim();
    if (normalized.length < 4) {
      throw const StoragePermissionException(
        'Vault PIN must be at least 4 digits.',
      );
    }
    final salt = _generateSaltHex();
    final hash = _hashPin(normalized, salt);
    await _vaultDao.saveConfig(
      VaultConfig(
        pinHash: hash,
        pinSalt: salt,
        biometricEnabled: biometricEnabled,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> verifyPin(String pin) async {
    final config = await _vaultDao.getConfig();
    if (config == null) return false;
    return _hashPin(pin.trim(), config.pinSalt) == config.pinHash;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final config = await _vaultDao.getConfig();
    if (config == null) return;
    await _vaultDao.saveConfig(
      VaultConfig(
        pinHash: config.pinHash,
        pinSalt: config.pinSalt,
        biometricEnabled: enabled,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<bool> authenticateWithBiometrics() async {
    final config = await _vaultDao.getConfig();
    if (config == null || !config.biometricEnabled) return false;
    if (!await isBiometricAvailable()) return false;
    return _biometricGateway.authenticate(
      'Unlock your CineVault Private Video Folder',
    );
  }

  Future<List<VaultVideoRecord>> getVaultVideos() => _vaultDao.getAllVideos();

  /// Moves [video] into hidden app-private storage with a `.nomedia` marker
  /// so system galleries cannot scan it.
  Future<VaultVideoRecord> moveVideoToVault(VideoItem video) async {
    if (video.filePath.contains('://')) {
      throw const StoragePermissionException(
        'Only direct local files can be moved into the private vault.',
      );
    }
    final sourceFile = File(video.filePath);
    if (!await sourceFile.exists()) {
      throw const SubtitleFileException('Source video file does not exist.');
    }

    final vaultDir = await _ensureVaultDirectory();
    final safeName = video.fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = p.join(vaultDir.path, '${stamp}_$safeName');

    final copied = await sourceFile.copy(destPath);
    final size = await copied.length();

    final record = await _vaultDao.insertVideo(
      VaultVideoRecord(
        vaultFilePath: destPath,
        originalFilePath: video.filePath,
        title: video.title,
        fileName: video.fileName,
        durationMs: video.effectiveDuration.inMilliseconds,
        sizeBytes: size,
        addedAtMs: stamp,
      ),
    );

    try {
      await _fileOps.deleteVideo(video);
    } catch (_) {
      // Keep vaulted copy even if OS declines deleting original MediaStore item.
    }
    return record;
  }

  /// Restores a vaulted video out of private storage into restored downloads
  /// (or its original path if writable) and removes it from the vault table.
  Future<String> restoreVideoFromVault(VaultVideoRecord record) async {
    final vaultFile = File(record.vaultFilePath);
    if (!await vaultFile.exists()) {
      if (record.id != null) {
        await _vaultDao.deleteVideoById(record.id!);
      }
      throw const SubtitleFileException('Vaulted file is missing on disk.');
    }

    String targetPath = record.originalFilePath;
    final originalDir = Directory(p.dirname(targetPath));
    try {
      if (!await originalDir.exists() || await File(targetPath).exists()) {
        final docs = await _documentsDirProvider();
        final restoredDir = Directory(p.join(docs.path, 'downloads'));
        if (!await restoredDir.exists()) {
          await restoredDir.create(recursive: true);
        }
        targetPath = p.join(
          restoredDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_${record.fileName}',
        );
      }
      await vaultFile.copy(targetPath);
    } catch (_) {
      final docs = await _documentsDirProvider();
      final restoredDir = Directory(p.join(docs.path, 'downloads'));
      if (!await restoredDir.exists()) {
        await restoredDir.create(recursive: true);
      }
      targetPath = p.join(
        restoredDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_${record.fileName}',
      );
      await vaultFile.copy(targetPath);
    }

    await vaultFile.delete();
    if (record.id != null) {
      await _vaultDao.deleteVideoById(record.id!);
    }
    return targetPath;
  }

  Future<void> deleteVaultVideo(VaultVideoRecord record) async {
    final vaultFile = File(record.vaultFilePath);
    if (await vaultFile.exists()) {
      await vaultFile.delete();
    }
    if (record.id != null) {
      await _vaultDao.deleteVideoById(record.id!);
    }
  }

  Future<Directory> _ensureVaultDirectory() async {
    final docsDir = await _documentsDirProvider();
    final vaultDir = Directory(p.join(docsDir.path, '.private_vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    final nomedia = File(p.join(vaultDir.path, '.nomedia'));
    if (!await nomedia.exists()) {
      await nomedia.writeAsString('', flush: true);
    }
    return vaultDir;
  }

  String _generateSaltHex() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt::$pin')).toString();
  }
}
