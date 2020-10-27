import 'dart:math';
import 'mapdimensions.dart';
import 'rect.dart';
import 'package:vector_math/vector_math.dart';
import 'camera.dart';

/// A 3D view of our 2D map
class View {
  final MapDimensions _mapDimensions;

  /// Camera pitch angle (in radians)
  double _cameraPitchAngle = 28.0 * (pi / 180.0);

  /// Camera FOV (vertically, in radians)
  final double cameraFOVy;

  /// Camera's near-plane distance
  final double cameraNear = 0.01;

  /// Camera's far-plane distance
  final double cameraFar = 100.0;

  /// Rectangle on the screen that this view projects to
  Rect _screenRect;

  /// Which position (in world coords) is shown in the center at the bottom of the screen
  Vector2 _worldBottomCenter;

  /// Size in world units of 1 pixel on screen (at the bottom of the screen)
  double _worldScale;

  /// Calculated camera metrics
  Camera _camera;

  View(MapDimensions mapDimensions, Rect screenRect,
      double verticalCameraFOVinDegrees)
      : _mapDimensions = mapDimensions,
        cameraFOVy = verticalCameraFOVinDegrees * (pi / 180.0) {
    _screenRect = Rect.copy(screenRect);

    _worldBottomCenter = Vector2.zero();
    _worldScale = 1.0;

    _recalculate();
  }

  /// Make a copy of View [other]
  View.copy(View other)
      : _mapDimensions = other._mapDimensions,
        _cameraPitchAngle = other._cameraPitchAngle,
        cameraFOVy = other.cameraFOVy,
        _screenRect = Rect.copy(other._screenRect),
        _worldScale = other._worldScale,
        _worldBottomCenter = Vector2.copy(other._worldBottomCenter),
        _camera = Camera.copy(other._camera);

  Rect get screenRect {
    return _screenRect;
  }

  set screenRect(Rect screenRect) {
    if (screenRect != _screenRect) {
      _screenRect = Rect.copy(screenRect);
      _recalculate();
    }
  }

  Vector2 get worldBottomCenter {
    return _worldBottomCenter;
  }

  set worldBottomCenter(Vector2 worldBottomCenter) {
    if (worldBottomCenter != _worldBottomCenter) {
      _worldBottomCenter = Vector2.copy(worldBottomCenter);
      _recalculate();
    }
  }

  double get worldScale {
    return _worldScale;
  }

  set worldScale(double worldScale) {
    if (worldScale != _worldScale) {
      _worldScale = worldScale;
      _recalculate();
    }
  }

  /// Aspect ratio of the screen
  double get screenAspect {
    return _screenRect.size.x / _screenRect.size.y;
  }

  double get cameraPitchAngle {
    return _cameraPitchAngle;
  }

  set cameraPitchAngle(double angle) {
    if (angle != _cameraPitchAngle) {
      _cameraPitchAngle = angle;
      _recalculate();
    }
  }

  Camera get camera {
    return _camera;
  }

  void fitToContent(Rect worldRect) {
    // Scale
    var worldSize = worldRect.size;
    var screenSize = _screenRect.size;
    var scale = Vector2(worldSize.x / screenSize.x, worldSize.y / screenSize.y);
    _worldScale = max(scale.x, scale.y);

    // Center
    _worldBottomCenter =
        Vector2((worldRect.min.x + worldRect.max.x) * 0.5, worldRect.max.y);

    _recalculate();
  }

  /// Convert screen-space position [pos] to a 2D world-space position (at Z=0).
  Vector2 screenToWorldPos(Vector2 pos) {
    return _camera.unproject(pos);
  }

  /// Convert world-space position [pos] (at Z=0) to a screen-space position.
  Vector2 worldToScreenPos(Vector2 pos) {
    return _camera.project(pos);
  }

  /// Recalculate all internal view metrics
  /// This is required whenever the screenRect, worldScale or worldBottomCenter
  /// is modified.
  void _recalculate() {
    // Limit scale
    var minScale = 1.0 / _mapDimensions.tileSize;
    var maxScale = min(
        _mapDimensions.numTilesXLod0 / _screenRect.size.x,
        cos(cameraPitchAngle + 0.5 * cameraFOVy) *
            (sin(0.5 * cameraFOVy) / sin(cameraFOVy)) *
            (2.0 * _mapDimensions.numTilesYLod0 / _screenRect.size.y));
    _worldScale = min(max(_worldScale, minScale), maxScale);

    // Update our camera metrics, so that we can use the updated metrics to
    // calculate the desired adjustments for the worldBottomCenter.
    _calculateCamera();

    // Calculate current world space positions of the screen
    var worldBottomLeft = screenToWorldPos(Vector2(0.0, _screenRect.max.y));
    var worldBottomRight = screenToWorldPos(screenRect.max);
    var worldTopCenter = screenToWorldPos(Vector2(_screenRect.center.x, 0.0));

    // Limit left and right
    if (worldBottomLeft.x < 0.0) {
      _worldBottomCenter.x -= worldBottomLeft.x;
      worldBottomRight.x -= worldBottomLeft.x;
    }
    if (worldBottomRight.x > _mapDimensions.numTilesXLod0) {
      _worldBottomCenter.x -= worldBottomRight.x - _mapDimensions.numTilesXLod0;
    }

    // Limit top and bottom
    if (worldTopCenter.y < 0.0) {
      _worldBottomCenter.y -= worldTopCenter.y;
      worldBottomRight.y -= worldTopCenter.y;
    }
    if (worldBottomRight.y > _mapDimensions.numTilesYLod0) {
      _worldBottomCenter.y -= worldBottomRight.y - _mapDimensions.numTilesYLod0;
    }

    _calculateCamera();
  }

  void _calculateCamera() {
    _camera = Camera(_screenRect, _worldScale, _worldBottomCenter, cameraFOVy,
        cameraPitchAngle, cameraNear, cameraFar);
  }
}
