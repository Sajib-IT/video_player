import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_app/core/errors/app_exception.dart';
import 'package:video_player_app/data/local/dao/vault_dao.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/features/library/domain/video_item.dart';
import 'package:video_player_app/features/vault/data/vault_repository.dart';

class _FakeBiometricGateway implements BiometricAuthGateway {
  @override
  Future<bool> authenticate(String reason) async => true;

  @override
  Future<bool> isBiometricAvailable() async => true;
}

void main() {
  sqfliteFfiInit();

  late DatabaseHelper dbHelper;
  late Directory tempDocsDir;
  late Directory sourceDir;
  late VaultRepository repository;

  setUp(() async {
    dbHelper = DatabaseHelper.custom(
      databaseFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await dbHelper.database;
    tempDocsDir = await Directory.systemTemp.createTemp('vault_docs_test');
    sourceDir = await Directory.systemTemp.createTemp('vault_src_test');
    repository = VaultRepository(
      vaultDao: VaultDao(dbHelper: dbHelper),
      biometricGateway: _FakeBiometricGateway(),
      documentsDirProvider: () async => tempDocsDir,
    );
  });

  tearDown(() async {
    await dbHelper.close();
    if (await tempDocsDir.exists()) await tempDocsDir.delete(recursive: true);
    if (await sourceDir.exists()) await sourceDir.delete(recursive: true);
  });

  test('sets salted PIN, rejects wrong PIN, and hides/restores video', () async {
    await expectLater(
      repository.setPin('123'),
      throwsA(isA<StoragePermissionException>()),
    );

    await repository.setPin('4321');
    expect(await repository.verifyPin('4321'), isTrue);
    expect(await repository.verifyPin('0000'), isFalse);

    final srcFile = File(p.join(sourceDir.path, 'private_clip.mkv'))
      ..writeAsBytesSync(<int>[1, 2, 3, 4, 5, 6]);
    final item = VideoItem(
      mediaKey: srcFile.path,
      filePath: srcFile.path,
      fileName: 'private_clip.mkv',
      title: 'Private Clip',
      folderPath: sourceDir.path,
      folderName: 'src',
      duration: const Duration(seconds: 30),
      sizeBytes: 6,
      modifiedAt: DateTime(2026, 3, 1),
    );

    final moved = await repository.moveVideoToVault(item);
    expect(await srcFile.exists(), isFalse);
    expect(await File(moved.vaultFilePath).exists(), isTrue);
    expect(
      await File(p.join(tempDocsDir.path, '.private_vault', '.nomedia')).exists(),
      isTrue,
    );

    final restoredPath = await repository.restoreVideoFromVault(moved);
    expect(restoredPath, srcFile.path);
    expect(await File(restoredPath).exists(), isTrue);
    expect(await File(moved.vaultFilePath).exists(), isFalse);
    expect(await repository.getVaultVideos(), isEmpty);
  });
}
