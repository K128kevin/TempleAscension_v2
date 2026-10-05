shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;

// Blood fallen on the floor (scripts/vfx.gd blood): a uneven pool with a
// few flecks thrown round it, each splat's shape its own (`seed`), wet under
// the torches. `fade` brings it in as it lands and takes it away as it dries.
uniform float seed = 0.0;
uniform float fade = 1.0;
uniform vec3 blood : source_color = vec3(.2, .008, .008);

float hash(float n) {
	return fract(sin(n * 12.9898 + seed * 4.37) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float angle = atan(p.y, p.x);
	float reach = .5 + .07 * sin(angle * 2.0 + seed) + .05 * sin(angle * 3.0 + seed * 2.3) + .03 * sin(angle * 5.0 + seed * 5.1) + .012 * sin(angle * 11.0 + seed * 3.3);
	float r = length(p);
	float spot = 1.0 - smoothstep(reach - .07, reach, r);
	for (int i = 0; i < 5; i++) {
		float n = float(i);
		float turn = hash(n) * 6.2832;
		vec2 at = vec2(cos(turn), sin(turn)) * (.68 + .22 * hash(n + 7.0));
		float size = .04 + .07 * hash(n + 13.0);
		spot = max(spot, 1.0 - smoothstep(size - .03, size, length(p - at)));
	}
	// Thinner, and so redder, toward its edge.
	ALBEDO = blood * (1.0 + .7 * smoothstep(reach - .3, reach, r));
	ROUGHNESS = .22;
	SPECULAR = .7;
	ALPHA = spot * fade * .92;
}
