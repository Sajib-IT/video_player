import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_app/core/config/subtitle_languages.dart';
import 'package:video_player_app/core/constants/media_formats.dart';
import 'package:video_player_app/core/utils/duration_formatter.dart';
import 'package:video_player_app/core/utils/movie_hash.dart';
import 'package:video_player_app/features/player/domain/ab_loop_range.dart';
import 'package:video_player_app/features/player/domain/aspect_ratio_mode.dart';

void main() {
  test('ABLoopRange validates span, swaps inverted points, and triggers loop', () {
    const empty = ABLoopRange();
    expect(empty.isActive, isFalse);

    final withA = empty.withPointA(const Duration(seconds: 20));
    expect(withA.hasPointA, isTrue);
    expect(withA.isActive, isFalse);

    final swapped = withA.withPointB(const Duration(seconds: 10));
    expect(swapped.pointA, const Duration(seconds: 10));
    expect(swapped.pointB, const Duration(seconds: 20));
    expect(swapped.isActive, isTrue);
    expect(swapped.shouldLoopAt(const Duration(seconds: 19)), isFalse);
    expect(swapped.shouldLoopAt(const Duration(seconds: 20)), isTrue);
  });

  test('AspectRatioMode maps to BoxFit and explicit ratios', () {
    expect(AspectRatioMode.fit.boxFit, BoxFit.contain);
    expect(AspectRatioMode.fill.boxFit, BoxFit.cover);
    expect(AspectRatioMode.stretch.boxFit, BoxFit.fill);
    expect(AspectRatioMode.ratio16x9.aspectRatio, closeTo(16 / 9, 0.0001));
    expect(AspectRatioMode.ratio4x3.aspectRatio, closeTo(4 / 3, 0.0001));
  });

  test('DurationFormatter, MediaFormats, and SubtitleLanguages behave cleanly', () {
    expect(DurationFormatter.format(const Duration(seconds: 65)), '01:05');
    expect(
      DurationFormatter.format(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '01:02:03',
    );
    expect(
      DurationFormatter.formatSignedSeconds(
        const Duration(milliseconds: -500),
        decimal: true,
      ),
      '-0.5s',
    );
    expect(MediaFormats.isSupportedVideo('/tmp/demo.MKV'), isTrue);
    expect(MediaFormats.isSupportedSubtitle('/tmp/demo.ass'), isTrue);
    expect(MediaFormats.isStyledAssSubtitle('/tmp/demo.SSA'), isTrue);
    expect(SubtitleLanguages.labelForCode('ben'), 'Bengali');
    expect(SubtitleLanguages.labelForCode('ja-JP'), 'Japanese');
  });

  test('MovieHash computes 16-char hex digest for files >= 64 KiB', () async {
    final tempDir = await Directory.systemTemp.createTemp('movie_hash_test');
    addTearDown(() => tempDir.delete(recursive: true));

    final smallFile = File('${tempDir.path}/small.mp4')
      ..writeAsBytesSync(List<int>.filled(1024, 1));
    expect(await MovieHash.compute(smallFile.path), isNull);

    final mediaFile = File('${tempDir.path}/sample.mkv')
      ..writeAsBytesSync(List<int>.filled(150 * 1024, 7));
    final hash = await MovieHash.compute(mediaFile.path);
    expect(hash, isNotNull);
    expect(hash!.length, 16);
  });
}
