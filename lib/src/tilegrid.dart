import 'dart:math';

import 'frustum2d.dart';
import 'tile.dart';

class TileGrid {
  final int _lod;
  final int _numTilesPerAxis;
  final List<Tile> _tiles;
  TileGrid(int lod, int numTilesPerAxis)
      : _lod = lod,
        _numTilesPerAxis = numTilesPerAxis,
        _tiles = List<Tile>(numTilesPerAxis * numTilesPerAxis);

  void addTile(Tile tile) {
    _tiles[tile.cellIndex.y * _numTilesPerAxis + tile.cellIndex.x] = tile;
  }

  /// Determine which of the tiles in this tilegrid are overlapping with [frustum]
  List<Tile> getTilesAndBorderCellsInFrustum(Frustum2d frustum) {
    var worldBoundsRect = frustum.worldBoundsRect;

    var tileSize = pow(2, _lod);
    var tl = Point<int>(
        (worldBoundsRect.min.x / tileSize)
            .floor()
            .clamp(0, _numTilesPerAxis - 1),
        (worldBoundsRect.min.y / tileSize)
            .floor()
            .clamp(0, _numTilesPerAxis - 1));
    var br = Point<int>(
        (worldBoundsRect.max.x / tileSize)
            .floor()
            .clamp(0, _numTilesPerAxis - 1),
        (worldBoundsRect.max.y / tileSize)
            .floor()
            .clamp(0, _numTilesPerAxis - 1));

    // Gather all tiles that overlap our frustum
    var visibleTiles = <Tile>[];
    for (var y = tl.y; y <= br.y; ++y) {
      for (var x = tl.x; x <= br.x; ++x) {
        var t = _tiles[y * _numTilesPerAxis + x];

        if (frustum.overlaps(t.worldRect)) {
          visibleTiles.add(t);
        }
      }
    }

    return visibleTiles;
  }
}
