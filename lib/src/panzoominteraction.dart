import 'package:vector_math/vector_math.dart';
import 'dart:html';
import 'view.dart';
import 'panzoominteractionspot.dart';

class PanZoomInteraction {
  final View _view;

  bool _isMousePanning;
  PanZoomInteractionSpot _mousePanInitialPoint;
  PanZoomInteractionSpot _mousePanCurrentPoint;

  bool _isMouseZooming;

  PanZoomInteraction(Element owner, View view)
      : _view = view,
        _isMousePanning = false,
        _isMouseZooming = false {
    owner.onMouseDown.listen(_onMouseDown);
    owner.onMouseUp.listen(_onMouseUp);
    owner.onMouseMove.listen(_onMouseMove);
  }

  void _onMouseDown(MouseEvent event) {
    if (!_isMousePanning && !_isMouseZooming) {
      _mousePanInitialPoint = PanZoomInteractionSpot(
          _view, Vector2(event.client.x.toDouble(), event.client.y.toDouble()));
      _mousePanCurrentPoint =
          PanZoomInteractionSpot.copy(_mousePanInitialPoint);
      _isMousePanning = true;
    }
  }

  void _onMouseUp(MouseEvent event) {
    _isMousePanning = false;
  }

  void _onMouseMove(MouseEvent event) {
    if (_isMousePanning) {
      _mousePanCurrentPoint = PanZoomInteractionSpot(
          _view, Vector2(event.client.x.toDouble(), event.client.y.toDouble()));
    }
  }
}
