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
    // The animated flame sprite replaces the authored solid flame only.
    float fire = smoothstep(0.48, 0.65, model_height)
        * step(color.g * 1.15, color.r) * step(color.b * 1.4, color.g);
    if (fire > 0.01) { discard; }
}
