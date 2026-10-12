shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Gilded leather (the Marathon Boots, tools/make_shoes.py): a brown hide
// with a thin leaf of gold over it. The photographed leather's grain and
// pores show through the gilt (assets/shaders/detail.gdshaderinc); the gold
// is uneven, duller in some places than others; the hide creases where the
// boot flexes, across the front of the ankle and over the toes; the gilt is
// rubbed through to the brown on the toe, the heel and the worn edges; and
// the pieces are joined by seams, a groove with a row of stitches either
// side: the welt round the sole, the toe cap, the quarters, the shaft's
// back and its top under the cuff.
//
// Laid in the boot's own space (metres about the ankle, as built: X out, Y
// up, Z forward), the same for every part of it.
#include "res://assets/shaders/detail.gdshaderinc"
uniform vec3 gilt : source_color = vec3(0.78, 0.6, 0.29);
uniform vec3 hide : source_color = vec3(0.2, 0.11, 0.05);
uniform vec3 thread : source_color = vec3(0.36, 0.25, 0.12);
uniform float tile = 0.045;
// (Kept in step with tools/make_shoes.py.)
const float SOLE_TOP = -0.087;
const float SHAFT_TOP = 0.243;
const float MID_X = 0.017;
const float SHAFT_X = 0.013;

varying vec3 boot;
varying vec3 boot_normal;

void vertex() {
	boot = VERTEX;
	boot_normal = NORMAL;
}

// A seam `d` metres off (a signed distance across it) at `along` metres
// along it: its groove (x) and its stitches either side (y), faded where
// they are too fine to see.
vec2 seam(float d, float along) {
	float fine = clamp(fwidth(d) / 0.0012, 0.0, 1.0);
	float groove = 1.0 - smoothstep(0.0004, 0.0013, abs(d));
	float row = 1.0 - smoothstep(0.00035, 0.0008, abs(abs(d) - 0.0028));
	float dash = smoothstep(0.15, 0.3, fract(along / 0.0042)) * (1.0 - smoothstep(0.7, 0.85, fract(along / 0.0042)));
	return vec2(groove * (1.0 - 0.5 * fine), row * dash * (1.0 - fine));
}

