import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/features/cast/presentation/cast_controller.dart';
import 'package:video_player_app/features/cast/presentation/cast_device_sheet.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/presentation/player_view_controller.dart';
import 'package:video_player_app/features/player/presentation/widgets/playback_sheets.dart';
import 'package:video_player_app/features/player/presentation/widgets/player_controls_overlay.dart';
import 'package:video_player_app/features/player/presentation/widgets/player_hud_overlay.dart';
import 'package:video_player_app/features/player/services/device_control_service.dart';
import 'package:video_player_app/features/player/services/player_service.dart';
import 'package:video_player_app/features/subtitles/data/ai_subtitle_service.dart';
import 'package:video_player_app/features/subtitles/data/subtitle_repository.dart';
import 'package:video_player_app/features/subtitles/presentation/widgets/subtitle_manager_sheet.dart';

/// Full-screen dark cinema & audio player with gesture HUDs, custom controls,
/// Night Mode, Background Audio continuity, PiP, Cast, Sleep Timer, and wake-lock.
class PlayerScreen extends StatefulWidget {
  final PlayerService playerService;
  final MediaPlaybackRequest request;
  final DeviceControlService? deviceControlService;
  final SubtitleRepository? subtitleRepository;
  final CastController? castController;
  final AiSubtitleService? aiSubtitleService;
  final bool resumeCurrentSession;

