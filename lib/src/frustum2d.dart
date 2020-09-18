import 'package:planetary/src/frustumedge.dart';
import 'package:vector_math/vector_math.dart';
import 'rect.dart';
import 'dart:math';

/// Metrics of a frustum, in 2D, as projected on the world's XY plane (z=0).
/// This has the shape of a isosceles trapezoid (when the camera's pitch angle is non-zero)
class Frustum2d {
  FrustumEdge _edgeLeft;
  FrustumEdge _edgeRight;

  Vector2 _posTopLeft;
  Vector2 _posBottomLeft;
  Vector2 _posTopRight;
  Vector2 _posBottomRight;

  Rect _worldBoundsRect;

  /// Construct a 2D frustum from model-view-projection matrix [viewProjMatrix]
  /// This assumes that the view from [viewProjMatrix] only contains a rotation
  /// on the X axis (for camera pitch).
  Frustum2d(List<double> viewProjMatrix) {
    // Based on http://www.cs.otago.ac.nz/postgrads/alexis/planeExtraction.pdf

    assert(viewProjMatrix.length == 16);

    // Extract our frustum's four bounding edges first.

    _edgeLeft = FrustumEdge(
        viewProjMatrix[3] + viewProjMatrix[0],
        viewProjMatrix[7] + viewProjMatrix[4],
        viewProjMatrix[11] + viewProjMatrix[8],
        viewProjMatrix[15] + viewProjMatrix[12]);

    _edgeRight = FrustumEdge(
        viewProjMatrix[3] - viewProjMatrix[0],
        viewProjMatrix[7] - viewProjMatrix[4],
        viewProjMatrix[11] - viewProjMatrix[8],
        viewProjMatrix[15] - viewProjMatrix[12]);

    var edgeTop = FrustumEdge(
        viewProjMatrix[3] - viewProjMatrix[1],
        viewProjMatrix[7] - viewProjMatrix[5],
        viewProjMatrix[11] - viewProjMatrix[9],
        viewProjMatrix[15] - viewProjMatrix[13]);

    var edgeBottom = FrustumEdge(
        viewProjMatrix[3] + viewProjMatrix[1],
        viewProjMatrix[7] + viewProjMatrix[5],
        viewProjMatrix[11] + viewProjMatrix[9],
        viewProjMatrix[15] + viewProjMatrix[13]);

    // Calculate corners of 2D frustum (in 2D)
    _posTopLeft = _edgeLeft.intersect(edgeTop);
    _posBottomLeft = _edgeLeft.intersect(edgeBottom);
    _posTopRight = _edgeRight.intersect(edgeTop);
    _posBottomRight = _edgeRight.intersect(edgeBottom);

    // Calculate axis-aligned bounds rect in world space
    // note: we assume here that our camera only contains pitch, so the frustum is always horizontal.
    _worldBoundsRect = Rect(
        Vector2(min(_posTopLeft.x, _posBottomLeft.x), _posTopLeft.y),
        Vector2(max(_posTopRight.x, _posBottomRight.x), _posBottomRight.y));
  }

  /// Make a copy of Frustum2d [other]
  Frustum2d.copy(Frustum2d other)
      : _edgeLeft = FrustumEdge.copy(other._edgeLeft),
        _edgeRight = FrustumEdge.copy(other._edgeRight),
        _posTopLeft = Vector2.copy(other._posTopLeft),
        _posBottomLeft = Vector2.copy(other._posBottomLeft),
        _posTopRight = Vector2.copy(other._posTopRight),
        _posBottomRight = Vector2.copy(other._posBottomRight),
        _worldBoundsRect = Rect.copy(other._worldBoundsRect);

  /// Check if this 2D frustum overlaps with world-space rectangle [worldRect]
  bool overlaps(Rect worldRect) {
    // note: we assume here that our camera only contains pitch, so the frustum is always horizontal.
    return worldRect.max.y >= _posTopLeft.y &&
        worldRect.min.y <= _posBottomRight.y &&
        !_edgeLeft.isCompletelyOnBackSide(worldRect) &&
        !_edgeRight.isCompletelyOnBackSide(worldRect);
  }
}
