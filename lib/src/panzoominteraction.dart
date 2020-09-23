import 'dart:html';
import 'dart:math';
import 'view.dart';
import 'panzoominteractionspot.dart';
import 'panzoominteractiontouchinfo.dart';

/// Controller class reponsible for panning and zooming a view based on user input.
/// This currently supports mouse and touch input.
class PanZoomInteraction {
  final View _view;

  // Mouse-based panning
  bool _isMousePanning;
  PanZoomInteractionSpot _mousePanInitialPoint;
  PanZoomInteractionSpot _mousePanCurrentPoint;

  // Mouse-based zooming
  bool _isMouseZooming;
  double _mouseZoomCurrentAmount;
  double _mouseZoomDesiredAmount;
  PanZoomInteractionSpot _mouseZoomInitialPoint;

  // Currently active touches
  Map<int, PanZoomInteractionTouchInfo> _touchInfos;

  // Touch-based panning
  bool _isTouchPanning;
  PanZoomInteractionTouchInfo _touchPanTouchInfo;

  // Touch-based zooming
  bool _isTouchZooming;
  PanZoomInteractionTouchInfo _touchZoomTouchInfoA;
  PanZoomInteractionTouchInfo _touchZoomTouchInfoB;

  PanZoomInteraction(Element owner, View view)
      : _view = view,
        _isMousePanning = false,
        _isMouseZooming = false,
        _isTouchPanning = false,
        _isTouchZooming = false {
    // Mouse handlers
    owner.onMouseDown.listen(_onMouseDown);
    owner.onMouseUp.listen(_onMouseUp);
    owner.onMouseMove.listen(_onMouseMove);
    owner.onMouseWheel.listen(_onMouseWheel);

    // Touch handlers
    owner.onTouchStart.listen(_onTouchStart);
    owner.onTouchEnd.listen(_onTouchEnd);
    owner.onTouchMove.listen(_onTouchMove);
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

    // Panning with touch?
    if (_isTouchPanning) {
      // Calculate current touch position in worldspace of the initial view
      var currentTouchWorldPos = _touchPanTouchInfo.initialSpot.view
          .screenToWorldPos(_touchPanTouchInfo.currentSpot.screenPos);

      // Calculate delta with initial world position of the touch
      var deltaTouchWorldPos =
          currentTouchWorldPos - _touchPanTouchInfo.initialSpot.worldPos;

      // Recalculate the world bottom center
      _view.worldBottomCenter =
          _touchPanTouchInfo.initialSpot.view.worldBottomCenter -
              deltaTouchWorldPos;
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

    // Zooming with touch? (Pinch zoom)
    if (_isTouchZooming) {
      var initialWorldDelta = _touchZoomTouchInfoB.initialSpot.worldPos -
          _touchZoomTouchInfoA.initialSpot.worldPos;
      var initialWorldDistance = initialWorldDelta.length;
      var currentWorldDelta = _touchZoomTouchInfoB.currentSpot.worldPos -
          _touchZoomTouchInfoA.currentSpot.worldPos;
      var currentWorldDistance = currentWorldDelta.length;

      var scaleFactor = (currentWorldDistance > 0.0)
          ? (initialWorldDistance / currentWorldDistance)
          : 1.0;

      // Adjust scale
      _view.worldScale = _touchZoomTouchInfoA.initialSpot.view.worldScale *
          pow(scaleFactor, 0.7);
    }
  }

  void _onMouseDown(MouseEvent event) {
    if (!_isMousePanning && !_isMouseZooming) {
      _mousePanInitialPoint = PanZoomInteractionSpot(_view, event.client);
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
      _mousePanCurrentPoint = PanZoomInteractionSpot(_view, event.client);
    }
  }

  void _onMouseWheel(WheelEvent event) {
    if (!_isMousePanning && !_isMouseZooming) {
      var maxZoomAmount = 0.75;
      var zoom_delta =
          max(-maxZoomAmount, min(maxZoomAmount, -event.deltaY / 200.0));

      _mouseZoomCurrentAmount = 1;
      _mouseZoomDesiredAmount = pow(2, -zoom_delta);
      _mouseZoomInitialPoint = PanZoomInteractionSpot(_view, event.client);

      _isMouseZooming = true;
    }
  }

  void _onTouchStart(TouchEvent event) {
    // Add all new touches to the touchInfos
    for (var touch in event.touches) {
      if (_touchInfos.containsKey(touch.identifier)) {
        continue;
      }

      var spot = PanZoomInteractionSpot(_view, touch.client);

      _touchInfos[touch.identifier] =
          PanZoomInteractionTouchInfo(touch.identifier, spot);
    }

    // Determine if we're panning (and with which touch)
    _isTouchPanning = _touchInfos.length == 1;
    if (_isTouchPanning) {
      _touchPanTouchInfo = _touchInfos[_touchInfos.keys.elementAt(0)];
    }

    // Determine if we're zooming (and with which two touches)
    _isTouchZooming = _touchInfos.length == 2;
    if (_isTouchZooming) {
      _touchZoomTouchInfoA = _touchInfos[_touchInfos.keys.elementAt(0)];
      _touchZoomTouchInfoB = _touchInfos[_touchInfos.keys.elementAt(1)];
    }
  }

  void _onTouchEnd(TouchEvent event) {
    var newTouchInfos = <int, PanZoomInteractionTouchInfo>{};

    // Copy over the start infos for only the still active touches
    for (var touch in event.touches) {
      newTouchInfos[touch.identifier] = _touchInfos[touch.identifier];
    }
    _touchInfos = newTouchInfos;

    // Determine if we're panning (and with which touch)
    _isTouchPanning = _touchInfos.length == 1;
    if (_isTouchPanning) {
      _touchPanTouchInfo = _touchInfos[_touchInfos.keys.elementAt(0)];

      if (_isTouchZooming) {
        _touchPanTouchInfo.initialSpot =
            PanZoomInteractionSpot.copy(_touchPanTouchInfo.currentSpot);
      }
    }

    // Determine if we're zooming (and with which two touches)
    _isTouchZooming = _touchInfos.length == 2;
    if (_isTouchZooming) {
      _touchZoomTouchInfoA = _touchInfos[_touchInfos.keys.elementAt(0)];
      _touchZoomTouchInfoB = _touchInfos[_touchInfos.keys.elementAt(1)];
    }
  }

  void _onTouchMove(TouchEvent event) {
    for (var touch in event.touches) {
      _touchInfos[touch.identifier].currentSpot =
          PanZoomInteractionSpot(_view, touch.client);
    }
  }
}
