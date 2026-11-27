import 'package:flutter/material.dart';
import 'package:video_player_app/core/theme/app_theme.dart';
import 'package:video_player_app/features/cast/presentation/cast_controller.dart';
import 'package:video_player_app/features/player/domain/media_playback_request.dart';
import 'package:video_player_app/features/player/services/player_service.dart';

/// Opens the Chromecast / Android TV discovery & streaming sheet.
Future<void> showCastDeviceSheet(
  BuildContext context, {
  required CastController castController,
  required PlayerService playerService,
  required MediaPlaybackRequest media,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _CastDeviceSheetBody(
      castController: castController,
      playerService: playerService,
      media: media,
    ),
  );
}

class _CastDeviceSheetBody extends StatefulWidget {
  final CastController castController;
  final PlayerService playerService;
  final MediaPlaybackRequest media;

  const _CastDeviceSheetBody({
    required this.castController,
    required this.playerService,
    required this.media,
  });

  @override
  State<_CastDeviceSheetBody> createState() => _CastDeviceSheetBodyState();
}

class _CastDeviceSheetBodyState extends State<_CastDeviceSheetBody> {
  @override
  void initState() {
    super.initState();
    if (!widget.castController.isConnected) {
      widget.castController.scanDevices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.castController,
      builder: (context, _) {
        final ctrl = widget.castController;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cast_rounded, color: AppTheme.accent),
                    const SizedBox(width: 10),
                    Text(
                      'Cast to TV',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (!ctrl.isConnected)
                      TextButton.icon(
                        onPressed: ctrl.isScanning ? null : ctrl.scanDevices,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Scan'),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (ctrl.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      ctrl.errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (ctrl.isConnected && ctrl.connectedDevice != null) ...[
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.cast_connected_rounded,
                        color: AppTheme.success,
                      ),
                      title: Text(ctrl.connectedDevice!.name),
                      subtitle: Text(
                        'Streaming "${widget.media.title}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: TextButton(
                        onPressed: ctrl.disconnect,
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: ctrl.togglePlayPause,
                        icon: Icon(
                          ctrl.isRemotePlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        label: Text(ctrl.isRemotePlaying ? 'Pause TV' : 'Play TV'),
                      ),
                    ],
                  ),
                ] else if (ctrl.isScanning || ctrl.isConnecting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 10),
                          Text(
                            'Searching Wi-Fi for Chromecast devices...',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (ctrl.devices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No Chromecast devices found on this Wi-Fi network.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  for (final device in ctrl.devices)
                    ListTile(
                      leading: const Icon(Icons.tv_rounded),
                      title: Text(device.name),
                      subtitle: Text('${device.host}:${device.port}'),
                      onTap: () async {
                        final pos = widget.playerService.snapshot.position;
                        await widget.playerService.pause();
                        await ctrl.castMedia(
                          device: device,
                          media: widget.media,
                          startPosition: pos,
                        );
                      },
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
