import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl';
import 'dart:math';
import 'package:vector_math/vector_math.dart';

import 'view.dart';
import 'mapdimensions.dart';
import 'tile.dart';
import 'rect.dart';
import 'tilegrid.dart';
import 'panzoominteraction.dart';

class InitShadersException implements Exception {
  String _shadersLog;
  InitShadersException(shadersLog) {
    _shadersLog = shadersLog;
  }
  @override
  String toString() {
    return _shadersLog;
  }
}

Float32List _quadVertices =
    Float32List.fromList([0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0]);

/// A planetary map
class Map {
  final RenderingContext _gl;
  final MapDimensions _dimensions;
  final String _tileImagesBasePath;
  int _screenWidth;
  int _screenHeight;
  View _view;
  Tile _rootTile;
  List<TileGrid> _tileGrids;
  PanZoomInteraction _panZoomInteraction;

  UniformLocation _uniWorldTopLeft;
  UniformLocation _uniWorldBottomRight;
  UniformLocation _uniViewProjectionMatrix;

  Map(CanvasElement canvas, MapDimensions dimensions, String tileImagesBasePath,
      double verticalFOVinDegrees, double pitchAngle)
      : _gl = canvas.getContext3d(),
        _dimensions = dimensions,
        _tileImagesBasePath = tileImagesBasePath {
    assert(_gl != null);

    _screenWidth = canvas.width;
    _screenHeight = canvas.height;

    // Construct our view
    _view = View(
        dimensions,
        Rect(Vector2.zero(),
            Vector2(_screenWidth.toDouble(), _screenHeight.toDouble())),
        verticalFOVinDegrees,
        pitchAngle);

    _view.fitToContent(Rect(Vector2(8, 8), Vector2(9, 9)));

    // Create our empty grids
    print('planetary: constructing tile grids.');
    _tileGrids = [];
    for (var lod = 0; lod < dimensions.numLods; lod++) {
      _tileGrids.add(TileGrid(lod, pow(2, (dimensions.numLods - 1) - lod)));
    }

    // Create our tree of tiles
    print('planetary: constructing tile tree.');
    var maxTilesPerAxisLod0 =
        max(dimensions.numTilesXLod0, dimensions.numTilesYLod0);
    _rootTile = Tile(
        null,
        dimensions.numLods - 1,
        Rect(
            Vector2.zero(),
            Vector2(maxTilesPerAxisLod0.toDouble(),
                maxTilesPerAxisLod0.toDouble())),
        Point<int>(0, 0),
        Point<int>(0, 0),
        tileImagesBasePath,
        dimensions);
    _tileGrids[dimensions.numLods - 1].addTile(_rootTile);
    _createTileChildrenRecursive(_rootTile);

    // Initialize our panning and zooming interaction
    _panZoomInteraction = PanZoomInteraction(canvas, _view);
  }

  /// Initialize the map
  /// (mandatory to call this before using it)
  void init() async {
    print('planetary: loading shaders.');

    // Compile shaders and link
    var vs = _gl.createShader(WebGL.VERTEX_SHADER);
    _gl.shaderSource(vs, await _downloadTextFile('tile.vert'));
    _gl.compileShader(vs);

    var fs = _gl.createShader(WebGL.FRAGMENT_SHADER);
    _gl.shaderSource(fs, await _downloadTextFile('tile.frag'));
    _gl.compileShader(fs);

    var program = _gl.createProgram();
    _gl.attachShader(program, vs);
    _gl.attachShader(program, fs);
    _gl.linkProgram(program);
    _gl.useProgram(program);

    // Check if shaders were compiled properly
    if (!_gl.getShaderParameter(vs, WebGL.COMPILE_STATUS)) {
      throw InitShadersException(_gl.getShaderInfoLog(vs));
    }

    if (!_gl.getShaderParameter(fs, WebGL.COMPILE_STATUS)) {
      throw InitShadersException(_gl.getShaderInfoLog(fs));
    }

    if (!_gl.getProgramParameter(program, WebGL.LINK_STATUS)) {
      throw InitShadersException(_gl.getProgramInfoLog(program));
    }

    // Create vbo
    var vbo = _gl.createBuffer();
    _gl.bindBuffer(WebGL.ARRAY_BUFFER, vbo);
    _gl.bufferData(WebGL.ARRAY_BUFFER, _quadVertices, WebGL.STATIC_DRAW);

    var posAttrib = _gl.getAttribLocation(program, 'aPosition');
    _gl.enableVertexAttribArray(0);
    _gl.vertexAttribPointer(posAttrib, 2, WebGL.FLOAT, false, 0, 0);

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.viewport(0, 0, _screenWidth, _screenHeight);

    _uniWorldTopLeft = _gl.getUniformLocation(program, 'uWorldTopLeft');
    _uniWorldBottomRight = _gl.getUniformLocation(program, 'uWorldBottomRight');
    _uniViewProjectionMatrix =
        _gl.getUniformLocation(program, 'uViewProjectionMatrix');
  }

