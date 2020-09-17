import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';
import 'package:planetary/planetary.dart' as planetary;

CanvasElement canvas = document.getElementById('planetaryCanvas');
RenderingContext gl;
planetary.Map map;
num counter;
num canvasWidth;
num canvasHeight;

Future<void> initGL() async {
  canvasWidth = canvas.width;
  canvasHeight = canvas.height;

  map = planetary.Map(gl);

  await map.init(canvas.width, canvas.height);

  print('planetary: initialized.');
}

void render(num deltaTime) {
  // Resize our canvas?
  if (window.innerWidth != canvasWidth || window.innerHeight != canvasHeight) {
    canvasWidth = window.innerWidth;
    canvasHeight = window.innerHeight;
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;

    map.resize(canvas.width, canvas.height);
  }

  map.render();

  // redraw when ready
  window.animationFrame.then(render);
}

// https://gist.github.com/m-decoster/ec44495badb54c26bb1c

void main() async {
  gl = canvas.getContext3d();
  assert(gl != null);

  counter = 0;

  await initGL();

  window.animationFrame.then(render);
}