  const PlayerScreen({
    super.key,
    required this.playerService,
    required this.request,
    this.deviceControlService,
    this.subtitleRepository,
    this.castController,
    this.aiSubtitleService,
    this.resumeCurrentSession = false,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final PlayerViewController _viewController;
  CastController? _ownedCastController;
  late final CastController _castController;
  Offset _lastDoubleTapPosition = Offset.zero;
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _viewController = PlayerViewController(
      playerService: widget.playerService,
      deviceControlService: widget.deviceControlService,
    );
    if (widget.castController != null) {
      _castController = widget.castController!;
    } else {
      _ownedCastController = CastController();
      _castController = _ownedCastController!;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startPlayback();
      }
    });
  }

  Future<void> _startPlayback() async {
    _viewController.enterImmersiveMode();
    _viewController.initialize();
    final activeKey = widget.playerService.snapshot.currentMedia?.mediaKey;
    if (widget.resumeCurrentSession && activeKey == widget.request.mediaKey) {
      return;
    }
    try {
      await widget.playerService.openMedia(widget.request, autoPlay: true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _exitPlayer() async {
    if (_exiting) return;
    _exiting = true;
    unawaited(_viewController.restoreSystemChrome());
    if (!widget.playerService.snapshot.isBackgroundAudioEnabled) {
      await widget.playerService.stop();
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openModalSheet(Future<void> Function() opener) async {
    _viewController.setModalOpen(true);
    try {
      await opener();
    } finally {
      _viewController.setModalOpen(false);
    }
  }

  @override
  void dispose() {
    if (!_exiting && !widget.playerService.snapshot.isBackgroundAudioEnabled) {
      widget.playerService.stop();
    }
    _viewController.restoreSystemChrome();
    _ownedCastController?.dispose();
    _viewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _exitPlayer();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[
            widget.playerService.snapshotListenable,
            _viewController,
          ]),
          builder: (context, _) {
            final snapshot = widget.playerService.snapshot;
            final videoController = widget.playerService.videoController;
            final activeMedia = snapshot.currentMedia ?? widget.request;
            final isAudioOnly = activeMedia.isAudioOnly;

            return LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = constraints.maxWidth;
                final viewportHeight = constraints.maxHeight;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (isAudioOnly)
                      _AudioPlaybackArtwork(media: activeMedia)
                    else if (videoController != null)
                      Video(
                        controller: videoController,
                        controls: NoVideoControls,
                        wakelock: false,
                        pauseUponEnteringBackgroundMode: false,
                        fit: snapshot.aspectRatioMode.boxFit,
                        aspectRatio: snapshot.aspectRatioMode.aspectRatio,
                        fill: Colors.black,
                        subtitleViewConfiguration: SubtitleViewConfiguration(
                          visible: snapshot.selectedSubtitleTrackId != 'no',
                          style: TextStyle(
                            height: 1.4,
                            fontSize: snapshot.subtitleFontSize,
                            color: Colors.white,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.65,
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            _viewController.controlsVisible ? 96 : 28,
                          ),
                        ),
                      )
                    else
                      const Center(
                        child: Icon(
                          Icons.play_circle_outline_rounded,
                          size: 72,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    if (snapshot.isNightMode)
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: Color.fromRGBO(255, 145, 38, 0.22),
                          ),
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _viewController.onSingleTap,
                      onDoubleTapDown: (details) {
                        _lastDoubleTapPosition = details.localPosition;
                      },
                      onDoubleTap: () {
                        final isRightHalf =
                            _lastDoubleTapPosition.dx >= (viewportWidth / 2);
                        _viewController.onDoubleTap(isRightHalf: isRightHalf);
                      },
                      onHorizontalDragStart: (_) =>
                          _viewController.onHorizontalDragStart(),
                      onHorizontalDragUpdate: (details) =>
                          _viewController.onHorizontalDragUpdate(
                            deltaDx: details.delta.dx,
                            viewportWidth: viewportWidth,
                          ),
                      onHorizontalDragEnd: (_) =>
                          _viewController.onHorizontalDragEnd(),
                      onVerticalDragStart: (details) {
                        final isLeftHalf =
                            details.localPosition.dx < (viewportWidth / 2);
                        _viewController.onVerticalDragStart(
                          isLeftHalf: isLeftHalf,
                        );
                      },
                      onVerticalDragUpdate: (details) =>
                          _viewController.onVerticalDragUpdate(
                            deltaDy: details.delta.dy,
                            viewportHeight: viewportHeight,
                          ),
                      onVerticalDragEnd: (_) =>
                          _viewController.onVerticalDragEnd(),
                      child: const SizedBox.expand(),
                    ),
                    if (snapshot.errorMessage != null)
                      _PlaybackErrorBanner(message: snapshot.errorMessage!),
                    PlayerHudOverlay(hudState: _viewController.hudState),
                    PlayerControlsOverlay(
                      snapshot: snapshot,
                      viewController: _viewController,
                      onBack: _exitPlayer,
                      onOpenSpeedSheet: () => _openModalSheet(
                        () => showPlaybackSpeedSheet(
                          context,
                          playerService: widget.playerService,
                        ),
                      ),
                      onOpenAspectRatioSheet: () => _openModalSheet(
                        () => showAspectRatioSheet(
                          context,
                          playerService: widget.playerService,
                        ),
                      ),
                      onOpenTracksSheet: () => _openModalSheet(
                        () => showSubtitleManagerSheet(
                          context,
                          playerService: widget.playerService,
                          subtitleRepository: widget.subtitleRepository,
                          aiSubtitleService: widget.aiSubtitleService,
                        ),
                      ),
                      onOpenSleepTimerSheet: () => _openModalSheet(
                        () => showSleepTimerSheet(
                          context,
                          playerService: widget.playerService,
                        ),
                      ),
                      onOpenCastSheet: () => _openModalSheet(
                        () => showCastDeviceSheet(
                          context,
                          castController: _castController,
                          playerService: widget.playerService,
                          media: activeMedia,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AudioPlaybackArtwork extends StatelessWidget {
  final MediaPlaybackRequest media;

  const _AudioPlaybackArtwork({required this.media});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF171E30), Colors.black],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceElevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  size: 72,
                  color: AppTheme.accent,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                media.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Audio Playback Mode',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaybackErrorBanner extends StatelessWidget {
  final String message;

  const _PlaybackErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.only(top: 64, left: 20, right: 20),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.danger.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
