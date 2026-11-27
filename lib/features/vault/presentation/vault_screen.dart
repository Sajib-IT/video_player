import 'package:flutter/material.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/data/local/models/vault_models.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/presentation/player_screen.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/vault/presentation/vault_controller.dart';

/// Private Video Vault UI embedded as a Library tab with PIN & biometric lock.
class VaultTabView extends StatefulWidget {
  final VaultController controller;
  final PlayerService playerService;
  final VoidCallback onLibraryChanged;

  const VaultTabView({
    super.key,
    required this.controller,
    required this.playerService,
    required this.onLibraryChanged,
  });

  @override
  State<VaultTabView> createState() => _VaultTabViewState();
}

class _VaultTabViewState extends State<VaultTabView> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.controller.initialize();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _playVaultVideo(VaultVideoRecord record) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PlayerScreen(
          playerService: widget.playerService,
          request: MediaPlaybackRequest.fromFilePath(
            record.vaultFilePath,
            title: record.title,
            fileSizeBytes: record.sizeBytes,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        if (ctrl.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!ctrl.isPinConfigured) {
          return _buildPinSetupView(ctrl);
        }

        if (!ctrl.isUnlocked) {
          return _buildUnlockView(ctrl);
        }

        return _buildUnlockedVaultList(ctrl);
      },
    );
  }

  Widget _buildPinSetupView(VaultController ctrl) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.enhanced_encryption_rounded,
                size: 56,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 14),
              Text(
                'Set Up Private Video Vault',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Hidden videos are moved out of public folders with a .nomedia shield and protected by your PIN & biometrics.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Create Vault PIN (4–8 digits)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _confirmPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Confirm Vault PIN',
                  border: OutlineInputBorder(),
                ),
              ),
              if (ctrl.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    ctrl.errorMessage!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ),
              FilledButton.icon(
                onPressed: () async {
                  final pin = _pinController.text.trim();
                  if (pin != _confirmPinController.text.trim()) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PINs do not match.')),
                    );
                    return;
                  }
                  final ok = await ctrl.setupPin(pin);
                  if (ok) {
                    _pinController.clear();
                    _confirmPinController.clear();
                  }
                },
                icon: const Icon(Icons.lock_rounded),
                label: const Text('Create Vault PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockView(VaultController ctrl) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_person_rounded,
                size: 56,
                color: AppTheme.accent,
              ),
              const SizedBox(height: 14),
              Text(
                'Private Vault Locked',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter Vault PIN',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) async {
                  final ok = await ctrl.unlockWithPin(value);
                  if (ok) _pinController.clear();
                },
              ),
              if (ctrl.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    ctrl.errorMessage!,
                    style: const TextStyle(color: AppTheme.danger),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: () async {
                      final ok = await ctrl.unlockWithPin(_pinController.text);
                      if (ok) _pinController.clear();
                    },
                    child: const Text('Unlock'),
                  ),
                  if (ctrl.biometricAvailable && ctrl.biometricEnabled)
                    OutlinedButton.icon(
                      onPressed: ctrl.unlockWithBiometrics,
                      icon: const Icon(Icons.fingerprint_rounded),
                      label: const Text('Biometric'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedVaultList(VaultController ctrl) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              const Icon(Icons.shield_rounded, color: AppTheme.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${ctrl.videos.length} protected ${ctrl.videos.length == 1 ? 'video' : 'videos'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: ctrl.lockVault,
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: const Text('Lock Vault'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ctrl.videos.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Vault is empty. Open any video menu in your library and choose "Move to Private Vault".',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: ctrl.videos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = ctrl.videos[index];
                    return Card(
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.lock_open_rounded,
                            color: AppTheme.accent,
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${DurationFormatter.formatFileSize(item.sizeBytes)}'
                          '${item.duration > Duration.zero ? ' • ${DurationFormatter.format(item.duration)}' : ''}',
                        ),
                        onTap: () => _playVaultVideo(item),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) async {
                            if (value == 'restore') {
                              await ctrl.restoreVideo(item);
                              widget.onLibraryChanged();
                            } else if (value == 'delete') {
                              await ctrl.deleteVideo(item);
                            }
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem<String>(
                              value: 'restore',
                              child: Text('Restore from Vault'),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Text('Delete Permanently'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
