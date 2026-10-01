shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// A cloak that folds over the legs instead of letting them through
// (assets/shaders/cloth_fold.gdshaderinc), in felted wool: mottled, with a
// fuzzy weave. With `tatter` the hem is frayed and torn into ragged tongues,
// a few holes are worn through low down, and the cloth is grimed toward the
// hem. Patterns are laid on the cloak's rest pose (CUSTOM0, from
// Art.rest_pose_mesh), so they stay fixed to the cloth as it swings.
#include "res://assets/shaders/cloth_fold.gdshaderinc"
uniform vec3 cloth_color : source_color = vec3(0.1, 0.19, 0.1);
uniform bool rest_pose = false;
// 0: a clean garment; 1: a ranger's weathered, tattered cloak.
uniform float tatter = 0.0;
// The rest-pose height of the hem, in metres.
uniform float hem_height = 0.3;

varying vec3 cloth_position;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1,0,0)), f.x),
		mix(hash3(i + vec3(0,1,0)), hash3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0,0,1)), hash3(i + vec3(1,0,1)), f.x),
		mix(hash3(i + vec3(0,1,1)), hash3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm3(vec3 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += noise3(p) * amplitude;
		p = p * 2.07 + vec3(11.3, 7.1, 3.7);
		amplitude *= 0.5;
	}
	return total / 0.9375;
}

void vertex() {
	cloth_position = rest_pose ? CUSTOM0.xyz : VERTEX;
	VERTEX = fold_cloth(VERTEX);
}

void fragment() {
	vec3 p = cloth_position;
	if (tatter > 0.0) {
		// The hem frays into ragged tongues of differing length.
		float ragged = fbm3(vec3(p.x, 0.0, p.z) * 9.0) * 0.11 + noise3(vec3(p.x, 0.0, p.z) * 55.0) * 0.025;
		if (p.y < hem_height + ragged * tatter) discard;
		// A few holes worn through, low on a badly worn cloak.
		float wear = fbm3(p * 7.0 + 21.0);
		float low = 1.0 - smoothstep(hem_height + 0.15, hem_height + 0.5, p.y);
		if (tatter > 0.6 && wear * low > 0.66) discard;
	}
	// Felted wool: broad mottling, a darker grain and a fuzz.
	float mottle = fbm3(p * 4.5);
	float grain = noise3(p * 60.0);
	float fuzz = noise3(p * 260.0);
	vec3 color = cloth_color * (0.72 + mottle * 0.55);
	color *= 0.9 + grain * 0.14 + fuzz * 0.08;
	// Paler, olive patches where the dye has faded.
	color = mix(color, color * vec3(1.25, 1.2, 0.95), smoothstep(0.62, 0.8, fbm3(p * 2.2 + 5.0)) * tatter);
	// Grime and wear darken the cloth toward the hem.
	float grime = (1.0 - smoothstep(hem_height, hem_height + 0.45, p.y)) * tatter;
	color *= 1.0 - grime * (0.35 + mottle * 0.2);
	ALBEDO = color;
	// The fuzz and grain catch the light a little.
	float h = grain * 0.0012 + fuzz * 0.0005;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
