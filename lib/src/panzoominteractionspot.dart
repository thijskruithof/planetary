import 'dart:math';

import 'package:vector_math/vector_math.dart';
import 'view.dart';

/// A spot on the screen where we're interacting with the pan/zoom,
/// either with touch or with a mouse.
class PanZoomInteractionSpot {
  /// Screen position
  final Vector2 screenPos;

  /// World position
  final Vector2 worldPos;

  /// View at the moment of the interaction
  final View view;

  PanZoomInteractionSpot(View view, Point<num> eventPos)
      : screenPos = Vector2(eventPos.x.toDouble(), eventPos.y.toDouble()),
        worldPos = view.screenToWorldPos(
            Vector2(eventPos.x.toDouble(), eventPos.y.toDouble())),
        view = View.copy(view);

  PanZoomInteractionSpot.copy(PanZoomInteractionSpot other)
      : screenPos = Vector2.copy(other.screenPos),
        worldPos = Vector2.copy(other.worldPos),
        view = View.copy(other.view);
}
