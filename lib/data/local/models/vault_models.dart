/// Stored PIN hash, salt, and biometric preference for the Private Video Vault.
class VaultConfig {
  final int id;
  final String pinHash;
  final String pinSalt;
  final bool biometricEnabled;
  final int updatedAtMs;

  const VaultConfig({
    this.id = 1,
    required this.pinHash,
    required this.pinSalt,
    this.biometricEnabled = true,
    required this.updatedAtMs,
  });

  Map<String, Object?> toMap() => <String, Object?>{
    'id': id,
    'pin_hash': pinHash,
    'pin_salt': pinSalt,
    'biometric_enabled': biometricEnabled ? 1 : 0,
    'updated_at': updatedAtMs,
  };

  factory VaultConfig.fromMap(Map<String, Object?> map) {
    return VaultConfig(
      id: (map['id'] as int?) ?? 1,
      pinHash: map['pin_hash'] as String,
      pinSalt: map['pin_salt'] as String,
      biometricEnabled: ((map['biometric_enabled'] as int?) ?? 1) == 1,
      updatedAtMs: (map['updated_at'] as int?) ?? 0,
    );
  }
}

/// Metadata for a hidden video stored inside the private app-internal vault.
class VaultVideoRecord {
  final int? id;
  final String vaultFilePath;
  final String originalFilePath;
  final String title;
  final String fileName;
  final int durationMs;
  final int sizeBytes;
  final int addedAtMs;

  const VaultVideoRecord({
    this.id,
    required this.vaultFilePath,
    required this.originalFilePath,
    required this.title,
    required this.fileName,
    this.durationMs = 0,
    this.sizeBytes = 0,
    required this.addedAtMs,
  });

  Duration get duration => Duration(milliseconds: durationMs);

  VaultVideoRecord copyWith({int? id}) {
    return VaultVideoRecord(
      id: id ?? this.id,
      vaultFilePath: vaultFilePath,
      originalFilePath: originalFilePath,
      title: title,
      fileName: fileName,
      durationMs: durationMs,
      sizeBytes: sizeBytes,
      addedAtMs: addedAtMs,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
    if (id != null) 'id': id,
    'vault_file_path': vaultFilePath,
    'original_file_path': originalFilePath,
    'title': title,
    'file_name': fileName,
    'duration_ms': durationMs,
    'size_bytes': sizeBytes,
    'added_at': addedAtMs,
  };

  factory VaultVideoRecord.fromMap(Map<String, Object?> map) {
    return VaultVideoRecord(
      id: map['id'] as int?,
      vaultFilePath: map['vault_file_path'] as String,
      originalFilePath: map['original_file_path'] as String,
      title: map['title'] as String,
      fileName: map['file_name'] as String,
      durationMs: (map['duration_ms'] as int?) ?? 0,
      sizeBytes: (map['size_bytes'] as int?) ?? 0,
      addedAtMs: (map['added_at'] as int?) ?? 0,
    );
  }
}
