precision highp float;

varying vec2 vUV;

uniform sampler2D uAlbedo00Sampler;
uniform sampler2D uElevation00Sampler;

uniform vec2 uAlbedo00TopLeft;
uniform vec2 uAlbedo00Size;
uniform vec2 uElevation00TopLeft;
uniform vec2 uElevation00Size;

void main() {
  vec4 albedo = texture2D(uAlbedo00Sampler, uAlbedo00TopLeft + vUV*uAlbedo00Size);

  vec4 elevation = texture2D(uElevation00Sampler, uElevation00TopLeft + vUV*uElevation00Size);

  gl_FragColor = 0.001*albedo + elevation;
}