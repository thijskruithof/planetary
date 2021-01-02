precision highp float;

// Position of corner vertex [0..1],[0..1],[0..1]
attribute vec3 aPosition;

// World-space position of quad's corners
uniform vec2 uWorldTopLeft;
uniform vec2 uWorldBottomRight;

// UV coords of quad's corners
uniform vec2 uUVTopLeft;
uniform vec2 uUVBottomRight;

uniform mat4 uViewProjectionMatrix;
// uniform mat4 uViewMatrix;

varying vec2 vUV;
// varying vec2 vReliefSampleDir;

uniform float uReliefDepth;


void main() {
  vec2 worldPos = mix(uWorldTopLeft, uWorldBottomRight, aPosition.xy);
  vec4 worldPos4 = vec4(worldPos, 0.0, 1.0);
  gl_Position = uViewProjectionMatrix * worldPos4; 

  vUV = mix(uUVTopLeft, uUVBottomRight, aPosition.xy);

  // // e: eye space
  // // t: tangent space
  // vec3 eview = normalize((uViewMatrix * worldPos4).xyz);
  // vec3 tview = normalize(vec3(dot(eview, uViewMatrix[0].xyz), dot(eview, uViewMatrix[1].xyz), dot(eview, -uViewMatrix[2].xyz)));

  // vReliefSampleDir = tview.xy * uReliefDepth / tview.z;
}