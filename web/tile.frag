precision highp float;

varying vec2 vUV;

uniform sampler2D uSampler;

uniform vec2 uAlbedo00TopLeft;
uniform vec2 uAlbedo00Size;

void main() {
  vec2 uv = uAlbedo00TopLeft + vUV*uAlbedo00Size;
  gl_FragColor = texture2D(uSampler, uv);
}