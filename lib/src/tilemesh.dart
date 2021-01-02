import 'dart:html';
import 'dart:web_gl';
import 'dart:math';
import 'dart:typed_data';
import 'mapdimensions.dart';

enum ETileMeshLoadingState { Unloaded, Loading, Loaded }

class TileMesh {
  final String filePath;
  ETileMeshLoadingState loadingState;
  Buffer vertexBuffer;
  Buffer indexBuffer;
  int numIndices;
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
    loadingState = ETileMeshLoadingState.Loading;
    numTileMeshesLoading++;

    HttpRequest.request(filePath, responseType: 'arraybuffer').then(_onLoaded);
  }

  void _onLoaded(request) {
    List<int> header = Uint32List.view(request.response);
    // var w = header[0];
    // var h = header[1];
    var numVertices = header[2];
    numIndices = header[3];

    // print(
    //     'LOADED MESH! $filePath is $w x $h and has $verts vertices and $inds indices.');

    // Upload our vertices and indices
    var vertices = Float32List.view(
        request.response, 16, numVertices * 3); // 3 floats per vertex
    var indices =
        Uint16List.view(request.response, 16 + numVertices * 3 * 4, numIndices);

    vertexBuffer = _gl.createBuffer();
    _gl.bindBuffer(WebGL.ARRAY_BUFFER, vertexBuffer);
    _gl.bufferData(WebGL.ARRAY_BUFFER, vertices, WebGL.STATIC_DRAW);

    indexBuffer = _gl.createBuffer();
    _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, indexBuffer);
    _gl.bufferData(WebGL.ELEMENT_ARRAY_BUFFER, indices, WebGL.STATIC_DRAW);

    loadingState = ETileMeshLoadingState.Loaded;
    numTileMeshesLoading--;
  }

  // void _onError(event) {
  //   print('Error loading mesh from $filePath');
  // }
}
