shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A soft additive glow for particles (scripts/vfx.gd): a camera-facing dot,
// as large as the particle, bright at its middle and clear at its edge,
// coloured and faded by the particle's colour. The brightness it adds is
// worked out here (colour times fade), not left to the blend: in the
// Compatibility renderer the additive blend now and then ignored alpha, and
// every dot drew as a solid square.
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float fade = clamp(1.0 - length(UV * 2.0 - 1.0), 0.0, 1.0);
	ALBEDO = COLOR.rgb * COLOR.a * fade;
}
