import 'dart:html';
import 'package:planetary/planetary.dart';

import 'tile.dart';
import 'tileimage.dart';

/// A small scale representation of the streaming status of each tile of the map
class StreamingMiniMap {
  final CanvasElement _canvas;
  CanvasRenderingContext2D _context2d;
  final Tile _rootTile;
  final MapDimensions _mapDimensions;

  final int tileScreenSize = 6;

  StreamingMiniMap(
      CanvasElement canvas, Tile rootTile, MapDimensions mapDimensions)
      : _canvas = canvas,
        _rootTile = rootTile,
        _mapDimensions = mapDimensions {
    canvas.hidden = true;

    canvas.width = _rootTile.worldRect.size.x.toInt() * tileScreenSize;
    canvas.height = _rootTile.worldRect.size.y.toInt() * tileScreenSize;

    _context2d = canvas.context2D;
  }

  bool get visible {
    return !_canvas.hidden;
  }

  set visible(bool v) {
    _canvas.hidden = !v;
  }

  void drawTile(Tile tile) {
    // if (!tile.isValid) return;
    // if (tile.albedoImage.loadingState == ETileImageLoadingState.Unloaded) {
    //   return;
    // }

    // var intensity = 255 - 255 * tile.lod / _mapDimensions.numLods;

    // if (tile.albedoImage.loadingState == ETileImageLoadingState.Loading)
    // _context2d.fillStyle = rgb(intensity, 0, 0);
    //   emissiveMaterial(intensity, 0, 0);
    // else
    //   emissiveMaterial(0, intensity, 0);

    // var center = tile.worldRect.center.clone().multiply(tileScale);
    // var size = tile.worldRect.size.clone().multiply(tileScale);
    // translate(center.x, center.y, 0.0);
    // plane(size.x, size.y);
    // translate(-center.x, -center.y, 0.0);
  }

  void update() {
    if (!visible) return;

    var ctx = canvas.context2D;
    ctx.fillStyle = '#000000';
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    _rootTile.visitChildren(drawTile);
  }
}
