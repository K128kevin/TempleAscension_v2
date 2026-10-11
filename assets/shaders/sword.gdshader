shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// The hero's sword, colored by part along the imported mesh's normalized
// length: brass pommel and cross guard, a dark brown leather grip, and a
// silver blade with a fuller (groove) down the middle of both flat faces.
// (Uniforms, so that the ranger's dagger, cut differently along its length,
// is finished the same way: Art.dagger_material.)
// Each part wears photographed detail (assets/shaders/detail.gdshaderinc):
// the blade worn, scratched steel honed bright at its edges and dull in its
// fuller; the fittings old bronze, darker in their recesses; the grip a
// worn leather.
#include "res://assets/shaders/detail.gdshaderinc"
uniform float POMMEL_TOP = 0.045;
uniform float GRIP_TOP = 0.215;
uniform float GUARD_TOP = 0.33;
// How far the blade sweeps back toward its point (the bandits' sica,
// tools/make_bandits.py): its fuller follows the curve.
uniform float SWEEP = 0.0;
// The colours of its parts (an item's look may give its own: scripts/items.gd).
uniform vec3 blade_color : source_color = vec3(0.82, 0.84, 0.87);
uniform vec3 fittings_color : source_color = vec3(0.78, 0.58, 0.25);
uniform vec3 wrap_color : source_color = vec3(0.16, 0.085, 0.04);
const float FULLER_END = 0.86;
const float FULLER_HALF_WIDTH = 0.04;

varying vec3 local_position;
varying vec3 local_normal;
// The model's own space in metres (the mesh is made a unit long and sized by
// its node), for the photographed detail.
varying vec3 metric_position;
varying vec3 metric_normal;

void vertex() {
	local_position = VERTEX;
	float swept = max(0.0, VERTEX.y - 0.36) / 0.64;
	local_position.x += SWEEP * swept * swept;
	local_normal = NORMAL;
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	metric_position = VERTEX * size;
	metric_normal = normalize(NORMAL / size);
}

// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

void fragment() {
	float y = local_position.y;
	vec3 brass = fittings_color;
	vec3 leather = wrap_color;
	vec3 steel = blade_color;
	vec3 p = metric_position;
	vec3 n = normalize(metric_normal);
	vec3 w = tri_weights(n);
	vec3 bent = n;
	float edge = edge_wear(NORMAL, VERTEX, 0.004);
	if (y < POMMEL_TOP || (y >= GRIP_TOP && y < GUARD_TOP)) {
		// Cast bronze: its high points rubbed bright, dark in its recesses.
		vec4 d = mat_data(p / 0.12, n, w, MAT_BRONZE);
		float shade = mat_shade(p / 0.12, n, w, MAT_BRONZE);
		ALBEDO = brass * mix(1.0, shade, 0.5) * (0.65 + 0.35 * d.g) * (1.0 + 0.3 * edge);
		METALLIC = 1.0;
		ROUGHNESS = clamp(0.38 + d.r * 0.35 - edge * 0.15, 0.28, 0.75);
		bent = mat_normal(p / 0.12, n, w, MAT_BRONZE, 0.8);
	} else if (y < GRIP_TOP) {
		// Leather wrap: diagonal bands, the hide's grain and the hand's polish.
		float wrap = 0.8 + 0.2 * step(0.5, fract((y + local_position.x * 0.6) * 60.0));
		vec4 d = mat_data(p / 0.1, n, w, MAT_LEATHER_WORN);
		ALBEDO = leather * wrap * mix(1.0, mat_shade(p / 0.1, n, w, MAT_LEATHER_WORN), 0.5) * (0.75 + 0.25 * d.g);
		METALLIC = 0.0;
		ROUGHNESS = clamp(0.45 + d.r * 0.4, 0.4, 0.85);
		bent = mat_normal(p / 0.1, n, w, MAT_LEATHER_WORN, 1.4);
	} else {
		// Worn steel: scratched, a little mottled, honed bright along its
		// edges.
		vec4 d = mat_data(p / 0.25, n, w, MAT_STEEL_WORN);
		float shade = mat_shade(p / 0.25, n, w, MAT_STEEL_WORN);
		ALBEDO = steel * 0.82 * mix(1.0, shade, 0.6) * (0.85 + 0.15 * d.g);
		METALLIC = 1.0;
		ROUGHNESS = clamp(0.28 + d.r * 0.35, 0.24, 0.65);
		bent = mat_normal(p / 0.25, n, w, MAT_STEEL_WORN, 0.7);
		ALBEDO = mix(ALBEDO, steel, edge * 0.6);
		ROUGHNESS = mix(ROUGHNESS, 0.2, edge);
		// The fuller runs along the flat faces, fading out toward the point.
		bool flat_face = abs(normalize(local_normal).z) > 0.6;
		float along = smoothstep(GUARD_TOP, GUARD_TOP + 0.02, y) * (1.0 - smoothstep(FULLER_END - 0.04, FULLER_END, y));
		float groove = (1.0 - smoothstep(FULLER_HALF_WIDTH * 0.6, FULLER_HALF_WIDTH, abs(local_position.x))) * along;
		if (flat_face && groove > 0.0) {
			ALBEDO = mix(ALBEDO, ALBEDO * 0.55, groove);
			ROUGHNESS = mix(ROUGHNESS, 0.5, groove);
			// Tilt the normal across the groove so it catches light like a channel.
			float slope = clamp(local_position.x / FULLER_HALF_WIDTH, -1.0, 1.0);
			vec3 tilt = (VIEW_MATRIX * MODEL_MATRIX * vec4(sign(local_normal.z) * vec3(-slope * 0.6, 0.0, 0.0), 0.0)).xyz;
			NORMAL = normalize(NORMAL + tilt * groove);
		}
	}
	NORMAL = detail_normal(bent, n, p, VERTEX, NORMAL);
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