void fragment() {
	vec3 p = boot;
	vec3 n = normalize(boot_normal);
	vec3 w = tri_weights(n);
	vec3 q = p / tile;
	vec4 d = mat_data(q, n, w, MAT_LEATHER_WORN);
	float grain = mat_shade(q, n, w, MAT_LEATHER_WORN);
	float broad = detail_fbm(p * 22.0);
	float h = 0.0;

	// Creases: across the front of the ankle, where the foot bends against
	// the shin, and over the toes, where the vamp flexes; wandering a little,
	// deepest in the middle of each band.
	float wander = detail_noise(p * 70.0);
	float ankle_band = smoothstep(-0.035, -0.01, p.y) * (1.0 - smoothstep(0.05, 0.085, p.y)) * smoothstep(0.02, 0.06, p.z) * smoothstep(-0.2, 0.4, n.z);
	float ankle_phase = (p.y + 0.005 * sin(p.x * 55.0 + p.z * 30.0) + 0.006 * wander) / 0.011;
	float ankle_wave = cos(fract(ankle_phase) * 6.2832);
	// (Each crease its own length: broken off here and there along it.)
	float ankle_run = smoothstep(0.42, 0.62, detail_noise(vec3(p.x * 45.0 + p.z * 45.0, floor(ankle_phase) * 3.7, 1.0)));
	float toe_band = smoothstep(0.1, 0.13, p.z) * (1.0 - smoothstep(0.16, 0.185, p.z)) * smoothstep(0.1, 0.5, n.y);
	float toe_phase = (p.z + 9.0 * (p.x - MID_X) * (p.x - MID_X) + 0.005 * wander) / 0.014;
	float toe_wave = cos(fract(toe_phase) * 6.2832);
	float toe_run = smoothstep(0.4, 0.6, detail_noise(vec3(p.x * 60.0, floor(toe_phase) * 5.3, 2.0)));
	float crease = ankle_band * ankle_run * smoothstep(0.8, 1.0, ankle_wave) + toe_band * toe_run * smoothstep(0.82, 1.0, toe_wave) * 0.8;
	crease *= 1.0 - clamp(fwidth(p.y + p.z) / 0.003, 0.0, 1.0) * 0.6;
	h -= crease * 0.0006;

	// The seams.
	float welt_along = atan(p.x - MID_X, p.z - 0.07) * 0.09;
	vec2 welt = seam(p.y - (SOLE_TOP + 0.007), welt_along);
	float cap_line = p.z - (0.172 - 7.0 * (p.x - MID_X) * (p.x - MID_X));
	vec2 cap = seam(cap_line, p.x) * step(SOLE_TOP + 0.004, p.y);
	// (The quarters' seams run down each side from the ankle to the welt.)
	float side = abs(p.x - MID_X) - 0.03;
	vec2 quarter = seam(p.z - (0.035 + (0.03 - p.y) * 0.45), p.y) * step(0.0, side) * step(p.y, 0.03) * step(SOLE_TOP + 0.004, p.y);
	vec2 back_seam = seam(p.x - SHAFT_X, p.y) * step(p.z, -0.03) * step(-0.02, p.y);
	vec2 top = seam(p.y - (SHAFT_TOP - 0.004), atan(p.x - SHAFT_X, p.z) * 0.075);
	vec2 seams = max(max(max(welt, cap), max(quarter, back_seam)), top);
	h -= seams.x * 0.0005;
	h += seams.y * 0.0004;

	// Wear: the gilt rubbed through to the hide on the toe, the heel, low
	// round the welt and along the boot's edges; scuffed in patches.
	float scuff_noise = detail_fbm(p * 45.0 + 7.0);
	float toe = smoothstep(0.215, 0.245, p.z);
	float heel = smoothstep(-0.055, -0.08, p.z) * smoothstep(-0.03, -0.07, p.y);
	float low = 1.0 - smoothstep(SOLE_TOP + 0.003, SOLE_TOP + 0.02, p.y);
	float edge = edge_wear(NORMAL, VERTEX, 0.004);
	float rub = clamp((toe * 0.4 + heel * 0.4 + low * 0.4) * smoothstep(0.5, 0.8, scuff_noise) + edge * 0.25 + crease * 0.25, 0.0, 1.0);
	float scuff = smoothstep(0.72, 0.8, detail_fbm(p * 40.0 + 3.0)) * (0.4 + 0.4 * toe);

	// The gilt: uneven, its leaf thinner or duller here and there; the
	// leather's pores and grain dark through it.
	vec3 leaf = gilt * (0.82 + 0.32 * broad) * mix(1.0, grain, 0.45) * (0.7 + 0.3 * d.g);
	leaf = mix(leaf, leaf * vec3(1.05, 0.95, 0.82), smoothstep(0.55, 0.75, detail_fbm(p * 9.0 + 11.0)) * 0.6);
	vec3 brown = hide * mix(1.0, grain, 0.7) * (0.75 + 0.35 * broad);
	vec3 colour = mix(leaf, brown, rub);
	colour = mix(colour, colour * vec3(0.92, 0.88, 0.8) * 1.08, scuff * 0.5);
	colour *= 1.0 - crease * 0.4;
	colour *= 1.0 - seams.x * 0.55;
	colour = mix(colour, thread * (0.8 + 0.4 * grain), seams.y);
	ALBEDO = colour;
	float gilded = (1.0 - rub) * (1.0 - seams.y) * (1.0 - 0.5 * scuff);
	METALLIC = 0.55 * gilded;
	ROUGHNESS = mix(0.78 + 0.15 * d.r, mix(0.32, 0.62, d.r) + 0.12 * broad + 0.2 * scuff, gilded);
	SPECULAR = 0.4;
	// The relief: the hide's grain, and the creases and seams over it.
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	NORMAL = detail_normal(mat_normal(q, n, w, MAT_LEATHER_WORN, 2.2), n, p, VERTEX, NORMAL);
}
