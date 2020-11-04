precision highp float;

varying vec2 vUV;
varying vec2 vReliefSampleDir;

// 2x2 Albedo textures
uniform sampler2D uAlbedo00Sampler;
uniform sampler2D uAlbedo01Sampler;
uniform sampler2D uAlbedo10Sampler;
uniform sampler2D uAlbedo11Sampler;
uniform vec2 uAlbedo00TopLeft;
uniform vec2 uAlbedo01TopLeft;
uniform vec2 uAlbedo10TopLeft;
uniform vec2 uAlbedo11TopLeft;
uniform vec2 uAlbedo00Size;
uniform vec2 uAlbedo01Size;
uniform vec2 uAlbedo10Size;
uniform vec2 uAlbedo11Size;

// 2x2 Elevation textures
uniform sampler2D uElevation00Sampler;
uniform sampler2D uElevation01Sampler;
uniform sampler2D uElevation10Sampler;
uniform sampler2D uElevation11Sampler;
uniform vec2 uElevation00TopLeft;
uniform vec2 uElevation01TopLeft;
uniform vec2 uElevation10TopLeft;
uniform vec2 uElevation11TopLeft;
uniform vec2 uElevation00Size;
uniform vec2 uElevation01Size;
uniform vec2 uElevation10Size;
uniform vec2 uElevation11Size;

// UV coords of quad's corners
uniform vec2 uUVTopLeft;
uniform vec2 uUVBottomRight;


#define SAMPLE_MAP1(sampler, tl, sz, offX, offY) return texture2D(sampler, tl + (uv + vec2(offX,offY))*sz).r
#define SAMPLE_MAP3(sampler, tl, sz, offX, offY) return texture2D(sampler, tl + (uv + vec2(offX,offY))*sz).xyz

#define SAMPLE_ROW1(samplerMiddle, samplerOutside, tlMiddle, szMiddle, tlOutside, szOutside, offY) if (uv.x < 0.0) SAMPLE_MAP1(samplerOutside, tlOutside, szOutside, 1.0, offY); else if (uv.x > 1.0) SAMPLE_MAP1(samplerOutside, tlOutside, szOutside, -1.0, offY); else SAMPLE_MAP1(samplerMiddle, tlMiddle, szMiddle, 0.0, offY);
#define SAMPLE_ROW3(samplerMiddle, samplerOutside, tlMiddle, szMiddle, tlOutside, szOutside, offY) if (uv.x < 0.0) SAMPLE_MAP3(samplerOutside, tlOutside, szOutside, 1.0, offY); else if (uv.x > 1.0) SAMPLE_MAP3(samplerOutside, tlOutside, szOutside, -1.0, offY); else SAMPLE_MAP3(samplerMiddle, tlMiddle, szMiddle, 0.0, offY);

float sampleElevation3x3(vec2 uv)
{
    // Top?
    if (uv.y < 0.0) 
    { 
        SAMPLE_ROW1(uElevation10Sampler, uElevation11Sampler, uElevation10TopLeft, uElevation10Size, uElevation11TopLeft, uElevation11Size, 1.0); 
    }
    // Bottom?
    else if (uv.y >= 1.0) 
    { 
        SAMPLE_ROW1(uElevation10Sampler, uElevation11Sampler, uElevation10TopLeft, uElevation10Size, uElevation11TopLeft, uElevation11Size, -1.0); 
    }
    // Middle?
    else 
    { 
        SAMPLE_ROW1(uElevation00Sampler, uElevation01Sampler, uElevation00TopLeft, uElevation00Size, uElevation01TopLeft, uElevation01Size, 0.0); 
    }
}


vec3 sampleAlbedo3x3(vec2 uv)
{
    // Top?
    if (uv.y < 0.0)
    { 
        SAMPLE_ROW3(uAlbedo10Sampler, uAlbedo11Sampler, uAlbedo10TopLeft, uAlbedo10Size, uAlbedo11TopLeft, uAlbedo11Size, 1.0); 
    }
    // Bottom?
    else if (uv.y > 1.0) 
    { 
        SAMPLE_ROW3(uAlbedo10Sampler, uAlbedo11Sampler, uAlbedo10TopLeft, uAlbedo10Size, uAlbedo11TopLeft, uAlbedo11Size, -1.0); 
    }
    // Middle?
    else 
    { 
        SAMPLE_ROW3(uAlbedo00Sampler, uAlbedo01Sampler, uAlbedo00TopLeft, uAlbedo00Size, uAlbedo01TopLeft, uAlbedo01Size, 0.0); 
    }
}

  

float find_intersection(vec2 dp, vec2 ds) 
{
	const int linear_steps = 32;
	const int binary_steps = 16;
	float depth_step = 1.0 / float(linear_steps);
	float size = depth_step;
	float depth = 1.0;
	float best_depth = 1.0;
	for (int i = 0 ; i < linear_steps - 1 ; ++i) 
    {
		depth -= size;
        vec2 uv = dp + ds * depth;
		float t = sampleElevation3x3(uv);
		if (depth >= 1.0 - t)
			best_depth = depth;
	}
	depth = best_depth - size;
	for (int i = 0 ; i < binary_steps ; ++i) 
    {
		size *= 0.5;
        vec2 uv = dp + ds * depth;
		float t = sampleElevation3x3(uv);
		if (depth >= 1.0 - t) 
        {
			best_depth = depth;
			depth -= 2.0 * size;
		}
		depth += size;
	}
	return best_depth;
}  


void main() 
{
    vec2 uv = max(uUVTopLeft, min(uUVBottomRight, vUV));

    float dist = find_intersection(uv, vReliefSampleDir);
    uv += dist * vReliefSampleDir;

    gl_FragColor = vec4(sampleAlbedo3x3(uv), 1.0); 
}