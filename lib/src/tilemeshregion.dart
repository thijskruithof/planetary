import 'rect.dart';
import 'tilemesh.dart';

class TileMeshRegion {
  final TileMesh mesh;
  final int startIndex;
  final int numIndices;
  final Rect worldRect;
  final Rect uvRect;

  TileMeshRegion(TileMesh mesh, int startIndex, int numIndices, Rect worldRect,
      Rect uvRect)
      : mesh = mesh,
        startIndex = startIndex,
        numIndices = numIndices,
        worldRect = worldRect,
        uvRect = uvRect;
}
