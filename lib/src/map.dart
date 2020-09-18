import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl';
import 'dart:math';
import 'package:vector_math/vector_math.dart';

import 'view.dart';
import 'mapdimensions.dart';
import 'tile.dart';
import 'rect.dart';

class InitShadersException implements Exception {
  InitShadersException(shadersLog);
}

Float32List _vertices =
    Float32List.fromList([-0.95, 0.95, 0.0, -0.95, 0.95, 0.95]);

/// A planetary map
class Map {
  final RenderingContext _gl;
  final MapDimensions _dimensions;
  final String _tileImagesBasePath;
  int _screenWidth;
  int _screenHeight;
  View _view;
  Tile _rootTile;

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

    // Create our tree of tiles
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
    _createTileChildrenRecursive(_rootTile);
  }

  /// Initialize the map
  /// (mandatory to call this before using it)
  void init() async {
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
    _gl.bufferData(WebGL.ARRAY_BUFFER, _vertices, WebGL.STATIC_DRAW);

    var posAttrib = _gl.getAttribLocation(program, 'position');
    _gl.enableVertexAttribArray(0);
    _gl.vertexAttribPointer(posAttrib, 2, WebGL.FLOAT, false, 0, 0);

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.viewport(0, 0, _screenWidth, _screenHeight);
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
    _gl.clear(WebGL.COLOR_BUFFER_BIT);
    _gl.drawArrays(WebGL.TRIANGLES, 0, 3);
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

        //gTileGrids[tile.lod - 1].addTile(newTile);

        _createTileChildrenRecursive(newTile);
      }
    }
  }
}
