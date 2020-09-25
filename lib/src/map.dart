import 'dart:async';
import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl';
import 'dart:math';
import 'package:planetary/src/tileimage.dart';
import 'package:vector_math/vector_math.dart';

import 'tileimageregion.dart';
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
  final double _reliefDepth;

  UniformLocation _uniWorldTopLeft;
  UniformLocation _uniWorldBottomRight;
  UniformLocation _uniUVTopLeft;
  UniformLocation _uniUVBottomRight;
  UniformLocation _uniViewProjectionMatrix;
  UniformLocation _uniViewMatrix;

  UniformLocation _uniReliefDepth;

  UniformLocation _uniAlbedo00TopLeft;
  UniformLocation _uniAlbedo00Size;
  UniformLocation _uniAlbedoSampler;
  UniformLocation _uniElevation00TopLeft;
  UniformLocation _uniElevation00Size;
  UniformLocation _uniElevationSampler;

  Map(CanvasElement canvas, MapDimensions dimensions, String tileImagesBasePath,
      double verticalFOVinDegrees, double pitchAngle, double reliefDepth)
      : _gl = canvas.getContext3d(),
        _dimensions = dimensions,
        _tileImagesBasePath = tileImagesBasePath,
        _reliefDepth = reliefDepth {
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
        _gl,
        tileImagesBasePath,
        dimensions);
    _tileGrids[dimensions.numLods - 1].addTile(_rootTile);
    _createTileChildrenRecursive(_rootTile);

    // Initialize our panning and zooming interaction
    _panZoomInteraction = PanZoomInteraction(canvas, _view);
  }

  /// Initialize the map
  /// (mandatory to call this before using it)
  Future<void> init() async {
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

    // Resolve our uniforms
    _uniWorldTopLeft = _gl.getUniformLocation(program, 'uWorldTopLeft');
    _uniWorldBottomRight = _gl.getUniformLocation(program, 'uWorldBottomRight');
    _uniUVTopLeft = _gl.getUniformLocation(program, 'uUVTopLeft');
    _uniUVBottomRight = _gl.getUniformLocation(program, 'uUVBottomRight');
    _uniViewProjectionMatrix =
        _gl.getUniformLocation(program, 'uViewProjectionMatrix');
    _uniViewMatrix = _gl.getUniformLocation(program, 'uViewMatrix');
    _uniReliefDepth = _gl.getUniformLocation(program, 'uReliefDepth');
    _uniAlbedoSampler = _gl.getUniformLocation(program, 'uAlbedo00Sampler');
    _uniAlbedo00TopLeft = _gl.getUniformLocation(program, 'uAlbedo00TopLeft');
    _uniAlbedo00Size = _gl.getUniformLocation(program, 'uAlbedo00Size');
    _uniElevationSampler =
        _gl.getUniformLocation(program, 'uElevation00Sampler');
    _uniElevation00TopLeft =
        _gl.getUniformLocation(program, 'uElevation00TopLeft');
    _uniElevation00Size = _gl.getUniformLocation(program, 'uElevation00Size');

    assert(_uniWorldTopLeft != null);
    assert(_uniWorldBottomRight != null);
    assert(_uniUVTopLeft != null);
    assert(_uniUVBottomRight != null);
    assert(_uniViewProjectionMatrix != null);
    assert(_uniViewMatrix != null);
    assert(_uniReliefDepth != null);
    assert(_uniAlbedoSampler != null);
    assert(_uniAlbedo00TopLeft != null);
    assert(_uniAlbedo00Size != null);
    assert(_uniElevationSampler != null);
    assert(_uniElevation00TopLeft != null);
    assert(_uniElevation00Size != null);
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

    // Mark all tiles as invisible
    _visitTileChildren(_rootTile, (tile) => {tile.isVisible = false});

    // Determine what is visible
    var desiredLod = _calcDesiredLod();

    var visibleTiles = _tileGrids[desiredLod]
        .getTilesAndBorderCellsInFrustum(_view.camera.frustum);

    _gl.clear(WebGL.COLOR_BUFFER_BIT);

    // Bind our camera matrices
    _gl.uniformMatrix4fv(
        _uniViewProjectionMatrix, false, _view.camera.viewProjectionMatrix);
    _gl.uniformMatrix4fv(_uniViewMatrix, false, _view.camera.viewMatrix);

    // Set the relief depth
    _gl.uniform1f(_uniReliefDepth, _reliefDepth / pow(2.0, desiredLod));

    for (var visibleTile in visibleTiles) {
      if (!visibleTile.isValid) {
        continue;
      }

      // Mark this tile as being visible, uncluding all its parents
      _visitTileParents(visibleTile, (tile) => {tile.isVisible = true});

      var uvRect = Rect(Vector2.zero(), Vector2(1.0, 1.0));

      _drawTileQuad(visibleTile, desiredLod, visibleTile.worldRect, uvRect);
    }

    // Update loading
    _updateTileLoading(desiredLod);
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

  /// Draw a single quad tile
  void _drawTileQuad(Tile tile, int desiredLod, Rect worldRect, Rect uvRect) {
    // Get our albedo and elevation images and their regions
    var albedoImageRegion = _getTileAlbedoImageRegion(tile);
    if (albedoImageRegion == null) return;
    var elevationImageRegion = _getTileElevationImageRegion(tile);
    if (elevationImageRegion == null) return;

    // Our quad's corner coords
    _gl.uniform2f(_uniWorldTopLeft, worldRect.min.x, worldRect.min.y);
    _gl.uniform2f(_uniWorldBottomRight, worldRect.max.x, worldRect.max.y);
    _gl.uniform2f(_uniUVTopLeft, uvRect.min.x, uvRect.min.y);
    _gl.uniform2f(_uniUVBottomRight, uvRect.max.x, uvRect.max.y);

    // Our albedo image's coordinates
    _gl.uniform2f(_uniAlbedo00TopLeft, albedoImageRegion.region.min.x,
        albedoImageRegion.region.min.y);
    _gl.uniform2f(_uniAlbedo00Size, albedoImageRegion.region.size.x,
        albedoImageRegion.region.size.y);

    // Our elevation image's coordinates
    _gl.uniform2f(_uniElevation00TopLeft, elevationImageRegion.region.min.x,
        elevationImageRegion.region.min.y);
    _gl.uniform2f(_uniElevation00Size, elevationImageRegion.region.size.x,
        elevationImageRegion.region.size.y);

    // Our albedo and elevation textures
    _gl.activeTexture(WebGL.TEXTURE0);
    _gl.bindTexture(WebGL.TEXTURE_2D, albedoImageRegion.image.texture);
    _gl.activeTexture(WebGL.TEXTURE1);
    _gl.bindTexture(WebGL.TEXTURE_2D, elevationImageRegion.image.texture);
    _gl.uniform1i(_uniAlbedoSampler, 0);
    _gl.uniform1i(_uniElevationSampler, 1);

    _gl.drawArrays(WebGL.TRIANGLE_STRIP, 0, 4);
  }

  /// Get the albedo image and the image's region
  TileImageRegion _getTileAlbedoImageRegion(Tile tile) {
    // Start with the full size image rect
    var imageRect = Rect(Vector2.zero(), Vector2(1, 1));

    // If our tile's image is not loaded find the first parent tile that has its image loaded.
    while (tile != null &&
        tile.albedoImage.loadingState != ETileImageLoadingState.Loaded) {
      // Recalculate our image rect
      var newImageRectSize = imageRect.size * 0.5;
      var newImageRectOffset = (imageRect.min * 0.5) +
          (Vector2(tile.childIndex.x.toDouble(), tile.childIndex.y.toDouble()) *
              0.5);
      imageRect =
          Rect(newImageRectOffset, newImageRectOffset + newImageRectSize);

      tile = tile.parent;
    }

    if (tile == null ||
        tile.albedoImage.loadingState != ETileImageLoadingState.Loaded) {
      return null;
    }

    return TileImageRegion(tile.albedoImage, imageRect);
  }

  /// Get the elevation image and the image's region
  TileImageRegion _getTileElevationImageRegion(Tile tile) {
    // Start with the full size image rect
    var imageRect = Rect(Vector2.zero(), Vector2(1, 1));

    // If our tile's image is not loaded find the first parent tile that has its image loaded.
    while (tile != null &&
        tile.elevationImage.loadingState != ETileImageLoadingState.Loaded) {
      // Recalculate our image rect
      var newImageRectSize = imageRect.size * 0.5;
      var newImageRectOffset = (imageRect.min * 0.5) +
          (Vector2(tile.childIndex.x.toDouble(), tile.childIndex.y.toDouble()) *
              0.5);
      imageRect =
          Rect(newImageRectOffset, newImageRectOffset + newImageRectSize);

      tile = tile.parent;
    }

    if (tile == null ||
        tile.elevationImage.loadingState != ETileImageLoadingState.Loaded) {
      return null;
    }

    return TileImageRegion(tile.elevationImage, imageRect);
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
            _gl,
            _tileImagesBasePath,
            _dimensions);
        tile.children.add(newTile);

        _tileGrids[tile.lod - 1].addTile(newTile);

        _createTileChildrenRecursive(newTile);
      }
    }
  }

  /// Determine if we can start loading another another tile image
  bool _canStartLoadingTileImage() {
    const maxNumSimultaneousImagesBeingLoaded = 6;

    return TileImage.numTileImagesLoading < maxNumSimultaneousImagesBeingLoaded;
  }

  void _updateTileLoading(int desiredLod) {
    var tilesToLoad = _getTilesToLoad(desiredLod);

    for (var tile in tilesToLoad) {
      if (!_canStartLoadingTileImage()) {
        return;
      }

      // Do we have to load the albedo?
      if (tile.albedoImage.loadingState == ETileImageLoadingState.Unloaded) {
        tile.albedoImage.startLoading();
      }

      if (!_canStartLoadingTileImage()) {
        return;
      }

      // Do we have to load the elevation?
      if (tile.elevationImage.loadingState == ETileImageLoadingState.Unloaded) {
        tile.elevationImage.startLoading();
      }
    }
  }

  /// Determine which tiles to load.
  /// This returns the tiles that are on screen, for lods 4 to desired visible lod.
  List<Tile> _getTilesToLoad(int desiredLod) {
    var tilesPerLod = <List<Tile>>[];
    for (var i = 0; i < _dimensions.numLods; ++i) {
      tilesPerLod.add(<Tile>[]);
    }

    // Gather all visible tiles that need to have something loaded
    _visitTileChildren(
        _rootTile,
        (tile) => {
              if (tile.lod >= desiredLod &&
                  tile.isVisible &&
                  (tile.albedoImage.loadingState ==
                          ETileImageLoadingState.Unloaded ||
                      tile.elevationImage.loadingState ==
                          ETileImageLoadingState.Unloaded))
                {tilesPerLod[tile.lod].add(tile)}
            });

    // Gather all tiles, LOD N first
    var result = tilesPerLod[tilesPerLod.length - 1];
    for (var j = tilesPerLod.length - 2; j >= 0; --j) {
      result.addAll(tilesPerLod[j]);
    }
    return result;
  }

  void _visitTileChildren(Tile tile, Function(Tile) visitor) {
    if (tile == null || tile.isValid == false) {
      return;
    }

    visitor(tile);

    for (var child in tile.children) {
      _visitTileChildren(child, visitor);
    }
  }

  void _visitTileParents(Tile tile, Function(Tile) visitor) {
    while (tile != null) {
      visitor(tile);
      tile = tile.parent;
    }
  }
}
