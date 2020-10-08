import 'package:vector_math/vector_math.dart';

/// A simple 2D rectangle, using Vector2 for its two corner points
class Rect {
  Vector2 min;
  Vector2 max;

  Rect(Vector2 min, Vector2 max)
      : min = Vector2.copy(min),
        max = Vector2.copy(max);
  Rect.copy(Rect other)
      : min = Vector2.copy(other.min),
        max = Vector2.copy(other.max);
  Rect.unit()
      : min = Vector2(0, 0),
        max = Vector2(1, 1);

  Vector2 get center {
    return (min + max) * 0.5;
  }

  Vector2 get size {
    return max - min;
  }

  @override
  bool operator ==(Object other) {
    return (other is Rect) && min == other.min && max == other.max;
  }

  /// Does [other] overlap with this rectangle?
  bool overlaps(Rect other) {
    return !(max.x < other.min.x ||
        max.y < other.min.y ||
        min.x > other.max.x ||
        min.y > other.max.y);
  }

  /// Calculate fraction that [pos] is within this rectangle.
  /// Returned fraction is unclamped! So will return <0 or >1 on any axis
  /// when [pos] is outside this rectangle.
  Vector2 getFraction(Vector2 pos) {
    return Vector2(
        (pos.x - min.x) / (max.x - min.x), (pos.y - min.y) / (max.y - min.y));
  }

  /// Reduce the width of this rectangle by removing a part from the right
  /// This will return a Rect for the part that was cut off
  /// (or null when nothing was removed).
  Rect removeRight(fractionX) {
    if (fractionX <= 0.0 || fractionX >= 1.0) {
      return null;
    }

    var splitX = min.x + fractionX * (max.x - min.x);

    var rightRect = Rect(Vector2(splitX, min.y), max);
    max.x = splitX;
    return rightRect;
  }

  /// Reduce the width of this rectangle by removing a part from the bottom
  /// This will return a Rect for the part that was cut off
  /// (or null when nothing was removed).
  Rect removeBottom(fractionY) {
    if (fractionY <= 0.0 || fractionY >= 1.0) {
      return null;
    }

    var splitY = min.y + fractionY * (max.y - min.y);

    var bottomRect = Rect(Vector2(min.x, splitY), max);
    max.y = splitY;
    return bottomRect;
  }
}
