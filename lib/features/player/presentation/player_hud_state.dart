/// Active HUD feedback type displayed during player gestures and quick actions.
enum HudFeedbackType {
  none,
  brightness,
  volume,
  seekPreview,
  doubleTapSeek,
  toast,
}

/// Immutable state driving live player HUD overlays.
class PlayerHudState {
  final HudFeedbackType type;
  final double brightness;
  final double volumePercent;
  final Duration seekTarget;
  final Duration seekDelta;
  final Duration mediaDuration;
  final bool doubleTapForward;
  final String? toastMessage;

  const PlayerHudState({
    this.type = HudFeedbackType.none,
    this.brightness = 0.5,
    this.volumePercent = 100.0,
    this.seekTarget = Duration.zero,
    this.seekDelta = Duration.zero,
    this.mediaDuration = Duration.zero,
    this.doubleTapForward = true,
    this.toastMessage,
  });

  static const PlayerHudState hidden = PlayerHudState();

  bool get isVisible => type != HudFeedbackType.none;
  bool get isAudioBoosted => volumePercent > 100.5;
}
