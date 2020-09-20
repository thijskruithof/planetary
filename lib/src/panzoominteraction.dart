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
  double _mouseZoomCurrentAmount;
  double _mouseZoomDesiredAmount;
  PanZoomInteractionSpot _mouseZoomInitialPoint;

  PanZoomInteraction(Element owner, View view)
      : _view = view,
        _isMousePanning = false,
        _isMouseZooming = false {
    owner.onMouseDown.listen(_onMouseDown);
    owner.onMouseUp.listen(_onMouseUp);
    owner.onMouseMove.listen(_onMouseMove);
    owner.onMouseWheel.listen(_onMouseWheel);
  }

  void update() {
    // Panning with the mouse?
    if (_isMousePanning) {
      // Calculate current mouse position in worldspace of the initial view
      var currentMouseWorldPos = _mousePanInitialPoint.view
          .screenToWorldPos(_mousePanCurrentPoint.screenPos);

      // Calculate delta with initial world position of the mouse
      var deltaMouseWorldPos =
          currentMouseWorldPos - _mousePanInitialPoint.worldPos;

      // Recalculate the world bottom center
      _view.worldBottomCenter =
          _mousePanInitialPoint.view.worldBottomCenter - deltaMouseWorldPos;
    }

    // Zooming with the mouse?
    if (_isMouseZooming) {
      _mouseZoomCurrentAmount +=
          (_mouseZoomDesiredAmount - _mouseZoomCurrentAmount) * 0.2;

      // Adjust scale
      _view.worldScale =
          _mouseZoomInitialPoint.view.worldScale * _mouseZoomCurrentAmount;

      // Calculate new world position of the initial mouse's screen pos
      var newZoomPivotWorldPos =
          _view.screenToWorldPos(_mouseZoomInitialPoint.screenPos);

      // Remove panning caused by scaling around the world center
      _view.worldBottomCenter -=
          (newZoomPivotWorldPos - _mouseZoomInitialPoint.worldPos);

      // Did we reach the desired zoom amount? Then stop zooming
      if ((_mouseZoomCurrentAmount - _mouseZoomDesiredAmount).abs() <= 0.01) {
        _isMouseZooming = false;
      }
    }
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

  void _onMouseWheel(WheelEvent event) {
    if (!_isMousePanning && !_isMouseZooming) {
      var maxZoomAmount = 0.75;
      var zoom_delta =
          max(-maxZoomAmount, min(maxZoomAmount, -event.deltaY / 200.0));

      _mouseZoomCurrentAmount = 1;
      _mouseZoomDesiredAmount = pow(2, -zoom_delta);
      _mouseZoomInitialPoint = new InteractionPoint(getMousePos());

      _isMouseZooming = true;
    }
  }
}
