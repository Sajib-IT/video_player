/// Immutable A-B loop segment boundaries and active toggle state.
class ABLoopRange {
  static const Duration minLoopSpan = Duration(milliseconds: 200);

  final Duration? pointA;
  final Duration? pointB;
  final bool enabled;

  const ABLoopRange({
    this.pointA,
    this.pointB,
    this.enabled = false,
  });

  bool get hasPointA => pointA != null;
  bool get hasPointB => pointB != null;

  bool get isValidSpan =>
      pointA != null && pointB != null && (pointB! - pointA!) >= minLoopSpan;

  bool get isActive => enabled && isValidSpan;

  bool shouldLoopAt(Duration position) {
    return isActive && position >= pointB!;
  }

  ABLoopRange withPointA(Duration a) {
    final normalizedA = a < Duration.zero ? Duration.zero : a;
    final currentB = pointB;
    if (currentB != null && (currentB - normalizedA) < minLoopSpan) {
      return ABLoopRange(pointA: normalizedA, pointB: null, enabled: false);
    }
    return ABLoopRange(
      pointA: normalizedA,
      pointB: currentB,
      enabled: currentB != null ? enabled : false,
    );
  }

  ABLoopRange withPointB(Duration b) {
    final normalizedB = b < Duration.zero ? Duration.zero : b;
    final currentA = pointA;
    if (currentA == null) {
      return ABLoopRange(pointA: normalizedB, pointB: null, enabled: false);
    }
    if ((normalizedB - currentA).abs() < minLoopSpan) {
      return this;
    }
    if (normalizedB < currentA) {
      return ABLoopRange(
        pointA: normalizedB,
        pointB: currentA,
        enabled: true,
      );
    }
    return ABLoopRange(
      pointA: currentA,
      pointB: normalizedB,
      enabled: true,
    );
  }

  ABLoopRange copyWith({
    Duration? pointA,
    Duration? pointB,
    bool? enabled,
  }) {
    return ABLoopRange(
      pointA: pointA ?? this.pointA,
      pointB: pointB ?? this.pointB,
      enabled: enabled ?? this.enabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ABLoopRange &&
        other.pointA == pointA &&
        other.pointB == pointB &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(pointA, pointB, enabled);
}
