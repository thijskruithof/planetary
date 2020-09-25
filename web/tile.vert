precision highp float;

// Position of corner vertex [0..1],[0..1]
attribute vec2 aPosition;

// World-space position of quad's corners
uniform vec2 uWorldTopLeft;
uniform vec2 uWorldBottomRight;

// UV coords of quad's corners
uniform vec2 uUVTopLeft;
uniform vec2 uUVBottomRight;

uniform mat4 uViewProjectionMatrix;
uniform mat4 uViewMatrix;

varying vec2 vUV;
varying vec3 vPositionView;
varying vec3 vEyeGroundNormal;
varying vec3 vEyeGroundTangent;
varying vec3 vEyeGroundBitangent;


void main() {
  vec2 worldPos = mix(uWorldTopLeft, uWorldBottomRight, aPosition);
  vec4 worldPos4 = vec4(worldPos, 0.0, 1.0);
  gl_Position = uViewProjectionMatrix * worldPos4; 

  vUV = mix(uUVTopLeft, uUVBottomRight, aPosition);

  vPositionView = (uViewMatrix * positionVec4).xyz;

  vEyeGroundNormal = (uViewMatrix * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
  vEyeGroundTangent = (uViewMatrix * vec4(1.0, 0.0, 0.0, 0.0)).xyz;
  vEyeGroundBitangent = cross(vEyeGroundNormal, vEyeGroundTangent); 
}