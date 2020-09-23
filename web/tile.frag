precision highp float;

varying vec2 vUV;

uniform sampler2D uSampler;

void main() {
  gl_FragColor = texture2D(uSampler, vec2(vUV.x, vUV.y));
}