shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float flame_time = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
        mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void vertex() {
    // Face the camera while preserving the sprite's world position and scale.
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
        INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
        INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
        INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz), MODEL_MATRIX[3]);
}

void fragment() {
    vec2 p = vec2(UV.x - 0.5, 1.0 - UV.y);
    float t = flame_time;
    float y = max(0.0, (p.y - 0.08) / 0.74);
    float flow = noise(vec2(p.x * 9.0, y * 5.0 - t * 2.8));
    float detail = noise(vec2(p.x * 19.0 + 3.0, y * 11.0 - t * 4.5));
    float sway = sin(t * 3.1 - y * 5.5) * 0.045 * y;
    float tongue = 0.035 * sin(t * 4.3 + y * 9.0) * y;
    float width = 0.27 * pow(max(0.0, 1.0 - y), 0.85);
    width *= smoothstep(0.0, 0.16, y) * (0.78 + flow * 0.44);
    float edge = width - abs(p.x - sway - tongue) + (flow - 0.5) * 0.075 * y;
    float flame = smoothstep(-0.025, 0.045, edge);
    flame *= smoothstep(0.0, 0.07, y) * (1.0 - smoothstep(0.78, 1.0, y));
    float core = smoothstep(0.03, 0.15, edge) * (1.0 - smoothstep(0.2, 0.68, y));
    vec3 fire_color = mix(vec3(1.0, 0.16, 0.012), vec3(1.0, 0.62, 0.055),
        clamp(edge * 7.0 + detail * 0.2, 0.0, 1.0));
    fire_color = mix(fire_color, vec3(1.0, 0.94, 0.56), core);
    float sparks = 0.0;
    for (int i = 0; i < 3; i++) {
        float seed = float(i);
        float life = fract(t * (0.29 + seed * 0.047) + seed * 0.317);
        vec2 ember = vec2(sin(t * 1.8 + seed * 9.0) * (0.04 + life * 0.13),
            0.36 + life * 0.59);
        float spark = 1.0 - smoothstep(0.004, 0.014, length((p - ember) * vec2(1.0, 0.65)));
        sparks += spark * sin(life * 3.14159) * 0.65;
    }
    ALBEDO = mix(fire_color, vec3(1.0, 0.57, 0.09), clamp(sparks, 0.0, 1.0));
    EMISSION = ALBEDO * (1.4 + core * 1.4);
    ALPHA = clamp(flame * 0.96 + sparks, 0.0, 1.0);
}
