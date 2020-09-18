precision highp float;

attribute vec2 aPosition;

uniform vec2 uWorldTopLeft;
uniform vec2 uWorldBottomRight;

uniform mat4 uViewProjectionMatrix;

varying vec2 vUV;

void main() {
  vec2 worldPos = mix(uWorldTopLeft, uWorldBottomRight, aPosition);
  vec4 worldPos4 = vec4(worldPos, 0.0, 1.0);
  gl_Position = uViewProjectionMatrix * positionVec4; 

  vUV = aPosition;
}