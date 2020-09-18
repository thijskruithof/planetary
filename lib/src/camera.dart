import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'math.dart';
import 'rect.dart';
import 'frustum2d.dart';

/// Utility class to store various calculated camera metrics
class Camera {
  Vector3 _pos;
  Vector3 _targetPos;
  Vector3 _up;
  Rect _screenRect;
  List<double> _viewProjectionMatrix;
  Frustum2d _frustum;

  Camera(
      Rect screenRect,
      double worldScale,
      Vector2 worldBottomCenter,
      double cameraFOVy,
      double cameraPitchAngle,
      double cameraNear,
      double cameraFar) {
    // Store our screen rect
    _screenRect = Rect.copy(screenRect);

    // Calculate Z of the camera
    var halfScreenWorldHeight = 0.5 * screenRect.size.y * worldScale;
    var cameraZ = halfScreenWorldHeight / tan(0.5 * cameraFOVy);

    // Rotate camera in 2D (ZY space) around bottom of world
    var cameraPosZY =
        Vector2(cameraZ, worldBottomCenter.y - halfScreenWorldHeight);
    var cameraFwdZY = Vector2(-1.0, 0.0);
    var planeBottomCenterPosZY = Vector2(0.0, worldBottomCenter.y);

    var cameraOffsetZY =
        rotateVector2(cameraPosZY - planeBottomCenterPosZY, cameraPitchAngle);
    cameraFwdZY = rotateVector2(cameraFwdZY, cameraPitchAngle);

    // Calculate new camera position
    cameraPosZY = planeBottomCenterPosZY + cameraOffsetZY;

    // Store camera position
    _pos = Vector3(worldBottomCenter.x, cameraPosZY.y, cameraPosZY.x);

    // Calculate position that we're looking at
    var targetPosZY = cameraPosZY + cameraFwdZY;

    // Store target position
    _targetPos = Vector3(worldBottomCenter.x, targetPosZY.y, targetPosZY.x);

    // Store up axis of the camera
    _up = Vector3(0.0, -cameraFwdZY.x, cameraFwdZY.y);

    // Calculate projection matrix
    var aspect = screenRect.size.x / screenRect.size.y;
    var projMatrix =
        _calcProjectionMatrix(cameraFOVy, cameraNear, cameraFar, aspect);

    // Calculate view matrix
    var viewMatrix = _calcViewMatrix(_pos, _targetPos, _up);

    // Calculate view * proj
    _viewProjectionMatrix = multiplyMatrix4x4(viewMatrix, projMatrix);

    // Calculate our 2D frustum
    _frustum = Frustum2d(_viewProjectionMatrix);
  }

  /// Make a copy of Camera [other]
  Camera.copy(Camera other)
      : _pos = Vector3.copy(other._pos),
        _targetPos = Vector3.copy(other._targetPos),
        _up = Vector3.copy(other._up),
        _screenRect = Rect.copy(other._screenRect),
        _viewProjectionMatrix = List<double>.from(other._viewProjectionMatrix),
        _frustum = Frustum2d.copy(other._frustum);

  /// Convert screen-space position [pos] to a 2D world-space position (at Z=0).
  Vector2 unproject(Vector2 pos) {
    // First convert pos (in pixels) to normalized device coords (-1..1)
    var ndcPos = Vector2(
        2.0 * (pos.x / _screenRect.size.x) - 1.0, // -1..+1
        -2.0 * (pos.y / _screenRect.size.y) + 1.0 // +1..-1
        );

    // Convert the ndc pos to world-space by multiplying the ndc pos with the
    // inverse of our camera's view-projection matrix:

    // If ndcPos = M * v  (M = MVP matrix and v is position in world space)
    // Then:
    // v = M^-1 * ndcPos
    //
    // Because we know that v.z = 0 we can directly solve this transformation:

    final M = _viewProjectionMatrix;

    var dk = ndcPos.x * M[3] - M[0];
    var k0 = (M[4] - ndcPos.x * M[7]) / dk;
    var k1 = (M[12] - ndcPos.x * M[15]) / dk;

    var ndiv = ndcPos.y * M[7] - M[5];
    var n0 = (M[1] - ndcPos.y * M[3]) / ndiv;
    var n1 = (M[13] - ndcPos.y * M[15]) / ndiv;

    var y = (n0 * k1 + n1) / (1.0 - n0 * k0);
    var x = k0 * y + k1;

    return Vector2(x, y);
  }

  /// Convert world-space position [pos] (at Z=0) to a screen-space position.
  Vector2 project(Vector2 pos) {
    var M = _viewProjectionMatrix;

    // Simple multiplication of (pos.x, pos.y, 0.0) with M,
    // including projection by dividing by w.
    var w = M[3] * pos.x + M[7] * pos.y + M[15];

    var ndcPos = Vector2(
      (M[0] * pos.x + M[4] * pos.y + M[12]) / w,
      (M[1] * pos.x + M[5] * pos.y + M[13]) / w,
    );

    return Vector2((0.5 + ndcPos.x * 0.5) * _screenRect.size.x,
        (0.5 - ndcPos.y * 0.5) * _screenRect.size.y);
  }

  /// Calculate our projection matrix
  /// Note: based on p5js's implementation of perspective
  /// Returns a list with 16 doubles, representing a 4x4 matrix
  List<double> _calcProjectionMatrix(
      double FOVy, double near, double far, double aspect) {
    // Calculate projection matrix
    var f = 1.0 / tan(FOVy / 2);
    var nf = 1.0 / (near - far);

    return [
      f / aspect,
      0,
      0,
      0,
      0,
      -f,
      0,
      0,
      0,
      0,
      (far + near) * nf,
      -1,
      0,
      0,
      2 * far * near * nf,
      0
    ];
  }

  /// Calculate our view matrix
  /// Note: based on p5hs's implementation of Camera._getLocalAxes
  /// Returns a list with 16 doubles, representing a 4x4 matrix
  List<double> _calcViewMatrix(Vector3 pos, Vector3 targetPos, Vector3 up) {
    // calculate camera local Z vector
    var z = pos - targetPos;

    // normalize camera local Z vector
    z.normalize();

    // compute camera local X vector as up vector (local Y) cross local Z
    var x = up.cross(z);

    // compute y = z cross x
    var y = z.cross(x);

    // cross product gives area of parallelogram, which is < 1.0 for
    // non-perpendicular unit-length vectors; so normalize x, y here:
    x.normalize();
    y.normalize();

    // Calculate orientation matrix
    var mat4 = List<double>(16);

    mat4[0] = x.x;
    mat4[1] = y.x;
    mat4[2] = z.x;
    mat4[3] = 0.0;

    mat4[4] = x.y;
    mat4[5] = y.y;
    mat4[6] = z.y;
    mat4[7] = 0.0;

    mat4[8] = x.z;
    mat4[9] = y.z;
    mat4[10] = z.z;
    mat4[11] = 0.0;

    // Add inverse camera position
    var t = -pos;

    mat4[12] = mat4[0] * t.x + mat4[4] * t.y + mat4[8] * t.z;
    mat4[13] = mat4[1] * t.x + mat4[5] * t.y + mat4[9] * t.z;
    mat4[14] = mat4[2] * t.x + mat4[6] * t.y + mat4[10] * t.z;
    mat4[15] = 1.0;

    return mat4;
  }
}
