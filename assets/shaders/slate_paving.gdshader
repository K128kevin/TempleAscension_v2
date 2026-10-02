shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Grey sandstone paving for the open-air terraces, laid in the French
// Versailles pattern of the reference photo (a split-face grey sandstone
// pattern set): square and oblong stones of 1 x 1 to 3 x 2 units, 48 of them
// in a 12 x 11 unit panel, set exactly as in the photo and repeated. Each
// stone its own shade of grey (some bluer, some warmer, a few darker), with
// the sandstone's streaky bedding running across it, a split-face surface of
// thin cleft layers whose broken edges catch the light, softly chipped
// arrises and thin dark joints. Drawn in world space so batched floor tiles
// stay continuous.
// A cool grey, so it still reads grey under the braziers' warm light.
uniform vec3 stone_color : source_color = vec3(0.45, 0.49, 0.56);
uniform vec3 joint_color : source_color = vec3(0.13, 0.13, 0.14);
// One unit of the pattern, in metres (the smallest stones are a unit square).
uniform float unit = 0.3;

const int PIECES = 48;
const int COLUMNS = 12;
const int ROWS = 11;
// The stones of the panel as (column, row, width, height) in units, from the
// reference photo, left to right and top to bottom.
const vec4 LAYOUT[PIECES] = vec4[](
	vec4(0.0, 0.0, 2.0, 3.0), vec4(2.0, 0.0, 1.0, 2.0), vec4(3.0, 0.0, 2.0, 1.0), vec4(5.0, 0.0, 2.0, 2.0),
	vec4(7.0, 0.0, 1.0, 2.0), vec4(8.0, 0.0, 1.0, 1.0), vec4(9.0, 0.0, 3.0, 2.0), vec4(3.0, 1.0, 2.0, 2.0),
	vec4(8.0, 1.0, 1.0, 1.0), vec4(2.0, 2.0, 1.0, 1.0), vec4(5.0, 2.0, 1.0, 1.0), vec4(6.0, 2.0, 3.0, 2.0),
	vec4(9.0, 2.0, 2.0, 1.0), vec4(11.0, 2.0, 1.0, 2.0), vec4(0.0, 3.0, 1.0, 1.0), vec4(1.0, 3.0, 3.0, 2.0),
	vec4(4.0, 3.0, 2.0, 2.0), vec4(9.0, 3.0, 1.0, 2.0), vec4(10.0, 3.0, 1.0, 1.0), vec4(0.0, 4.0, 1.0, 2.0),
	vec4(6.0, 4.0, 1.0, 1.0), vec4(7.0, 4.0, 1.0, 2.0), vec4(8.0, 4.0, 1.0, 1.0), vec4(10.0, 4.0, 2.0, 2.0),
	vec4(1.0, 5.0, 2.0, 1.0), vec4(3.0, 5.0, 2.0, 2.0), vec4(5.0, 5.0, 2.0, 3.0), vec4(8.0, 5.0, 2.0, 2.0),
	vec4(0.0, 6.0, 2.0, 3.0), vec4(2.0, 6.0, 1.0, 1.0), vec4(7.0, 6.0, 1.0, 1.0), vec4(10.0, 6.0, 1.0, 1.0),
	vec4(11.0, 6.0, 1.0, 2.0), vec4(2.0, 7.0, 2.0, 2.0), vec4(4.0, 7.0, 1.0, 1.0), vec4(7.0, 7.0, 2.0, 2.0),
	vec4(9.0, 7.0, 2.0, 1.0), vec4(4.0, 8.0, 2.0, 2.0), vec4(6.0, 8.0, 1.0, 1.0), vec4(9.0, 8.0, 1.0, 1.0),
	vec4(10.0, 8.0, 2.0, 3.0), vec4(0.0, 9.0, 1.0, 2.0), vec4(1.0, 9.0, 3.0, 2.0), vec4(6.0, 9.0, 2.0, 1.0),
	vec4(8.0, 9.0, 2.0, 2.0), vec4(4.0, 10.0, 1.0, 1.0), vec4(5.0, 10.0, 2.0, 1.0), vec4(7.0, 10.0, 1.0, 1.0));
// Which stone covers each unit square of the panel, row by row.
const int CELLS[COLUMNS * ROWS] = int[](
	0, 0, 1, 2, 2, 3, 3, 4, 5, 6, 6, 6,
	0, 0, 1, 7, 7, 3, 3, 4, 8, 6, 6, 6,
	0, 0, 9, 7, 7, 10, 11, 11, 11, 12, 12, 13,
	14, 15, 15, 15, 16, 16, 11, 11, 11, 17, 18, 13,
	19, 15, 15, 15, 16, 16, 20, 21, 22, 17, 23, 23,
	19, 24, 24, 25, 25, 26, 26, 21, 27, 27, 23, 23,
	28, 28, 29, 25, 25, 26, 26, 30, 27, 27, 31, 32,
	28, 28, 33, 33, 34, 26, 26, 35, 35, 36, 36, 32,
	28, 28, 33, 33, 37, 37, 38, 35, 35, 39, 40, 40,
	41, 42, 42, 42, 37, 37, 43, 43, 44, 44, 40, 40,
	41, 42, 42, 42, 45, 46, 46, 47, 44, 44, 40, 40);

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
	return total / 0.97;
}

