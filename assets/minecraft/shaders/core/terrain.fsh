#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:globals.glsl>
#moj_import <minecraft:chunksection.glsl>
#moj_import <minecraft:matrix.glsl>

uniform sampler2D Sampler0;
uniform sampler2D Sampler1;

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec4 vertexColor;
in vec2 texCoord0;
in vec4 texProj0;
in vec3 worldPos;
in vec2 screenPos;
in vec3 viewDir;

out vec4 fragColor;

#define NUM_LAYERS 8.0
#define TAU 6.28318
#define PI 3.141592
#define Velocity 0.0125
#define CanvasView 10.0

float Star(vec2 uv) {
    vec2 d = abs(uv) - vec2(0.03);
    float box = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
    return smoothstep(0.005, 0.0, box);
}

float Hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

const vec3 COLORS[4] = vec3[](
    vec3(255.0, 204.0, 252.0) / 255.0,
    vec3(255.0, 255.0, 255.0) / 255.0,
    vec3(255.0, 163.0, 250.0) / 255.0,
    vec3(171.0, 117.0, 255.0) / 255.0
);

vec3 StarLayer(vec2 uv, float iTime) {
    vec3 col = vec3(0.0);
    vec2 gv = fract(uv);
    vec2 id = floor(uv);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 offs = vec2(x, y);
            float n = Hash21(id + offs);
            float size = fract(n);

            // Pick two different random colors per star using different hash values
            int colorA = int(fract(n * 13.7) * 4.0);
            int colorB = int(fract(n * 27.3) * 4.0);

            // Fade between them over the star's twinkle lifetime
            float life = sin(iTime * 0.6 + n * TAU) * 0.5 + 0.5;
            vec3 color = mix(COLORS[colorA], COLORS[colorB], life);

            vec2 starUV = gv - offs - vec2(n, fract(n * 34.0)) + 0.5;
            float star = Star(starUV);
            star *= life;
            col += star * color;
        }
    }
    return col;
}

vec4 sampleNearest(sampler2D sampler, vec2 uv, vec2 pixelSize, vec2 du, vec2 dv, vec2 texelScreenSize) {
    vec2 tileSizeUV = vec2(16.0, 16.0) * pixelSize;
    vec2 tileOrigin = floor(uv / tileSizeUV) * tileSizeUV;
    vec2 topLeftUV = tileOrigin + pixelSize * 0.5;
    vec4 topLeftColor = textureLod(sampler, topLeftUV, 0.0);

    if (topLeftColor == vec4(205.0, 206.0, 74.0, 255.0) / 255.0) {
        float iTime = GameTime * 1200.0;
        float t = iTime * Velocity;

        vec2 screenUV = screenPos;

        vec3 col = vec3(0.0);
        for (float i = 0.0; i < 1.0; i += 1.0 / NUM_LAYERS) {
            float depth = fract(i + t);
            float scale = mix(CanvasView, 0.5, depth);
            float fade = depth * smoothstep(1.0, 0.9, depth);
            // Center the UV so stars stream from middle outward instead of drifting sideways
            vec2 layerUV = screenUV * scale + i * 453.2;
            col += StarLayer(layerUV, iTime) * fade;
        }

        return vec4(col, 1.0);
    }

    vec2 uvTexelCoords = uv / pixelSize;
    vec2 texelCenter = round(uvTexelCoords) - 0.5f;
    vec2 texelOffset = uvTexelCoords - texelCenter;

    texelOffset = (texelOffset - 0.5f) * pixelSize / texelScreenSize + 0.5f;
    texelOffset = clamp(texelOffset, 0.0f, 1.0f);

    uv = (texelCenter + texelOffset) * pixelSize;
    return textureGrad(sampler, uv, du, dv);
}

vec4 sampleNearest(sampler2D source, vec2 uv, vec2 pixelSize) {
    vec2 du = dFdx(uv);
    vec2 dv = dFdy(uv);
    vec2 texelScreenSize = sqrt(du * du + dv * dv);
    return sampleNearest(source, uv, pixelSize, du, dv, texelScreenSize);
}

vec4 sampleRGSS(sampler2D source, vec2 uv, vec2 pixelSize) {
    vec2 du = dFdx(uv);
    vec2 dv = dFdy(uv);

    vec2 texelScreenSize = sqrt(du * du + dv * dv);

    float duLength = length(du);
    float dvLength = length(dv);
    float minDerivative = min(duLength, dvLength);
    float maxDerivative = max(duLength, dvLength);
    float effectiveDerivative = sqrt(minDerivative * maxDerivative);

    float minPixelSize = min(pixelSize.x, pixelSize.y);
    float mipLevelExact = max(0.0, log2(effectiveDerivative / minPixelSize));
    float mipLevelLow = floor(mipLevelExact);
    float mipLevelHigh = mipLevelLow + 1.0;
    float mipBlend = fract(mipLevelExact);

    const vec2 offsets[4] = vec2[](
        vec2(0.125, 0.375),
        vec2(-0.125, -0.375),
        vec2(0.375, -0.125),
        vec2(-0.375, 0.125)
    );

    vec4 rgssColorLow = vec4(0.0);
    vec4 rgssColorHigh = vec4(0.0);
    for (int i = 0; i < 4; ++i) {
        vec2 sampleUV = uv + offsets[i] * pixelSize;
        rgssColorLow += textureLod(source, sampleUV, mipLevelLow);
        rgssColorHigh += textureLod(source, sampleUV, mipLevelHigh);
    }
    rgssColorLow *= 0.25;
    rgssColorHigh *= 0.25;

    vec4 nearestColor = sampleNearest(source, uv, pixelSize, du, dv, texelScreenSize);
    return nearestColor;
}

void main() {
    vec4 sampled = sampleNearest(Sampler0, texCoord0, 1.0f / TextureSize);
    vec4 color = sampled * vertexColor;

    vec2 pixelSize = 1.0f / TextureSize;
    vec2 tileSizeUV = vec2(16.0, 16.0) * pixelSize;
    vec2 tileOrigin = floor(texCoord0 / tileSizeUV) * tileSizeUV;
    vec2 topLeftUV = tileOrigin + pixelSize * 0.5;
    vec4 topLeftColor = textureLod(Sampler0, topLeftUV, 0.0);

    if (topLeftColor == vec4(205.0, 206.0, 74.0, 255.0) / 255.0) {
        color = sampled;
    }

    color = mix(FogColor * vec4(1, 1, 1, color.a), color, ChunkVisibility);
#ifdef ALPHA_CUTOUT
    if (color.a < ALPHA_CUTOUT) {
        discard;
    }
#endif
    fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance, FogEnvironmentalStart, FogEnvironmentalEnd, FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
}