import 'dart:html';
import 'dart:web_gl';
import 'dart:math';
import 'dart:typed_data';
import 'mapdimensions.dart';

enum ETileMeshLoadingState { Unloaded, Downloading, Downloaded, Loaded }

class TileMesh {
  String filePath;
  ETileMeshLoadingState loadingState;
  Buffer vertexBuffer;
  Buffer indexBuffer;
  int numIndices;
  Float32List _downloadedVertices;
  Uint16List _downloadedIndices;
  final RenderingContext _gl;

  static int numTileMeshesLoading = 0;

  TileMesh(RenderingContext gl, String tileImagesBasePath,
      MapDimensions mapDimensions, int lod, Point<int> cellIndex)
      : _gl = gl,
        filePath = (lod < mapDimensions.numLods - 1)
            ? '$tileImagesBasePath/$lod/${cellIndex.y}/${cellIndex.x}.el'
            : '$tileImagesBasePath/$lod/0/0.el',
        loadingState = ETileMeshLoadingState.Unloaded;

  TileMesh.fromFilePath(RenderingContext gl, String filePath)
      : _gl = gl,
        filePath = filePath,
        loadingState = ETileMeshLoadingState.Unloaded;

  void startLoading() {
    assert(loadingState == ETileMeshLoadingState.Unloaded);
    loadingState = ETileMeshLoadingState.Downloading;
    numTileMeshesLoading++;

    HttpRequest.request(filePath, responseType: 'arraybuffer').then(_onLoaded);
  }

  void unload() {
    assert(loadingState == ETileMeshLoadingState.Loaded);

    _gl.deleteBuffer(vertexBuffer);
    _gl.deleteBuffer(indexBuffer);
    vertexBuffer = null;
    indexBuffer = null;

    loadingState = ETileMeshLoadingState.Unloaded;
  }

  void updateLoading() {
    assert(loadingState != ETileMeshLoadingState.Unloaded);

    if (loadingState == ETileMeshLoadingState.Downloaded) {
      vertexBuffer = _gl.createBuffer();
      _gl.bindBuffer(WebGL.ARRAY_BUFFER, vertexBuffer);
      _gl.enableVertexAttribArray(0);
      _gl.vertexAttribPointer(0, 3, WebGL.FLOAT, false, 0, 0);
      _gl.bufferData(
          WebGL.ARRAY_BUFFER, _downloadedVertices, WebGL.STATIC_DRAW);
      assert(_gl.getError() == 0);

      indexBuffer = _gl.createBuffer();
      _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, indexBuffer);
      _gl.bufferData(
          WebGL.ELEMENT_ARRAY_BUFFER, _downloadedIndices, WebGL.STATIC_DRAW);
      assert(_gl.getError() == 0);

      _downloadedVertices = null;
      _downloadedIndices = null;

      loadingState = ETileMeshLoadingState.Loaded;
    }
  }

  void _onLoaded(request) {
    assert(loadingState == ETileMeshLoadingState.Downloading);
    List<int> header = Uint32List.view(request.response);
    assert(header.length == 99079);

    // var w = header[0];
    // var h = header[1];
    var numVertices = header[2];
    numIndices = header[3];
    assert(numVertices == 16641);
    assert(numIndices == 98304);

    // Upload our vertices and indices
    _downloadedVertices = Float32List.fromList(Float32List.view(
        request.response, 16, numVertices * 3)); // 3 floats per vertex
    _downloadedIndices = Uint16List.fromList(Uint16List.view(
        request.response, 16 + numVertices * 3 * 4, numIndices));

    loadingState = ETileMeshLoadingState.Downloaded;
    numTileMeshesLoading--;
  }
}
