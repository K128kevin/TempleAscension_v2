shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The warrior's war kilt, after his concept art (tools/warrior_kit.py): long
// pteruges, separate stiff strips of dark leather each hung from the belt and
// swung on its own (scripts/kilt_strips.gd), each with a stitched, raised
// border, a steel leaf motif and a Greek-key band near its hem, under a row
// of short rounded tabs with a steel stud. Each strip carries its place in
// its UVs: U its number (the tabs from 18) plus how far across it, V how far
// down it; the backs and cut edges are U plus 500, a rougher flesh side. Laid
// on the kilt's rest pose (CUSTOM0), so the leather's wear stays on each
// strip as it swings. Photographed leather and steel over it
// (assets/shaders/detail.gdshaderinc).
#include "res://assets/shaders/detail.gdshaderinc"
uniform bool rest_pose = false;
const float STRIPS = 18.0;

varying vec3 kilt_position;
varying vec3 kilt_normal;

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

float fbm2(vec2 p) {
	float t = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { t += noise2(p) * a; p = p * 2.03 + 7.1; a *= 0.5; }
	return t / 0.9375;
}

void vertex() {
	kilt_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	kilt_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
}

// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

void fragment() {
	vec3 p = kilt_position;
	bool back = UV.x > 250.0;
	float code = back ? UV.x - 500.0 : UV.x;
	float strip = floor(code + 0.0001);
	float u = clamp(code - strip, 0.0, 1.0);
	// (glTF turns V over.)
	float t = clamp(1.0 - UV.y, 0.0, 1.0);
	bool tab = strip >= STRIPS - 0.5;
	float seed = hash2(vec2(strip, 3.0));
	vec2 wear_uv = vec2(strip * 3.1 + u * 2.0, t * (tab ? 2.0 : 8.0));
	float wear = fbm2(wear_uv * 3.0);
	vec3 leather = vec3(0.17, 0.13, 0.12) * (0.75 + wear * 0.5) * (0.9 + seed * 0.2);
	// A dull red cast to some strips, as in the concept.
	leather = mix(leather, vec3(0.22, 0.11, 0.1) * (0.8 + wear * 0.4), step(0.6, seed) * 0.6);
	vec3 steel = vec3(0.5, 0.51, 0.53) * (0.7 + fbm2(wear_uv * 6.0) * 0.45);
	vec3 color = leather;
	float h = 0.0;
	float metal = 0.0;
	if (back) {
		// The flesh side and the cut edges: rough, paler suede.
		color = vec3(0.2, 0.15, 0.12) * (0.7 + wear * 0.5);
	} else {
		// A raised border, stitched a little in from each edge.
		float edge = min(min(u, 1.0 - u) * (tab ? 0.065 : 0.06), (1.0 - t) * (tab ? 0.1 : 0.39));
		color *= 0.78 + 0.35 * smoothstep(0.0, 0.006, edge);
		h = 0.0012 * smoothstep(0.0, 0.005, edge);
		if (abs(edge - 0.0055) < 0.0009 && fract(t * (tab ? 22.0 : 90.0) + u * 0.0) < 0.55) color *= 1.55;
		if (tab) {
			// The tab's steel stud.
			float stud = length(vec2((u - 0.5) * 0.065, (t - 0.45) * 0.1));
			if (stud < 0.0085) {
				color = steel * (1.0 + 0.4 * (1.0 - stud / 0.0085));
				h = 0.004 * (1.0 - stud / 0.0085);
				metal = 1.0;
			}
		} else {
			// A steel leaf motif, a diamond with a raised spine.
			vec2 m = vec2((u - 0.5) * 3.2, (t - 0.5) / 0.14);
			float leaf = abs(m.x) + abs(m.y) * 0.55;
			if (leaf < 0.55) {
				color = steel * (0.75 + 0.5 * (1.0 - leaf / 0.55));
				h = 0.003 * (1.0 - leaf / 0.55);
				metal = 0.85;
			}
			// A Greek-key band near the hem.
			float kb = (t - 0.8) / 0.08;
			if (kb > 0.0 && kb < 1.0 && u > 0.1 && u < 0.9) {
				float kx = fract((u - 0.1) / 0.8 * 3.0);
				bool line = kb < 0.15 || kb > 0.85 || kx < 0.15 || (kx < 0.65 && kb > 0.55 && kb < 0.7) || (kx > 0.5 && kx < 0.65 && kb > 0.3);
				if (line) { color = steel * 0.95; h = 0.0012; metal = 0.7; }
			}
			// Scuffed paler along the hem, where it is kicked.
			color = mix(color, color * 1.35, smoothstep(0.9, 1.0, t) * 0.4 * (1.0 - metal));
		}
	}
	// Photographed leather and steel over it (assets/shaders/detail.gdshaderinc).
	vec3 kn = normalize(kilt_normal);
	vec3 kw = tri_weights(kn);
	float layer = metal > 0.5 ? MAT_STEEL_WORN : MAT_LEATHER_WORN;
	float tile = metal > 0.5 ? 0.25 : 0.18;
	vec4 scan = mat_data(p / tile, kn, kw, layer);
	color *= mix(1.0, mat_shade(p / tile, kn, kw, layer), 0.45) * (0.72 + 0.28 * scan.g);
	ALBEDO = color;
	METALLIC = metal;
	SPECULAR = mix(0.12, 0.5, metal);
	ROUGHNESS = clamp(mix(back ? 0.8 : 0.62, 0.3, metal) + scan.r * 0.3, 0.2, 0.95);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	NORMAL = detail_normal(mat_normal(p / tile, kn, kw, layer, metal > 0.5 ? 0.8 : 1.3), kn, p, VERTEX, NORMAL);
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
