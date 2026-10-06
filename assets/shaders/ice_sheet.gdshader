shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

// A sheet of ice frozen over the floor (scripts/wizard_fx.gd, Patch): a disc
// laid flat, solid through its middle with a ragged frosted rim. Everything
// in it (its colour, cloudiness, cracks and rime) is worked out from
// where it lies in the world, not from the disc, so where patches overlap they
// show the same ice and run together into one even sheet. `melt` runs 0 to 1
// as it thaws: it breaks up from its rim inward, unevenly, rather than fading.
uniform float melt = 0.0;
uniform float grow = 1.0;
// Its radius in metres, so its rim is as ragged on a wide sheet as a small one.
uniform float radius = 1.0;

varying vec3 world;

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
	for (int i = 0; i < 3; i++) {
		total += noise(p) * amplitude;
		p = p * 2.03 + vec2(3.1, 7.7);
		amplitude *= 0.5;
	}
	return total;
}

// Distance to the nearest edge between cells: the ice's cracks.
float cracks(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			vec2 seed = vec2(hash(cell + o), hash(cell + o + 19.7));
			float d = length(o + seed - f);
			if (d < first) { second = first; first = d; }
			else if (d < second) { second = d; }
		}
	}
	return second - first;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float cloud = fbm(p * 1.3);
	float grain = noise(p * 7.0);
	// Its rim, made ragged by noise; melting eats it back.
	float d = length(UV * 2.0 - 1.0);
	float ragged = d + (fbm(p * 2.6) - 0.5) * min(0.45, 0.45 / radius);
	float reach = mix(0.86, 0.0, melt) * mix(0.3, 1.0, grow);
	float cover = 1.0 - smoothstep(reach - min(0.06, 0.06 / radius), reach, ragged);
	// Cracks running through it.
	float crack = 1.0 - smoothstep(0.0, 0.05, cracks(p * 1.7 + (cloud - 0.5) * 0.6));
	// Rime: whiter, rougher frost in its cloudy parts (by where it lies, not
	// by the disc, so no seam shows where patches overlap).
	float rime = smoothstep(0.4, 0.75, cloud);
	vec3 clear = vec3(0.64, 0.8, 0.9);
	vec3 frosted = vec3(0.86, 0.93, 0.98);
	vec3 color = mix(clear, frosted, clamp(rime * 0.8 + grain * 0.35, 0.0, 1.0));
	color = mix(color, vec3(0.97, 0.99, 1.0), crack * 0.75);
	ALBEDO = color;
	ROUGHNESS = mix(0.08, 0.55, rime * 0.7 + grain * 0.3);
	SPECULAR = 0.9;
	METALLIC = 0.0;
	EMISSION = vec3(0.08, 0.13, 0.18);
	ALPHA = cover * 0.97;
}
