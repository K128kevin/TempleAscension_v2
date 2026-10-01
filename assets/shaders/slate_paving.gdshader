shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Grey cleft-slate pavers laid in an ashlar pattern, for the open-air
// terraces: rectangles of several sizes interlocking in a 2.4m module, each
// paver a slightly different tone, with a riven, uneven surface, softly
// rounded edges and thin dark joints. Drawn in world space so batched floor
// tiles stay continuous.
// A cool grey, so it still reads grey under the braziers' warm light.
uniform vec3 stone_color : source_color = vec3(0.39, 0.43, 0.50);
uniform vec3 joint_color : source_color = vec3(0.16, 0.16, 0.17);
// One grid unit of the pattern, in metres.
uniform float unit = 0.4;

const int PIECES = 9;
// The module, 6 x 6 units: each paver as (x, y, width, height) in units.
const vec4 LAYOUT[PIECES] = vec4[](
	vec4(0.0, 0.0, 3.0, 2.0), vec4(3.0, 0.0, 2.0, 2.0), vec4(5.0, 0.0, 1.0, 3.0),
	vec4(0.0, 2.0, 2.0, 2.0), vec4(2.0, 2.0, 3.0, 2.0), vec4(5.0, 3.0, 1.0, 3.0),
	vec4(0.0, 4.0, 3.0, 2.0), vec4(3.0, 4.0, 1.0, 2.0), vec4(4.0, 4.0, 1.0, 2.0));

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(cell), hash2(cell + vec2(1, 0)), f.x),
		mix(hash2(cell + vec2(0, 1)), hash2(cell + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 5; i++) {
		total += noise(p) * amplitude;
		p = p * 2.07 + vec2(13.7, 5.3);
		amplitude *= 0.5;
	}
	return total;
}

// The paver under world point `p`: its identity, and how far `p` lies
// inside it from its nearest edge (in metres).
void paver(vec2 p, out vec2 id, out float inset) {
	vec2 g = p / unit;
	vec2 module = floor(g / 6.0);
	vec2 local = g - module * 6.0;
	// Mirror alternate modules so the repeat does not read as a grid.
	vec2 flip = mod(module, 2.0);
	if (flip.x > 0.5) local.x = 6.0 - local.x;
	if (flip.y > 0.5) local.y = 6.0 - local.y;
	id = module * 16.0;
	inset = 0.0;
	for (int i = 0; i < PIECES; i++) {
		vec4 r = LAYOUT[i];
		vec2 d = min(local - r.xy, r.xy + r.zw - local);
		if (d.x >= 0.0 && d.y >= 0.0) {
			id += vec2(float(i), float(i) * 3.0);
			inset = min(d.x, d.y) * unit;
			return;
		}
	}
}

// Surface height (metres): the riven top of a paver, falling away over its
// rounded edge into the joint.
float surface(vec2 p) {
	vec2 id;
	float inset;
	paver(p, id, inset);
	float seed = hash2(id);
	float riven = fbm(p * 3.1 + seed * 31.0) * 0.011 + fbm(p * 11.0 + seed * 7.0) * 0.004;
	float edge = smoothstep(0.004, 0.03, inset);
	return riven * edge - (1.0 - edge) * 0.008;
}

void fragment() {
	// Multimesh-safe world position: VERTEX is view space in fragment().
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 id;
	float inset;
	paver(p, id, inset);
	float seed = hash2(id);
	// Each paver its own shade of grey, some a touch bluer or browner.
	vec3 color = stone_color * (0.86 + seed * 0.24);
	color *= vec3(1.0 + (hash2(id + 5.0) - 0.5) * 0.06, 1.0, 1.0 + (hash2(id + 9.0) - 0.5) * 0.08);
	// Mottling and fine grain in the riven face.
	color *= 0.88 + fbm(p * 1.7 + seed * 13.0) * 0.24;
	color *= 0.94 + noise(p * 70.0) * 0.12;
	float joint = 1.0 - smoothstep(0.003, 0.009, inset);
	float rim = 1.0 - smoothstep(0.009, 0.03, inset);
	color = mix(color, color * 0.8, rim * 0.6);
	color = mix(color, joint_color, joint);
	ALBEDO = color;
	// Light catches the riven relief and the rounded edges.
	float e = 0.004;
	float h = surface(p);
	vec3 n = normalize(vec3((h - surface(p + vec2(e, 0.0))) / e, 1.0, (h - surface(p + vec2(0.0, e))) / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(0.88, 0.95, joint);
	SPECULAR = 0.25;
}
