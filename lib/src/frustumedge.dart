import 'dart:math';
import 'package:vector_math/vector_math.dart';
import 'rect.dart';

/// An edge of the frustum, in 2D, as it is projected on the world's XY plane (z=0)
class FrustumEdge {
  /// Direction of the edge of the frustum
  Vector2 _dir;

  /// A position on the edge of the frustum
  Vector2 _pos;

  /// Vector perpendicular to edge's dir, pointing to the inside of the frustum
  Vector2 _perpDirInside;

  /// Construct a frustum edge from a set of plane coefficients
  /// ([frustumPlaneA], [frustumPlaneB], [frustumPlaneC], [frustumPlaneD])
  FrustumEdge(double frustumPlaneA, double frustumPlaneB, double frustumPlaneC,
      double frustumPlaneD) {
    // Normalize our plane's coeffs
    var planeMag = sqrt(frustumPlaneA * frustumPlaneA +
        frustumPlaneB * frustumPlaneB +
        frustumPlaneC * frustumPlaneC);

    frustumPlaneA /= planeMag;
    frustumPlaneB /= planeMag;
    frustumPlaneC /= planeMag;
    frustumPlaneD /= planeMag;

    // Calculate the edge between the frustum plane and the XY plane

    // Intersection ray's dir is normal(cross(normal, xyplane.normal)),
    // Which equals to:
    //  normalize(cross(normal, [0,0,1]))
    //  normalize(normal.y, -normal.x, 0)
    //
    // And because normal equals to [a,b,c]:
    //  normalize(b, -a)
    _dir = Vector2(frustumPlaneB, -frustumPlaneA);
    _dir.normalize();

    // Then we have to calculate a position on on both planes.
    //
    // Our own plane says:
    // 	N*(V - pos) = 0
    // And our XY plane says:
    //  posz = 0
    //
    // So we can solve this by combining the two:
    //   Nx(Vx - posx) + Ny(Vy - posy) - Nz*posz = 0
    //
    // And then let's assume Vx = 0:
    //   -Nx*posx + Ny(Vy - posy) - Nz*posz = 0
    //  Ny(Vy - posy) = Nx*posx + Nz*posz
    //  Vy = (Nx*posx + Nz*posz)/Ny + posy
    //  Vx = 0
    //
    // Note: this only works if Ny != 0. So we'll have to find a solution for when Ny ~= 0
    //
    // We can find that by solving for Vy = 0 (instead of Vx = 0):
    //  Nx(Vx - posx) - Ny*posy - Nz*posz = 0
    //  Nx(Vx - posx) = Ny*posy + Nz*posz
    //  Vx = (Ny*posy + Nz*posz)/Nx + posx
    //  Vy = 0
    //
    // And for both we subsitute normal with [a,b,c] and pos with [-d*a,-d*b,-d*c]:
    //
    // (1) Vy = (Nx*posx + Nz*posz)/Ny + posy
    //     Vy = (a*-d*a + c*-d*c)/b + -d*b
    //     Vy = -d*((a*a + c*c)/b + b)
    //
    // (2) Vx = (Ny*posy + Nz*posz)/Nx + posx
    //     Vx = (b*-d*b + c*-d*c)/a + -d*a
    //     Vx = -d*((b*v + c*c)/a + a)
    //
    if (frustumPlaneB.abs() > frustumPlaneA.abs()) {
      _pos = Vector2(
          0.0,
          -frustumPlaneD *
              ((frustumPlaneA * frustumPlaneA + frustumPlaneC * frustumPlaneC) /
                      frustumPlaneB +
                  frustumPlaneB));
    } else {
      _pos = Vector2(
          -frustumPlaneD *
              ((frustumPlaneB * frustumPlaneB + frustumPlaneC * frustumPlaneC) /
                      frustumPlaneA +
                  frustumPlaneA),
          0.0);
    }

    // Precalculate the perpendicular direction
    // (it will be the one pointing to the inside of the frustum)
    _perpDirInside = Vector2(-_dir.y, _dir.x);
  }

  /// Make a copy of frustum edge [other]
  FrustumEdge.copy(FrustumEdge other)
      : _dir = other._dir,
        _pos = other._pos,
        _perpDirInside = other._perpDirInside;

  /// Calculate intersection of this edge with [otherEdge]
  /// Returns the 2D intersection position
  Vector2 intersect(FrustumEdge otherEdge) {
    // Solve for:
    //  a(t) = b(t)
    // Where:
    //  a(u) = adir*u + apos
    //  b(v) = bdir*v + bpos
    //
    // Option 1:
    // Solve for x:
    //  adirx*u + aposx = bdirx*v + bposx
    //  u = (bdirx/adirx)*v + (bposx - aposx)/adirx
    //
    // Solve for y:
    //  adiry*u + aposy = bdiry*v + bposy
    //  adiry*((bdirx/adirx)*v + (bposx - aposx)/adirx) + aposy = bdiry*v + bposy
    //  adiry*(bdirx/adirx)*v + (adiry/adirx)*(bposx - aposx) + aposy = bdiry*v + bposy

    //  (adiry*(bdirx/adirx) - bdiry)*v = (bposy - aposy) - (adiry/adirx)*(bposx - aposx)
    //  v = ((bposy - aposy) - (adiry/adirx)*(bposx - aposx)) / (adiry*(bdirx/adirx) - bdiry)
    //
    // Option 2: Same as option 1, but then solved for y first and then for x,
    // which effectively gives the same solution as option 1, but then all x and y swapped.

    var v;

    if (_dir.x.abs() > _dir.y.abs()) {
      v = ((otherEdge._pos.y - _pos.y) -
              (_dir.y / _dir.x) * (otherEdge._pos.x - _pos.x)) /
          (_dir.y * (otherEdge._dir.x / _dir.x) - otherEdge._dir.y);
    } else {
      v = ((otherEdge._pos.x - _pos.x) -
              (_dir.x / _dir.y) * (otherEdge._pos.y - _pos.y)) /
          (_dir.x * (otherEdge._dir.y / _dir.y) - otherEdge._dir.x);
    }

    return (otherEdge._dir * v) + otherEdge._pos;
  }

  /// Check if [rect] is completely on the back side of this frustum's edge
  /// (so completely outside of the frustum)
  bool isCompletelyOnBackSide(Rect rect) {
    // Check the rect's 4 corners
    return _isOnBackSide(rect.min) &&
        _isOnBackSide(rect.max) &&
        _isOnBackSide(Vector2(rect.max.x, rect.min.y)) &&
        _isOnBackSide(Vector2(rect.min.x, rect.max.y));
  }

  /// Check if [pos] is on the back side of this frustum's edge
  /// (so outside of the frustum)
  bool _isOnBackSide(Vector2 pos) {
    return (pos - _pos).dot(_perpDirInside) < 0.0;
  }
}
