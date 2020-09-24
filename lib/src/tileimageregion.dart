import 'tileimage.dart';
import 'rect.dart';

class TileImageRegion {
  final TileImage image;
  final Rect region;

  TileImageRegion(TileImage image, Rect region)
      : image = image,
        region = region;
}
