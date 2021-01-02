import 'dart:math';
import 'dart:web_gl';
import 'package:planetary/planetary.dart';

import 'rect.dart';
import 'mapdimensions.dart';
import 'tileimage.dart';
import 'tilemesh.dart';

/// A description of a single tile
class Tile {
  final Tile parent;
  final List<Tile> children;
  final int lod;
  final Rect worldRect;
  final Point<int> cellIndex;
  final Point<int> childIndex;
  final bool isValid;
  bool isVisible;
  final TileImage albedoImage;
  final TileImage elevationImage;
  final TileMesh mesh;
  List<Tile> neighbourTiles; // 3x3 neighbour tiles

  Tile(
      Tile parent,
      int lod,
      Rect worldRect,
      Point<int> cellIndex,
      Point<int> childIndex,
      RenderingContext gl,
      String tileImagesBasePath,
      MapDimensions mapDimensions)
      : parent = parent,
        children = List<Tile>.empty(growable: true),
        lod = lod,
        worldRect = Rect.copy(worldRect),
        cellIndex = Point<int>(cellIndex.x, cellIndex.y),
        childIndex = Point<int>(childIndex.x, childIndex.y),
        isValid = (worldRect.min.x < mapDimensions.numTilesXLod0) &&
            (worldRect.min.y < mapDimensions.numTilesYLod0),
        isVisible = false,
        albedoImage = TileImage(
            gl, tileImagesBasePath, mapDimensions, lod, cellIndex, ''),
        elevationImage = TileImage(gl, tileImagesBasePath + '/prev',
            mapDimensions, lod, cellIndex, '_e'),
        mesh = TileMesh(gl, tileImagesBasePath, mapDimensions, lod, cellIndex),
        neighbourTiles = List<Tile>(9);

  void visitChildren(Function(Tile) visitor) {
    if (isValid == false) return;

    visitor(this);

    for (var child in children) {
      if (child != null) child.visitChildren(visitor);
    }
  }

  void visitParents(Function(Tile) visitor) {
    var tile = this;
    while (tile != null) {
      visitor(tile);
      tile = tile.parent;
    }
  }
}
