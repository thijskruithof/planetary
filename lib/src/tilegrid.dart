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

  /// Set references of each tile to their neighbouring tiles.
  void linkNeighbours() {
    for (var y = 0; y < _numTilesPerAxis; ++y) {
      for (var x = 0; x < _numTilesPerAxis; ++x) {
        var tile = _tiles[y * _numTilesPerAxis + x];

        for (var iy = -1; iy <= 1; ++iy) {
          var iiy = y + iy;
          if (iiy < 0 || iiy >= _numTilesPerAxis) continue;

          for (var ix = -1; ix <= 1; ++ix) {
            var iix = x + ix;
            if (iix < 0 || iix >= _numTilesPerAxis) continue;

            if (_tiles[iiy * _numTilesPerAxis + iix].isValid) {
              tile.neighbourTiles[(iy + 1) * 3 + (ix + 1)] =
                  _tiles[iiy * _numTilesPerAxis + iix];
            }
          }
        }
      }
    }
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
