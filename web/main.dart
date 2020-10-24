import 'dart:html';
import 'package:angular/angular.dart';
import 'package:pedantic/pedantic.dart';
import 'package:planetary/planetary.dart' as planetary;

import 'package:planetary/app_component.template.dart' as ng;

CanvasElement canvas = document.getElementById('planetaryCanvas');
planetary.Map map;
num counter;
num canvasWidth;
num canvasHeight;

void render(num deltaTime) {
  // Resize our canvas?
  if (window.innerWidth != canvasWidth || window.innerHeight != canvasHeight) {
    canvasWidth = window.innerWidth;
    canvasHeight = window.innerHeight;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    map.resize(canvas.width, canvas.height);
  }

  // Render a frame
  map.render();

  // Schedule next frame
  window.animationFrame.then(render);
}

void onSettingsChanged(double reliefDepth) {
  map.reliefDepth = reliefDepth;
}

// https://gist.github.com/m-decoster/ec44495badb54c26bb1c

void main() async {
  canvasWidth = canvas.width;
  canvasHeight = canvas.height;

  var dimensions = planetary.MapDimensions(512, 64, 32);

  map = planetary.Map(canvas, dimensions, 'tiles', 60.0, 28.0, 0.5);

  await map.init();

  print('planetary: initialized.');

  unawaited(window.animationFrame.then(render));

  ng.AppComponent.onAppSettingsChanged = onSettingsChanged;

  runApp(ng.AppComponentNgFactory);
}
