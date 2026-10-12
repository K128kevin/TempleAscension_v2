shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The warrior's articulated steel (tools/warrior_kit.py): his pauldrons, a
// domed cop over each shoulder and lames lapping down the upper arm, and his
// gauntlets, a bell cuff over the wrist, lames over the back of the hand, a
// knuckle plate and a scale over each joint of every finger, on a glove of
// oiled leather whose palm and finger-insides show. Hammered, worn steel as
// his greaves are (assets/shaders/plate.gdshader).
//
// The pieces carry their plates in their UVs: V is the plate's number plus how
// far across it (0 at the edge lapped under the plate before, 1 at its own
// free edge); U is metres round it (plus 100 for the gauntlets' leather).
// Laid on the rest pose (CUSTOM0 position, CUSTOM1 normal: Art.rest_pose_mesh)
// so the wear stays put as he moves. Over it lies photographed steel and
// leather (assets/shaders/detail.gdshaderinc). Full metal: it reflects the
// scene's sky (scripts/reflections.gd).
#include "res://assets/shaders/detail.gdshaderinc"
uniform bool rest_pose = false;
// 0 the pauldrons, 1 the gauntlets.
uniform int kind = 0;
// One of a pair (pictured alone): the side of the body kept, +1 or -1.
uniform float keep_side = 0.0;
// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

varying vec3 rest;
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

// A round rivet head `size` across, on a row every `spacing` metres along
// `run`, at `across` from the row's line.
float rivet(float run, float across, float spacing, float size) {
	float d = length(vec2((fract(run / spacing) - 0.5) * spacing, across));
	return 1.0 - smoothstep(size * 0.55, size, d);
}

void vertex() {
	rest = rest_pose ? CUSTOM0.xyz : VERTEX;
	rest_normal = rest_pose ? CUSTOM1.xyz : NORMAL;
}

