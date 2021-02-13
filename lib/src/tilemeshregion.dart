import 'tilemesh.dart';

class TileMeshRegion {
  final TileMesh mesh;
  final int startIndex;
  final int numIndices;

  TileMeshRegion(TileMesh mesh, int startIndex, int numIndices)
      : mesh = mesh,
        startIndex = startIndex,
        numIndices = numIndices;
}
