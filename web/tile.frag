precision highp float;

varying vec2 vUV;
varying vec2 vReliefSampleDir;

// Albedo texture
uniform sampler2D uAlbedoSampler;
uniform vec2 uAlbedoTopLeft;
uniform vec2 uAlbedoSize;

// UV coords of quad's corners
uniform vec2 uUVTopLeft;
uniform vec2 uUVBottomRight;


vec3 sampleAlbedo(vec2 uv)
{
    return texture2D(uAlbedoSampler, uAlbedoTopLeft + uv*uAlbedoSize).xyz;
}
 


void main() 
{
    vec2 uv = max(uUVTopLeft, min(uUVBottomRight, vUV));

    // float dist = find_intersection(uv, vReliefSampleDir);
    // uv += dist * vReliefSampleDir;

    gl_FragColor = vec4(1.0,0.0,1.0,1.0) + 0.01*vec4(sampleAlbedo(uv), 1.0); 
}