shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Steel plate armor on the hero's legs (tools/outfit_hero.py HeroGreaves and
// HeroCuisses): hammered, worn steel as the warrior's helm is
// (assets/shaders/gladiator_helm.gdshader), made up of lames, overlapping
// horizontal plates each with a dark seam under its lower edge and a row of
// rivets along it; a rolled, riveted rim at the top and bottom; a raised
// ridge down the front of each shin and a domed cop over each knee (the
// greaves), or a brighter crease down the front of the thigh (the cuisses).
// Laid on the piece's rest pose (CUSTOM0 position, CUSTOM1 normal: from
// Art.rest_pose_mesh), the figure's front along +Z, heights in metres.
uniform bool rest_pose = false;
// Where the plates run, up the leg: the rims sit at `rim_low` and
// `rim_high`, the lames between them every `lame` metres (0: one plate).
uniform float rim_low = 0.03;
uniform float rim_high = 0.55;
uniform float lame = 0.0;
// The knee cop's height (below 0: none), the ankle's, where the foot's plates
// meet the greave under a rolled rim (below 0: none), and whether a shin
// ridge runs down the front.
uniform float knee = -1.0;
uniform float ankle = -1.0;
uniform float ridge = 1.0;
// The legs' axes, out from the figure's middle.
uniform float leg_x = 0.1;

varying vec3 plate_position;
varying vec3 rest_normal;

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

float noise3(vec3 p) {
	return mix(noise2(p.xy + floor(p.z) * 17.0), noise2(p.xy + (floor(p.z) + 1.0) * 17.0), smoothstep(0.0, 1.0, fract(p.z)));
}

// A row of round rivet heads along `run` (metres) at `across` from their line.
float rivets(float run, float across, float spacing, float size) {
	float d = length(vec2((fract(run / spacing) - 0.5) * spacing, across));
	return 1.0 - smoothstep(size * 0.6, size, d);
}

void vertex() {
	plate_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	rest_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
}

// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

void fragment() {
	vec3 p = plate_position;
	// Round the leg this point is on (metres along its girth), and how
	// squarely it faces the front.
	vec2 off = vec2(p.x - sign(p.x) * leg_x, p.z);
	float around = atan(off.x, off.y) * 0.17;
	vec3 n = normalize(rest_normal);
	float front = smoothstep(0.55, 0.95, n.z);
	// Hammered steel: broad dents, a fine grain, darker oxidised patches,
	// rust specks, and scratches running every which way.
	float dents = noise3(p * 55.0);
	float grain = noise2(vec2(p.x + p.z, p.y) * 900.0);
	float patina = smoothstep(0.45, 0.75, noise3(p * 14.0 + 3.0));
	vec3 color = vec3(0.6, 0.61, 0.63) * (0.82 + dents * 0.22) * (0.95 + grain * 0.08);
	color = mix(color, vec3(0.32, 0.31, 0.3), patina * 0.55);
	float rust = smoothstep(0.82, 0.93, noise3(p * 60.0 + 11.0)) * smoothstep(0.55, 0.85, noise3(p * 9.0));
	color = mix(color, vec3(0.34, 0.19, 0.1), rust * 0.8);
	float scratch_a = smoothstep(0.92, 0.97, noise2(vec2(p.x * 700.0 + p.y * 120.0, p.y * 25.0 + p.z * 40.0)));
	float scratch_b = smoothstep(0.93, 0.97, noise2(vec2(p.y * 650.0 - p.z * 200.0, p.x * 30.0)));
	float scratch = max(scratch_a, scratch_b);
	color = mix(color, vec3(0.8, 0.81, 0.82), scratch * 0.6);
	float h = (dents - 0.5) * 0.0012 - scratch * 0.0002;
	float rough = 0.32 + dents * 0.12 + patina * 0.25 + rust * 0.4 - scratch * 0.1;
	// The lames: each plate laps over the one below, a dark seam in its
	// shadow and rivets along its lower edge.
	if (lame > 0.0 && p.y > rim_low && p.y < rim_high) {
		float up = fract((p.y - rim_low) / lame) * lame;
		float seam = smoothstep(0.012, 0.0, up);
		h -= 0.0016 * seam;
		color *= 1.0 - 0.45 * seam;
		float rv = rivets(around, up - 0.018, 0.03, 0.0038);
		h += 0.0017 * rv;
		color = mix(color, vec3(0.78), rv * 0.5);
	}
	// The rolled rims, riveted.
	float lower = p.y - rim_low;
	if (abs(lower) < 0.014) {
		h += 0.002 * smoothstep(0.014, 0.005, abs(lower));
		color *= 0.94;
		float lr = rivets(around, lower - 0.022, 0.03, 0.0036);
		h += 0.0015 * lr;
		color = mix(color, vec3(0.78), lr * 0.5);
	}
	float upper = p.y - rim_high;
	if (abs(upper) < 0.014) {
		h += 0.002 * smoothstep(0.014, 0.005, abs(upper));
		color *= 0.94;
		float ur = rivets(around, upper + 0.022, 0.03, 0.0036);
		h += 0.0015 * ur;
		color = mix(color, vec3(0.78), ur * 0.5);
	}
	// The ankle: a rolled rim where the foot's plates meet the greave.
	float shin = p.y - ankle;
	if (ankle > 0.0 && abs(shin) < 0.012) {
		h += 0.0018 * smoothstep(0.012, 0.004, abs(shin));
		color *= 0.9;
		float ar = rivets(around, shin + 0.018, 0.028, 0.0034);
		h += 0.0014 * ar;
		color = mix(color, vec3(0.78), ar * 0.5);
	}
	// A ridge down the front of the shin, and the knee cop, a dome with a
	// ring round it.
	if (ridge > 0.5) {
		float crest = front * smoothstep(0.03, 0.0, abs(off.x));
		h += 0.0024 * crest;
		color *= 1.0 + 0.12 * crest;
	}
	if (knee > 0.0) {
		float boss = length(vec2(off.x, p.y - knee) / vec2(0.055, 0.065));
		float dome = front * smoothstep(1.0, 0.6, boss);
		h += 0.005 * dome;
		color = mix(color, vec3(0.66) * (0.85 + 0.3 * dome), dome * 0.7);
		float ring = abs(boss - 0.82);
		if (ring < 0.06) color *= 1.0 - 0.4 * front * (1.0 - ring / 0.06);
	}
	ALBEDO = color;
	METALLIC = 0.45;
	ROUGHNESS = clamp(rough, 0.2, 0.9);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
