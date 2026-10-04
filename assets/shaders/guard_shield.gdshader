shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A town guard's shield (scripts/town_guard.gd), on the KayKit square
// shield: a legionary's board, faced with leather painted red, with a bronze
// rim, an iron boss and bronze bars above and below it, all knocked about,
// faded, scraped through to the wood and dusty toward its foot. The model is
// a unit box (tools/prepare_models.py): X across, Y up from its foot, Z its
// thickness.
uniform sampler2D grit : source_color, filter_linear_mipmap, repeat_enable;
uniform float seed = 0.0;
// Its size in metres, so the trim keeps its width.
uniform vec3 size = vec3(0.6, 1.0, 0.2);

varying vec3 unit;

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	unit = VERTEX;
}

void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	// On the board's face, in metres from its middle.
	vec2 m = vec2(unit.x * size.x, (unit.y - 0.5) * size.y);
	vec2 at = m + vec2(seed * 3.1, seed * 1.7);
	float edge = min(size.x * 0.5 - abs(m.x), size.y * 0.5 - abs(m.y));
	float boss = length(m);
	float bar = abs(abs(m.y) - 0.2);
	float wear = noise2(at * 9.0) * 0.6 + noise2(at * 31.0) * 0.4;
	float scrape = smoothstep(0.62, 0.8, noise2(at * vec2(14.0, 40.0)) * 0.5 + noise2(at * 60.0) * 0.5);
	vec3 colour;
	float rough;
	float metal = 0.0;
	if (edge < 0.025) {
		// The bronze rim.
		colour = mix(vec3(0.4, 0.27, 0.12), vec3(0.66, 0.48, 0.24), smoothstep(0.3, 0.8, wear));
		rough = 0.5;
		metal = 0.5;
	} else if (boss < 0.085) {
		// The iron boss, rubbed bright on its crown.
		colour = mix(vec3(0.24, 0.23, 0.22), vec3(0.55, 0.55, 0.56), smoothstep(0.06, 0.0, boss) * 0.8 + wear * 0.2);
		if (abs(boss - 0.08) < 0.004) colour *= 0.6;
		rough = 0.4;
		metal = 0.5;
	} else if (bar < 0.018 && abs(m.x) < size.x * 0.36) {
		// The bronze bars.
		colour = mix(vec3(0.38, 0.26, 0.11), vec3(0.6, 0.44, 0.22), wear);
		rough = 0.5;
		metal = 0.45;
	} else {
		// Red-painted leather over the wood, faded, scraped through to the
		// board in places.
		colour = vec3(0.42, 0.07, 0.06) * (0.8 + wear * 0.35);
		colour = mix(colour, vec3(0.5, 0.3, 0.26), smoothstep(0.45, 0.85, noise2(at * 4.0)) * 0.35);
		colour = mix(colour, vec3(0.36, 0.25, 0.15) * (0.8 + noise2(vec2(at.x * 90.0, at.y * 6.0)) * 0.4), scrape);
		rough = 0.85;
	}
	// The dust of the road, toward its foot.
	float dust = texture(grit, at * 2.3).r;
	float grime = smoothstep(0.4, 0.75, dust + (1.0 - unit.y) * 0.3) * (0.3 + 0.4 * (1.0 - unit.y));
	colour = mix(colour, colour * vec3(0.55, 0.47, 0.38) + vec3(0.05, 0.04, 0.03), grime);
	ALBEDO = colour;
	ROUGHNESS = clamp(rough + grime * 0.3, 0.0, 1.0);
	METALLIC = metal * (1.0 - grime * 0.6);
	SPECULAR = 0.35;
}
