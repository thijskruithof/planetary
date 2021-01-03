import 'dart:async';
import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl';
import 'dart:math';
import 'package:vector_math/vector_math.dart';

import 'streamingminimap.dart';
import 'tileimage.dart';
import 'tilemesh.dart';
import 'tileimageregion.dart';
import 'view.dart';
import 'mapdimensions.dart';
import 'tile.dart';
import 'rect.dart';
import 'tilegrid.dart';
import 'panzoominteraction.dart';
// import 'screenquad.dart';

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

// Float32List _quadVertices =
//     Float32List.fromList([0.0, 1.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0]);
// [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0]);

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
  double _reliefDepth = 0.5;
  StreamingMiniMap _streamingMiniMap;

  TileImageRegion _nullTileAlbedoImageRegion;
  // TileImageRegion _nullTileElevationImageRegion;

  Program _shaderProgram;

  UniformLocation _uniWorldTopLeft;
  UniformLocation _uniWorldBottomRight;
  UniformLocation _uniViewProjectionMatrix;
  // UniformLocation _uniViewMatrix;

  // UniformLocation _uniReliefDepth;

  UniformLocation _uniAlbedoTopLeft;
  UniformLocation _uniAlbedoSize;
  UniformLocation _uniAlbedoSampler;

  Map(
      CanvasElement mapCanvas,
      CanvasElement streamingMiniMapCanvas,
      MapDimensions dimensions,
      String tileImagesBasePath,
      double verticalFOVinDegrees)
      : _gl = mapCanvas.getContext3d(),
        _dimensions = dimensions,
        _tileImagesBasePath = tileImagesBasePath {
    assert(_gl != null);

    _screenWidth = mapCanvas.width;
    _screenHeight = mapCanvas.height;

    // Construct our view
    _view = View(
        dimensions,
        Rect(Vector2.zero(),
            Vector2(_screenWidth.toDouble(), _screenHeight.toDouble())),
        verticalFOVinDegrees);

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

    // Link neighbours
    print('planetary: linking neighbouring tiles.');
    for (var tileGrid in _tileGrids) {
      tileGrid.linkNeighbours();
    }

    // Initialize our panning and zooming interaction
    _panZoomInteraction = PanZoomInteraction(_view);

    // Initialize our streaming mini map
    _streamingMiniMap =
        StreamingMiniMap(streamingMiniMapCanvas, _rootTile, _dimensions, _view);
  }

  /// Initialize the map
  /// (mandatory to call this before using it)
  Future<void> init() async {
    // Set up our null tile images
    print('planetary: loading nulltile.');

    var nullTileAlbedoImage = TileImage.fromFilePath(_gl, 'nulltile.jpg');
    // var nullTileElevationImage = TileImage.fromFilePath(_gl, 'nulltile_e.jpg');
    _nullTileAlbedoImageRegion =
        TileImageRegion(nullTileAlbedoImage, Rect.unit());
    // _nullTileElevationImageRegion =
    //     TileImageRegion(nullTileElevationImage, Rect.unit());
    nullTileAlbedoImage.startLoading();
    // nullTileElevationImage.startLoading();

    print('planetary: loading shaders.');

    // Compile shaders and link
    var vs = _gl.createShader(WebGL.VERTEX_SHADER);
    _gl.shaderSource(vs, await _downloadTextFile('tile.vert'));
    _gl.compileShader(vs);

    var fs = _gl.createShader(WebGL.FRAGMENT_SHADER);
    _gl.shaderSource(fs, await _downloadTextFile('tile.frag'));
    _gl.compileShader(fs);

    _shaderProgram = _gl.createProgram();
    _gl.attachShader(_shaderProgram, vs);
    _gl.attachShader(_shaderProgram, fs);
    _gl.linkProgram(_shaderProgram);
    _gl.useProgram(_shaderProgram);

    // Check if shaders were compiled properly
    if (!_gl.getShaderParameter(vs, WebGL.COMPILE_STATUS)) {
      throw InitShadersException(_gl.getShaderInfoLog(vs));
    }

    if (!_gl.getShaderParameter(fs, WebGL.COMPILE_STATUS)) {
      throw InitShadersException(_gl.getShaderInfoLog(fs));
    }

    if (!_gl.getProgramParameter(_shaderProgram, WebGL.LINK_STATUS)) {
      throw InitShadersException(_gl.getProgramInfoLog(_shaderProgram));
    }

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.viewport(0, 0, _screenWidth, _screenHeight);

    // Resolve our uniforms
    _uniWorldTopLeft = _gl.getUniformLocation(_shaderProgram, 'uWorldTopLeft');
    _uniWorldBottomRight =
        _gl.getUniformLocation(_shaderProgram, 'uWorldBottomRight');
    _uniViewProjectionMatrix =
        _gl.getUniformLocation(_shaderProgram, 'uViewProjectionMatrix');
    // _uniViewMatrix = _gl.getUniformLocation(_shaderProgram, 'uViewMatrix');
    // _uniReliefDepth = _gl.getUniformLocation(_shaderProgram, 'uReliefDepth');

    _uniAlbedoSampler =
        _gl.getUniformLocation(_shaderProgram, 'uAlbedoSampler');
    _uniAlbedoTopLeft =
        _gl.getUniformLocation(_shaderProgram, 'uAlbedoTopLeft');
    _uniAlbedoSize = _gl.getUniformLocation(_shaderProgram, 'uAlbedoSize');

    assert(_uniWorldTopLeft != null);
    assert(_uniWorldBottomRight != null);
    assert(_uniViewProjectionMatrix != null);
    // assert(_uniViewMatrix != null);
    // assert(_uniReliefDepth != null);

    assert(_uniAlbedoSampler != null);
    assert(_uniAlbedoTopLeft != null);
    assert(_uniAlbedoSize != null);

    print('planetary: initialized!');
  }

  double get reliefDepth {
    return _reliefDepth;
  }

  set reliefDepth(double value) {
    _reliefDepth = value;
  }

  double get pitchAngle {
    return _view.cameraPitchAngle;
  }

  set pitchAngle(double value) {
    _view.cameraPitchAngle = value;
  }

  PanZoomInteraction get panZoomInteraction {
    return _panZoomInteraction;
  }

  StreamingMiniMap get streamingMiniMap {
    return _streamingMiniMap;
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
    _rootTile.visitChildren((tile) => {tile.isVisible = false});

    // Determine what is visible
    var desiredLod = _calcDesiredLod();

    var visibleTiles = <Tile>[];
    var borderCells = <Rect>[];

    _tileGrids[desiredLod].getTilesAndBorderCellsInFrustum(
        _view.camera.frustum, visibleTiles, borderCells);

    _gl.clear(WebGL.COLOR_BUFFER_BIT);

    _gl.useProgram(_shaderProgram);

    // Bind our camera matrices
    _gl.uniformMatrix4fv(
        _uniViewProjectionMatrix, false, _view.camera.viewProjectionMatrix);
    // _gl.uniformMatrix4fv(_uniViewMatrix, false, _view.camera.viewMatrix);

    // Set the relief depth
    //_gl.uniform1f(_uniReliefDepth, _reliefDepth / pow(2.0, desiredLod));
    // _gl.uniform1f(_uniReliefDepth, _reliefDepth);

    // Draw all visible tiles
    for (var visibleTile in visibleTiles) {
      if (!visibleTile.isValid) {
        continue;
      }

      // Mark this tile as being visible, uncluding all its parents
      visibleTile.visitParents((tile) => {tile.isVisible = true});

      _drawTileMesh(visibleTile);
    }

    // Unbind all buffers and textures
    _gl.bindBuffer(WebGL.ARRAY_BUFFER, null);
    _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, null);
    _gl.activeTexture(WebGL.TEXTURE0);
    _gl.bindTexture(WebGL.TEXTURE_2D, null);

    // // Draw all border cells
    // for (var borderCell in borderCells) {
    //   _drawBorderCellQuad(borderCell);
    // }

    // Update loading and unloading
    _updateTileLoading(desiredLod);
    _updateTileUnloading();

    // Update the streaming minimap
    _streamingMiniMap.update();
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

  /// Draw a single tile
  void _drawTileMesh(Tile tile) {
    if (tile.mesh.loadingState != ETileMeshLoadingState.Loaded) return;

    // Get our albedo image and region
    var albedoImageRegion = _getTileAlbedoImageRegion(tile);
    if (albedoImageRegion.image.loadingState != ETileImageLoadingState.Loaded) {
      return;
    }

    // Set albedo image's uv coordinates
    _gl.uniform2f(_uniAlbedoTopLeft, albedoImageRegion.region.min.x,
        albedoImageRegion.region.min.y);
    _gl.uniform2f(_uniAlbedoSize, albedoImageRegion.region.size.x,
        albedoImageRegion.region.size.y);

    // Bind albedo texture
    _gl.activeTexture(WebGL.TEXTURE0);
    _gl.bindTexture(WebGL.TEXTURE_2D, albedoImageRegion.image.texture);
    _gl.uniform1i(_uniAlbedoSampler, 0);

    // Our quad's corner coords
    _gl.uniform2f(_uniWorldTopLeft, tile.worldRect.min.x, tile.worldRect.min.y);
    _gl.uniform2f(
        _uniWorldBottomRight, tile.worldRect.max.x, tile.worldRect.max.y);

    var mesh = tile.mesh;
    // var t = tile;
    // while (t.lod < 2) {
    //   t = t.parent;
    //   mesh = t.mesh;
    // }

    // Bind vertices and indices
    _gl.bindBuffer(WebGL.ARRAY_BUFFER, mesh.vertexBuffer);
    _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, mesh.indexBuffer);
    _gl.enableVertexAttribArray(0);
    _gl.vertexAttribPointer(0, 3, WebGL.FLOAT, false, 0, 0);

    // Draw our triangles
    _gl.drawElements(WebGL.TRIANGLES, mesh.numIndices, WebGL.UNSIGNED_SHORT, 0);
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

    // If we don't have any image loaded for this tile, simply show the null tile.
    if (tile == null ||
        tile.albedoImage.loadingState != ETileImageLoadingState.Loaded) {
      return _nullTileAlbedoImageRegion;
    }

    return TileImageRegion(tile.albedoImage, imageRect);
  }

  //   return TileImageRegion(tile.elevationImage, imageRect);
  // }

  // /// Draw a single quad of a border cell
  // void _drawBorderCellQuad(Rect rect) {
  //   // Set current cell uniforms (cell 0)
  //   _setTileCellUniforms(0, null);
  //   // Set left/right cell uniforms (cell 1)
  //   _setTileCellUniforms(1, null);
  //   // Set above/below cell uniforms (cell 2)
  //   _setTileCellUniforms(2, null);
  //   // Set diagonal cell uniforms (cell 3)
  //   _setTileCellUniforms(3, null);

  //   // Our quad's corner coords
  //   _gl.uniform2f(_uniWorldTopLeft, rect.min.x, rect.min.y);
  //   _gl.uniform2f(_uniWorldBottomRight, rect.max.x, rect.max.y);
  //   _gl.uniform2f(_uniUVTopLeft, 0, 0);
  //   _gl.uniform2f(_uniUVBottomRight, 1, 1);

  //   // Draw a single quad
  //   _gl.drawArrays(WebGL.TRIANGLE_STRIP, 0, 4);
  // }

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
  bool _canStartLoadingTileAsset() {
    const maxNumSimultaneousAssetsBeingLoaded = 6;

    return (TileImage.numTileImagesLoading + TileMesh.numTileMeshesLoading) <
        maxNumSimultaneousAssetsBeingLoaded;
  }

  void _updateTileLoading(int desiredLod) {
    var tilesToLoad = _getTilesToLoad(desiredLod);

    for (var tile in tilesToLoad) {
      if (!_canStartLoadingTileAsset()) {
        return;
      }

      // Do we have to load the albedo?
      if (tile.albedoImage.loadingState == ETileImageLoadingState.Unloaded) {
        tile.albedoImage.startLoading();
      }

      if (!_canStartLoadingTileAsset()) {
        return;
      }

      if (tile.mesh.loadingState == ETileMeshLoadingState.Unloaded) {
        tile.mesh.startLoading();
      }

      if (!_canStartLoadingTileAsset()) {
        return;
      }

      // Do we have to load the elevation?
      if (tile.elevationImage.loadingState == ETileImageLoadingState.Unloaded) {
        tile.elevationImage.startLoading();
      }
    }
  }

  void _updateTileUnloadingPerTile(tile) {
    if (tile.isVisible) {
      return;
    }

    if (tile.albedoImage.loadingState == ETileImageLoadingState.Loaded) {
      tile.albedoImage.unload();
    }

    if (tile.elevationImage.loadingState == ETileImageLoadingState.Loaded) {
      tile.elevationImage.unload();
    }

    if (tile.mesh.loadingState == ETileMeshLoadingState.Loaded) {
      tile.mesh.unload();
    }
  }

  void _updateTileUnloading() {
    _rootTile.visitChildren(_updateTileUnloadingPerTile);
  }

  /// Determine which tiles to load.
  /// This returns the tiles that are on screen, for lods 4 to desired visible lod.
  List<Tile> _getTilesToLoad(int desiredLod) {
    var tilesPerLod = <List<Tile>>[];
    for (var i = 0; i < _dimensions.numLods; ++i) {
      tilesPerLod.add(<Tile>[]);
    }

    // Gather all visible tiles that need to have something loaded
    _rootTile.visitChildren((tile) => {
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
}
