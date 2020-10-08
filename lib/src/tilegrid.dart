import 'dart:math';
import 'package:vector_math/vector_math.dart';

import 'frustum2d.dart';
import 'tile.dart';
import 'rect.dart';

/// A square 2D grid with tiles, used for storing all tiles of a specific LOD level.
class TileGrid {
  final int _lod;
  final int _numTilesPerAxis;
  final List<Tile> _tiles;
  final List<Rect> _borderCellsLeft;
  final List<Rect> _borderCellsRight;

  TileGrid(int lod, int numTilesPerAxis)
      : _lod = lod,
        _numTilesPerAxis = numTilesPerAxis,
        _tiles = List<Tile>(numTilesPerAxis * numTilesPerAxis),
        _borderCellsLeft = List<Rect>(numTilesPerAxis * numTilesPerAxis),
        _borderCellsRight = List<Rect>(numTilesPerAxis * numTilesPerAxis) {
    // Construct all border cell rectangles
    var tileSize = pow(2, _lod);
    for (var y = 0; y < numTilesPerAxis; ++y) {
      for (var x = 0; x < numTilesPerAxis; ++x) {
        _borderCellsLeft[y * numTilesPerAxis + x] = Rect(
            Vector2(-(x + 1) * tileSize, y * tileSize),
            Vector2(-x * tileSize, (y + 1) * tileSize));
        _borderCellsRight[y * numTilesPerAxis + x] = Rect(
            Vector2((numTilesPerAxis + x) * tileSize, y * tileSize),
            Vector2((numTilesPerAxis + x + 1) * tileSize, (y + 1) * tileSize));
      }
    }
  }

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
  void getTilesAndBorderCellsInFrustum(
      Frustum2d frustum, List<Tile> tiles, List<Rect> borderCells) {
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
    for (var y = tl.y; y <= br.y; ++y) {
      for (var x = tl.x; x <= br.x; ++x) {
        var t = _tiles[y * _numTilesPerAxis + x];

        if (frustum.overlaps(t.worldRect)) {
          tiles.add(t);
        }
      }
    }

    var numBorderCellsLeft = (tl.x < 0) ? (-tl.x) : 0;
    var numBorderCellsRight =
        (br.x >= _numTilesPerAxis) ? (br.x - (_numTilesPerAxis - 1)) : 0;

    // Gather all border cells that overlap our frustum, on the left and right
    for (var x = 0; x < numBorderCellsLeft; ++x) {
      for (var y = tl.y; y <= br.y; ++y) {
        var c = _borderCellsLeft[y * _numTilesPerAxis + x];

        if (frustum.overlaps(c)) {
          borderCells.add(c);
        }
      }
    }
    for (var x = 0; x < numBorderCellsRight; ++x) {
      for (var y = tl.y; y <= br.y; ++y) {
        var c = _borderCellsRight[y * _numTilesPerAxis + x];

        if (frustum.overlaps(c)) {
          borderCells.add(c);
        }
      }
    }
  }
}
