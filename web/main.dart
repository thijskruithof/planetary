import 'dart:html';
import 'dart:web_gl';

CanvasElement canvas = document.getElementById('planetaryCanvas');
RenderingContext gl;

void initGL() {
  gl.clearColor(0.0, 0.0, 0.0, 1.0);
  gl.viewport(0, 0, canvas.width, canvas.height);
}

void render(num deltaTime) {
  gl.clear(0x00004000);

  // draw
//   gl.drawArrays(RenderingContext.TRIANGLES, 0, 3);

  // redraw when ready
  window.animationFrame.then(render);
}

// https://gist.github.com/m-decoster/ec44495badb54c26bb1c

void main() {
  gl = canvas.getContext3d();
  assert(gl != null);

  initGL();

  window.animationFrame.then(render);
}
