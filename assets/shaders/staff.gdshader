shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The hero wizard's staffs (tools/make_staffs.py), one part at a time: its
// metal, its crystal, the leather or cord of its grip, its wood, its bronze.
// Each part is unwrapped round and along itself (UV.x once round, UV.y in
// metres along it), so its grain, scratches and wrapping are fixed to it.
// Over each lies photographed detail (assets/shaders/detail.gdshaderinc).
#include "res://assets/shaders/detail.gdshaderinc"
uniform int part = 0;
uniform vec3 metal : source_color = vec3(0.8, 0.81, 0.84);
uniform vec3 crystal : source_color = vec3(0.78, 0.9, 1.0);
uniform vec3 leather : source_color = vec3(0.23, 0.15, 0.1);
uniform vec3 wood : source_color = vec3(0.5, 0.41, 0.31);
uniform vec3 bronze : source_color = vec3(0.6, 0.42, 0.22);
// How brightly the crystal glows.
uniform float glow = 0.9;

varying vec3 metric_position;
varying vec3 metric_normal;

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	metric_position = VERTEX * size;
	metric_normal = normalize(NORMAL / size);
}

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
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

void fragment() {
	vec2 uv = UV;
	float facing = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	vec3 mp = metric_position;
	vec3 mn = normalize(metric_normal);
	vec3 mw = tri_weights(mn);
	vec3 bent = mn;
	if (part == 1) {
		// The crystal: clear and pale, lit from within, brightest toward its
		// edges as light runs through it; a faint cloud inside.
		float cloud = fbm(vec2(uv.x * 6.0, uv.y * 30.0));
		float edge = pow(1.0 - facing, 2.0);
		ALBEDO = crystal * (0.35 + 0.25 * cloud);
		EMISSION = crystal * glow * (0.35 + 0.9 * edge + 0.25 * cloud);
		METALLIC = 0.0;
		ROUGHNESS = 0.06;
		SPECULAR = 1.0;
		RIM = 0.4;
	} else if (part == 2) {
		// Leather or cord, wound round: darker in the hollows between the
		// turns, worn paler on the high side of each, with a fine grain.
		float turn = fract(uv.y / 0.019 - uv.x);
		float ridge = sin(3.14159 * turn);
		float grain = fbm(vec2(uv.x * 60.0, uv.y * 200.0));
		vec3 color = leather * (0.55 + 0.55 * ridge) * (0.85 + 0.3 * grain);
		vec4 d = mat_data(mp / 0.08, mn, mw, MAT_LEATHER_WORN);
		ALBEDO = color * (0.8 + 0.2 * d.g);
		METALLIC = 0.0;
		ROUGHNESS = clamp(0.62 - 0.15 * ridge + d.r * 0.2, 0.35, 0.9);
		bent = mat_normal(mp / 0.08, mn, mw, MAT_LEATHER_WORN, 1.2);
	} else if (part == 3) {
		// Ash: pale grey-brown, its grain running along the branch in long
		// streaks, darker in its crevices and at the knots.
		float streak = fbm(vec2(uv.x * 22.0, uv.y * 1.6));
		float fine = noise(vec2(uv.x * 140.0, uv.y * 9.0));
		float dark = smoothstep(0.35, 0.75, streak);
		vec3 color = wood * mix(1.08, 0.62, dark) * (0.9 + 0.18 * fine);
		vec4 d = mat_data_up(mp / 0.3, mn, mw, MAT_WOOD_ASH);
		ALBEDO = color * mix(1.0, mat_shade_up(mp / 0.3, mn, mw, MAT_WOOD_ASH), 0.6) * (0.8 + 0.2 * d.g);
		METALLIC = 0.0;
		ROUGHNESS = clamp(0.6 + d.r * 0.3, 0.45, 0.95);
		bent = mat_normal_up(mp / 0.3, mn, mw, MAT_WOOD_ASH, 1.2);
	} else if (part == 4) {
		// Bronze, rubbed bright on its edges and green with age in patches.
		float patina = smoothstep(0.55, 0.8, fbm(vec2(uv.x * 9.0, uv.y * 40.0)));
		float rub = pow(1.0 - facing, 1.5);
		vec3 color = mix(bronze * (0.9 + 0.3 * rub), vec3(0.28, 0.42, 0.34), patina * 0.65);
		vec4 d = mat_data(mp / 0.1, mn, mw, MAT_BRONZE);
		ALBEDO = color * mix(1.0, mat_shade(mp / 0.1, mn, mw, MAT_BRONZE), 0.4) * (0.7 + 0.3 * d.g);
		METALLIC = mix(1.0, 0.15, patina);
		ROUGHNESS = mix(clamp(0.28 + d.r * 0.3, 0.2, 0.7), 0.75, patina);
		bent = mat_normal(mp / 0.1, mn, mw, MAT_BRONZE, 0.8);
	} else {
		// Metal: polished, with fine scratches along it and tarnish dulling
		// it here and there.
		float scratch = hash(vec2(floor(uv.x * 140.0), floor(uv.y * 6.0)));
		float tarnish = fbm(vec2(uv.x * 7.0, uv.y * 12.0));
		vec3 color = metal * (0.82 + 0.16 * scratch) * mix(1.05, 0.75, smoothstep(0.45, 0.8, tarnish));
		// (Full metal: it reflects the scene's sky, scripts/reflections.gd.)
		vec4 d = mat_data_up(mp / 0.2, mn, mw, MAT_STEEL_BRUSHED);
		float edge = edge_wear(NORMAL, VERTEX, 0.004);
		ALBEDO = mix(color * mix(1.0, mat_shade_up(mp / 0.2, mn, mw, MAT_STEEL_BRUSHED), 0.4) * (0.8 + 0.2 * d.g), metal, edge * 0.5);
		METALLIC = 1.0;
		ROUGHNESS = mix(clamp(mix(0.22, 0.45, tarnish) + d.r * 0.15, 0.15, 0.7), 0.15, edge);
		bent = mat_normal_up(mp / 0.2, mn, mw, MAT_STEEL_BRUSHED, 0.5);
	}
	if (part != 1) NORMAL = detail_normal(bent, mn, mp, VERTEX, NORMAL);
}
