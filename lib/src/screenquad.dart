import 'package:vector_math/vector_math.dart';
import 'rect.dart';

class ScreenQuad {
  Rect worldRect;
  Rect uvRect;

  ScreenQuad(Rect worldRect, Rect uvRect)
      : worldRect = Rect.copy(worldRect),
        uvRect = Rect.copy(uvRect);

  ScreenQuad.copy(ScreenQuad other)
      : worldRect = Rect.copy(other.worldRect),
        uvRect = Rect.copy(other.uvRect);

  /// Split a list of quads in two at world coord [x]. This returns a new list
  /// of quads.
  static List<ScreenQuad> splitAtWorldX(List<ScreenQuad> quads, double x) {
    var result = <ScreenQuad>[];
    for (var quad in quads) {
      var splitFraction = quad.worldRect.getFraction(Vector2(x, 0));

      if (splitFraction.x <= 0.0 || splitFraction.x >= 1.0) {
        result.add(ScreenQuad.copy(quad));
      } else {
        var leftWorldRect = Rect.copy(quad.worldRect);
        var leftUvRect = Rect.copy(quad.uvRect);
        var rightWorldRect = leftWorldRect.removeRight(splitFraction.x);
        var rightUvRect = leftUvRect.removeRight(splitFraction.x);
        result.add(ScreenQuad(leftWorldRect, leftUvRect));
        result.add(ScreenQuad(rightWorldRect, rightUvRect));
      }
    }
    return result;
  }

  /// Split a list of quads in two at world coord [y]. This returns a new list
  /// of quads.
  static List<ScreenQuad> splitAtWorldY(List<ScreenQuad> quads, double y) {
    var result = <ScreenQuad>[];
    for (var quad in quads) {
      var splitFraction = quad.worldRect.getFraction(Vector2(0, y));

      if (splitFraction.y <= 0.0 || splitFraction.y >= 1.0) {
        result.add(ScreenQuad.copy(quad));
      } else {
        var topWorldRect = Rect.copy(quad.worldRect);
        var topUvRect = Rect.copy(quad.uvRect);
        var bottomWorldRect = topWorldRect.removeBottom(splitFraction.y);
        var bottomUvRect = topUvRect.removeBottom(splitFraction.y);
        result.add(ScreenQuad(topWorldRect, topUvRect));
        result.add(ScreenQuad(bottomWorldRect, bottomUvRect));
      }
    }
    return result;
  }
}
