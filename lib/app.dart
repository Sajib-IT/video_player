import 'package:flutter/material.dart';
import 'package:video_player_app/core/config/app_config.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/data/local/database_helper.dart';
import 'package:video_player_app/features/downloader/data/web_video_download_service.dart';
import 'package:video_player_app/features/library/presentation/library_controller.dart';
import 'package:video_player_app/features/library/presentation/library_screen.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/vault/presentation/vault_controller.dart';

/// Root application widget configured with dark cinema theme and core service DI.
class CineVaultApp extends StatefulWidget {
  final PlayerService playerService;
  final DatabaseHelper databaseHelper;
  final LibraryController? libraryController;
  final VaultController? vaultController;
  final WebVideoDownloadController? downloadController;
  final Widget? homeOverride;

  const CineVaultApp({
    super.key,
    required this.playerService,
    required this.databaseHelper,
    this.libraryController,
    this.vaultController,
    this.downloadController,
    this.homeOverride,
  });

  @override
  State<CineVaultApp> createState() => _CineVaultAppState();
}

class _CineVaultAppState extends State<CineVaultApp>
    with WidgetsBindingObserver {
  late final LibraryController _libraryController;
  late final bool _ownsLibraryController;
  late final VaultController _vaultController;
  late final bool _ownsVaultController;
  late final WebVideoDownloadController _downloadController;
  late final bool _ownsDownloadController;

  @override
  void initState() {
    super.initState();
    _ownsLibraryController = widget.libraryController == null;
    _libraryController = widget.libraryController ?? LibraryController();
    _ownsVaultController = widget.vaultController == null;
    _vaultController = widget.vaultController ?? VaultController();
    _ownsDownloadController = widget.downloadController == null;
    _downloadController =
        widget.downloadController ?? WebVideoDownloadController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.playerService.handleAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _vaultController.lockVault();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsLibraryController) {
      _libraryController.dispose();
    }
    if (_ownsVaultController) {
      _vaultController.dispose();
    }
    if (_ownsDownloadController) {
      _downloadController.dispose();
    }
    widget.playerService.dispose();
    widget.databaseHelper.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: AppTheme.dark(),
      home:
          widget.homeOverride ??
          LibraryScreen(
            controller: _libraryController,
            playerService: widget.playerService,
            vaultController: _vaultController,
            downloadController: _downloadController,
          ),
    );
  }
}
