shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// A spike of ice (scripts/wizard_fx.gd, Ice Spikes): a faceted crystal, its
// model a unit high from its foot (y 0) to its point (y 1). Deep blue-green
// and glassy through its heart, cloudy white rime crusting its foot, streaks
// and fractures running up its length and bubbles caught in it, its facets
// catching the light and glowing cold where they turn from the eye. Drawn
// from its model's own space, so each spike's ice goes with it; `seed`
// makes each one its own.
uniform float seed = 0.0;

varying vec3 local;

float hash(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise(p) * amplitude;
		p = p * 2.1 + vec2(4.3, 1.9);
		amplitude *= 0.5;
	}
	return total;
}

void vertex() {
	local = VERTEX;
}

void fragment() {
	float h = local.y;
	float around = atan(local.z, local.x);
	vec2 skin = vec2(around * 1.6 + seed, h * 3.0);
	// Streaks drawn up its length, and fractures across them.
	float streaks = fbm(vec2(around * 5.0 + seed * 3.0, h * 0.8));
	float fracture = 1.0 - smoothstep(0.0, 0.035, abs(fbm(skin * 2.0 + 7.0) - 0.5));
	// Bubbles caught in the ice.
	vec2 cell = floor(skin * 9.0);
	float bubble = step(0.93, hash(cell + seed)) * (1.0 - smoothstep(0.15, 0.35, length(fract(skin * 9.0) - 0.5)));
	// Rime: thick and white at its foot, thinning in tatters up it.
	float rime = 1.0 - smoothstep(0.08, 0.42, h + (fbm(skin * 3.0) - 0.5) * 0.3);
	vec3 deep = vec3(0.12, 0.36, 0.5);
	vec3 clear = vec3(0.5, 0.78, 0.9);
	vec3 frost = vec3(0.86, 0.93, 0.97);
	vec3 color = mix(deep, clear, smoothstep(0.25, 0.75, streaks) * 0.8 + h * 0.25);
	color = mix(color, frost, max(fracture * 0.7, bubble * 0.6));
	color = mix(color, frost, rime);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = color;
	ROUGHNESS = mix(0.05, 0.6, max(rime, fracture * 0.5));
	SPECULAR = 0.9;
	METALLIC = 0.05;
	// It glows cold where its facets turn from the eye, and at its point.
	EMISSION = vec3(0.35, 0.6, 0.8) * (rim * 0.9 + smoothstep(0.7, 1.0, h) * 0.25) + vec3(0.04, 0.08, 0.11);
	ALPHA = mix(0.82, 0.97, max(rime, rim));
}
