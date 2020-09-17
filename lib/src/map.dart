import 'dart:html';
import 'dart:typed_data';
import 'dart:web_gl';

class InitShadersException implements Exception {
  InitShadersException(shadersLog);
}

Float32List _vertices =
    Float32List.fromList([-0.95, 0.95, 0.0, -0.95, 0.95, 0.95]);

class Map {
  RenderingContext gl;
  num screenWidth;
  num screenHeight;

  Map(RenderingContext gl) : gl = gl;

  void init(num screenWidth, num screenHeight) async {
    // Compile shaders and link
    var vs = gl.createShader(WebGL.VERTEX_SHADER);
    gl.shaderSource(vs, await _downloadTextFile('tile.vert'));
    gl.compileShader(vs);

    var fs = gl.createShader(WebGL.FRAGMENT_SHADER);
    gl.shaderSource(fs, await _downloadTextFile('tile.frag'));
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
    gl.bufferData(WebGL.ARRAY_BUFFER, _vertices, WebGL.STATIC_DRAW);

    var posAttrib = gl.getAttribLocation(program, 'position');
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(posAttrib, 2, WebGL.FLOAT, false, 0, 0);

    gl.clearColor(0.0, 0.0, 0.0, 1.0);
    gl.viewport(0, 0, screenWidth, screenHeight);
  }

  void resize(num screenWidth, num screenHeight) {
    this.screenWidth = screenWidth;
    this.screenHeight = screenHeight;
    gl.viewport(0, 0, screenWidth, screenHeight);
  }

  void render() {
    gl.clear(WebGL.COLOR_BUFFER_BIT);
    gl.drawArrays(WebGL.TRIANGLES, 0, 3);
  }

  Future<String> _downloadTextFile(String url) {
    return HttpRequest.getString(url);
  }
}