void fragment() {
	if (keep_side != 0.0 && rest.x * keep_side < 0.0) discard;
	vec3 p = rest;
	vec3 n = normalize(rest_normal);
	bool leather = UV.x > 50.0;
	float across = leather ? UV.x - 100.0 : UV.x;
	// (glTF turns V over: 1 - V is the plate and how far across it.)
	float v = 1.0 - UV.y;
	float plate = floor(v + 0.0001);
	float f = clamp(v - plate, 0.0, 1.0);
	// Hammered steel: broad dents, a fine grain, darker oxidised patches,
	// rust specks, and scratches every which way.
	float dents = noise3(p * 55.0);
	float grain = noise2(vec2(p.x + p.z, p.y) * 900.0);
	float patina = smoothstep(0.45, 0.75, noise3(p * 14.0 + 3.0));
	float rust = smoothstep(0.82, 0.93, noise3(p * 60.0 + 11.0)) * smoothstep(0.55, 0.85, noise3(p * 9.0));
	float scratch = max(smoothstep(0.92, 0.97, noise2(vec2(p.x * 700.0 + p.y * 120.0, p.y * 25.0 + p.z * 40.0))), smoothstep(0.93, 0.97, noise2(vec2(p.y * 650.0 - p.z * 200.0, p.x * 30.0))));
	vec3 color = vec3(0.66, 0.67, 0.69) * (0.82 + dents * 0.22) * (0.95 + grain * 0.08);
	color = mix(color, vec3(0.32, 0.31, 0.3), patina * 0.55);
	color = mix(color, vec3(0.34, 0.19, 0.1), rust * 0.8);
	color = mix(color, vec3(0.8, 0.81, 0.82), scratch * 0.6);
	float h = (dents - 0.5) * 0.0012 - scratch * 0.0002;
	float rough = 0.32 + dents * 0.12 + patina * 0.25 + rust * 0.4 - scratch * 0.1;
	float metal = 1.0 - rust * 0.85;
	if (kind == 0) {
		// --- Pauldrons. Each plate's free edge is rolled and riveted; the
		// edge each lame laps under lies in the shadow of the plate above;
		// the cop is etched with a band along its rim.
		float rim = smoothstep(0.86, 0.95, f);
		h += 0.0018 * rim * (1.0 - smoothstep(0.95, 1.0, f));
		color *= 1.0 - 0.1 * rim;
		float row = rivet(across, (f - 0.8) * 0.05, 0.032, 0.0042);
		h += 0.0016 * row;
		color = mix(color, vec3(0.8), row * 0.45);
		if (plate > 0.5) {
			float under = 1.0 - smoothstep(0.0, 0.22, f);
			color *= 1.0 - 0.5 * under;
			rough += 0.15 * under;
		} else {
			// An etched band inside the cop's rim: two fine lines, darkened
			// between with old blacking.
			float band = smoothstep(0.66, 0.68, f) * (1.0 - smoothstep(0.76, 0.78, f));
			float lines = 1.0 - smoothstep(0.0, 0.006, min(abs(f - 0.67), abs(f - 0.77)));
			color *= 1.0 - 0.25 * band - 0.35 * lines;
			h -= 0.0004 * lines;
		}
	} else if (!leather) {
		// --- Gauntlets.
		if (plate < 0.5) {
			// The cuff: a rolled, riveted rim at its opening, a raised ridge
			// down the back of the wrist, and an etched band.
			float lip = 1.0 - smoothstep(0.0, 0.12, f);
			h += 0.002 * lip * smoothstep(0.0, 0.05, f);
			color *= 1.0 - 0.08 * lip;
			float row = rivet(across, (f - 0.17) * 0.11, 0.024, 0.0036);
			h += 0.0015 * row;
			color = mix(color, vec3(0.8), row * 0.45);
			float band = smoothstep(0.3, 0.32, f) * (1.0 - smoothstep(0.4, 0.42, f));
			color *= 1.0 - 0.22 * band;
			// Where the cuff meets the hand's lames, lapped over them.
			float edge = smoothstep(0.9, 1.0, f);
			color *= 1.0 - 0.15 * edge;
		} else {
			// Each lame, the knuckle plate and every finger's scales: dark in
			// the seam where it slides under the one before, its own edge
			// raised and catching the light.
			float seam = 1.0 - smoothstep(0.0, 0.16, f);
			color *= 1.0 - 0.55 * seam;
			h -= 0.0009 * seam;
			float lead = smoothstep(0.7, 0.96, f) * (1.0 - smoothstep(0.96, 1.0, f));
			h += 0.0008 * lead;
			color *= 1.0 + 0.08 * lead;
			if (plate > 4.5 && plate < 5.5) {
				// The knuckles, each a raised boss.
				float knuck = 1.0 - smoothstep(0.004, 0.011, abs(fract(across / 0.024) - 0.5) * 0.024);
				h += 0.0016 * knuck * smoothstep(0.2, 0.6, f);
			}
			rough += 0.04;
		}
	}
	vec3 dn = n;
	vec3 dw = tri_weights(dn);
	if (leather) {
		// --- The glove: oiled dark leather, creased across the palm and the
		// finger joints, a stitched seam down each side.
		float crease = noise3(p * vec3(160.0, 40.0, 160.0));
		color = vec3(0.17, 0.1, 0.06) * (0.75 + crease * 0.45);
		float stitch = (1.0 - smoothstep(0.0, 0.0012, abs(fract(across / 0.022) - 0.5) * 0.022)) * step(0.5, fract(v * 40.0));
		color = mix(color, vec3(0.32, 0.24, 0.16), stitch * 0.6);
		h = (crease - 0.5) * 0.0008;
		vec3 lp = p / 0.12;
		vec4 ld = mat_data(lp, dn, dw, MAT_LEATHER_WORN);
		color *= mix(1.0, mat_shade(lp, dn, dw, MAT_LEATHER_WORN), 0.45) * (0.8 + 0.2 * ld.g);
		rough = clamp(0.5 + ld.r * 0.35, 0.4, 0.85);
		metal = 0.0;
	} else {
		// The photographed steel: its scratches, mottling and pits, grime
		// in its hollows.
		vec3 dp = p / 0.3;
		vec4 scan = mat_data(dp, dn, dw, MAT_STEEL_WORN);
		color *= mix(1.0, mat_shade(dp, dn, dw, MAT_STEEL_WORN), 0.55) * (0.72 + 0.28 * scan.g);
		rough = rough * 0.75 + scan.r * 0.3 + (1.0 - scan.g) * 0.2 + 0.1;
	}
	ALBEDO = color;
	METALLIC = metal;
	ROUGHNESS = clamp(rough, 0.3, 0.9);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	if (!leather) {
		// Its edges rubbed bright.
		float edge = edge_wear(NORMAL, VERTEX, 0.003) * (1.0 - rust);
		ALBEDO = mix(ALBEDO, vec3(0.78, 0.79, 0.8), edge * 0.5);
		ROUGHNESS = mix(ROUGHNESS, 0.26, edge * 0.7);
		NORMAL = detail_normal(mat_normal(p / 0.3, dn, dw, MAT_STEEL_WORN, 0.8), dn, p, VERTEX, NORMAL);
	} else {
		NORMAL = detail_normal(mat_normal(p / 0.12, dn, dw, MAT_LEATHER_WORN, 1.2), dn, p, VERTEX, NORMAL);
	}
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
