import 'package:flutter/widgets.dart';

/// Supported viewport aspect ratio and scaling modes for video rendering.
enum AspectRatioMode {
  fit(id: 'fit', label: 'Fit', boxFit: BoxFit.contain, aspectRatio: null),
  fill(id: 'fill', label: 'Fill / Crop', boxFit: BoxFit.cover, aspectRatio: null),
  stretch(id: 'stretch', label: 'Stretch', boxFit: BoxFit.fill, aspectRatio: null),
  ratio16x9(
    id: 'ratio16x9',
    label: '16:9',
    boxFit: BoxFit.contain,
    aspectRatio: 16 / 9,
  ),
  ratio4x3(
    id: 'ratio4x3',
    label: '4:3',
    boxFit: BoxFit.contain,
    aspectRatio: 4 / 3,
  );

  final String id;
  final String label;
  final BoxFit boxFit;
  final double? aspectRatio;

  const AspectRatioMode({
    required this.id,
    required this.label,
    required this.boxFit,
    required this.aspectRatio,
  });

  AspectRatioMode next() {
    final values = AspectRatioMode.values;
    return values[(index + 1) % values.length];
  }

  static AspectRatioMode fromId(String? raw) {
    for (final mode in AspectRatioMode.values) {
      if (mode.id == raw) return mode;
    }
    return AspectRatioMode.fit;
  }
}
