import 'package:planetary/src/panzoominteractionspot.dart';

/// Information about an active touch
class PanZoomInteractionTouchInfo {
  /// Identifier to uniquely identify the touch (equal to Touch.identifier)
  final int identifier;

  /// Spot where we initially touched
  PanZoomInteractionSpot initialSpot;

  /// Spot where the touch currently is
  PanZoomInteractionSpot currentSpot;

  PanZoomInteractionTouchInfo(
      int identifier, PanZoomInteractionSpot initialSpot)
      : identifier = identifier,
        initialSpot = PanZoomInteractionSpot.copy(initialSpot),
        currentSpot = PanZoomInteractionSpot.copy(initialSpot);
}
