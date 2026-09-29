shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
varying float model_height;
void vertex() {
    model_height = VERTEX.y;
}
void fragment() {
    vec3 color = texture(atlas, UV).rgb;
    ALBEDO = color;
    ROUGHNESS = 0.8;
    // The particle flame replaces the authored solid flame: its orange tongues
    // and its pale yellow core. Dark claws and grey metal stay.
    float orange = step(color.g * 1.15, color.r) * step(color.b * 1.4, color.g);
    float pale = step(0.58, min(color.r, color.g));
    float fire = smoothstep(0.48, 0.65, model_height) * max(orange, pale);
    if (fire > 0.01) { discard; }
}
