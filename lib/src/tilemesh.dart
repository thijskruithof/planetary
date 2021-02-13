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
  Float32List _downloadedVertices;
  final RenderingContext _gl;
  final int lod;
  int cntr;

  static int numTileMeshesLoading = 0;

  TileMesh(RenderingContext gl, String tileImagesBasePath,
      MapDimensions mapDimensions, int lod, Point<int> cellIndex)
      : _gl = gl,
        filePath = (lod < mapDimensions.numLods - 1)
            ? '$tileImagesBasePath/$lod/${cellIndex.y}/${cellIndex.x}.el'
            : '$tileImagesBasePath/$lod/0/0.el',
        loadingState = ETileMeshLoadingState.Unloaded,
        lod = lod;

  void startLoading() {
    assert(loadingState == ETileMeshLoadingState.Unloaded);
    loadingState = ETileMeshLoadingState.Downloading;
    numTileMeshesLoading++;

    HttpRequest.request(filePath, responseType: 'arraybuffer').then(_onLoaded);
  }

  void unload() {
    assert(loadingState == ETileMeshLoadingState.Loaded);

    _gl.deleteBuffer(vertexBuffer);
    vertexBuffer = null;

    loadingState = ETileMeshLoadingState.Unloaded;
  }

  void updateLoading() {
    assert(loadingState != ETileMeshLoadingState.Unloaded);

    if (loadingState == ETileMeshLoadingState.Downloaded) {
      if (cntr > 0) {
        cntr--;
        return;
      }
      vertexBuffer = _gl.createBuffer();
      _gl.bindBuffer(WebGL.ARRAY_BUFFER, vertexBuffer);
      _gl.enableVertexAttribArray(0);
      _gl.vertexAttribPointer(0, 3, WebGL.FLOAT, false, 0, 0);
      _gl.bufferData(
          WebGL.ARRAY_BUFFER, _downloadedVertices, WebGL.STATIC_DRAW);
      var res = _gl.getError();
      assert(res == 0);

      _downloadedVertices = null;
      numTileMeshesLoading--;

      loadingState = ETileMeshLoadingState.Loaded;
    }
  }

  void _onLoaded(request) {
    assert(loadingState == ETileMeshLoadingState.Downloading);
    List<int> header = Uint32List.view(request.response);
    assert(header.length == 49926);

    // var w = header[0];
    // var h = header[1];
    var numVertices = header[2];
    assert(numVertices == 16641);

    // Upload our vertices and indices
    _downloadedVertices = Float32List.fromList(Float32List.view(
        request.response, 12, numVertices * 3)); // 3 floats per vertex

    loadingState = ETileMeshLoadingState.Downloaded;
    cntr = 100;

    // vertexBuffer = _gl.createBuffer();
    // _gl.bindBuffer(WebGL.ARRAY_BUFFER, vertexBuffer);
    // _gl.enableVertexAttribArray(0);
    // _gl.vertexAttribPointer(0, 3, WebGL.FLOAT, false, 0, 0);
    // _gl.bufferData(WebGL.ARRAY_BUFFER, _downloadedVertices, WebGL.STATIC_DRAW);
    // var res = _gl.getError();
    // assert(res == 0);

    // _downloadedVertices = null;

    // loadingState = ETileMeshLoadingState.Loaded;

    // numTileMeshesLoading--;
  }
}
