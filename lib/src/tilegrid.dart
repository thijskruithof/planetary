import 'tile.dart';

class TileGrid {
  final int _lod;
  final int _numTilesPerAxis;
  final List<Tile> _tiles;
  TileGrid(int lod, int numTilesPerAxis)
      : _lod = lod,
        _numTilesPerAxis = numTilesPerAxis,
        _tiles = List<Tile>(numTilesPerAxis * numTilesPerAxis);

  void addTile(Tile tile) {
    _tiles[tile.cellIndex.y * _numTilesPerAxis + tile.cellIndex.x] = tile;
  }
}