// The stone under world point `p`: an id for it, and how far `p` lies inside
// it from its nearest edge (metres), the edge a little ragged as split stone
// is.
void stone(vec2 p, out vec2 id, out float inset) {
	vec2 g = p / unit;
	vec2 panel = floor(g / vec2(float(COLUMNS), float(ROWS)));
	vec2 local = g - panel * vec2(float(COLUMNS), float(ROWS));
	ivec2 c = clamp(ivec2(floor(local)), ivec2(0), ivec2(COLUMNS - 1, ROWS - 1));
	int index = CELLS[c.y * COLUMNS + c.x];
	vec4 r = LAYOUT[index];
	vec2 d = min(local - r.xy, r.xy + r.zw - local);
	id = panel * 64.0 + vec2(float(index), float(index) * 3.0);
	float ragged = (noise(p * 38.0 + float(index)) - 0.5) * 0.006 + (noise(p * 140.0) - 0.5) * 0.002;
	inset = min(d.x, d.y) * unit + ragged;
}

// The bedding direction of a stone: sandstone splits along its layers, which
// show as streaks running across the face.
vec2 bedding(vec2 id) {
	float a = hash2(id + 17.0) * 3.1416;
	return vec2(cos(a), sin(a));
}

// Surface height (metres): the cleft face of thin layers, each step a broken
// edge, falling away over the chipped arris into the joint.
float surface(vec2 p) {
	vec2 id;
	float inset;
	stone(p, id, inset);
	float seed = hash2(id);
	vec2 along = bedding(id);
	vec2 b = vec2(dot(p, along), dot(p, vec2(-along.y, along.x)));
	// Terraced layers: the cleft surface stepping in thin sheets.
	float t = fbm(b * vec2(2.2, 5.5) + seed * 31.0) * 4.0;
	float layer = floor(t) + smoothstep(0.0, 0.18, fract(t));
	float cleft = layer * 0.0035 + fbm(p * 14.0 + seed * 7.0) * 0.0025;
	float edge = smoothstep(0.003, 0.025, inset);
	return cleft * edge - (1.0 - edge) * 0.008;
}

void fragment() {
	// Multimesh-safe world position: VERTEX is view space in fragment().
	vec2 p = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;
	vec2 id;
	float inset;
	stone(p, id, inset);
	float seed = hash2(id);
	vec2 along = bedding(id);
	vec2 b = vec2(dot(p, along), dot(p, vec2(-along.y, along.x)));
	// Each stone its own grey: most mid, some lighter, a few darker; some a
	// touch bluer, some warmer.
	float shade = 0.84 + seed * 0.26 - step(0.86, hash2(id + 3.0)) * 0.14;
	vec3 color = stone_color * shade;
	float hue = hash2(id + 5.0) - 0.5;
	color *= vec3(1.0 + hue * 0.06, 1.0, 1.0 - hue * 0.07);
	// The bedding: soft light and dark streaks across the stone, wavering.
	float streak = fbm(b * vec2(0.8, 9.0) + seed * 13.0);
	color *= 0.86 + streak * 0.28;
	// Mottling and the fine sandy grain.
	color *= 0.92 + fbm(p * 2.3 + seed * 9.0) * 0.14;
	color *= 0.94 + noise(p * 220.0) * 0.12;
	// The broken edges of the cleft layers, pale where they catch the light.
	float t = fbm(b * vec2(2.2, 5.5) + seed * 31.0) * 4.0;
	float ridge = 1.0 - smoothstep(0.0, 0.08, abs(fract(t) - 0.04));
	color = mix(color, color * 1.32 + 0.04, ridge * 0.55 * smoothstep(0.01, 0.03, inset));
	// The chipped arris, darker, then the joint.
	float aa = fwidth(inset);
	float joint = 1.0 - smoothstep(0.004 - aa, 0.007 + aa, inset);
	float rim = 1.0 - smoothstep(0.008, 0.026, inset);
	color = mix(color, color * 0.78, rim * 0.5);
	color = mix(color, joint_color, joint);
	ALBEDO = color;
	// Light catches the cleft relief and the chipped edges.
	float e = 0.003;
	float h = surface(p);
	vec3 n = normalize(vec3((h - surface(p + vec2(e, 0.0))) / e, 1.0, (h - surface(p + vec2(0.0, e))) / e));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	ROUGHNESS = mix(0.86 - ridge * 0.08, 0.95, joint);
	SPECULAR = 0.28;
}
