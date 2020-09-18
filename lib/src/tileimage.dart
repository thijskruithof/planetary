import 'mapdimensions.dart';
import 'dart:math';

enum ETileImageLoadingState { Unloaded, Loading, Loaded }

class TileImage {
  final String filePath;
  ETileImageLoadingState loadingState;

  TileImage(String tileImagesBasePath, MapDimensions mapDimensions, int lod,
      Point<int> cellIndex, String filenameSuffix)
      : filePath = (lod < mapDimensions.numLods - 1)
            ? '$tileImagesBasePath/$lod/${cellIndex.y}/${cellIndex.x}$filenameSuffix.jpg'
            : '$tileImagesBasePath/$lod/0/0$filenameSuffix.jpg',
        loadingState = ETileImageLoadingState.Unloaded;
}