  /// Resize the map's dimensions to [screenWidth] x [screenHeight] pixels
  void resize(num screenWidth, num screenHeight) {
    _screenWidth = screenWidth;
    _screenHeight = screenHeight;
    _gl.viewport(0, 0, screenWidth, screenHeight);
    _view.screenRect = Rect(Vector2.zero(), Vector2(screenWidth, screenHeight));
  }

  /// Render the map
  void render() {
    _panZoomInteraction.update();

    _gl.clear(WebGL.COLOR_BUFFER_BIT);

    var desiredLod = _calcDesiredLod();

    var visibleTiles = _tileGrids[desiredLod]
        .getTilesAndBorderCellsInFrustum(_view.camera.frustum);

    for (var visibleTile in visibleTiles) {
      if (!visibleTile.isValid) {
        continue;
      }

      var uvRect = Rect(Vector2.zero(), Vector2(1.0, 1.0));

      _drawTileQuad(visibleTile, desiredLod, visibleTile.worldRect, uvRect);
    }
  }

  /// Calculate the lowest LOD level we like to see on screen
  int _calcDesiredLod() {
    var bottomViewWorldWidth = _view.screenToWorldPos(_view.screenRect.max).x -
        _view
            .screenToWorldPos(
                Vector2(_view.screenRect.min.x, _view.screenRect.max.y))
            .x;

    var numTilePixelsOnScreen = bottomViewWorldWidth * _dimensions.tileSize;
    var numTilePixelsPerScreenPixel =
        numTilePixelsOnScreen / _view.screenRect.size.x;

    var lod = max(1.0, numTilePixelsPerScreenPixel);
    var lodInt = (log(lod) / log(2.0)).round();
    lodInt = min(_dimensions.numLods - 1, lodInt);

    return lodInt;
  }

  void _drawTileQuad(Tile tile, int desiredLod, Rect worldRect, Rect uvRect) {
    _gl.uniform2f(_uniWorldTopLeft, worldRect.min.x, worldRect.min.y);
    _gl.uniform2f(_uniWorldBottomRight, worldRect.max.x, worldRect.max.y);
    _gl.uniformMatrix4fv(
        _uniViewProjectionMatrix, false, _view.camera.viewProjectionMatrix);

    _gl.drawArrays(WebGL.TRIANGLE_STRIP, 0, 4);
  }

  Future<String> _downloadTextFile(String url) {
    return HttpRequest.getString(url);
  }

  /// Create child tiles for the given tile, for all lod levels until lod 0.
  void _createTileChildrenRecursive(Tile tile) {
    if (tile.lod == 0) return;

    var childTileSize = tile.worldRect.size * 0.5;

    for (var y = 0; y < 2; ++y) {
      for (var x = 0; x < 2; ++x) {
        var rectMin = tile.worldRect.min +
            Vector2(childTileSize.x * x, childTileSize.y * y);
        var rect = Rect(rectMin, rectMin + childTileSize);
        var newTile = Tile(
            tile,
            tile.lod - 1,
            rect,
            Point<int>(tile.cellIndex.x * 2 + x, tile.cellIndex.y * 2 + y),
            Point<int>(x, y),
            _tileImagesBasePath,
            _dimensions);
        tile.children.add(newTile);

        _tileGrids[tile.lod - 1].addTile(newTile);

        _createTileChildrenRecursive(newTile);
      }
    }
  }
}
