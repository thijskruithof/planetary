import 'dart:html';
import 'package:planetary/planetary.dart';

import 'tile.dart';
import 'tileimage.dart';
import 'view.dart';

/// A small scale representation of the streaming status of each tile of the map
class StreamingMiniMap {
  final CanvasElement _canvas;
  CanvasRenderingContext2D _context2d;
  final Tile _rootTile;
  final MapDimensions _mapDimensions;
  final View _view;

  final int _tileScreenSize = 6;
  final List<String> _tileColorLoading;
  final List<String> _tileColorLoaded;

  StreamingMiniMap(CanvasElement canvas, Tile rootTile,
      MapDimensions mapDimensions, View view)
      : _canvas = canvas,
        _rootTile = rootTile,
        _mapDimensions = mapDimensions,
        _view = view,
        _tileColorLoading = List<String>(mapDimensions.numLods),
        _tileColorLoaded = List<String>(mapDimensions.numLods) {
    canvas.hidden = true;

    canvas.width = _rootTile.worldRect.size.x.toInt() * _tileScreenSize;
    canvas.height = _rootTile.worldRect.size.y.toInt() * _tileScreenSize;

    _context2d = canvas.context2D;

    for (var i = 0; i < mapDimensions.numLods; ++i) {
      var intensity = 255.0 - 255.0 * i / mapDimensions.numLods;
      _tileColorLoading[i] = 'rgb(' + intensity.toInt().toString() + ', 0, 0)';
      _tileColorLoaded[i] = 'rgb(0, ' + intensity.toInt().toString() + ', 0)';
    }
  }

  bool get visible {
    return !_canvas.hidden;
  }

  set visible(bool v) {
    _canvas.hidden = !v;
  }

  void drawTile(Tile tile) {
    if (!tile.isValid ||
        tile.albedoImage.loadingState == ETileImageLoadingState.Unloaded) {
      return;
    }

    if (tile.albedoImage.loadingState == ETileImageLoadingState.Loading) {
      _context2d.fillStyle = _tileColorLoading[tile.lod];
    } else {
      _context2d.fillStyle = _tileColorLoaded[tile.lod];
    }

    // Draw all tiles
    _context2d.fillRect(
        tile.worldRect.min.x * _tileScreenSize,
        tile.worldRect.min.y * _tileScreenSize,
        tile.worldRect.size.x * _tileScreenSize,
        tile.worldRect.size.y * _tileScreenSize);

    // Draw frustum
    _context2d.fillStyle = 'rgba(0,0,0,0.0)';
    _context2d.strokeStyle = 'rgba(255,255,0,0.7)';
    _context2d.beginPath();
    _context2d.moveTo(_view.camera.frustum.posTopLeft.x * _tileScreenSize,
        _view.camera.frustum.posTopLeft.y * _tileScreenSize);
    _context2d.lineTo(_view.camera.frustum.posTopRight.x * _tileScreenSize,
        _view.camera.frustum.posTopRight.y * _tileScreenSize);
    _context2d.lineTo(_view.camera.frustum.posBottomRight.x * _tileScreenSize,
        _view.camera.frustum.posBottomRight.y * _tileScreenSize);
    _context2d.lineTo(_view.camera.frustum.posBottomLeft.x * _tileScreenSize,
        _view.camera.frustum.posBottomLeft.y * _tileScreenSize);
    _context2d.lineTo(_view.camera.frustum.posTopLeft.x * _tileScreenSize,
        _view.camera.frustum.posTopLeft.y * _tileScreenSize);
    _context2d.stroke();
  }

  void update() {
    if (!visible) return;

    _context2d.fillStyle = '#000000';
    _context2d.fillRect(0, 0, _canvas.width, _canvas.height);

    _rootTile.visitChildren(drawTile);
  }
}
