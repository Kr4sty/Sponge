#version 330

#moj_import <minecraft:fog.glsl>
#moj_import <minecraft:globals.glsl>
#moj_import <minecraft:chunksection.glsl>
#moj_import <minecraft:projection.glsl>

out vec3 viewDir;
in vec3 Position;
in vec4 Color;
in vec2 UV0;
in ivec2 UV2;
in vec3 Normal;

uniform sampler2D Sampler2;

out float sphericalVertexDistance;
out float cylindricalVertexDistance;
out vec4 vertexColor;
out vec4 texProj0;
out vec2 texCoord0;
out vec3 worldPos;
out vec2 screenPos;


vec4 minecraft_sample_lightmap(sampler2D lightMap, ivec2 uv) {
    return texture(lightMap, clamp((uv / 256.0) + 0.5 / 16.0, vec2(0.5 / 16.0), vec2(15.5 / 16.0)));
}

void main() {
    vec3 pos = Position + (ChunkPosition - CameraBlockPos) + CameraOffset;
    gl_Position = ProjMat * ModelViewMat * vec4(pos, 1.0);
    texProj0 = projection_from_position(gl_Position);
    worldPos = Position + ChunkPosition;
    sphericalVertexDistance = fog_spherical_distance(pos);
    cylindricalVertexDistance = fog_cylindrical_distance(pos);
    vertexColor = Color * minecraft_sample_lightmap(Sampler2, UV2);
    screenPos = gl_Position.xy / gl_Position.w * vec2(ScreenSize.x / ScreenSize.y, 1.0);
    // Extract view-space position, strip translation for rotation-only transform
    vec3 viewPos = mat3(ModelViewMat) * (Position + ChunkPosition - vec3(CameraBlockPos) + CameraOffset);
    viewDir = viewPos;
    texCoord0 = UV0;
}
