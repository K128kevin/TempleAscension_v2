shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// A soft glow facing the camera, added onto what is behind it: brightest at
// its middle and fading smoothly to nothing at its edge, drawn without a
// texture. The node's x and y scale are its width and height (a tall one is
// a pillar of light: the wizard's teleport, scripts/wizard_fx.gd Blink; a
// round one a flash's heart: Ignition). `strength` fades it.
uniform vec4 tint : source_color = vec4(0.75, 0.68, 1.0, 1.0);
uniform float strength = 1.0;
// How quickly it falls away from its middle.
uniform float softness = 2.6;

void vertex() {
	// Billboard: keep the node's position and scale, face the camera.
	float wide = length(MODEL_MATRIX[0].xyz);
	float tall = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * wide, INV_VIEW_MATRIX[1] * tall, INV_VIEW_MATRIX[2] * wide, MODEL_MATRIX[3]);
	// Pulled toward the camera so the floor does not cut off its lower part
	// (the camera is orthographic: its place on screen is unchanged).
	MODELVIEW_MATRIX[3].z += max(wide, tall) * 0.6;
}

void fragment() {
	vec2 from_middle = (UV - 0.5) * 2.0;
	float r = length(from_middle);
	float glow = exp(-r * r * softness) * (1.0 - smoothstep(0.8, 1.0, r));
	ALBEDO = tint.rgb * tint.a * glow * strength;
}
