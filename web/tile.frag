precision highp float;

varying vec2 vUV;

// Albedo texture
uniform sampler2D uAlbedoSampler;
uniform vec2 uAlbedoTopLeft;
uniform vec2 uAlbedoSize;

uniform float uDebugMeshLod;

void main() 
{
    gl_FragColor = texture2D(uAlbedoSampler, uAlbedoTopLeft + vUV*uAlbedoSize);
    gl_FragColor.r = 0.1+uDebugMeshLod/5.0;
}