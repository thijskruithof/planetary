import 'dart:math';
import 'dart:web_gl';
import 'package:planetary/planetary.dart';

import 'rect.dart';
import 'mapdimensions.dart';
import 'tileimage.dart';

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
        elevationImage = TileImage(
            gl, tileImagesBasePath, mapDimensions, lod, cellIndex, '_e');
}
