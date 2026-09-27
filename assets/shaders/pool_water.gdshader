shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec2 center = vec2(0.0);
uniform float radius = 0.0;
uniform vec4 wakes[8];
uniform float water_time = 0.0;
varying vec3 world_position;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = world_position.xz;
    float distance_to_center = length(p - center);
    if (radius > 0.0 && distance_to_center > radius) { discard; }
    float wave = sin(p.x * 5.0 + p.y * 3.0 + water_time * 1.3)
        * sin(p.y * 6.0 - p.x * 2.0 - water_time * 1.1);
    float rings = pow(max(0.0, sin(distance_to_center * 7.0 - water_time * 3.0 + wave * 0.5)), 22.0)
        * exp(-distance_to_center * 0.32) * 0.6;
    float wake = 0.0;
    for (int i = 0; i < 8; i++) {
        float age = water_time - wakes[i].z;
        float d = length(p - wakes[i].xy);
        float ring = exp(-pow((d - age * 1.3) * 14.0, 2.0));
        wake += ring * max(0.0, 1.0 - age / 1.8) * wakes[i].w;
    }
    ALBEDO = vec3(0.10, 0.34, 0.32) + vec3(0.13, 0.22, 0.20) * (wave * 0.15 + rings + wake);
    // A little scattered moon-blue light keeps the shallows readable between torches.
    EMISSION = vec3(0.045, 0.10, 0.085) + vec3(0.10, 0.16, 0.14) * (rings + wake);
    ROUGHNESS = 0.22;
    SPECULAR = 0.8;
    NORMAL = normalize(NORMAL + vec3(wave * 0.08, 0.0, cos(p.x * 4.0 - water_time) * 0.06));
    ALPHA = 0.56 + rings * 0.12 + min(wake, 1.0) * 0.16;
}
