shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// A bed of burning coals filling a brazier's bowl (scripts/temple.gd): lumps
// of charcoal, the cells of a pattern, heaped unevenly, black and ashen on
// top, glowing orange in the cracks between them and here and there through
// a lump, the glow breathing slowly, each lump in its own time.
uniform vec3 hot : source_color = vec3(1.0, 0.42, 0.08);
uniform float glow = 2.0;
// How many lumps across the bed's own breadth, height and depth (a brazier's
// bowl is small; the smithy's forge is a broad bed of them).
uniform vec3 grain = vec3(7.0, 3.0, 7.0);
uniform float fine_grain = 26.0;
varying vec3 coal_position;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

// The random value of the cell around `p`, and the distance to its border.
float lump(vec3 p, out float border) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec3 nearest = cell;
	for (int x = -1; x <= 1; x++)
	for (int y = -1; y <= 1; y++)
	for (int z = -1; z <= 1; z++) {
		vec3 o = vec3(float(x), float(y), float(z));
		vec3 r = o + hash33(cell + o) - f;
		float d = dot(r, r);
		if (d < d1) { d2 = d1; d1 = d; nearest = cell + o; }
		else if (d < d2) { d2 = d; }
	}
	border = sqrt(d2) - sqrt(d1);
	return hash3(nearest + 3.7);
}

void vertex() {
	coal_position = VERTEX;
	// Heaped lumps rather than a smooth dome; only upward, so none push out
	// through the bowl's side.
	float border;
	float r = lump(VERTEX * grain, border);
	VERTEX.y += (smoothstep(0.0, 0.25, border) * 0.25 + r * 0.15) * max(NORMAL.y, 0.0);
}

void fragment() {
	float border;
	float r = lump(coal_position * grain, border);
	float fine;
	lump(coal_position * fine_grain, fine);
	// Charcoal: near black, ash grey on some lumps.
	float ash = smoothstep(0.55, 0.95, r);
	ALBEDO = mix(vec3(0.035, 0.03, 0.028), vec3(0.22, 0.2, 0.19), ash * 0.6);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	float breath = 0.65 + 0.35 * sin(TIME * (0.7 + r * 1.3) + r * 40.0);
	float crack = 1.0 - smoothstep(0.02, 0.12, border);
	float seam = (1.0 - smoothstep(0.01, 0.05, fine)) * 0.35;
	// Some lumps burn through; ashen ones barely.
	float through = smoothstep(0.35, 0.05, r) * 0.45;
	float heat = (crack + seam + through) * (1.0 - ash * 0.8) * breath;
	EMISSION = hot * heat * glow + vec3(1.0, 0.75, 0.35) * pow(crack * breath, 3.0) * glow * 0.6;
}
