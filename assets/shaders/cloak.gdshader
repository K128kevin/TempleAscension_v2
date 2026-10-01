shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap, specular_schlick_ggx;

// A cloak that folds over the legs instead of letting them through
// (assets/shaders/cloth_fold.gdshaderinc), in felted wool: mottled, with a
// fuzzy weave. With `tatter` the hem is frayed and torn into ragged tongues,
// the wool is rubbed thin in places low down (never through), and
// the cloth is grimed toward the hem. Patterns are laid on the cloak's rest pose (CUSTOM0, from
// Art.rest_pose_mesh), so they stay fixed to the cloth as it swings.
#include "res://assets/shaders/cloth_fold.gdshaderinc"
uniform vec3 cloth_color : source_color = vec3(0.1, 0.19, 0.1);
uniform bool rest_pose = false;
// 0: a clean garment; 1: a ranger's weathered, tattered cloak.
uniform float tatter = 0.0;
// The rest-pose height of the hem, in metres.
uniform float hem_height = 0.3;
// The drape: soft vertical folds that deepen toward the hem.
uniform float fold_depth = 0.004;
// A wizard's robe (1), after his concept art: a wrap collar crossing the
// chest, the front opened below the sash over a dark under-robe, a stitched
// band round the hem and cuffs at the wide sleeves' ends (`sleeve_end`: how
// far out along the arms they reach, in the rest pose).
uniform float robe = 0.0;
uniform float sleeve_end = 0.56;

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
	float thin = 0.0;
	if (tatter > 0.0) {
		// The hem frays into ragged tongues of differing length.
		float ragged = fbm3(vec3(p.x, 0.0, p.z) * 9.0) * 0.11 + noise3(vec3(p.x, 0.0, p.z) * 55.0) * 0.025;
		if (p.y < hem_height + ragged * tatter) discard;
		// Low on a badly worn cloak the wool is rubbed thin in patches: paler,
		// flatter, its weave showing.
		float wear = fbm3(p * 7.0 + 21.0);
		float low = 1.0 - smoothstep(hem_height + 0.15, hem_height + 0.5, p.y);
		thin = smoothstep(0.58, 0.7, wear * low) * step(0.6, tatter);
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
	// Worn patches: the nap rubbed off, the weave showing through.
	float weave = abs(sin(p.x * 900.0 + p.z * 900.0)) * abs(sin(p.y * 900.0));
	color = mix(color, color * (1.15 + weave * 0.25), thin);
	// The grain catches the light a little (the fuzz only tints: as relief
	// it glittered like satin).
	float h = grain * 0.0006;
	// The drape: folds running down from the shoulders, deeper and broader
	// toward the hem, wandering a little.
	float around = atan(p.x, p.z + 0.03);
	float hang = clamp((1.45 - p.y) / 1.1, 0.0, 1.0);
	float wander = fbm3(vec3(p.x, p.y * 0.35, p.z) * 3.0) * 4.0;
	float fold = sin(around * 7.0 + wander) * 0.65 + sin(around * 13.0 + wander * 1.7) * 0.35;
	h += fold * fold_depth * hang;
	color *= 1.0 - (0.5 - 0.5 * fold) * 0.12 * hang;
	// Worn: the dye faded and dusty on the raised folds and toward the hem.
	float dust = (1.0 - smoothstep(hem_height, hem_height + 0.7, p.y)) * 0.5 + max(fold, 0.0) * 0.25 * hang;
	float grey = dot(color, vec3(0.3, 0.5, 0.2));
	color = mix(color, vec3(grey) * vec3(1.12, 1.06, 0.95), clamp(dust * (0.25 + mottle * 0.3), 0.0, 0.4));
	if (robe > 0.5) {
		vec3 trim = color * 0.55;
		vec3 thread = mix(cloth_color * 2.4, vec3(0.42, 0.44, 0.48), 0.35);
		bool front = p.z > 0.03 && abs(p.x) < 0.3;
		// The hem band, with a line of stitching along its top.
		float band = hem_height + 0.075;
		if (p.y < band) { color = trim; h += 0.0012; }
		if (abs(p.y - band + 0.008) < 0.0016 && fract(around * 60.0) < 0.55) color = thread;
		// The cuffs of the wide sleeves.
		float reach = abs(p.x);
		if (reach > sleeve_end - 0.06 && reach > 0.4) { color = trim; h += 0.0012; }
		if (reach > 0.4 && abs(reach - sleeve_end + 0.068) < 0.0016 && fract(p.y * 220.0 + p.z * 220.0) < 0.55) color = thread;
		if (front && p.y < 0.975) {
			// Below the sash the robe falls open a little over a dark under-robe,
			// wider toward the hem, each edge bound in a darker trim.
			float open = 0.004 + 0.035 * clamp((0.975 - p.y) / 0.8, 0.0, 1.0);
			float edge = abs(p.x - 0.012);
			if (edge < open) { color = vec3(0.045, 0.04, 0.038) * (0.8 + mottle * 0.4); h -= 0.003; }
			else if (edge < open + 0.02) { color = trim; h += 0.0015; }
			if (abs(edge - open - 0.024) < 0.0015 && fract(p.y * 110.0) < 0.55) color = thread;
		} else if (front && p.y < 1.55) {
			// The wrap collar: the right lapel crossing over to the left hip,
			// the left one's edge showing at the neck.
			float lapel = -0.06 + (p.y - 1.0) * 0.31;
			float under = 0.07 - (p.y - 1.0) * 0.36;
			float d = min(abs(p.x - lapel), p.y > 1.3 ? abs(p.x + under) : 1.0);
			if (d < 0.022) { color = trim * (0.9 + 0.2 * smoothstep(0.022, 0.0, d)); h += 0.0018 * smoothstep(0.022, 0.012, d); }
			if (abs(d - 0.027) < 0.0015 && fract(p.y * 110.0) < 0.55) color = thread;
			// The overlapping lapel casts a little shadow on the cloth beneath.
			if (p.x < lapel - 0.022 && p.x > lapel - 0.05) color *= 0.8;
		}
	}
	ALBEDO = color;
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 r1 = cross(sy, NORMAL);
	vec3 r2 = cross(NORMAL, sx);
	float det = dot(sx, r1);
	vec3 gradient = (dFdx(h) * r1 + dFdy(h) * r2) * sign(det) / max(abs(det), 0.000001);
	NORMAL = normalize(NORMAL - gradient);
	// A dull, matte wool.
	ROUGHNESS = 1.0;
	SPECULAR = 0.03;
}
