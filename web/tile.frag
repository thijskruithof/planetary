precision highp float;

varying vec2 vUV;

// Albedo texture
uniform sampler2D uAlbedoSampler;
uniform vec2 uAlbedoTopLeft;
uniform vec2 uAlbedoSize;

void main() 
{
    gl_FragColor = texture2D(uAlbedoSampler, uAlbedoTopLeft + vUV*uAlbedoSize);
}