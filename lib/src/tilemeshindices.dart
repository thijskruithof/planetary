import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';

enum ETileMeshIndicesLoadingState { Loading, Loaded }

class TileMeshIndices {
  final String filePath;
  ETileMeshIndicesLoadingState loadingState;
  Buffer indexBuffer;
  int numIndices;
  int numQuadsPerAxis;
  final RenderingContext _gl;

  TileMeshIndices(RenderingContext gl, String filePath)
      : _gl = gl,
        filePath = filePath,
        loadingState = ETileMeshIndicesLoadingState.Loading {
    HttpRequest.request(filePath, responseType: 'arraybuffer').then(_onLoaded);
  }

  void _onLoaded(request) {
    List<int> header = Uint32List.view(request.response);
    assert(header.length == 49155);

    var w = header[0];
    // var h = header[1];
    numIndices = header[2];
    assert(numIndices == 98304);

    numQuadsPerAxis = w;

    // Upload our vertices and indices
    var downloadedIndices =
        Uint16List.fromList(Uint16List.view(request.response, 12, numIndices));

    indexBuffer = _gl.createBuffer();
    _gl.bindBuffer(WebGL.ELEMENT_ARRAY_BUFFER, indexBuffer);
    _gl.bufferData(
        WebGL.ELEMENT_ARRAY_BUFFER, downloadedIndices, WebGL.STATIC_DRAW);
    assert(_gl.getError() == 0);

    loadingState = ETileMeshIndicesLoadingState.Loaded;
  }
}
