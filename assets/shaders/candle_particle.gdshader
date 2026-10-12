shader_type spatial;
// One tongue of a candle's flame (scripts/candle_flame.gd): a particle drawn
// as a soft teardrop, round at its foot and drawn to a point above, standing
// upright and turned to the eye about its upright (as a flame is seen from
// any side), coloured and faded by the particle's colour; added onto what is
// behind it. Many of them, rising from the wick and cooling as they go, make
// the flame, swaying and stretching as the air moves it.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

void vertex() {
	float wide = length(MODEL_MATRIX[0].xyz);
	float tall = length(MODEL_MATRIX[1].xyz);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 side = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 facing = normalize(cross(side, up));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(side * wide, 0.0), vec4(up * tall, 0.0), vec4(facing * wide, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float up = 1.0 - UV.y;
	float across = (UV.x - 0.5) * 2.0;
	float width = sin(3.1416 * pow(clamp(up, 0.0, 1.0), 0.6)) * (1.0 - 0.45 * up);
	float edge = abs(across) / max(width, 0.001);
	float body = (1.0 - smoothstep(0.3, 1.0, edge)) * (1.0 - smoothstep(0.85, 1.0, up));
	ALBEDO = COLOR.rgb * COLOR.a * body;
}
