import 'dart:html';
import 'dart:web_gl';
import 'dart:math';
import 'mapdimensions.dart';

enum ETileImageLoadingState { Unloaded, Loading, Loaded }

class TileImage {
  final String filePath;
  ETileImageLoadingState loadingState;
  final Texture texture;
  final RenderingContext _gl;

  static int numTileImagesLoading = 0;

  TileImage(
      RenderingContext gl,
      String tileImagesBasePath,
      MapDimensions mapDimensions,
      int lod,
      Point<int> cellIndex,
      String filenameSuffix)
      : _gl = gl,
        filePath = (lod < mapDimensions.numLods - 1)
            ? '$tileImagesBasePath/$lod/${cellIndex.y}/${cellIndex.x}$filenameSuffix.jpg'
            : '$tileImagesBasePath/$lod/0/0$filenameSuffix.jpg',
        loadingState = ETileImageLoadingState.Unloaded,
        texture = gl.createTexture();

  TileImage.fromFilePath(RenderingContext gl, String filePath)
      : _gl = gl,
        filePath = filePath,
        loadingState = ETileImageLoadingState.Unloaded,
        texture = gl.createTexture();

  void startLoading() {
    loadingState = ETileImageLoadingState.Loading;
    numTileImagesLoading++;

    var image = ImageElement();
    image.onLoad.listen(_onLoad);
    image.onError.listen(_onError);
    image.src = filePath;
  }

  void _onLoad(event) {
    _gl.pixelStorei(WebGL.UNPACK_FLIP_Y_WEBGL, 0);
    _gl.bindTexture(WebGL.TEXTURE_2D, texture);
    _gl.texImage2D(
      WebGL.TEXTURE_2D,
      0,
      WebGL.RGBA,
      WebGL.RGBA,
      WebGL.UNSIGNED_BYTE,
      event.target,
    );
    _gl.texParameteri(
      WebGL.TEXTURE_2D,
      WebGL.TEXTURE_MAG_FILTER,
      WebGL.LINEAR,
    );
    _gl.texParameteri(
      WebGL.TEXTURE_2D,
      WebGL.TEXTURE_MIN_FILTER,
      WebGL.LINEAR_MIPMAP_NEAREST,
    );
    _gl.texParameteri(
      WebGL.TEXTURE_2D,
      WebGL.TEXTURE_WRAP_S,
      WebGL.CLAMP_TO_EDGE,
    );
    _gl.texParameteri(
      WebGL.TEXTURE_2D,
      WebGL.TEXTURE_WRAP_T,
      WebGL.CLAMP_TO_EDGE,
    );
    _gl.generateMipmap(WebGL.TEXTURE_2D);
    _gl.bindTexture(WebGL.TEXTURE_2D, null);

    loadingState = ETileImageLoadingState.Loaded;
    numTileImagesLoading--;
  }

  void _onError(event) {
    print('Error loading image from $filePath');
  }
}
