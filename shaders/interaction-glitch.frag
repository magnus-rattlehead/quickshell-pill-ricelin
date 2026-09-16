#version 440
// Ported from the user's active Ghostty shader. Original attribution follows.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 outputColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 resolution;
    float paddingPx;
    float time;
    float motion;
    float hoverStrength;
    float clickStrength;
};
layout(binding = 1) uniform sampler2D source;
#define iResolution vec3(resolution, 1.0)
#define iTime time
#define iFrame int(time * 60.0)

// Keep the texture's transparent margin for tooltips outside the pill.
vec4 terminalSample(vec2 uv) {
    vec2 texSize = vec2(textureSize(source, 0));
    return texture(source, (uv * resolution + vec2(paddingPx)) / texSize);
}

// modified version of https://www.shadertoy.com/view/wld3WN
// Hover uses the user's 5% strength; clicks restore the original full strength.
#define INTENSITY max(0.05 * hoverStrength, clickStrength)

#define UI0 1597334673U
#define UI1 3812015801U
#define UI2 uvec2(UI0, UI1)
#define UI3 uvec3(UI0, UI1, 2798796415U)
#define UIF (1. / float(0xffffffffU))

// Hash by David_Hoskins
vec3 hash33(vec3 p)
{
	uvec3 q = uvec3(ivec3(p)) * UI3;
	q = (q.x ^ q.y ^ q.z)*UI3;
	return -1. + 2. * vec3(q) * UIF;
}

// Gradient noise by iq
float gnoise(vec3 x)
{
    // grid
    vec3 p = floor(x);
    vec3 w = fract(x);
    
    // quintic interpolant
    vec3 u = w * w * w * (w * (w * 6. - 15.) + 10.);
    
    // gradients
    vec3 ga = hash33(p + vec3(0., 0., 0.));
    vec3 gb = hash33(p + vec3(1., 0., 0.));
    vec3 gc = hash33(p + vec3(0., 1., 0.));
    vec3 gd = hash33(p + vec3(1., 1., 0.));
    vec3 ge = hash33(p + vec3(0., 0., 1.));
    vec3 gf = hash33(p + vec3(1., 0., 1.));
    vec3 gg = hash33(p + vec3(0., 1., 1.));
    vec3 gh = hash33(p + vec3(1., 1., 1.));
    
    // projections
    float va = dot(ga, w - vec3(0., 0., 0.));
    float vb = dot(gb, w - vec3(1., 0., 0.));
    float vc = dot(gc, w - vec3(0., 1., 0.));
    float vd = dot(gd, w - vec3(1., 1., 0.));
    float ve = dot(ge, w - vec3(0., 0., 1.));
    float vf = dot(gf, w - vec3(1., 0., 1.));
    float vg = dot(gg, w - vec3(0., 1., 1.));
    float vh = dot(gh, w - vec3(1., 1., 1.));
	
    // interpolation
    float gNoise = va + u.x * (vb - va) + 
           		u.y * (vc - va) + 
           		u.z * (ve - va) + 
           		u.x * u.y * (va - vb - vc + vd) + 
           		u.y * u.z * (va - vc - ve + vg) + 
           		u.z * u.x * (va - vb - ve + vf) + 
           		u.x * u.y * u.z * (-va + vb + vc - vd + ve - vf - vg + vh);
    
    return 2. * gNoise;
}

void mainImage( out vec4 fragColor, in vec2 fragCoord )
{
    vec2 uv = fragCoord / iResolution.xy;
    vec4 source = terminalSample(uv);
    float t = iTime;
    
    // The original interval envelope peaked at 0.25. A click supplies that peak.
    float glitchAmount = 0.25 * clickStrength;  
	float displayNoise = 0.;
    vec3 col = vec3(0.);
    vec2 eps = vec2(5. * INTENSITY / iResolution.x, 0.);
    vec2 st = vec2(0.);

    // Subtle analog distortion
    float y = uv.y * iResolution.y;
    float distortion = gnoise(vec3(0., y * .01, t * 500.)) * (glitchAmount * 4. + .1);
    distortion *= gnoise(vec3(0., y * .02, t * 250.)) * (glitchAmount * 2. + .025);

    ++displayNoise;
    distortion += smoothstep(.999, 1., sin((uv.y + t * 1.6) * 2.)) * .02;
    distortion -= smoothstep(.999, 1., sin((uv.y + t) * 2.)) * .02;
    distortion *= INTENSITY;
    st = uv + vec2(distortion, 0.);
    // chromatic aberration
    col.r += terminalSample(st + eps + distortion).r;
    col.g += terminalSample(st).g;
    col.b += terminalSample(st - eps - distortion).b;
    
    // Interaction noise (no scanline modulation).
    displayNoise = 0.2 * INTENSITY * clamp(displayNoise, 0., 1.);
    col += (.15 + .65 * glitchAmount) * (hash33(vec3(fragCoord, mod(float(iFrame),
					1000.))).r) * displayNoise;
    // Keep the incoming opacity instead of making the background opaque.
    fragColor = vec4(col, source.a);
}

void main() {
    vec4 original = texture(source, qt_TexCoord0);
    if (hoverStrength <= 0.0 && clickStrength <= 0.0) {
        outputColor = original * qt_Opacity;
        return;
    }
    vec2 pixel = qt_TexCoord0 * vec2(textureSize(source, 0)) - vec2(paddingPx);
    if (any(lessThan(pixel, vec2(0.0))) || any(greaterThan(pixel, resolution))) {
        outputColor = original * qt_Opacity;
        return;
    }
    vec4 result;
    mainImage(result, pixel);
    // Qt textures use premultiplied alpha; bloom/noise must not fill the corners.
    result.a = original.a;
    result.rgb = clamp(result.rgb, vec3(0.0), vec3(result.a));
    outputColor = result * qt_Opacity;
}
