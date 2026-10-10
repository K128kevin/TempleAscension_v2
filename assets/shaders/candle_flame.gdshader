shader_type spatial;
// A candle's flame (scripts/candle_flame.gd): a small teardrop of light
// standing on its wick, turned to face the camera about its upright. White
// and yellow at its heart, orange to its tip, a little blue at its foot; it
// sways and stretches as the air moves, each flame by its own beat (from
// where it stands).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

varying float phase;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	phase = dot(NODE_POSITION_WORLD, vec3(7.31, 3.7, 5.13));
}

void fragment() {
	// Up the flame (0 at the wick, 1 at its tip), and across it.
	float up = 1.0 - UV.y;
	float flicker = 0.85 + 0.15 * sin(TIME * 13.0 + phase) * sin(TIME * 7.3 + phase * 1.7);
	float sway = (sin(TIME * 3.1 + phase) * 0.6 + sin(TIME * 5.7 + phase * 2.3) * 0.4) * 0.12 * up * up;
	float across = (UV.x - 0.5) * 2.0 - sway;
	// Its outline: round at the foot, drawn to a point at the tip (a little
	// taller as it flares).
	float tall = up / (0.82 + 0.18 * flicker);
	float width = sin(3.1416 * pow(clamp(tall, 0.0, 1.0), 0.55)) * (1.0 - 0.55 * tall);
	float edge = abs(across) / max(width, 0.001);
	float body = (1.0 - smoothstep(0.55, 1.0, edge)) * step(tall, 1.0);
	float heart = (1.0 - smoothstep(0.0, 0.55, edge)) * (1.0 - smoothstep(0.15, 0.6, tall));
	vec3 colour = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.8, 0.35), smoothstep(0.85, 0.2, tall));
	colour = mix(colour, vec3(1.0, 0.97, 0.85), heart);
	// Blue where it meets the wick.
	colour = mix(colour, vec3(0.25, 0.35, 0.9), (1.0 - smoothstep(0.0, 0.12, tall)) * 0.55);
	ALBEDO = colour * body * flicker * 1.6;
}
