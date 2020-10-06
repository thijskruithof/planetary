precision highp float;

varying vec2 vUV;
varying vec3 vPositionView;
varying vec3 vEyeGroundNormal;
varying vec3 vEyeGroundTangent;
varying vec3 vEyeGroundBitangent;

uniform sampler2D uAlbedo00Sampler;
uniform sampler2D uElevation00Sampler;

uniform vec2 uAlbedo00TopLeft;
uniform vec2 uAlbedo00Size;
uniform vec2 uElevation00TopLeft;
uniform vec2 uElevation00Size;

uniform float uReliefDepth;

float sampleElevation3x3(vec2 uv)
{
    // // Top?
    // if (uv.y < 0.0)
    // {
    //     if (uv.x < 0.0)
    //         return texture2D(uElevationTexture11, uElevationTexture11TopLeft + (uv + vec2(1.0,1.0))*uElevationTexture11Size).r;
    //     else if (uv.x >= 1.0)
    //         return texture2D(uElevationTexture11, uElevationTexture11TopLeft + (uv + vec2(-1.0,1.0))*uElevationTexture11Size).r;
    //     else 
    //         return texture2D(uElevationTexture10, uElevationTexture10TopLeft + (uv + vec2(0.0,1.0))*uElevationTexture10Size).r;
    // }
    // // Bottom?
    // else if (uv.y >= 1.0)
    // {
    //     if (uv.x < 0.0)
    //         return texture2D(uElevationTexture11, uElevationTexture11TopLeft + (uv + vec2(1.0,-1.0))*uElevationTexture11Size).r;
    //     else if (uv.x >= 1.0)
    //         return texture2D(uElevationTexture11, uElevationTexture11TopLeft + (uv + vec2(-1.0,-1.0))*uElevationTexture11Size).r;
    //     else 
    //         return texture2D(uElevationTexture10, uElevationTexture10TopLeft + (uv + vec2(0.0,-1.0))*uElevationTexture10Size).r;
    // }    
    // // Middle?
    // else
    {
        // if (uv.x < 0.0)
        //     return texture2D(uElevationTexture01, uElevationTexture01TopLeft + (uv + vec2(1.0,0.0))*uElevationTexture01Size).r;
        // else if (uv.x >= 1.0)
        //     return texture2D(uElevationTexture01, uElevationTexture01TopLeft + (uv + vec2(-1.0,0.0))*uElevationTexture01Size).r;
        // else 
            return texture2D(uElevation00Sampler, uElevation00TopLeft + (uv + vec2(0.0,0.0))*uElevation00Size).r;
    }
}


vec3 sampleAlbedo3x3(vec2 uv)
{
    // // Top?
    // if (uv.y < 0.0)
    // {
    //     if (uv.x < 0.0)
    //         return texture2D(uAlbedoTexture11, uAlbedoTexture11TopLeft + (uv + vec2(1.0,1.0))*uAlbedoTexture11Size).xyz;            
    //     else if (uv.x >= 1.0)
    //         return texture2D(uAlbedoTexture11, uAlbedoTexture11TopLeft + (uv + vec2(-1.0,1.0))*uAlbedoTexture11Size).xyz;
    //     else 
    //         return texture2D(uAlbedoTexture10, uAlbedoTexture10TopLeft + (uv + vec2(0.0,1.0))*uAlbedoTexture10Size).xyz;
    // }
    // // Bottom?
    // else if (uv.y >= 1.0)
    // {
    //     if (uv.x < 0.0)
    //         return texture2D(uAlbedoTexture11, uAlbedoTexture11TopLeft + (uv + vec2(1.0,-1.0))*uAlbedoTexture11Size).xyz;            
    //     else if (uv.x >= 1.0)
    //         return texture2D(uAlbedoTexture11, uAlbedoTexture11TopLeft + (uv + vec2(-1.0,-1.0))*uAlbedoTexture11Size).xyz;
    //     else 
    //         return texture2D(uAlbedoTexture10, uAlbedoTexture10TopLeft + (uv + vec2(0.0,-1.0))*uAlbedoTexture10Size).xyz;        
    // }    
    // // Middle?
    // else
    {
        // if (uv.x < 0.0)
        //     return texture2D(uAlbedoTexture01, uAlbedoTexture01TopLeft + (uv + vec2(1.0,0.0))*uAlbedoTexture01Size).xyz;            
        // else if (uv.x >= 1.0)
        //     return texture2D(uAlbedoTexture01, uAlbedoTexture01TopLeft + (uv + vec2(-1.0,0.0))*uAlbedoTexture01Size).xyz;
        // else 
            return texture2D(uAlbedo00Sampler, uAlbedo00TopLeft + (uv + vec2(0.0,0.0))*uAlbedo00Size).xyz;        
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
  // vec4 albedo = texture2D(uAlbedo00Sampler, uAlbedo00TopLeft + vUV*uAlbedo00Size);

  // vec4 elevation = texture2D(uElevation00Sampler, uElevation00TopLeft + vUV*uElevation00Size);

  // gl_FragColor = 0.001*albedo + elevation;

  // e: eye space
	// t: tangent space
	vec3 eview = normalize(vPositionView.xyz);
	vec3 tview = normalize(vec3(dot(eview, normalize(vEyeGroundTangent)), dot(eview, normalize(vEyeGroundBitangent)), dot(eview, -normalize(vEyeGroundNormal))));
	vec2 ds = tview.xy * uReliefDepth / tview.z;
	float dist = find_intersection(vUV, ds);
	vec2 uv = vUV + dist * ds;

  gl_FragColor = vec4(sampleAlbedo3x3(uv), 1.0); 
}