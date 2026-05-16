#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:dynamictransforms.glsl>
#moj_import <minecraft:globals.glsl>

in float sphericalVertexDistance;
in float cylindricalVertexDistance;
in vec4 vertexColor;
in vec3 worldPos;

out vec4 fragColor;

#define NUM_LAYERS 8.0
#define TAU 6.28318
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
            int colorA = int(fract(n * 13.7) * 4.0);
            int colorB = int(fract(n * 27.3) * 4.0);
            float life = sin(iTime * 0.6 + n * TAU) * 0.5 + 0.5;
            vec3 color = mix(COLORS[colorA], COLORS[colorB], life);
            vec2 starUV = gv - offs - vec2(n, fract(n * 34.0)) + 0.5;
            col += Star(starUV) * life * color;
        }
    }
    return col;
}

void main() {
    vec4 color = vertexColor * ColorModulator;
    if (color.a < 0.1) {
        discard;
    }

    vec4 target = vec4(51.0, 50.0, 50.0, 255.0) / 255.0;
    if (all(lessThan(abs(color - target), vec4(0.004)))) {
        float iTime = GameTime * 1200.0;
        float t = iTime * Velocity;

        // Use gl_FragCoord for a distortion-free screen UV
        vec2 fragUV = (gl_FragCoord.xy / ScreenSize) * 2.0 - 1.0;
        fragUV.x *= ScreenSize.x / ScreenSize.y;

        vec3 col = vec3(0.0);
        for (float i = 0.0; i < 1.0; i += 1.0 / NUM_LAYERS) {
            float depth = fract(i + t);
            float fade = depth * smoothstep(1.0, 0.9, depth);
            col += StarLayer(fragUV * mix(CanvasView, 0.5, depth) + i * 453.2, iTime) * fade;
        }
        fragColor = vec4(col, 1.0);
        return;
    }

    fragColor = apply_fog(color, sphericalVertexDistance, cylindricalVertexDistance,
        FogEnvironmentalStart, FogEnvironmentalEnd,
        FogRenderDistanceStart, FogRenderDistanceEnd, FogColor);
}