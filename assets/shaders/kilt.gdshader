shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// The warrior's armoured kilt, after his concept art, on a ring of hanging
// cloth that swings and folds over his legs (assets/shaders/cloth_fold.gdshaderinc):
// a row of short rounded tabs with steel studs under the belt, then long
// pteruges, strips of dark leather each with a steel leaf motif and a
// Greek-key band, hanging apart over a dark red linen underskirt that shows
// between them, frayed at the hem. Laid on the kilt's rest pose (CUSTOM0), so the
// pattern stays on the cloth as it moves.
#include "res://assets/shaders/cloth_fold.gdshaderinc"
uniform float shadowed = 0.0;
uniform bool rest_pose = false;
uniform float top = 0.995;
uniform float hem = 0.64;
// The rest pose's centre line, in the mesh's space (x, z).
uniform vec2 centre = vec2(0.0, -0.025);
const float STRIPS = 18.0;

varying vec3 cloth_position;

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
	cloth_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	VERTEX = fold_cloth(VERTEX);
}

// An item of another make (scripts/items.gd `tint`): its colours redrawn in
// that one, keeping their light and dark.
uniform vec3 tint : source_color = vec3(1.0);
uniform float recolor = 0.0;

void fragment() {
	vec3 p = cloth_position;
	float around = atan(p.x - centre.x, p.z - centre.y) / 6.28318 + 0.5;
	float t = clamp((top - p.y) / (top - hem), 0.0, 1.0);
	float strip = floor(around * STRIPS);
	float u = fract(around * STRIPS);
	float seed = hash2(vec2(strip, 3.0));
	vec2 wear_uv = vec2(around * 40.0, p.y * 30.0);
	float wear = fbm2(wear_uv);
	vec3 leather = vec3(0.17, 0.13, 0.12) * (0.75 + wear * 0.5) * (0.9 + seed * 0.2);
	// A dull red cast to some strips, as in the concept.
	leather = mix(leather, vec3(0.22, 0.11, 0.1) * (0.8 + wear * 0.4), step(0.6, seed) * 0.6);
	vec3 steel = vec3(0.5, 0.51, 0.53) * (0.7 + fbm2(wear_uv * 2.0) * 0.45);
	vec3 color = leather;
	float h = 0.0;
	float metal = 0.0;
	if (t < 0.24) {
		// The upper row: short rounded tabs, offset half a strip, each with a
		// steel stud.
		float uu = fract(around * STRIPS + 0.5);
		float tt = t / 0.24;
		float edge = length(vec2((uu - 0.5) * 1.6, max(tt - 0.55, 0.0) * 2.2));
		if (edge > 0.8 && tt > 0.5) {
			// Between the tabs, the strips below show.
		} else {
			color = mix(leather * 1.15, leather * 0.6, smoothstep(0.62, 0.8, edge));
			h = 0.002 * (1.0 - smoothstep(0.6, 0.8, edge));
			float stud = length(vec2((uu - 0.5) * 0.9, (tt - 0.42) * 0.55));
			if (stud < 0.07) { color = steel * 1.2; h = 0.004 * (1.0 - stud / 0.07); metal = 1.0; }
		}
	}
	if (t >= 0.24 || color == leather) {
		// The long strips, hanging apart: between them the underskirt shows,
		// a dark red linen in shadow, sunk behind the strips (never the
		// legs or the ground through the kilt).
		float gap = 0.07 + 0.04 * smoothstep(0.3, 1.0, t);
		if ((u < gap || u > 1.0 - gap) && t > 0.2) {
			float threads = 0.85 + 0.15 * noise2(vec2(around * 900.0, p.y * 120.0));
			color = vec3(0.13, 0.065, 0.06) * threads * (0.8 + wear * 0.3);
			h = -0.002;
		} else {
			// A raised rim and stitched edges.
			float rim = min(u - gap, 1.0 - gap - u);
			color = leather * (0.8 + 0.35 * smoothstep(0.0, 0.08, rim));
			h = 0.0015 * smoothstep(0.0, 0.06, rim);
			if (abs(rim - 0.07) < 0.012 && fract(p.y * 90.0) < 0.5) color *= 1.5;
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
			if (kb > 0.0 && kb < 1.0) {
				float kx = fract(u * 3.0);
				bool line = kb < 0.15 || kb > 0.85 || kx < 0.15 || (kx < 0.65 && kb > 0.55 && kb < 0.7) || (kx > 0.5 && kx < 0.65 && kb > 0.3);
				if (line) { color = steel * 0.95; h = 0.0012; metal = 0.7; }
			}
		}
	}
	// The hem frays.
	if (t > 0.93 && noise2(vec2(around * 300.0, p.y * 60.0)) * 0.08 > 1.0 - t) discard;
	// (Hidden in the shadows: scripts/visual.gd set_shadowed.)
	ALBEDO = mix(color, vec3(0.02, 0.02, 0.04), shadowed * 0.92);
	METALLIC = metal * 0.45;
	ROUGHNESS = mix(0.82, 0.38, metal);
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	ALBEDO = mix(ALBEDO, dot(ALBEDO, vec3(0.299, 0.587, 0.114)) * tint * 1.8, recolor);
}
