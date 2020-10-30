import 'dart:math';
import 'math.dart';

class MapDimensions {
  final int tileSize;
  final int numTilesXLod0;
  final int numTilesYLod0;
  final int numLods;

  MapDimensions(int tileSize, int numTilesXLod0, int numTilesYLod0)
      : tileSize = tileSize,
        numTilesXLod0 = numTilesXLod0,
        numTilesYLod0 = numTilesYLod0,
        numLods = max(log2(numTilesXLod0) + 1, log2(numTilesYLod0) + 1) {
    assert(numTilesXLod0 >= 1);
    assert(numTilesYLod0 >= 1);
    assert(tileSize > 0);
    assert(((log(tileSize) / log(2)) % 1) == 0);
  }
}
