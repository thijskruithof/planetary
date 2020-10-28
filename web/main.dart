import 'dart:html';
import 'dart:math';
import 'package:angular/angular.dart';
import 'package:pedantic/pedantic.dart';
import 'package:planetary/planetary.dart' as planetary;

import 'package:planetary/app_component.template.dart' as ng;

CanvasElement mapCanvas = document.getElementById('planetaryMapCanvas');
CanvasElement streamingMiniMapCanvas =
    document.getElementById('planetaryStreamingMiniMapCanvas');
planetary.Map map;
num canvasWidth;
num canvasHeight;

void render(num deltaTime) {
  // Resize our canvas?
  if (window.innerWidth != canvasWidth || window.innerHeight != canvasHeight) {
    canvasWidth = window.innerWidth;
    canvasHeight = window.innerHeight;
    mapCanvas.width = window.innerWidth;
    mapCanvas.height = window.innerHeight;

    map.resize(mapCanvas.width, mapCanvas.height);
  }

  // Render a frame
  map.render();

  // Schedule next frame
  window.animationFrame.then(render);
}

void onAppSettingsChanged(
    double reliefDepth, double pitchAngle, bool showStreamingMiniMap) {
  setMapSettings(reliefDepth, pitchAngle, showStreamingMiniMap);
}

void setMapSettings(
    double reliefDepth, double pitchAngle, bool showStreamingMiniMap) {
  map.reliefDepth = reliefDepth / 100.0;
  map.pitchAngle = pitchAngle * (pi / 180.0);
  map.streamingMiniMap.visible = showStreamingMiniMap;
}

void onAppSettingsDialogVisibilityChanged(bool isVisible) {
  map.panZoomInteraction.enabled = !isVisible;
}

// https://gist.github.com/m-decoster/ec44495badb54c26bb1c

void main() async {
  canvasWidth = mapCanvas.width;
  canvasHeight = mapCanvas.height;

  var dimensions = planetary.MapDimensions(512, 64, 32);

  map = planetary.Map(
      mapCanvas, streamingMiniMapCanvas, dimensions, 'tiles', 60.0);

  setMapSettings(ng.AppComponent.defaultReliefDepth,
      ng.AppComponent.defaultPitchAngle, false);

  await map.init();

  print('planetary: initialized.');

  unawaited(window.animationFrame.then(render));

  ng.AppComponent.onAppSettingsChanged = onAppSettingsChanged;
  ng.AppComponent.onAppSettingsDialogVisibilityChanged =
      onAppSettingsDialogVisibilityChanged;

  runApp(ng.AppComponentNgFactory);
}
