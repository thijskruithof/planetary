import 'dart:html';
import 'dart:web_gl';
import 'dart:typed_data';

CanvasElement canvas = document.getElementById('planetaryCanvas');
RenderingContext gl;

String vertexShaderSrc = '''
attribute vec2 position;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
}
''';

String fragmentShaderSrc = '''
precision mediump float;
void main() {
  gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
''';

Float32List vertices = Float32List.fromList([-0.5, 0.5, 0.0, -0.5, 0.5, 0.5]);

class InitShadersException implements Exception {
  InitShadersException(shadersLog);
}

void initGL() {
  gl.clearColor(0.0, 0.0, 0.0, 1.0);
  gl.viewport(0, 0, canvas.width, canvas.height);

  // Compile shaders and link
  var vs = gl.createShader(WebGL.VERTEX_SHADER);
  gl.shaderSource(vs, vertexShaderSrc);
  gl.compileShader(vs);

  var fs = gl.createShader(WebGL.FRAGMENT_SHADER);
  gl.shaderSource(fs, fragmentShaderSrc);
  gl.compileShader(fs);

  var program = gl.createProgram();
  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.linkProgram(program);
  gl.useProgram(program);

  // Check if shaders were compiled properly
  if (!gl.getShaderParameter(vs, WebGL.COMPILE_STATUS)) {
    throw InitShadersException(gl.getShaderInfoLog(vs));
  }

  if (!gl.getShaderParameter(fs, WebGL.COMPILE_STATUS)) {
    throw InitShadersException(gl.getShaderInfoLog(fs));
  }

  if (!gl.getProgramParameter(program, WebGL.LINK_STATUS)) {
    throw InitShadersException(gl.getProgramInfoLog(program));
  }

  // Create vbo
  var vbo = gl.createBuffer();
  gl.bindBuffer(WebGL.ARRAY_BUFFER, vbo);
  gl.bufferData(WebGL.ARRAY_BUFFER, vertices, WebGL.STATIC_DRAW);

  var posAttrib = gl.getAttribLocation(program, 'position');
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(posAttrib, 2, WebGL.FLOAT, false, 0, 0);

  print('planetary: initialized.');
}

void render(num deltaTime) {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  gl.clear(WebGL.COLOR_BUFFER_BIT);

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
